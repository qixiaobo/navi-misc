{{                                              

os3rx - Oregon Scientific protocol V3.0 Receiver
────────────────────────────────────────────────

This is a receiver for the radio protocol used by Oregon
Scientific's wireless weather station devices. This module
has been written for protocol V3.0, because it's the newest
and it's what I have sensors for. If you have earlier sensors,
it might be possible to modify this module to work with them.

This module was produced without any documentation from Oregon
Scientific, using basic black-box reverse engineering of the
radio protocol. 

These modules use OOK (ASK) modulation at 433.92 MHz. You
should be able to use this module with any off-the-shelf OOK
or ASK receiver module that operates at this frequency with
at least 2 kHZ of bandwidth. I developed this module using
an MRX-011 receiver from Radios Inc (About $10 US in Feb 2009).

 ┌───────────────────────────────────┐
 │ Copyright (c) 2009 Micah Dowty    │               
 │ See end of file for terms of use. │
 └───────────────────────────────────┘

}}

CON
  ' I'm guessing that the nominal baud rate of the Oregon Scientific
  ' protocol is 2 KHz. It may actually be 2048 Hz, though this decoder
  ' includes clock recovery so there's a bit of wiggle room in the
  ' frequency.
  '
  ' Note that the actual *bit* rate is half this, due to the
  ' manchester encoding.

  NOMINAL_BAUD = 2000

  ' Sample at a multiple of the bit rate. The sampling rate needs
  ' to be at least twice the bandwidth of your radio. The MRX-011
  ' data sheet claims a 10 KHz bandwidth, so we need to sample at
  ' at least 20 KHz. To be on the safe side (and to deal with nice
  ' round numbers) we'll sample at 16x.
  '
  ' Our pattern matching code below hardcodes this sampling multiplier
  ' in the masks it uses. One manchester code must be 32 samples or less

  SAMPLING_RATE = NOMINAL_BAUD * 16 


VAR
  byte  cog

PUB start(rxPin, buffer) : okay
  '' Initialize the receiver cog, for a radio on 'rxPin'.

  param_rxmask := |< rxPin
  param_buffer := buffer
  param_samplePeriod := clkfreq / SAMPLING_RATE
  
  okay := cog := 1 + cognew(@entry, 0)
  
PUB stop
  if cog > 0
    cogstop(cog - 1)
    cog~

    
DAT

'==============================================================================
' Driver Cog
'==============================================================================

                        org

                        '======================================================
                        ' Initialization
                        '======================================================

entry
                        mov     periodTimer, cnt
                        add     periodTimer, param_samplePeriod

                        
                        '======================================================
                        ' Packet Reset
                        '======================================================

detect_break
                        mov     bitcount, #0
                        movs    detect_bit_s, #s_preamble_first  ' Initial state: Wait for preamble

                        cmp     packet_bits, #0 wz
              if_z      jmp     #mainLoop                        ' No prior packet to flush

                        mov     r0, param_buffer                 ' Write back the 128-bit packet
                        add     r0, #16
                        wrlong  packet_data+3, r0
                        sub     r0, #4
                        wrlong  packet_data+2, r0
                        sub     r0, #4
                        wrlong  packet_data+1, r0
                        sub     r0, #4
                        wrlong  packet_data+0, r0
                        sub     r0, #4
                        wrlong  packet_bits, r0                  ' Write packet_bits last, to signal we're done.

                        mov     packet_bits, #0

                        
                        '======================================================
                        ' Filter sampling loop / Manchester Decoder
                        '======================================================

mainLoop
                        ' Next sample period...

                        waitcnt periodTimer, param_samplePeriod

                        ' Sample another bit, and use a shift register to low-pass filter it.
                        ' The (analog) output of the filter ends up in lpfilter_cnt.
                        
                        test    param_rxmask, ina wc
              if_c      add     lpfilter_cnt, #1
                        rcl     lpfilter, #1
                        test    lpfilter, lpfilter_tap wc
              if_c      sub     lpfilter_cnt, #1

                        ' Threshold the filter output at 1/2, and shift it into a
                        ' new pattern matching register.
                        
                        sub     lpfilter_cnt, #8 nr,wc
                        rcl     patternreg, #1
                        
                        ' Now use some pattern matching to see if this shift register
                        ' looks like a 01 or 10 manchester code. We want this detection
                        ' to have some timing fuzz, so that the input bit rate doesn't
                        ' have to be exactly nominal.
                        '
                        ' To avoid detecting two overlapping codes, we invalidate the
                        ' shift register's contents by XORing it with noise after any
                        ' valid detection. We also have a 'gap timer' to detect breaks
                        ' between codes.
                        '
                        ' This matcher has three output states:
                        '
                        '   detect_bit (C=1) -- Detected a valid 01 code
                        '   detect_bit (C=0) -- Detected a valid 10 code
                        '   detect_break     -- There was a gap between valid codes.
                        '                       Abort receiving the current packet.

                        mov     r0, patternreg          ' Mask off the detection window
                        and     r0, mask_11

                        cmp     r0, mask_01 wz          ' Detect 01
              if_nz     cmp     r0, mask_10 wz          ' or Detect 10
              if_z      test    r0, #1 wc               ' Put bit value in C flag
              if_z      xor     patternreg, mask_inval
              if_z      mov     patternreg_gap, #0
              if_z      add     bitcount, #1
