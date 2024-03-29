#Connecting IoT devices to edge and cloud devices 

This repo contains the code and experiment logs used for the final year project, conduted in National University of Singapore, under the WEISER group.
The code is modified from SendMy from Positive Security https://github.com/positive-security/send-my, TagAlong from PatLab UCSD https://github.com/patlab-ucsd/tagalong, and OpenHaystack from Seemoo Labs https://github.com/seemoo-lab/openhaystack.

The code base is in ESP-IDF, designed for the ESP32C3, and Swift for Mac OS 13

This repo contains 6 folders
1. BLEScan - ESP32 Firmware to scan for Apple BLE advertistments
2. Experiment Logs - Logs for experiments conducted under the FYP
3. OpenHaystack - Modified OpenHaystack code and compiled program to work with MacOS 13
4. SendMy - SendMy program, modified with WIFI and time stamping
5. TagAlong 8bit - Modifed Tagalong code, with WIFI time stamping. Allows up to 8 bits to be sent per message.
6. TagAlong 16byte - Modified  Tagalong code, with WIFI time stamping. Allows up to 16 byytes to be sent per message. Note Fetcher program is not modified for this segment
