s" MachineSettings.fth" file-exist? [if] fl MachineSettings.fth [then]
marker    rgb_ledstrip5_server.fth   cr lastacf .name #19 to-column .( 11-06-2024 )

\ Intended for an Esp32 with Cforth from: https://github.com/Jos-Ven/cforth
\ needs in flash:
needs wifi-station-on extra.fth
needs time>mmhh       tools/timediff.fth
needs Html	      tools/webcontrols.fth
needs wsPing          tools/wsping.fth
needs init-extra-uart uart_window.fth
needs pwm-frequency   rgb_ledstrip_tools.fth

\ needs in the file-system of the esp32:
needs SetLedDefaults rgb_leds_conf.fth \ Edit to the default settings if needed


DECIMAL ALSO HTML

0 [if]

cr .( test pwm )

2 to selected-ledstrip
: test-rgb ( selected-ledstrip - )
  0  selected-ledstrip &RedLed   @ set-pwm-duty
  0  selected-ledstrip &GreenLed @ set-pwm-duty
  0  selected-ledstrip &BlueLed  @ set-pwm-duty
 200 ms

  800 selected-ledstrip &RedLed   @ set-pwm-duty 200 ms \ 1
  20 selected-ledstrip &GreenLed @ set-pwm-duty 200 ms \ 0
  20 selected-ledstrip &BlueLed  @ set-pwm-duty 200 ms \ 1
;

/ledLevel   #ledStrips *  allocate throw to &LedLevels
SetLedDefaults allocate-mcpwm-leds
1 to selected-ledstrip selected-ledstrip test-rgb quit

[then]

: <RadioButton> ( btntxt cnt btnID colorID - )
   over = >r
    (.) &Radiovalue lplace
    s" SetRadioFunction" &Radiovalue +lplace
    &Radiovalue lcount  r>
      if   <CssBlueButton>
      else <CssButton>
      then  ;

: led-control-header ( - )
     +HTML| <tr valign="top" style="font-size: 16px; font-weight: bold;">|
    +HTML| <th colspan="2" valign="top" align="left">|
           SitesIndex
           s" /Schedule" s" Schedule" <<TopLink>>
           </td>

    4 aux if 1+ then  #Ledstrips 1 = if 1- then
          <#td +HTML| align="center" valign="top" >|  +HTML| Esp| ipaddr@ ipaddr$  3 - + 3 +html
           +HTML|  light control|    </td>
          <td> .htmlspace </td>
       <td>
    local-time-now .Html-Time-from-UtcTics  .HtmlBl <br> .HtmlSpace </td>

  </tr>
  <tr>  </tr>
   +HTML| <tr valign="top" style="font-size: 20px; font-weight: bold;">|
   aux   if    +HTML| <th align="center" valign="top" style="min-width:100px">|
               +auxtxt </td>
         then
    +HTML| <th align="center" valign="top" style="min-width:100px">| +HTML| Show|     </td>
    +HTML| <th align="center" valign="top" style="min-width:100px">| +HTML| LedStrip| </td>
   #Ledstrips 1 >
     if   +HTML| <th valign="top" style="min-width:100px">| +HTML| Set| </td>
     then
   <td> +HTML| Bright | </td>
   <td> +HTML| Speed | </td>
   <td> +HTML| Red | </td>
   <td> +HTML| Green | </td>
   <td> +HTML| Blue | </td>
  </tr>  ;

: LedSlider ( name cnt value10* - )
   10 /  HTML| class="vertslidecontainer"|  <div
    +HTML| <input type="range"  value="| .html
    +HTML| " name="|  +HTML    +HTML| " style="height: 160px"  |
    +HTML| list="values" orient="vertical"/> </div>| ;

aux 0 = [if]
: aux-on-ctrl  ( - txt cnt cmdOn cnt flag )  s" Err1"  s" ErrOn"  GpioSwitch gpio-pin@  ;
: aux-off-ctrl ( - txt cnt cmdOff cnt flag ) s" Err2"  s" ErrOff" GpioSwitch gpio-pin@  ;
[then]

