marker rgb_ledstrip_tools.fth  cr lastacf .name #19 to-column .( 28-03-2023 )  \ 217

decimal also html

\ ---- Settings -----------------------------------------------

\ See also rgb_leds_conf.fth for the following 3 parameters.
16 value GpioSwitch              3 value    #ledStrips
 1 value aux

1000 value pwm-frequency         pwm-frequency value MaxLevel
5 cells constant /mcpwm-config   6 cells constant /mcpwm-led
0 value selected-ledstrip        3 constant #led-channels  \ in 1 strip
9 constant MaxRadiobutton       65 constant BelowMinimum   \ 65
4 constant qfound               50 constant DimmMore
3 constant #ledStrips-max

9 6 + ( #parametrs )  cells constant /ledLevel \ 1 ledstrip
0 value &LedLevels

variable &ledStrips    6 cells constant /ledStrips

0 value &LedsAreOn     0 value &LightShowOn|Off
0 value ChosenRadioID  0 value ChosenLevelID
0 value #found         0 value &Radiovalue
111 value cMult \ to get to 999 from 9

\ ---- Application space --------------------------------------

: !cells  ( ... start end - )    do i ! cell +loop ;

: @GpioLed   ( &led - gpio# )   s" @ "        evaluate ; immediate
: &GpioLed   ( &led - &gpio )  ; immediate
: &PwmTimer  ( &led - &timer )  s" cell+"     evaluate ; immediate
: &PwmOp#    ( &led - &op )     s" [ 2 cells ] literal +" evaluate ; immediate
: &PwmSignal ( &led - &signal ) s" [ 3 cells ] literal +" evaluate ; immediate
: &PwmUnit#  ( &led - &pwm )    s" [ 4 cells ] literal +" evaluate ; immediate
: &PwmConfig ( &led - &pwm )    s" [ 5 cells ] literal +" evaluate ; immediate
: ?err  abort" PWM failed"  ;


: LedstripParm ( #ledStrip member - adr ) >r /ledStrips * &ledstrips @ + r> cells+ ;
: &RedLed    ( #ledStrip - adr ) 0 LedstripParm ;
: &GreenLed  ( #ledStrip - adr ) 1 LedstripParm ;
: &BlueLed   ( #ledStrip - adr ) 2 LedstripParm ;
: &RedGpio   ( #ledStrip - adr ) 3 LedstripParm ;
: &GreenGpio ( #ledStrip - adr ) 4 LedstripParm ;
: &BlueGpio  ( #ledStrip - adr ) 5 LedstripParm ;


: .mcpwm-led ( adr - )  \ 1 &RedLed @ .mcpwm-led
    dup >r 0 cells+
               ."      Gpio: " @ .
    r@ 1 cells+ cr ."  PwmTimer: " @ .
    r@ 2 cells+ cr ."    PwmOp#: " @ .
    r@ 3 cells+ cr ." PwmSignal: " @ .
    r@ 4 cells+ cr ."  PwmUnit#: " @ .
    r> 5 cells+ cr ." PwmConfig: " @ . cr ;  \ 0 &RedLed @ .mcpwm-led     0 &GreenLed @ .mcpwm-led

: .mcpwm-leds
    3 0
      do cr i . cr cr i &RedLed @ .mcpwm-led cr
            i &GreenLed @ .mcpwm-led cr
            i &blueLed @ .mcpwm-led
      loop ;

\ Slider positions For the selected-ledstrip
: i>&color ( RGBWled#  - adr )  cells selected-ledstrip /ledLevel *  + &LedLevels +  ;

: RedLevel    ( - &RedLevel )    0 i>&color ;
: GreenLevel  ( - &GreenLevel )  1 i>&color  ;
: BlueLevel   ( - &BlueLevel )   2 i>&color  ;
: SpeedLevel  ( - &SpeedLevel )  3 cells &LedLevels + ; \ 1 speed for all connected ledstrips
: BrightLevel ( - &BrightLevel ) 4 i>&color  ;
\ For each color:
: i>&mode    (  i - adr ) cells 5 i>&color + ;
: i>&target  (  i - adr ) cells 8 3 + i>&color + ;

: @3.r ( adr - ) dup h. @ 3 .r space ;

: .LedChanges  ( - )
   cr cr ." #  Mde act target"
   #Ledstrips 0
     do i to selected-ledstrip
          #led-channels 0
            do  i cr dup .
               dup i>&mode   @3.r
               dup i>&color  @3.r
                   i>&target @3.r
            loop
    loop ;

create slider-file$ ," ledStrip_sliders.dat"

: slider-file-props ( - adr size file-name cnt )
     &LedLevels /ledLevel #ledStrips * slider-file$ count ;

: save-ledstrips ( - ) slider-file-props file-it ;
: load-ledstrips ( - ) slider-file-props @file drop ;

3 constant GPIO_MODE_INPUT_OUTPUT \ For reading AND writing a GRIO port


\ if the Brightness is changed then the color might also change a bit.
: clevel>colorlevel ( colorlevel - 0-1000DimmedColorLevels )
   BrightLevel @  dup 810 */  1000 */  ; \ quadraticly.
\  BrightLevel @ 10 max * 1000 / ; \ Lineair.


: FindAdrActiveColor  ( - adr )      &LedLevels ChosenRadioID cells+ ;
: GetActiveColorLevel ( - level-id ) FindAdrActiveColor @ 100 / ;

: in-range  ( n i - flag )
    dup  i>&target @
    swap i>&mode @  0<
       if >
       else <
       then ;

: LedChange  \ Mode ( led# - newvalue|0 )
   dup >r i>&color @   r@ i>&target @  <>
     if   r@  i>&mode @ r@ i>&color @  + dup
          r@  in-range
               if    dup r> i>&color !
               else  r> 2drop 0
               then
     else  r> drop 0
     then  ;

: FindNewColor (  - color )
   MaxLevel randomlim 1 max   dup BelowMinimum <
      if drop 0
      then ;

: i>&target! ( n itarget -- ) s" i>&target ! " evaluate ; immediate

: SetNewColorTargetsRnd ( - )
   #Ledstrips 0
     do i to selected-ledstrip
    #led-channels  0  do    FindNewColor i i>&target!  loop
  loop ;

: SumTagetsRgbLeds ( - total )
  0 #led-channels 0
   do  i i>&target @ + loop ;

: SetMode ( n - )
     dup i>&color @ over i>&target @ >
       if   -1
       else  1
       then  swap i>&mode !  ;

: iCompensateLowHigh ( i - )
    SumTagetsRgbLeds BrightLevel @ 50 max - dup 0<
       if   abs 2/ swap i>&target +!
       else 2drop
       then  ;

: SetModes ( - )
   #ledstrips 0
    do i to selected-ledstrip
       #led-channels  0
          do  i  SetMode loop
    loop ;

: set-pwm-duty  ( us &PwmLed -- )
\  cr dup @ . ." ->"
  dup &PwmTimer 2@  rot &PwmUnit#  @  \ i.duty i.op# i.timer# MCPWM_UNIT
  mcpwm_set_duty_in_us ?err ;

: .ColorRnd ( color  iLedptr - )  selected-ledstrip swap   LedstripParm @ set-pwm-duty ;

: Change3LedsToNewColor ( - ) \ After newparms ***
   #ledstrips 0
     do i to selected-ledstrip
        #led-channels 0
           do    i LedChange dup
               if    clevel>colorlevel i .ColorRnd
               else   drop
                     FindNewColor #found 1+ dup to #found
                     qfound /mod drop 0=
                        if DimmMore / 1 max
                        then
                     i i>&target!
                     i iCompensateLowHigh
                     i SetMode
               then \ .LedChanges
          loop
    loop ;


: SelfLink ( linktext cnt - here count )
   HTML| <a href="http://|            here +lplace
   ipaddr@ ipaddr$                    here +lplace
   HTML| " target="_top">| here +lplace
   here +lplace
   HTML| </a>| here +lplace
   here lcount ;


: init-GpioSwitch ( -- )   0 GPIO_MODE_INPUT_OUTPUT GpioSwitch gpio-mode  ;
: switch-gpio     ( on/off- )   gpioswitch gpio-hold-dis GpioSwitch gpio-pin!   ;

: init-mcpwm-config ( PwmTimer# MCPWM_UNIT - &mem-mcpwm-config )
 /mcpwm-config allocate throw >r
  pwm-frequency r@ ! r@
  cell+ dup 0E0 sf!   \ Floating 0 - duty for A
  cell+ dup 0E0 sf!   \ Floating 0 - duty for B
  cell+ 0 over !      \ Active high
  cell+ 1 swap !     \ Mode - up counter
  r@ -rot mcpwm_init ?err r> ;


: init-mcpwm-led (  PwmConfig PwmUnit#  PwmOp# PwmTimer  GpioLed  addr - )  \ v3  alles fout
   over gpio-is-output    2>r  \ (  PwmConfig PwmUnit# PwmOp# PwmTimer  )
   2dup 1 lshift or            \ (  PwmConfig PwmUnit# PwmOp# PwmTimer PwmSignal )
   -rot  2r>                   \ (  PwmConfig PwmUnit# PwmSignal PwmOp# PwmTimer GpioLed  addr )
   dup >r /mcpwm-led + r@ !cells
   r@   @ r@ &PwmSignal @  r> &PwmUnit#  @ mcpwm_gpio_init ?err ; \  ( i.gpio# i.io_signal i.MCPWM_UNIT -- e.err? )


: allocate-mcpwm-leds ( -- )
  0 0 0 locals| timer mcpwm_unit &mcpwm-config |

\ ledstrip 0
     /mcpwm-led allocate throw dup >r 0 &RedLed !
   0 to timer   0  to  mcpwm_unit
   \ conf pwm_unit#  pwm_op#   pwm_timer gpioled     addr
     r@    mcpwm_unit 0      timer    0 &RedGpio @   r@ init-mcpwm-led
     timer mcpwm_unit init-mcpwm-config dup to &mcpwm-config r> &PwmConfig !

     /mcpwm-led allocate throw dup >r 0 &GreenLed !
     r@ mcpwm_unit    1 timer         0 &GreenGpio @ r@  init-mcpwm-led
     &mcpwm-config  r> &PwmConfig !

   1 to timer
     /mcpwm-led allocate throw dup >r 0 &BlueLed !
     r@    mcpwm_unit 0      timer    0 &BlueGpio @  r@ init-mcpwm-led
     timer mcpwm_unit init-mcpwm-config dup to &mcpwm-config r> &PwmConfig !

#Ledstrips 1 > if
\ ledstrip 1
     /mcpwm-led allocate throw dup >r 1 &RedLed  !
     r@ mcpwm_unit    1      timer    1 &RedGpio @   r@ init-mcpwm-led
     &mcpwm-config  r> &PwmConfig !

   2 to timer
    /mcpwm-led allocate throw dup >r  1 &GreenLed !
     r@    mcpwm_unit 0      timer    1 &GreenGpio @ r@ init-mcpwm-led
     timer mcpwm_unit init-mcpwm-config dup to &mcpwm-config r> &PwmConfig !

     /mcpwm-led allocate throw dup >r 1 &BlueLed !
     r@    mcpwm_unit 1      timer    1 &BlueGpio @  r@ init-mcpwm-led
     &mcpwm-config  r> &PwmConfig !

#Ledstrips 2 > if
\ ledstrip 2
    /mcpwm-led allocate throw dup >r  2 &RedLed !
   0  to timer    1  to  mcpwm_unit
     r@    mcpwm_unit 0      timer    2 &RedGpio @   r@ init-mcpwm-led
     timer mcpwm_unit init-mcpwm-config dup to &mcpwm-config r> &PwmConfig !

     /mcpwm-led allocate throw dup >r 2 &GreenLed !
     r@    mcpwm_unit 1      timer    2 &GreenGpio @ r@ init-mcpwm-led
     &mcpwm-config  r> &PwmConfig !

   1 to timer
     /mcpwm-led allocate throw dup >r 2 &BlueLed !
     r@    mcpwm_unit 0      timer    2 &BlueGpio @  r@ init-mcpwm-led
     timer mcpwm_unit init-mcpwm-config dup to &mcpwm-config r> &PwmConfig !
then then
 ;



previous

\ \s
