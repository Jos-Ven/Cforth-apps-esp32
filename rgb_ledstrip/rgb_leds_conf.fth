marker    -rgb_leds_conf.fth   cr lastacf .name #19 to-column .( 06-06-2024 )

decimal

\ -------------- Settings --------------

3   to #Ledstrips   \ Number of used RGB led strips 3 max

#33 to GpioSwitch   \ GPIO# for an optional switch
1   to aux          \ ID of an extra optional switch
aux 0 = [if] : +auxtxt ( - ) +HTML| None|   ; [then]
aux 1 = [if] : +auxtxt ( - ) +HTML| Fan|    ; [then]
aux 2 = [if] : +auxtxt ( - ) +HTML| Window| ; [then]

\ Wakeup 2 hours before sunset.
\ Only works if it gets that time from _sensorweb.fs

f# 2.0e0  f# 60e0 f* f# 60e0 f* f>s to seconds-before-sunset

\ --------------------------------------

: .levels
   #Ledstrips 0
     do i cr cr ." #" dup 1+ .  to selected-ledstrip
                cr ." Brightness:"  BrightLevel ? ." Speed:" SpeedLevel  ?
                cr ." R:" RedLevel ?   ."  G:" GreenLevel  ?   ."  B:" BlueLevel   ?
     loop ;

: SetLedDefaults ( - ) \  Use after allocating &LedLevels
   #ledstrips /ledStrips * allocate throw &ledstrips !
   0 25 over &RedGpio !  27 over &GreenGpio ! 26 swap &BlueGpio !
   1 32 over &RedGpio !  22 over &GreenGpio ! 23 swap &BlueGpio !
   2 19 over &RedGpio !  17 over &GreenGpio ! 18 swap &BlueGpio !

   0 to selected-ledstrip

   slider-file$ count file-exist? 0=
    if  870  RedLevel    !
        380  GreenLevel  !
        300  BlueLevel   !
        570  BrightLevel !

        1 to selected-ledstrip
        500  RedLevel    !
        600  GreenLevel  !
        230  BlueLevel   !
        600  BrightLevel !

        2 to selected-ledstrip
        500  RedLevel    !
        600  GreenLevel  !
        230  BlueLevel   !
        600  BrightLevel !

        375 SpeedLevel   !
    then
   0 to selected-ledstrip  ;
\ \s
