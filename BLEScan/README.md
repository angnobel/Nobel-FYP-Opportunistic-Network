# BLE Scan

This repo contains an ESP32 IDF firmware for a ESP32C3 to scan for BLE advertistment.
The firmware filters for Apple BLE advertistments using the manafacturer tag, and counts the unique MAC addresses associated with BLE advertistments of specific types: Nearby and AirPlay.

The number of unique MAC addresses allow the ESP32 to determine the number of Mac computers and Apple mobile devices around it.
