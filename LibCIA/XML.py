""" LibCIA.XML

Helpful utilities for dealing with DOM trees and higher-level objects built on them
"""
#
# CIA open source notification system
# Copyright (C) 2003-2004 Micah Dowty <micah@navi.cx>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

import types, os, shutil
import Nouvelle
from Ft.Xml import Domlette
from cStringIO import StringIO

parseString = Domlette.NonvalidatingReader.parseString


class XMLObject(object):
    """An object based on an XML document tree. This class provides
       methods to load it from a string or a DOM tree, and convert
       it back to an XML string.

       'xml' is either a DOM node, a string containing
       the message in XML, or a stream-like object.
       """
    defaultUri = "cia://anonymous-xml"

    def __init__(self, xml=None, uri=None):
        if type(xml) in types.StringTypes:
            self.loadFromString(xml, uri)
        elif hasattr(xml, 'read'):
            self.loadFromStream(xml, uri)
        elif hasattr(xml, 'nodeType'):
            self.loadFromDom(xml)

    def __str__(self):
        io = StringIO()
        Domlette.Print(self.xml, io)
        return io.getvalue()

    def loadFromString(self, string, uri=None):
        """Parse the given string as XML and set the contents of the message"""
        self.loadFromDom(Domlette.NonvalidatingReader.parseString(string, uri or self.defaultUri))

    def loadFromStream(self, stream, uri=None):
        """Parse the given stream as XML and set the contents of the message"""
        self.loadFromDom(Domlette.NonvalidatingReader.parseStream(string, uri or self.defaultUri))

    def loadFromDom(self, root):
        """Set the contents of the Message from a parsed DOM tree"""
        self.xml = root
        self.preprocess()

    def preprocess(self):
        """A hook where subclasses can add code to inspect a freshly
           loaded XML document and/or fill in any missing information.
           """
        pass


class XMLObjectParser(XMLObject):
    """An XMLObject that is parsed recursively on creation into any
       python object, stored in 'resultAttribute'. parse() dispatches
       control to an element_* method when it finds an element, and
       to parseString when it comes to character data.
       """
    requiredRootElement = None
    resultAttribute = 'result'

    def preprocess(self):
        """Upon creating this object, parse the XML tree recursively.
           The result returned from parsing the tree's root element
           is set to our resultAttribute.
           """
        docElement = self.xml.documentElement

        # Validate the root element type if the subclass wants us to.
        # This is hard to do elsewhere, since the element handlers don't
        # know where they are in the XML document.
        if self.requiredRootElement is not None:
            if docElement.nodeName != self.requiredRootElement:
                raise XMLValidityError("Found a %r element where a root element of %r is required" %
                                       (docElement.nodeName, self.requiredRootElement))

        setattr(self, self.resultAttribute, self.parse(docElement))

    def parse(self, node, *args, **kwargs):
        """Given a DOM node, finds an appropriate parse function and invokes it"""
        if node.nodeType == node.TEXT_NODE:
            return self.parseString(node.data, *args, **kwargs)

        elif node.nodeType == node.ELEMENT_NODE:
            f = getattr(self, "element_" + node.nodeName, None)
            if f:
                return f(node, *args, **kwargs)
            else:
                return self.unknownElement(node, *args, **kwargs)

    def childParser(self, node, *args, **kwargs):
        """A generator that parses all relevant child nodes, yielding their return values"""
        parseableTypes = (node.TEXT_NODE, node.ELEMENT_NODE)
        for child in node.childNodes:
            if child.nodeType in parseableTypes:
                yield self.parse(child, *args, **kwargs)

    def parseString(self, s):
        """The analogue to element_* for character data"""
        pass

    def unknownElement(self, element):
        """An unknown element was found, by default just generates an exception"""
        raise XMLValidityError("Unknown element name in %s: %r" % (self.__class__.__name__, element.nodeName))


class XMLFunction(XMLObjectParser):
    """An XMLObject that is parsed on creation into a function,
       making this class callable. The parser relies on member functions
       starting with 'element_' to recursively parse each element of the XML
       tree, returning a function implementing it.
       """
    resultAttribute = 'f'

    def __call__(self, *args, **kwargs):
        return self.f(*args, **kwargs)


class XMLValidityError(Exception):
    """This error is raised by subclasses of XMLObject that encounter problems
       in the structure of XML documents presented to them. Normally this should
       correspond with the document not being valid according to its schema,
       but we don't actually use a validating parser.
       """
    pass


def allTextGenerator(node):
    """A generator that, given a DOM tree, yields all text fragments in that tree"""
    if node.nodeType == node.TEXT_NODE:
        yield node.data
    for child in node.childNodes:
        for text in allTextGenerator(child):
            yield text


def allText(node):
    """Concatenate all text under the given element recursively, and return it"""
    return "".join(allTextGenerator(node))


def shallowTextGenerator(node):
    """A generator that, given a DOM tree, yields all text fragments contained immediately within"""
    if node.nodeType == node.TEXT_NODE:
        yield node.data


def shallowText(node):
    """Concatenate all text immediately within the given node"""
    return "".join(shallowText(node))


class HTMLPrettyPrinter(XMLObjectParser):
    """An object parser that converts arbitrary XML to pretty-printed
       representations in the form of Nouvelle-serializable tag trees.
       """
    def parseString(self, s):
        s = s.strip()
        if s:
            return Nouvelle.tag('p', _class='xml-text')[ s ]
        else:
            return ()

    def unknownElement(self, element):
        # Format the element name and attributes
        elementName = Nouvelle.tag('span', _class="xml-element-name")[ element.nodeName ]
        elementContent = [ elementName ]
        for attr in element.attributes.itervalues():
            elementContent.extend([
                ' ',
                Nouvelle.tag('span', _class='xml-attribute-name')[ attr.name ],
                '="',
                Nouvelle.tag('span', _class='xml-attribute-value')[ attr.value ],
                '"',
                ])

        # Now the contents...
        if element.hasChildNodes():
            completeElement = [
                "<", elementContent, ">",
                Nouvelle.tag('blockquote', _class='xml-element-content')[
                    [self.parse(e) for e in element.childNodes],
                ],
                "</", elementName, ">",
                ]
        else:
            completeElement = ["<", elementContent, "/>"]

        return Nouvelle.tag('div', _class='xml-element')[ completeElement ]

htmlPrettyPrint = HTMLPrettyPrinter().parse

### The End ###
