#include <stdio.h>
#include <string.h>
#include "esp_bt.h"
#include "esp_bt_main.h"
#include "esp_gap_ble_api.h"
#include "nvs_flash.h"
#include "esp_partition.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"

#define TAG "BLE_SCAN"

#define MAX_UNIQUE_MACS 100
#define MIN_PACKET_COUNT 0

static esp_ble_scan_params_t ble_scan_params = {
    .scan_type              = BLE_SCAN_TYPE_ACTIVE,
    .own_addr_type          = BLE_ADDR_TYPE_PUBLIC,
    .scan_filter_policy     = BLE_SCAN_FILTER_ALLOW_ALL,
    .scan_interval          = 0x50,
    .scan_window            = 0x30
};

static int applePacketCount = 0;

static esp_bd_addr_t unique_macs_09[MAX_UNIQUE_MACS];
static esp_bd_addr_t unique_macs_10[MAX_UNIQUE_MACS];
static esp_bd_addr_t unique_macs_16[MAX_UNIQUE_MACS];

static int unique_macs_09_packet_count[MAX_UNIQUE_MACS] = {0};
static int unique_macs_10_packet_count[MAX_UNIQUE_MACS] = {0};
static int unique_macs_16_packet_count[MAX_UNIQUE_MACS] = {0};

static int unique_macs_09_count = 0;
static int unique_macs_10_count = 0;
static int unique_macs_16_count = 0;

static void printData(esp_bd_addr_t bd_addr, int manufacturer_data_length, uint8_t* manufacturer_data) {
    printf("MAC Address: ");
    for (int i = 0; i < ESP_BD_ADDR_LEN; i++) {
        printf("%02X:", bd_addr[i]);
    }
    printf(" | ");
    printf("Manufacturer data: ");
    for (int i = 0; i < manufacturer_data_length; i++) {
        printf("%02X ", manufacturer_data[i]);
    }
    printf("\n");
}