aux 1 = [if]
: aux-on-ctrl  ( - txt cnt cmdOn  cnt flag ) s" On"    s" AuxOn"  GpioSwitch gpio-pin@  ;
: aux-off-ctrl ( - txt cnt cmdOff cnt flag ) s" Off"   s" AuxOff" GpioSwitch gpio-pin@  ;
[then]

aux 2 < [if]
: aux-stop-ctrl ;
: init-axa ;
[then]

0 value WindowIsopen \ Assumes: The window is closed

aux 2 = [if]  \ For an Axa windowopener

40 constant TimeOutCmd
20 constant TimeOutEmit

: clear-rx ( -- )  &RxBuf read-rx 2drop ;
: NoAxaError? ( Axa$ cnt -- flag )  s" 502" search nip nip 0= ;


: .response ( adr n - )
   cr ."  Axa:"
   over + swap
      ?do  i c@ dup bl <
             if  drop bl
             then
           emit
      loop ;


: .ReadResponse ( - adr n )
   &RxBuf read-rx  dup 0>
    if   .response
    else 0
    then ;

$d constant _cr
0 value Axa$
3 constant #maxAttempts

: SendChar ( char - ) sp@ 1 send-tx drop TimeOutEmit ms ;

: SendChars ( from n - )
   bounds
      ?do  i c@  SendChar
      loop ;

: .SendAxa  ( Counted$Cmd cnt - )  \ SendCmd
   #maxAttempts 0
       do  clear-rx _cr  SendChar TimeOutCmd ms
            SendChars
           _cr SendChar TimeOutCmd ms
           &RxBuf read-rx   Axa$ place
           Axa$ count  NoAxaError?
              if   leave
              then
       loop   ;

: test begin
    s" ?" .SendAxa key?
      until
    ;

: IsWindowOpen? ( - flag )
   clear-rx s" status" .SendAxa  Axa$ count  s" 211" search nip nip 0= ;

: aux-on-ctrl   ( - txt cnt cmdOn cnt  flag )   s" Open"  s" AuxOn"   WindowIsopen ;
: aux-off-ctrl  ( - txt cnt cmdOff cnt flag )   s" Close" s" AuxOff"  WindowIsopen ;
: aux-stop-ctrl ( - txt cnt cmdStopf cnt flag ) s" Stop"  s" AuxStop" WindowIsopen ;

: init-axa ( - )
     #33 #17 2 init-extra-uart \ ( rx-pin tx-pin uart_num -- )
               \ NOTE: GPIO33 can only be used as RX with an extra serial output
     80 allocate throw to Axa$ ;
[then]


