""" BZFlag.Client

Provides the BaseClient class, which implements basic communication
with the server and provides hooks for adding more functionality
in subclasses.
"""
# 
# Python BZFlag Protocol Package
# Copyright (C) 2003 Micah Dowty <micahjd@users.sourceforge.net>
# 
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
# 

import BZFlag
from BZFlag import Network, Protocol, Errors, Player
from BZFlag.Protocol import FromServer, ToServer, Common


class BaseClient:
    """Implements a very simple but extensible BZFlag client.
       This client can connect and disconnect, and it has a system
       for asynchronously processing messages. This class only processes
       messages related to upkeep on the server-client link, such as
       lag ping, disconnection, and UDP-related messages.

       The methods of this class and its subclasses use the following
       naming conventions:

         - Low-level socket handlers should be of the form handleFoo()
         - Event handlers for messages should be of the form onMsgFoo()
         - Event handlers for message replies should be of the form onMsgFooReply()
         - Event handlers for other events should be of the form onFoo()
       """
    def __init__(self, server=None):
        self.tcp = None
        self.udp = None
        self.connected = 0
        if server:
            self.connect(server)

    def connect(self, server):
        """This does the bare minimum necessary to connect to the
           BZFlag server. It does not negotiate flags, obtain the
           world database, or join the game. After this function
           returns, the client is connected to the server and can
           receive and transmit messages.
           """
        # Establish the TCP socket
        if self.tcp:
            self.disconnect()
        self.tcp = Network.Socket()
        self.tcp.connect(server, Common.defaultPort)
        self.tcp.setBlocking(0)

        # Until we establish a UDP connection, we'll need to send
        # normally-multicasted messages over TCP
        self.multicast = self.tcp

        # Now we have to wait for the server's Hello packet,
        # with the server version and client ID.
        self.tcp.handler = self.handleHelloPacket

    def disconnect(self):
        # Send a MsgExit first as a courtesy
        self.tcp.write(ToServer.MsgExit())
        if self.tcp:
            self.tcp.close()
            self.tcp = None
        if self.udp:
            self.udp.close()
            self.udp = None
        self.multicast = None
        self.connected = 0

    def getSockets(self):
        """Returns a list of sockets the client expects
           incoming data on. This is meant to be used with the
           Network.EventLoop class or compatible.
           """
        sockets = []
        if self.tcp:
            sockets.append(self.tcp)
        if self.udp:
            sockets.append(self.udp)
        return sockets

    def run(self):
        """A simple built-in event loop, for those not wanting
           to integrate the BZFlag client into an existing event
           loop using the above getSockets() and the sockets'
           poll() method.
           """
        Network.EventLoop().run(self.getSockets())

    def handleHelloPacket(self, socket, eventLoop):
        """This is a callback used to handle incoming socket
           data when we're expecting a hello packet.
           """
        # We should have just received a Hello packet with
        # the server version and our client ID.
        hello = socket.readStruct(FromServer.HelloPacket)
        if hello.version != BZFlag.protocolVersion:
            raise Errors.ProtocolException(
                "Protocol version mismatch: The server is version " +
                "'%s', this client is version '%s'." % (
                hello.version, BZFlag.protocolVersion))
        self.id = hello.clientId
        
        # Now we're connected
        self.connected = 1
        socket.handler = self.handleMessage
        self.onConnect()

    def handleMessage(self, socket, eventLoop):
        """This is a callback used to handle incoming socket
           data when we're expecting a message.
           """
        # This can return None if part of the mesasge but not the whole
        # thing is available. The rest of the message will be rebuffered,
        # so we'll read the whole thing next time this is called.
        msg = socket.readMessage(FromServer)
        if msg:
            msg.socket = socket
            msg.eventLoop = eventLoop
            msgName = msg.__class__.__name__
            handler = getattr(self, "on%s" % msgName, None)
            if self.onAnyMessage(msg):
                return
            if handler:
                handler(msg)
            else:
                self.onUnhandledMessage(msg)

    def onConnect(self):
        """This is called after a connection has been established.
           By default it doesn't do anything, it's up to subclasses
           to define what this does next.
           """
        pass

    def onAnyMessage(self, msg):
        """This is a hook that subclasses can use to easily
           monitor and intercept messages. It is called before
           dispatching each message, and if it returns true that
           message is cancelled.
           """
        return None

    def onUnhandledMessage(self, msg):
        raise Errors.ProtocolException("Unhandled message %s" % msg.__class__.__name__)
    
    def onMsgSuperKill(self, msg):
        """The server wants us to die immediately"""
        self.disconnect()

    def onMsgLagPing(self, msg):
        """The server is measuring our lag, reply with the same message."""
        msg.socket.write(msg)

    def onMsgNetworkRelay(self, msg):
        """The server needs us to use TCP instead of UDP for messages
           that we'd normally multicast.
           """
        self.multicast = self.tcp

        
class StatefulClient(BaseClient):
    """Extends the BaseClient to keep track of the state of the game
       world, as reported by the server and the other clients.
       """
    def onMsgFlagUpdate(self, msg):
        pass

    def onMsgTeamUpdate(self, msg):
        pass

    def onMsgAddPlayer(self, msg):
        pass

    def onMsgRemovePlayer(self, msg):
        pass

    def onMsgNewRabbit(self, msg):
        pass

    def onMsgAlive(self, msg):
        pass

    def onMsgPlayerUpdate(self, msg):
        pass

    def onMsgShotBegin(self, msg):
        pass


class PlayerClient(StatefulClient):
    """Extends the StatefulClient with functionality for implementing
       a player. This includes methods for entering and leaving the
       game, and a method of glueing the client with a frontend that
       provides actual player interaction, or a bot AI.
       """
    def __init__(self, server, playerIdentity):
        self.player = Player.Player(playerIdentity)
        StatefulClient.__init__(self, server)

    def onConnect(self):
        self.enterGame()

    def enterGame(self):
        msg = ToServer.MsgEnter()
        msg.playerType = self.player.identity.type
        msg.team = self.player.identity.team
        msg.callSign = self.player.identity.callSign
        msg.emailAddress = self.player.identity.emailAddress
        self.tcp.write(msg)

    def exitGame(self):
        self.tcp.write(ToServer.MsgExit())

    def onMsgAccept(self, msg):
        """This is called after we try to enterGame, if it's successful."""
        self.onEnterGame()

    def onEnterGame(self):
        pass

    def onMsgReject(self, msg):
        """This is called after we try to enterGame, if we failed."""
        raise Errors.GameException("Unable to enter the game: %s" % msg.reason)


### The End ###
        
    
