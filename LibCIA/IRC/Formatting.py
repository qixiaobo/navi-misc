""" LibCIA.IRC.Formatting

A thin abstraction for IRC formatting codes, and a converter
that generates IRC-formatted text from a <colorText> XML document.
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

from LibCIA import XML, ColorText
import types


class FormattingCode(object):
    """Represents a code used to format text in IRC"""
    codes = {
        # Colors
        "black"       : "\x0301",
        "dark blue"   : "\x0302",
        "dark green"  : "\x0303",
        "green"       : "\x0303",
        "red"         : "\x0304",
        "light red"   : "\x0304",
        "dark red"    : "\x0305",
        "purple"      : "\x0306",
        "brown"       : "\x0307",  # On some clients this is orange, others it is brown
        "orange"      : "\x0307",
        "yellow"      : "\x0308",
        "light green" : "\x0309",
        "aqua"        : "\x0310",
        "light blue"  : "\x0311",
        "blue"        : "\x0312",
        "violet"      : "\x0313",
        "grey"        : "\x0314",
        "gray"        : "\x0314",
        "light grey"  : "\x0315",
        "light gray"  : "\x0315",
        "white"       : "\x0316",

        # Other formatting
        "normal"      : "\x0F",
        "bold"        : "\x02",
        "reverse"     : "\x16",
        "underline"   : "\x1F",
        }

    def __init__(self, name):
        self.name = name
        self.value = self.codes[name]

    def __str__(self):
        return self.value


def format(text, *codeNames):
    """Apply each formatting code from the given list of code names
       to the given text, returnging a string ready for consumption
       by an IRC client.
       """
    if codeNames:
        codes = "".join([str(FormattingCode(codeName)) for codeName in codeNames])
        return codes + text + str(FormattingCode('normal'))
    else:
        return text


class ColortextFormatter(XML.XMLObjectParser):
    r"""Given a DOM tree with <colorText>-formatted text
        generate an equivalent message formatted for IRC.

        >>> f = ColortextFormatter()
        >>> f.parse(XML.parseString('<colorText><u><b>Hello</b> World</u></colorText>'))
        '\x1f\x02Hello\x0f\x1f World\x0f'

        >>> f.parse(XML.parseString(
        ...    "<colorText>" +
        ...        "<color bg='dark blue'><color fg='yellow'>" +
        ...            "<b>hello</b>" +
        ...        "</color></color>" +
        ...        "<u> world</u>" +
        ...    "</colorText>"))
        '\x0302\x16\x0308\x02hello\x0f\x1f world\x0f'

        """

    def element_colorText(self, node):
        # The root element converts our list of formatting codes to a flat string
        codes = []
        for childCodes in self.childParser(node, ()):
            codes.extend(childCodes)
        return "".join([str(code) for code in codes])

    def codeWrap(self, node, codeStack, *codeNames):
        """Wrap the children of the given xml element with the given formatting codes.
           This prepends the code list and appends a 'normal' tag, using codeStack
           to restore any codes we don't want to disable with the 'normal' tag.
           """
        # Apply all the codes we're given
        codes = [FormattingCode(name) for name in codeNames]

        # Insert the children here
        for childCodes in self.childParser(node, codeStack + tuple(codes)):
            codes.extend(childCodes)

        # An important optimization- since we're about to insert new codes
        # for everything in codeStack, remove codes from our 'codes' list until
        # we hit actual text. This prevents sequences from appearing in the output
        # where several codes are applied then immediately erased by a 'normal' code.
        # This also handles optimizing out formatting codes with no children.
        while codes and isinstance(codes[-1], FormattingCode):
            del codes[-1]

        # Now stick on a 'normal' code and the contents of our codeStack
        # to revert the codes we were given.
        codes.append(FormattingCode('normal'))
        codes.extend(codeStack)
        return codes

    def element_b(self, xml, codeStack):
        """Just wrap our contents in a bold tag"""
        return self.codeWrap(xml, codeStack, 'bold')

    def element_u(self, xml, codeStack):
        """Just wrap our contents in an underline tag"""
        return self.codeWrap(xml, codeStack, 'underline')

    def element_br(self, xml, codeStack):
        """Insert a literal newline"""
        return ["\n"]

    def element_color(self, xml, codeStack):
        """Generates formatting codes appropriate to represent a foreground and/or background color"""
        codes = []
        bg = xml.getAttributeNS(None, 'bg')

        if bg:
            if bg in ColorText.allowedColors:
                codes.append(bg)
                codes.append('reverse')
            else:
                raise XML.XMLValidityError("%r is not a color" % bg)
        if fg:
            if fg in ColorText.allowedColors:
                codes.append(fg)
            else:
                raise XML.XMLValidityError("%r is not a color" % fg)

        return self.codeWrap(xml, codeStack, *codes)

### The End ###