: led-controls ( - )
   <tr>  aux
     if
       +HTML| <td valign="top">|
        <p>   aux-on-ctrl      <CssBlue|GrayButton>  </p>
        <p>   aux-off-ctrl  0= <CssBlue|GrayButton>  </p>
       aux 2 =
        if
        <p>   aux-stop-ctrl drop 0 <CssBlue|GrayButton>  </p>
        then
        </td>
    then

    +HTML| <td valign="top">|
     <p> s" Run"   s" LightShowOn"  &LightShowOn|Off @ <CssBlue|GrayButton> </p>
     <p> s" Stop"  s" LightShowOff" &LightShowOn|Off @ 0= <CssBlue|GrayButton> </p>
   </td>

        +HTML| <td valign="top">|
        <p>  s" On"   s" LedsOn"   &LedsAreOn @     <CssBlue|GrayButton>  </p>
        <p>  s" Off"  s" LedsOff"  &LedsAreOn @  0= <CssBlue|GrayButton>  </p>
        <p>  s" Set"  s" SetLedlevels"
             <Btn  +html| " class="btn" style="background-color:#FFA040">|   Btn>  </p>
   </td>

   #Ledstrips 1 >
     if   +HTML| <td valign="top">|
                     <p>  s" Strip1" 0 ChosenRadioID <RadioButton> </p>
           #ledstrips 1 > if <p>  s" Strip2" 1 ChosenRadioID <RadioButton> </p> then
           #ledstrips 2 > if <p>  s" Strip3" 2 ChosenRadioID <RadioButton> </p> then
          </td>
      then

    ChosenRadioID to selected-ledstrip
    <td> s" BrightSlider" BrightLevel  @ LedSlider </td>
    <td> s" SpeedSlider"  SpeedLevel @ LedSlider </td>
    <td> s" RedSlider"    RedLevel     @ LedSlider </td>
    <td> s" GreenSlider"  GreenLevel   @ LedSlider </td>
    <td> s" BlueSlider"   BlueLevel    @ LedSlider </td>
    11 10 #DataValues
   </tr>

   +HTML| <tr valign="top" style="font-size: 16px; font-weight: bold">|
     +HTML| <th style="border: 1px solid black">| .forth-driven </td>
     2  aux  if  1+ then   #Ledstrips 1 = if 1- then
     <#tdC> .htmlspace </td>

     <td> BrightLevel  @ .html </td>
     <td> SpeedLevel @ .html </td>
     <td> RedLevel     @ .html </td>
     <td> GreenLevel   @ .html </td>
     <td> BlueLevel    @ .html </td>
   </tr> ;


: /home-page ( -- )    \ Builds the HTML-page starting at HtmlPage$
   s" Ledstrip controller" html-header         \ loads: html-header doctype_html header_styles
   +HTML| <body bgcolor="#3366FF" style=" height:100vh;">|
   +HTML| <table border="0" cellpadding="10" cellspacing="0"  width="5%" height="5%" |
   +HTML| style="padding-top:10px; border:1px solid #666; border-radius:8px; box-shadow:0 0 10px #666; |
   +HTML| margin-top:10%; margin-left:auto; margin-right:auto; background-color: #FEFFE6;">|
    <tdL>
        +HTML| <table border="0" cellpadding="0px" cellspacing="5"  width="10%">|
        <Form> led-control-header led-controls </form>
        </table>
  </td> </table> +HTML| </body> </html>|  ;


false value save-sliders?


: UpdateLeds ( - )
       RedLevel   @ clevel>colorlevel selected-ledstrip &RedLed @   set-pwm-duty
       GreenLevel @ clevel>colorlevel selected-ledstrip &GreenLed @ set-pwm-duty
       BlueLevel  @ clevel>colorlevel selected-ledstrip &BlueLed @  set-pwm-duty ;

: SetLevelSlider ( adr  - )
    parse-single    0=
       if abort then
    save-sliders?
       if    10 * swap !   &LedsAreOn @
             if    UpdateLeds
             then  save-ledstrips
       else  2drop
       then ;

: IgnoreValue ( - )  parse-word 2drop ;

: hold-pin ( pin - )
   dup gpio-pin@
      if    gpio-deep-sleep-hold-en
            gpio-hold-en
      else  drop
      then ;


: ExitPage  ( msg$ cnt -- )
   dup cell+ allocate drop dup >r lplace
   s" Update " html-header
   +HTML| <body>|     \ LeftTopStart
   +HTML| <br><center>|
   r@ lcount +HTML
   +HTML| <center></body> </html>|
   r> free drop ;

TCP/IP DEFINITIONS