detect_bit_s  if_z      jmp     #0                      ' Push the detect-bit state machine

                        add     patternreg_gap, #1      ' Increment the gap timer.
                        cmp     patternreg_gap, #50 wz  ' Gap too large? Detect a break.
              if_z      jmp     #detect_break

                        jmp     #mainLoop


                        '======================================================
                        ' Bit state machine
                        '======================================================

                        ' Wait for first preamble bit.
                        ' Whatever the first bit is, that's stored in our 'polarity' flag.
                        ' Next state: s_preamble_next
s_preamble_first
                        muxc    polarity, #1
                        movs    detect_bit_s, #s_preamble_next
                        jmp     #mainLoop

                        ' Next preamble bit.
                        '
                        ' If this doesn't match 'polarity', the preamble is over.
                        ' If we had at least 8 preamble cycles, try to receive
                        ' data. Otherwise, immediately give up. The transmitter
                        ' seems to send 24 full preamble cycles, so this still
                        ' gives plenty of time for the receiver AGC to warm up
                        ' while cutting out the vast majority of false positives.
s_preamble_next
                        muxc    r0, #1
                        xor     r0, polarity
                        test    r0, #1 wz
                        cmp     bitcount, #8 wc
        if_nz_and_nc    jmp     #s_first_data_bit
        if_nz_and_c     jmp     #detect_break
                        jmp     #mainLoop

                        ' First data bit.
                        '
                        ' Initialize the packet state, and fall through to s_data_Bit.
                        '
                        ' We also invert the 'polarity' so we can use it as an XOR mask.
                        ' Before this code executes, 'polarity' is the value of the
                        ' preamble bits. It seems like these bits are supposed to be
                        ' interpreted as '1's, so we invert the data bits only if the
                        ' preamble was a zero.
s_first_data_bit
                        xor     polarity, #1
                        movs    detect_bit_s, #s_data_bit
                        mov     packet_bits, #0
                        mov     packet_data+0, #0
                        mov     packet_data+1, #0
                        mov     packet_data+2, #0
                        mov     packet_data+3, #0

                        ' Correct the bit's polarity, and store it in a 128-bit
                        ' shift register. Keep track of the packet length. Each
                        ' device's packet has a different total length, and they
                        ' are not byte-aligned.
s_data_bit
                        rcl     packet_data+0, #1 wc
                        xor     packet_data+0, polarity
                        rcl     packet_data+1, #1 wc
                        rcl     packet_data+2, #1 wc
                        rcl     packet_data+3, #1
                        add     packet_bits, #1

                        ' DEBUG: Clock recovery test
                        'or      dira, #2
                        'xor     outa, #2
                            
                        jmp     #mainLoop

                        
'------------------------------------------------------------------------------
' Initialized Data
'------------------------------------------------------------------------------

param_rxmask            long    0
param_samplePeriod      long    0
param_buffer            long    0

lpfilter_cnt            long    0               ' Number of '1' bits in lpfilter
lpfilter                long    0
lpfilter_tap            long    $10000

mask_11                 long    %1111111111_1111111111
mask_01                 long    %0000000000_1111111111
mask_10                 long    %1111111111_0000000000
mask_inval              long    $55555555

polarity                long    0               ' Bit 0 has polarity of preamble codes
                                                                                       

'------------------------------------------------------------------------------
' Uninitialized Data
'------------------------------------------------------------------------------

r0                      res     1
r1                      res     1

patternreg              res     1
patternreg_gap          res     1
periodTimer             res     1

shiftreg                res     1
bitcount                res     1

packet_bits             res     1               ' Number of total packet bits received
packet_data             res     4               ' 128-bit buffer for received data.

                        fit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}  