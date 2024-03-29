# TagAlong - Modified, 16 byte

The application consists of two parts:
- Firmware: An ESP32 firmware that sends out BLE advertisment which will be picked up by Apple Find My devices
NOTE: The data fetcher is not implemented for the 16 byte version. The 8-bit data fetcher can be used to fetch messages with 1 byte per advertistment.

Both are based on [OpenHaystack](https://github.com/seemoo-lab/openhaystack), an open source implementation of the Find My Offline Finding protocol.


This repo is a modified version of the original TagAlong protocol. It makes the following changes.
ESP32 Firmware
* Add WIFI capability and NTP time synchronisation
* Add Timer
* Add Logging

The firmware can write up to 16 bytes per advertistment, starting from the LSB. If the data to send is more than the number of bits per advertistment, the program will send another message with the next fragement of data in the next avaliable position in the public key. If the whole data segment of the public key is used up, the new data fragment will wrap around to the LSB and XOR with the existing data.


# How to use

## ESP32C3 Firmware

1. Install ESP-IDF https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/
2. Mofidy the firmware by changing the `modem_id`, `current_message_id` and `data_to_send`
3. Connect the ESP32C3
4. Run "Select port to use (COM, tty, usbserial)" and select the port for the ESP32C3
5. Run "Set Espressif device target" and select ESP32C3 and via built-in USB-JTAG
6. Run "menuconfig" and change the following parameters
* Enable Bluetooth, Bluetooth 4.2 and Bluetooth Low Energy
* Change the partition to 'partitions.csv' and set the flash size to automatically detect
6. Run "Build, Flash and Start Monitor"



## The DataFetcher

1. Install OpenHaystack including the AppleMail plugin as explained https://github.com/seemoo-lab/openhaystack#installation
2. Run OpenHaystack and ensure that the AppleMail plugin indicator is green
3. Run the DataFetcher OFFetchReport application
4. Insert the 4 byte `modem_id` previously set in the ESP firmware as hex digits
5. Set the number of messages, message to start from and repeat fetch timing (0s if refetch is not needed)
6. Select a folder to set the log file, the file name will be automatically generated
7. Fetch uploaded messages