: /home ( -- )  ['] /home-page set-page ;

: BrightSlider	( <number> - n ) BrightLevel	SetLevelSlider ;
: SpeedSlider	( <number> - n ) SpeedLevel	SetLevelSlider ;
: RedSlider	( <number> - n ) &LightShowOn|Off @ if IgnoreValue else RedLevel   SetLevelSlider then ;
: GreenSlider	( <number> - n ) &LightShowOn|Off @ if IgnoreValue else GreenLevel SetLevelSlider then ;
: BlueSlider	( <number> - n ) &LightShowOn|Off @ if IgnoreValue else BlueLevel  SetLevelSlider then ;

: SetRadioFunction ( ChosenRadioID - )
    dup to ChosenRadioID to selected-ledstrip postpone \ /home-page ;

: 0SetRadioFunction  ( - ) 0 SetRadioFunction ;
: 1SetRadioFunction  ( - ) 1 SetRadioFunction ;
: 2SetRadioFunction  ( - ) 2 SetRadioFunction ;

: LightShowOff ( - ) 0 &LightShowOn|Off ! /home-page ;

: SetLightShowSlowRgb (  % ledstrip# - )
    >r
    dup RedLevel   @ * 100 / clevel>colorlevel r@ &RedLed @   set-pwm-duty
    dup GreenLevel @ * 100 / clevel>colorlevel r@ &GreenLed @ set-pwm-duty
        BlueLevel  @ * 100 / clevel>colorlevel r> &BlueLed @  set-pwm-duty ;


: 0SetSlowRgb (  % ledstrip# - )
    >r
    dup RedLevel   @ * 100 /  r@ &RedLed @   set-pwm-duty
    dup GreenLevel @ * 100 /  r@ &GreenLed @ set-pwm-duty
        BlueLevel  @ * 100 /  r> &BlueLed @  set-pwm-duty ;


: DimmColor (  ledstrip# - DimmedColor )
  BrightLevel @ 1 max * 1000 /  ;


: SetSlowRgb (  % ledstrip# - )
    >r
    dup RedLevel   @ DimmColor * 100 / r@ &RedLed @    set-pwm-duty
    dup GreenLevel @ DimmColor * 100 / r@ &GreenLed @  set-pwm-duty
        BlueLevel  @ DimmColor * 100 / r> &BlueLed @   set-pwm-duty ;


: LedsOn ( - )
   &LedsAreOn @ 0=
      if  selected-ledstrip  100 0
          do   #ledStrips 0
              do  j i to selected-ledstrip i  &LightShowOn|Off @
                    if   SetLightShowSlowRgb
                    else SetSlowRgb
                    then
              loop
          10 ms
          loop
        to selected-ledstrip
        true &LedsAreOn !
      then
    /home-page ;

: SetLedlevels ( - )  true to save-sliders?  ChosenRadioID to selected-ledstrip ;

: LedsOff ( - )
    &LedsAreOn @
       if  100 0
             do  #ledStrips 0
                   do  99 j -  i dup to selected-ledstrip   &LightShowOn|Off @
                       if   SetLightShowSlowRgb
                       else SetSlowRgb
                       then
                   loop
             10 ms
             loop
           false &LedsAreOn !
       then
    0 &LightShowOn|Off ! /home-page ;

: (LedsOff) ( - )
    &LedsAreOn @
    0 to selected-ledstrip  #ledStrips 0
       do  0 i &RedLed @   set-pwm-duty
           0 i &GreenLed @ set-pwm-duty
           0 i &BlueLed @  set-pwm-duty
       loop
    false &LedsAreOn ! ;

aux 2 < [if]  \  GpioSwitch .  \ Assigned in rgb_leds_conf.fth

: AuxOn  ( - )
    GpioSwitch gpio-pin@ 0=
       if   cr ." AuxOn"    true switch-gpio gpioswitch hold-pin
       then ;

: AuxOff ( - )
    GpioSwitch gpio-pin@
       if   cr ." AuxOff" gpio-deep-sleep-hold-dis false switch-gpio
       then ;

[else]  \ AXA window opener:


: AuxOn   ( - )  s" open"  .SendAxa  true to WindowIsopen ;
: AuxOff  ( - )  s" Close" .SendAxa  false to WindowIsopen ;
: AuxStop ( - )  s" Stop"  .SendAxa  s" status" .SendAxa ;

[then]

: HumidityStandBy ( Humidity*100 StandBy - ) \ After: Ask_HumidityStandBy
    aux 1 = and
      if   4000 <
             if    AuxOn
             else  AuxOff
             then
      else  drop
      then ;

: setlevels  { level -- }
   chosenradioid  #Ledstrips 0
     do   i to selected-ledstrip level over i>&color !
     loop drop ;


: SetcolorLevel ( level - )
   dup 9 >
     if    drop /home-page
     else  dup to ChosenLevelID   cMult * setlevels
           &LedsAreOn @ &LightShowOn|Off @ 0= and
              if    LedsOn
              else  /home-page
              then
     then  ;

: LightShowOn ( - )
    1 &LightShowOn|Off ! 10 to poll-interval
    &LedsAreOn @ 0=
      if   LedsOn   then   /home-page ;

: /Update ( - )
   +f s" _receiver_bg.txt" file-exist?
     if   s" _receiver_bg.txt"  delete-file reboot
     then
   s" Waiting to receive a file from the upload server. " here lplace
   s" refresh" SelfLink ExitPage
   SendHtmlPage 30 ms
   lsock lwip-close
   listener-socket   lwip-close receiver ;

\ ------- schedule

FORTH DEFINITIONS ALSO HTML

: Schedule-page  ( - )
   start-html-page
   [ifdef]  SitesIndex  SitesIndex [then]
   s" /home"    s" home"      <<TopLink>>
   +TimeDate/legend
   ['] add-options-dropdown html-schedule-list ;

PREVIOUS

: wakeup
    ['] noop is schedule-entry  WaitForsleeping-
       if   false to WaitForsleeping-
       then ;

: sleep             ( - )   ['] (sleeping-schedule) is schedule-entry ; \ Sleep till next item
: initial-sleep     ( - )   ['] (sleep-at-boot)     is schedule-entry ; \ sleep till sunset AT boot
: sleep-till-sunset ( - )   ['] (sleep-till-sunset) is schedule-entry ; \ sleepentry in schedule

: fan-check-sleep ( - ) \ Sends: 'lastpart-ip ask_PressurePresent' See also HumidityStandBy
   sleep-till-sunset
   my-host-id" tmp$ lplace
   s"  Ask_HumidityStandBy "  tmp$ +lplace
   tmp$ lcount time-server$   TcpWrite ;

ALSO TCP/IP
here dup to &options-table \ Options used by schedule
\                 Map: xt      cnt adr-string
' wakeup            dup , >name$ , ,  \ id = 0
' initial-sleep     dup , >name$ , ,
' sleep             dup , >name$ , ,
' sleep-till-sunset dup , >name$ , ,
' fan-check-sleep   dup , >name$ , ,
' AuxOff            dup , >name$ , ,
' AuxOn             dup , >name$ , ,

here swap - /option-record / to #option-records
create file-schedule-rgb ," schedule-rgb.dat"

PREVIOUS TCP/IP DEFINITIONS

alias /NewPage          noop

: check-sunset ( seconds-before-sunset - )
   UtcSunSet @time f- s>f f- fdup f0>
    if     initial-sleep
    then ;

: TcpTime ( UtcTics UtcOffset sunrise sunset - )
   depth 4 >=
    if   s>f LocalTics-from-UtcTics to utcsunset
         s>f LocalTics-from-UtcTics to utcsunrise drop set-system-time
         boot-time f0=
           if   @time to boot-time
           then
        cr bold .date .time space norm
        restart-schedule  \ restart-schedule needs the time!
        0 n>sched.option@ Sleep-till-sunset-option =
           if  seconds-before-sunset check-sunset
           then
   then ;

\  ---- Schedule page ----

: /Schedule  ( - ) ['] Schedule-page set-page ;
: /Scheduled  ( - ) clr-req-buf ['] Schedule-page set-page ;

: SetEntrySchedule ( schedule.record# hh mm #DropDown - )
   depth 4 >=
    if  3 pick  &schedule-table >#records @ <=
            if  setentry-schedule /Schedule
            else  2drop 2drop
            then
    then ;

: AddEntrySchedule ( - ) AddEntry-schedule /Schedule ;

: /      ( -- ) /home-page ;

FORTH DEFINITIONS

: RebootNotConnected ( #sec-timeout - )
   dhcp-status 0 =
      if   cr ." No connection." 3 rtc-clk-cpu-freq-set esp-wifi-stop
           1 rtc-clk-cpu-freq-set 10 ms deep-sleep
      else drop
      then ;

: newparms ( - ) SetNewColorTargetsRnd  SetModes  ;

\ RUNtime at 80 Mhz:
: CorTiming ( DelayTime - NewDelayTime )  3 / ;


[ifndef] create-timer:
       2variable TGettimer
[else] create-timer:  TGettimer
[then]

60 1000 * CorTiming constant TimeTGettimer
-1 TGettimer !

: OnNotimeReceived ( - )
   TimeTGettimer TGettimer tElapsed?
      if   AskTime TGettimer start-timer
      then ;

: poll-actions  ( timeout -- ) \ Responds to an html request and changes the leds when needed
    timed-accept
     if    &LightShowOn|Off @
              if    MaxRadiobutton SpeedLevel @ 100 / - dup dup * * to poll-interval  \ About 3 - 53 seconds
                    Change3LedsToNewColor
              else  1000 to poll-interval
              then
           GotTime? 0=
              if    OnNotimeReceived
              else  schedule  schedule-entry \ See also TcpTime
              then
           #1800 RebootNotConnected
     else  false to save-sliders?  http-responder
     then ;


: send_ask_time ( - )
   time-server$ 0<>
     if     cr ." Ask time from: " 100 ms time-server$ count type
            ms@ >r asktime ms@ r> - dup space . ." ms "  1000 >
                 if   cr ." Stream failed. Rebooting." 1500 ms
                      esp-wifi-stop 200 ms 2 deep-sleep
                 then
     then ;

: serve-http-loop  ( -- )
   arpnew 10 ms
   send_ask_time                     \ Note: time-server$ MUST be filled
   cr ." Running the rgb_ledstrip_server..." cr
   begin  poll-interval responder     \   responder executes poll-actions
          handle-timeout escape?
   until  ;

\ ---- Startup ------------------------------------------------


ALSO TCP/IP

\ variable and values are copied to the switch-server-task when started as a task
: init-mem ( - )
     decimal file-schedule-rgb init-schedule
     init-HtmlPage logon
     /ledLevel   #ledStrips-max *  allocate throw to &LedLevels
     #40 allocate throw to &Radiovalue
     cell allocate throw to &LedsAreOn       false &LedsAreOn !
     cell allocate throw to &LightShowOn|Off false &LightShowOn|Off !
     init-axa         \ When used.
     SetLedDefaults   \ Machine depended. see rgb_leds_conf.fth
     init-GpioSwitch
     allocate-mcpwm-leds
     (LedsOff)
     slider-file$ count file-exist?
         if  load-ledstrips
         then
     .levels cr
     init-seed newparms
     ['] poll-actions  to responder
     #80 http-listen                 \ To start the server
     gpio-deep-sleep-hold-dis ;


: start-led-server  ( -- )
    0 to WaitForsleeping-
    ['] /home-page set-page
    htmlpage$ 0= if init-mem  else  restart-schedule then
    also tcp/ip seal                 \ To handle all requests
    #1000 to poll-interval
    serve-http-loop                   \ Contains the loop of the server
    only forth also definitions quit ;

PREVIOUS

\ ' see-request is handle-request   \ Option to see what has been returned by the browser

PREVIOUS ORDER

: s start-led-server ;
cr .free
start-led-server
\ \s
