''
'' Spin object for the TSL230R Programmable Light to Frequency Converter
'' manufactured by Texas Advanced Optoelectronic Solutions (TAOS).
''
''        ┌────────┐
''     SO ┤ 1    8 ├ S3
''     S1 ┤ 2    7 ├ S2
''    /OE ┤ 3    6 ├ OUT
''    GND ┤ 4    5 ├ Vdd
''        └────────┘
''
'' OE can be tied to ground, unless you're sharing your OUT pin with
'' other devices. Connect all other pins in order, starting with the
'' Propeller pin given to start(): S0, S1, S2, S3, OUT.
''
'' Copyright (c) 2008 Micah Dowty <micah@navi.cx>
''

CON
  ' Pins
  S0 = 0
  S1 = 1
  S2 = 2
  S3 = 3
  OUT = 4

VAR
  byte pin
  byte multiplier
  byte divisor
  byte continuous
  long lastRisingEdge
  
PUB start(firstPin)
  pin := firstPin

  setSensitivity(100)
  setDivisor(1)

  dira[pin+S3 .. pin+S0]~~
  dira[pin+OUT]~

PUB setSensitivity(newMultiplier)
  '' Set the photodiode array sensitivity. "Multiplier" must be
  '' 1, 10, or 100. Any other value puts the device into power-down mode.

  multiplier := newMultiplier                     
  continuous := 0
  outa[pin+S1 .. pin+S0] := lookdownz(newMultiplier: 0, 1, 10, 100)
              
PUB setDivisor(newDivisor)
  '' Set the current-to-frequency converter's clock divisor.
  '' Values of 1, 2, 10, and 100 are supported.

  divisor := newDivisor
  continuous := 0
  outa[pin+S3 .. pin+S2] := lookdownz(newDivisor: 1, 2, 10, 100)

PUB discontinuity
  '' Let the object know that you missed a period, or that you want to
  '' purposefully discard the current period and start timing again on
  '' the next one. This should be called if there is any significant
  '' delay between measurePeriod calls. It is called implicitly any
  '' time the sensitivity or divisor changes. 

  continuous := 0
  
PUB measurePeriod : period | now, mask
  '' This is the lowest-level light measurement function: using the
  '' device's current settings, measure the length of the next period,
  '' in clock ticks.
  ''
  '' By default, we assume the caller is measuring every period continuously.
  '' If you miss a period, you must call the 'discontinuity' function in order
  '' to tell us to look for two consecutive edges instead of just one.

  mask := |< (pin + OUT)

  if not continuous
    waitpeq(0, mask, 0)
    waitpeq(mask, mask, 0)
    now := cnt

    lastRisingEdge := now
    continuous := 1   

  waitpeq(0, mask, 0)
  waitpeq(mask, mask, 0)
  now := cnt

  period := now - lastRisingEdge
  lastRisingEdge := now
  