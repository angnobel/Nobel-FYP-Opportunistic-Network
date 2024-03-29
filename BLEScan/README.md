# BLE Scan

This repo contains an ESP32 IDF firmware for a ESP32C3 to scan for BLE advertistment.
The firmware filters for Apple BLE advertistments using the manafacturer tag, and counts the unique MAC addresses associated with BLE advertistments of specific types: Nearby and AirPlay.

The number of unique MAC addresses allow the ESP32 to determine the number of Mac computers and Apple mobile devices around it.

## How to install
1. Install ESP-IDF https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/
2. Connect the ESP32C3
3. Run "Select port to use (COM, tty, usbserial)" and select the port for the ESP32C3
4. Run "Set Espressif device target" and select ESP32C3 and via built-in USB-JTAG
5. Run "menuconfig" and change the following parameters
* Enable Bluetooth, Bluetooth 4.2 and Bluetooth Low Energy
* Change the partition to 'partitions.csv' and set the flash size to automatically detect
6. Run "Build, Flash and Start Monitor"
