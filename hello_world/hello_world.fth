\ In cforth on an ESP32 there are 3 ways to use this hello_world.
\ 1) Use hello_world Interactive: Start cforth and enter:
\ ----------------------------------------------------------------

: hello_world ( - )   cr cr ." Hello world" ;

hello_world


0 [if]
\ 2): Use the file system on the ESP32 without xmodem, Enter:
\ ----------------------------------------------------------------


create text ," .| Hello world.|"

: double-quote-|text| ( adr len  -- )
   bounds
     do   i c@ [char] | =
             if  [char] "  i c!
             then
     loop ;

: wfile ( handle adr len - handle ) 2 pick write-file throw ;

s" hello_world.fth" r/w create-file  throw
s" : hello_world ( - )   cr cr  "    wfile
text count 2dup  double-quote-|text| wfile
s" ; hello_world " wfile
close-file throw

ls                    \  To see the directory
cat  hello_world.fth  \  To see the content of the file
fload hello_world.fth \  Compile the file
rm hello_world.fth    \  To remove the file



\ 3): Put hello_world.fth in flash memory as follows:
\ ----------------------------------------------------------------


Copy the file hello_world.fth to: ~/cforth/src/app/esp32-extra
Insert in the file: ~/cforth/src/app/esp32-extra/app.fth
  in the line before interrupt? the following line:
  fl hello_world.fth
flash the ESP32 again from your ~/cforth/build/esp32-extra with:
$ rm *.* && make flash # Check with pwd to see if you are in the build-directory!!

The start Cforth enter:
hello_world
see hello_world


[then]
