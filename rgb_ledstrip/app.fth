0 [if] \ 15-06-2024, Installation for rgb_ledstrip_server.fth on an ESP32:

Intended for an Esp32 with Cforth from: https://github.com/Jos-Ven/cforth

1) Backup the original ~\cforth\src\app\esp32-extra\app.fth
2) Copy this  app.fth   and uart_window.fth   and rgb_ledstrip_tools.fth
   to ~\cforth\src\app\esp32-extra
3) Login to your Linux machine
4) $ cd ~/cforth/build/esp32-extra
5) Set the ESP32 in the flash-mode.
6) $ COMPORT=/dev/ttyUSB0 make flash    # Change ttyUSB0 if needed.
7) Reboot the ESP32 and start your communication program to see Cforth on the ESP32
8) Upload   rgb_ledstrip_server.fth   and favicon.ico   and rgb_leds_conf.fth
   to the file system of the ESP32
9) fload rgb_ledstrip_server.fth  and Logon to your wifi network when asked
10) Enter the address after "Listening on" into a browser to see the application

[then]

\ Load file for application-specific Forth extensions

fl ../../lib/misc.fth
fl ../../lib/dl.fth
fl ../../lib/random.fth
fl ../../lib/ilog2.fth
fl ../../lib/tek.fth

warning @ warning off
: bye standalone?  if  restart  then  bye  ;
warning !

: .commit  ( -- )  'version cscount type  ;

: .built  ( -- )  'build-date cscount type  ;

: banner  ( -- )
   cr ." CForth built " .built
   ."  from " .commit
   cr
;

\ m-emit is defined in textend.c
alias m-key  key
alias m-init noop

: m-avail?  ( -- false | char true )
   key?  if  key true exit  then
   false
;

: ms>ticks  ( ms -- ticks )
   esp-clk-cpu-freq #80000000 over =
     if    drop
     else  #240000000 =
             if   exit
             else #1 lshift
             then
     then  #3 /
;

: system-time>f ( us seconds -- ) ( f: -- us )
   s" s>d d>f f# 1000000 f*  s>d d>f  f+ "  evaluate ; immediate

: usf@         ( f: -- us )
   s" dup dup sp@ get-system-time! system-time>f" evaluate ; immediate

: ms@         ( -- ms ) f# .001 usf@ f* f>d drop ;

alias get-msecs ms@

: fus  ( f: us - )
   usf@  f+
     begin   fdup  usf@  f- f# 100000000 f>
     while   #100000000 us
     repeat
   usf@  f- f>d drop abs us ;

: ms ( ms -- )   s>d d>f f# 1000 f* fus ;

fl wifi.fth

fl ../esp8266/xmifce.fth
fl ../../lib/crc16.fth
fl ../../lib/xmodem.fth
also modem
: rx  ( -- )  pad  unused pad here - -  (receive)  #100 ms  ;
previous

fl files.fth
fl server.fth
fl tasking_rtos.fth        \ Preemptive multitasking
fl tools/extra.fth
fl tools/table_sort.f
fl tools/timezones.f
fl tools/timediff.fth      \ Time calculations. The local time was received from a RPI
fl tools/webcontrols.fth   \ Extra tags in ROM
fl tools/svg_plotter.f
fl tools/rcvfile.fth
fl tools/wsping.fth
fl tools/schedule-tool.f   \ Daily schedule
fl uart_window.fth
fl rgb_ledstrip_tools.fth

: interrupt?  ( -- flag )
   ." Type a key within 2 seconds to interact" cr
   #20 0  do  #100 ms  key?  if  key drop  true unloop exit  then   loop
   false
;

: load-startup-file  ( -- ior )   " start" ['] included catch   ;

: app ( - ) \ Sometimes SPIFFS or a wifi connection causes an error. A reboot solves that.
   banner  hex  interrupt? 0=
      if     s" start" file-exist?
           if   load-startup-file
                if   ." Reading SPIFFS. " cr interrupt? 0=
                    if    reboot
                    then
                then
           then
      then
   quit
;

alias id: \

" app.dic" save
