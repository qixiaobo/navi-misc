""" pyunicone.device

Low-level interface for initializing the Unicone device
and communicating with controller emulators installed in its FPGA.

"""
#
# Universal Controller Emulator project
# Copyright (C) 2004 Micah Dowty
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

from libunicone import *

__all__ = ["UniconeDevice"]


class UniconeDevice:
    """Low-level interface for initializing the Unicone device
       and communicating with controller emulators installed in its FPGA.
       """
    _dev = None

    def __init__(self):
        unicone_usb_init()
        self._dev = unicone_device_new()
        if not self._dev:
            raise IOError("Unable to open Unicone device")

    def __del__(self):
        if self._dev:
            unicone_device_delete(self._dev)

    def configure(self, bitstream,
                  firmware = "firmware.bin",
                  progress = None):
        if unicone_device_configure(self._dev, firmware,
                                    bitstream, progress) < 0:
            raise IOError("Error configuring unicone device")

    def setLed(self, brightness, decayRate=0):
        unicone_device_set_led(self._dev, brightness, decayRate)

### The End ###
