{{

Zapper
------

This object implements an interface to a (modified) Zapper light gun.
The modified light gun has been equipped with a TSL230R light-to-frequency
converter chip. We sample the waveform from the sensor, and correlate it
with laser position data obtained from the OpticalProximity cogs.

References:
   http://ca.geocities.com/jefftranter@rogers.com/xgs/zapper.html
   http://www.zero-soft.com/HW/USB_ZAPPER/
   http://yikescode.blogspot.com/2007/12/nes-controller-arduino.html

Pin layout:   
                  ┌────┐
   (BLK) 1. Data  │•  •│ 4. Trigger (YEL)
   (ORG) 2. Latch │•  •│ 5. Light Sensor (GRN)
   (RED) 3. Clock │•  •│    +5V (WHT)
   (BLU)    Gnd   │• ┌─┘
                  └──┘

  All pins have a 10K pull-up resistor to 5V.

Zapper mod:

  I originally wrote this module for use with an unmodified Zapper
  controller. It was possible to trigger the Zapper using the laser
  projector, but sensitivity left much to be desired. The light sensor
  in the Zapper insn't particularly sensitive, but more importantly it
  has a band-pass filter on it which makes it even harder to trigger
  using laser light that's pulsed at frequencies we can produce.

  The mod works by installing a TSL230R light-to-frequency converter
  in front of the original light sensor board. The only modifications
  necessary to the original circuit board are to cut one trace and
  add three wires.

  First, prep the TSL230R with a series resistor (to limit output
  slew rate and current) and a decoupling capacitor. I did mine
  "dead bug" style, with the capacitor and resistor soldered
  directly onto the back of the chip after folding the leads in.
  
         +5v
           ┬
           │
           ┣──┳──────────────┐                                                    
           │  │ TSL230R      │               
           │  │ ┌──────────┐ │               
    0.1 µF ┣─┤ S0    S3 ├─┼─┐                      
           │  └─┤ S1    S2 ├─┫ │  100 Ω                    
           │  ┌─┤ /OE  OUT ├─┼─┼────── OUT                  
           │  ┣─┤ GND  Vdd ├─┘ │                     
           │  │ └──────────┘   │                         
           ┣──┻────────────────┘           
           

  Solder three wires onto the TSL230R assembly, for GND, +5v, and
  OUT. I used 30 gauge wire-wrap wire.

  Hot glue the TSL230R just behind the rearmost circular partition
  in the Zapper barrel. The chip in the TSL230R should be centered
  in the hole in this partition.

  Now attach it to the original Zapper circuit board. This is a
  bottom view of the board, with a corresponding portion of the
  schematic:

   ┌────────── ─ ─       +5v
   │        BC            ┬             
   │  •     •••           │          
   │ A•                    100 Ω       ┌─ A 
   │  •   •••  •D      D ┫          C ┫ 
   │  •    ••            10 µF        
   │                   B ┫             │
   └────────── ─ ─                     

  This shows the original Zapper's power supply filter, and its
  open-collector drive transistor for the original light detector
  output. To attach the new TSL230R assembly:

    - Cut the trace between point A and C
    - Connect the TSL230 ground to point D
    - Connect TSL230 power to point D (utilizing the original power filter)
    - Connect the TSL230 output (with 100 Ω resistor) to point A

  That's it! Test the sensor with an oscilloscope, then reassemble. The
  modified Zapper should not damage an NES, but it won't work correctly
  of course. If you want to undo the mod, just unglue (pull off) the TSL230R
  itself, unsolder its wires from the Zapper board, and run a jumper wire
  between points D and A.

┌───────────────────────────────────┐
│ Copyright (c) 2008 Micah Dowty    │               
│ See end of file for terms of use. │
└───────────────────────────────────┘

}}

CON
  
  ' Public cog data
  PARAM_TRIGGER_CNT  = 0   'OUT,    Counts trigger presses
  PARAM_LIGHT        = 1   'OUT,    Current light sensor period, in clock ticks
  PARAM_LIGHT_MIN    = 2   'IN/OUT, Minimum detected light sensor period
  PARAM_LIGHT_MAX    = 3   'IN/OUT, Maximum detected light sensor period
  PARAM_LIGHT_THRESH = 4   'IN,     Light sensor pulse threshold
  PARAM_LIGHT_CNT    = 5   'OUT,    Light sensor pulse counter
  PARAM_LIGHT_X      = 6   'OUT,    Last light sensor X position
  PARAM_LIGHT_Y      = 7   'OUT,    Last light sensor Y position
  NUM_PARAMS         = 8

  ' Private cog data
  COG_LIGHT_MASK     = 8   'CONST, base pin number
  COG_TRIGGER_MASK   = 9
  COG_POS_X          = 10  'CONST, X position address
  COG_POS_Y          = 11  'CONST, Y position address
  COG_DATA_SIZE      = 12  '(Must be last)

