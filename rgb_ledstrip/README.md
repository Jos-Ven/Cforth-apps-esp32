In combination with the https://github.com/Jos-Ven/A-smart-home-in-Forth
you can control multiple led strips on multiple ESP32 modules in 1 go.

One Esp32 module may contain 3 (PWM) RGB-ledstrips and 1 auxiliary device such as a switch
or an AXA window opener.

When the lights in the smart home in Forth are configured to run in automatic mode then it is possible that the Esp32 modules sleep till 2 hours before sunset and
put their lights on when it is getting dark and you are at home.

A zen-like light show is also possible.

Each module has its own web-site to control its led strip and its device.

For installation see the start in the file app.fth

IF THEN or CASE statements are not used to handle the strings from a GET request.
The dictionary system of Forth is used to handle those strings.
That saved me a lot of coding.

Here is how the interface looks:

![LightControl](https://github.com/Jos-Ven/Cforth-apps-esp32/assets/47664564/eebb714d-2bd7-4f06-bc09-03ad5c3dd28d)