static void esp_gap_cb(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
    switch (event) {
        case ESP_GAP_BLE_SCAN_PARAM_SET_COMPLETE_EVT: {
            if (param->scan_param_cmpl.status == ESP_BT_STATUS_SUCCESS) {
                printf("Scan parameters set, start scanning for 5 seconds...\n");
                esp_ble_gap_start_scanning(10);
            } else {
                printf("Unable to set scan parameters, error code %d\n", param->scan_param_cmpl.status);
            }
            break;
        }
        case ESP_GAP_BLE_SCAN_START_COMPLETE_EVT: {
            if (param->scan_start_cmpl.status != ESP_BT_STATUS_SUCCESS) {
                printf("Scan start failed, error code %d\n", param->scan_start_cmpl.status);
            }
            break;
        }
        case ESP_GAP_BLE_SCAN_RESULT_EVT: {
            esp_ble_gap_cb_param_t *scan_result = param;

            esp_bd_addr_t bd_addr;
            memcpy(bd_addr, scan_result->scan_rst.bda, sizeof(bd_addr));

            esp_bt_dev_type_t dev_type = scan_result->scan_rst.dev_type ; // Flag for device capability

            esp_ble_addr_type_t add_type = scan_result->scan_rst.ble_addr_type;

            esp_ble_evt_type_t event_type = scan_result->scan_rst.ble_evt_type;            

            
            if (scan_result->scan_rst.search_evt == ESP_GAP_SEARCH_INQ_RES_EVT) {
                uint8_t *adv_data = scan_result->scan_rst.ble_adv;
                uint8_t adv_data_len = scan_result->scan_rst.adv_data_len;

                // Variables to store data
                uint8_t flag_data[adv_data_len];
                uint8_t manufacturer_data[adv_data_len];
                int flag_data_length = 0;
                int manufacturer_data_length = 0;

                // Parse through the advertisement data to find the manufacturer-specific data
                for (int i = 0; i < adv_data_len;) {
                    uint8_t len = adv_data[i];
                    uint8_t type = adv_data[i + 1];
                    if (type == ESP_BLE_AD_MANUFACTURER_SPECIFIC_TYPE && len >= 3) {
                        // Check if the length is at least the minimum required for the manufacturer-specific data
                        uint16_t company_id = (adv_data[i + 3] << 8) | adv_data[i + 2];

                        if (company_id == 0x004C) { // Check for Apple device
                            // Store manufacturer-specific data
                            memcpy(manufacturer_data, adv_data + i, len + 1);
                            manufacturer_data_length = len + 1;
                        }                        

                    }
                    // else if (type == ESP_BLE_AD_TYPE_FLAG) {
                    //     // Print the flag data
                    //     memcpy(flag_data, adv_data + i, len + 1);
                    //     flag_data_length = len + 1;
                    // }
                    i += len + 1;
                }

                if (manufacturer_data_length > 0) {
                    // 09 Type
                    if (memcmp(manufacturer_data + 1, "\xFF\x4C\x00\x09", 4) == 0) {
                        bool is_unique = true;
                        for (int i = 0; i < unique_macs_09_count; i++) {
                            if (memcmp(bd_addr, unique_macs_09[i], sizeof(bd_addr)) == 0) {
                                is_unique = false;
                                unique_macs_09_packet_count[i] += 1;
                                break;
                            }
                        }

                        if (is_unique) {
                            // MAC address not found, add it if space available
                            if (unique_macs_09_count < MAX_UNIQUE_MACS) {
                                memcpy(unique_macs_09[unique_macs_09_count], bd_addr, sizeof(bd_addr));
                                unique_macs_09_count++;
                                unique_macs_09_packet_count[unique_macs_09_count] += 1;
                            } else {
                                printf("Maximum number of unique MACs reached.\n");
                            }
                        } 
                    }

                    // // 10 Type
                    // else if (memcmp(manufacturer_data + 1, "\xFF\x4C\x00\x10", 4) == 0) {
                    //     printData(bd_addr, manufacturer_data_length, manufacturer_data);
                    //     bool is_unique = true;
                    //     for (int i = 0; i < unique_macs_10_count; i++) {
                    //         if (memcmp(bd_addr, unique_macs_10[i], sizeof(bd_addr)) == 0) {
                    //             is_unique = false;
                    //             unique_macs_10_packet_count[i] += 1;
                    //             break;
                    //         }
                    //     }

                    //     if (is_unique) {
                    //         // MAC address not found, add it if space available
                    //         if (unique_macs_10_count < MAX_UNIQUE_MACS) {
                    //             memcpy(unique_macs_10[unique_macs_10_count], bd_addr, sizeof(bd_addr));
                    //             unique_macs_10_count++;
                    //             unique_macs_10_packet_count[unique_macs_10_count] += 1;
                    //         } else {
                    //             printf("Maximum number of unique MACs reached.\n");
                    //         }
                    //     }
                    // }
                    

                    // // 16 type
                    // else if (memcmp(manufacturer_data, "\xFF\x4C\x00\x16", 4) == 0) {
                    //     bool is_unique = true;
                    //     for (int i = 0; i < unique_macs_16_count; i++) {
                    //         if (memcmp(bd_addr, unique_macs_16[i], sizeof(bd_addr)) == 0) {
                    //             is_unique = false;
                    //             unique_macs_16_packet_count[i] += 1;
                    //             break;
                    //         }
                    //     }

                    //     if (is_unique) {
                    //         // MAC address not found, add it if space available
                    //         if (unique_macs_16_count < MAX_UNIQUE_MACS) {
                    //             memcpy(unique_macs_16[unique_macs_16_count], bd_addr, sizeof(bd_addr));
                    //             unique_macs_16_count++;
                    //             unique_macs_16_packet_count[unique_macs_16_count] += 1;
                    //         } else {
                    //             printf("Maximum number of unique MACs reached.\n");
                    //         }
                    //     }
                    // }

                    // printf("MAC Address: ");
                    // for (int i = 0; i < ESP_BD_ADDR_LEN; i++) {
                    //     printf("%02X:", bd_addr[i]);
                    // }
                    // printf(" | ");
                    // if (flag_data_length > 0) { 
                    //     printf("Flag data: ");
                    //     for (int i = 0; i < flag_data_length; i++) {
                    //         printf("%02X ", flag_data[i]);
                    //     }
                    //     printf(" | ");
                    // } else {
                    //     printf("No Flag | ");
                    // }

                    // printf("Manufacturer data: ");
                    // for (int i = 0; i < 5; i++) {
                    //     printf("%02X ", manufacturer_data[i]);
                    // }
                    // printf(" | ");

                    // if (dev_type == ESP_BT_DEVICE_TYPE_BLE) {
                    //     printf("Device type: BLE | ");
                    // } else if (dev_type == ESP_BT_DEVICE_TYPE_BREDR) {
                    //     printf("Device type: BR/EDR | ");
                    // } else {
                    //     printf("Device type: Unknown | ");
                    // }

                    // if (add_type == BLE_ADDR_TYPE_PUBLIC) {
                    //     printf("Address type: Public\n");
                    // } else if (add_type == BLE_ADDR_TYPE_RANDOM) {
                    //     printf("Address type: Random\n");
                    // } else {
                    //     printf("Address type: Random NR\n");
                    // }
                    // printf("\n");

                    applePacketCount++;
                }
            }
            break;
        }
        case ESP_GAP_BLE_SCAN_STOP_COMPLETE_EVT: {
            printf("Scan stopped\n");
            printf("Apple BLE packets found: %d\n", applePacketCount);
            break;
        }
        default:
            break;
    }
}