VAR
  long cog
  long cogdata[COG_DATA_SIZE]

  long trigger_pin
  long trigger_debounce
  
PUB start(lightPin, triggerPin, xAddr, yAddr) : okay
  '' Initialize the controller port, and start its driver cog.
  '' The controller must be connected to five pins, starting with 'basePin'.
  '' The supplied X and Y addresses will be sampled when the light sensor is triggered.

  ' Initialize cog parameters
  longfill(@cogdata, 0, COG_DATA_SIZE)
  cogdata[COG_POS_X] := xAddr
  cogdata[COG_POS_Y] := yAddr

  trigger_pin := triggerPin
  trigger_debounce := $FFFFFFFF

  if lightPin => 0
    cogdata[COG_LIGHT_MASK] := |< lightPin

  okay := (cog := cognew(@entry, @cogdata)) + 1
     
PUB stop
  if cog > 0
    cogstop(cog)
  cog := -1

PUB getParams : addr
  '' Get the address of our parameter block (public PARAM_* values)

  addr := @cogdata

PUB poll
  '' Poll the light gun trigger. This is called
  '' about every 10ms, from the supervisor cog.

  ' Debounce using a shift register
  trigger_debounce := (trigger_debounce << 1) | ina[trigger_pin]

  if (trigger_debounce & %11111111) == %11111000
    cogdata[PARAM_TRIGGER_CNT]++

  
DAT

'==============================================================================
' Driver Cog
'==============================================================================

                        org

                        '======================================================
                        ' Initialization
                        '======================================================

entry                   mov     t1, par                 ' Read pin masks
                        add     t1, #4*COG_LIGHT_MASK
                        rdlong  light_mask, t1

                        mov     t1, par                 ' Read X/Y position addresses
                        add     t1, #4*COG_POS_X
                        rdlong  addr_pos_x, t1

                        mov     t1, par
                        add     t1, #4*COG_POS_Y
                        rdlong  addr_pos_y, t1


                        '======================================================
                        ' Main polling loop
                        '======================================================

pollLoop
                        call    #takeSample

                        jmp     #pollLoop


                        '======================================================
                        ' Low-level light sampling
                        '======================================================

                        ' This function takes a single sample (one half-period),
                        ' and stores it locally in 'light_period' as well as
                        ' updating the current/min/max periods in the PARAMS block.
                        '
                        ' We also take the opportunity here to sample the trigger
                        ' button. For debouncing, we accumulate trigger samples
                        ' in a shift register, then test that shift register against
                        ' a mask.
                        
takeSample
                        ' Wait for the next edge, alternating
                        ' positive and negative edges.

                        waitpeq lightMask_toggle, light_mask                        
                        xor     lightMask_toggle, light_mask
                        mov     last_cnt, this_cnt
                        mov     this_cnt, cnt

                        mov     light_period, this_cnt
                        sub     light_period, last_cnt

                        ' Write output
                        mov     t1, par
                        add     t1, #4*PARAM_LIGHT
                        wrlong  light_period, t1

                        ' Update min
                        mov     t1, par
                        add     t1, #4*PARAM_LIGHT_MIN
                        rdlong  t2, t1
                        max     t2, light_period
                        wrlong  t2, t1  

                        ' Update max
                        mov     t1, par
                        add     t1, #4*PARAM_LIGHT_MAX
                        rdlong  t2, t1
                        min     t2, light_period
                        wrlong  t2, t1  

takeSample_ret          ret


'------------------------------------------------------------------------------
' Initialized Data
'------------------------------------------------------------------------------

lightMask_toggle        long    0
light_mask              long    1
light_cnt               long    0
                   
'------------------------------------------------------------------------------
' Uninitialized Data
'------------------------------------------------------------------------------

t1                      res     1
t2                      res     1

this_cnt                res     1
last_cnt                res     1

light_period            res     1

addr_pos_x              res     1
addr_pos_y              res     1

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