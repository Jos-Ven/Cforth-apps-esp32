In combination with the https://github.com/Jos-Ven/A-smart-home-in-Forth
you can control multiple led strips on multiple ESP32 modules in 1 go.

One Esp32 module may contain 3 (PWM) RGB-ledstrips and 1 auxiliary device such as a switch
or an AXA window opener.

When the lights in the smart home in Forth are configured to run in automatic mode then it is possible that the Esp32 modules sleep till 2 hours before sunset and
put their lights on when it is getting dark and you are at home.

A zen-like light show is also possible.

Each module has its own web-site to control its led strip and its device.

For installation see the start in the file app.fth