void app_main() {
    unique_macs_09_count = 0;
    unique_macs_10_count = 0;
    unique_macs_16_count = 0;

    printf("Initializing BLE Scan\n");

    ESP_ERROR_CHECK(nvs_flash_init());

    esp_err_t ret;

    esp_bt_controller_config_t bt_cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
    ret = esp_bt_controller_init(&bt_cfg);
    if (ret != ESP_OK) {
        printf("Bluetooth controller initialize failed\n");
        return;
    }

    ret = esp_bt_controller_enable(ESP_BT_MODE_BLE);
    if (ret != ESP_OK) {
        printf("Bluetooth controller enable failed\n");
        return;
    }

    ret = esp_bluedroid_init();
    if (ret != ESP_OK) {
        printf("Bluedroid initialize failed\n");
        return;
    }

    ret = esp_bluedroid_enable();
    if (ret != ESP_OK) {
        printf("Bluedroid enable failed\n");
        return;
    }

    ret = esp_ble_gap_register_callback(esp_gap_cb);
    if (ret != ESP_OK) {
        printf("BLE gap register failed\n");
        return;
    }

    ret = esp_ble_gap_set_scan_params(&ble_scan_params);
        if (ret != ESP_OK) {
            printf("Set scan parameters failed\n");
            return;
        }
    // Wait for 2 seconds
    vTaskDelay(1000 / portTICK_PERIOD_MS);
    esp_ble_gap_stop_scanning();


    // Filter small number of packets
    for (int i = 0; i < unique_macs_09_count; i++) {
        if (unique_macs_09_packet_count[i] <= MIN_PACKET_COUNT) {
            unique_macs_09_count--;
        }
    }

    for (int i = 0; i < unique_macs_10_count; i++) {
        if (unique_macs_10_packet_count[i] <= MIN_PACKET_COUNT) {
            unique_macs_10_count--;
        }
    }

    for (int i = 0; i < unique_macs_16_count; i++) {
        if (unique_macs_16_packet_count[i] <= MIN_PACKET_COUNT) {
            unique_macs_16_count--;
        }
    }

    // for (int i = 0; i < unique_macs_10_count; i++) {
    //     for (int j = 0; j < ESP_BD_ADDR_LEN; j++) {
    //         printf("%02X:", unique_macs_10[i][j]);
    //     }
    //     printf("\n");
    // }

    printf("Number of unique MAC FF 4C 00 09: %d\n", (int) unique_macs_09_count);
    printf("Number of unique MAC FF 4C 00 10: %d\n", (int) unique_macs_10_count);
    printf("Number of unique MAC FF 4C 00 16: %d\n", (int) unique_macs_16_count);
}