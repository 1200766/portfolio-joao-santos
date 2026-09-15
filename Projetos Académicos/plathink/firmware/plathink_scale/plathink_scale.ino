#include <HX711_ADC.h>
#if defined(ESP8266) || defined(ESP32) || defined(AVR)
#include <EEPROM.h>
#endif

// Pins
const int HX711_dout = 7;
const int HX711_sck = 6;
const int ledAzul = 12;
const int ledVerde = 11;
const int ledVermelho = 9;



// HX711 constructor
HX711_ADC LoadCell(HX711_dout, HX711_sck);
const int calVal_eepromAdress = 0;
unsigned long t = 0;
bool reading = false; // 🚀 Controls weight reading (Start/Stop)
float calibration_factor = 1.0; // Default calibration factor
// Variables for chewing time
unsigned long chewingStartTime = 0;
unsigned long chewingTime = 0;
bool chewingActive = false;


void setup() {
    Serial.begin(57600);
    delay(10);
    Serial.println("\nStarting...");

    LoadCell.begin();

    // Load calibration factor from EEPROM
    EEPROM.get(calVal_eepromAdress, calibration_factor);

    if (isnan(calibration_factor) || calibration_factor <= 0) {
        Serial.println("No valid calibration factor found. Setting default (1.0)...");
        calibration_factor = 1.0;
    } else {
        Serial.print("Calibration factor loaded: ");
        Serial.println(calibration_factor);
    }

    LoadCell.setCalFactor(calibration_factor); // ✅ Apply calibration factor

    unsigned long stabilizingtime = 2000;
    boolean _tare = false; // 🚀 Do NOT auto-tare immediately
    LoadCell.start(stabilizingtime, _tare);

    if (LoadCell.getTareTimeoutFlag() || LoadCell.getSignalTimeoutFlag()) {
        Serial.println("Timeout: Check wiring and HX711 connection.");
        while (1);
    } else {
        Serial.println("HX711 Initialized successfully.");
    }

    // 🚀 NEW: Auto-Tare After Startup
    Serial.println("Performing auto-tare...");
    LoadCell.tareNoDelay();
    while (!LoadCell.getTareStatus()) {
        LoadCell.update();
    }
    Serial.println("Tare complete. Scale is now zeroed.");

    // User instructions
    Serial.println("***");
    Serial.println("Commands:");
    Serial.println("'r' - Calibrate");
    Serial.println("'t' - Tare");
    Serial.println("'w' - Start weight reading");
    Serial.println("'s' - Stop weight reading");
    Serial.println("***");
    pinMode(ledAzul, OUTPUT);
    pinMode(ledVerde, OUTPUT);
    pinMode(ledVermelho, OUTPUT);

}

void loop() {
    // Read serial input for commands
    if (Serial.available() > 0) {
        String command = Serial.readStringUntil('\n');
        command.trim();

        if (command == "t") {
            tareWeight();
        }
        else if (command == "r") {
            calibrate();
        }
        else if (command == "w") {
            Serial.println("Starting weight reading...");
            reading = true;
        }
        else if (command == "s") {
            Serial.println("Stopping weight reading...");
            reading = false;
        }
        else if (command == "g") {
            // ✅ Start Meal → Turn Green LED On
            digitalWrite(ledVerde, HIGH);
            digitalWrite(ledVermelho, LOW);
            Serial.println("LED Green (Start Meal)");
        }
        else if (command.startsWith("c")) {
            // ✅ Chewing Time (e.g., "c10" → 10 seconds)
            chewingTime = command.substring(1).toInt() * 1000; // Convert seconds to milliseconds
            chewingStartTime = millis(); // Start timer
            chewingActive = true; // Activate chewing mode

            Serial.print("Chewing Time Received: ");
            Serial.print(chewingTime / 1000);
            Serial.println("s");

            // ✅ Switch LED to RED
            digitalWrite(ledVerde, LOW);
            digitalWrite(ledVermelho, HIGH);
        }
    }

    // ✅ Check if chewing time is over (Non-blocking method)
    if (chewingActive && millis() - chewingStartTime >= chewingTime) {
        chewingActive = false; // Reset chewing mode
        digitalWrite(ledVerde, HIGH);
        digitalWrite(ledVermelho, LOW);
        Serial.println("LED Green (Chewing Complete)");
    }

    // ✅ Weight reading remains unaffected
    if (reading) {
        static boolean newDataReady = false;
        const int serialPrintInterval = 500;

        if (LoadCell.update()) {
            newDataReady = true;
        }

        if (newDataReady) {
            if (millis() > t + serialPrintInterval) {
                float weight = LoadCell.getData();
                Serial.println(weight, 2);
                newDataReady = false;
                t = millis();
            }
        }
    }

    if (LoadCell.getTareStatus()) {
        Serial.println("Tare operation completed.");
    }
}

// 📌 Functions remain unchanged but now work only when called

void calibrate() {
    Serial.println("*** Starting Calibration ***");
    Serial.println("Remove all weight and type 't' to tare.");

    while (!LoadCell.getTareStatus()) {
        LoadCell.update();
        if (Serial.available() > 0) {
            char inByte = Serial.read();
            if (inByte == 't') {
                LoadCell.tareNoDelay();
            }
        }
    }
    Serial.println("Tare complete.");

    Serial.println("Place a known weight and enter the weight in grams:");
    float known_mass = 0;
    while (known_mass == 0) {
        LoadCell.update();
        if (Serial.available() > 0) {
            known_mass = Serial.parseFloat();
            if (known_mass > 0) {
                Serial.print("Known mass: ");
                Serial.println(known_mass);
            }
        }
    }

    LoadCell.refreshDataSet();
    calibration_factor = LoadCell.getNewCalibration(known_mass);
    Serial.print("New calibration factor: ");
    Serial.println(calibration_factor);

    Serial.println("Save calibration factor to EEPROM? (y/n):");
    while (true) {
        if (Serial.available() > 0) {
            char inByte = Serial.read();
            if (inByte == 'y') {
#if defined(ESP8266) || defined(ESP32)
                EEPROM.begin(512);
#endif
                EEPROM.put(calVal_eepromAdress, calibration_factor);
#if defined(ESP8266) || defined(ESP32)
                EEPROM.commit();
#endif
                Serial.println("Calibration factor saved.");
                break;
            } else if (inByte == 'n') {
                Serial.println("Calibration factor not saved.");
                break;
            }
        }
    }

    LoadCell.setCalFactor(calibration_factor); // ✅ Apply new calibration factor
    Serial.println("*** Calibration Complete ***");
}

void tareWeight() {
    LoadCell.tareNoDelay();
    Serial.println("Taring...");

    while (!LoadCell.getTareStatus()) {
        LoadCell.update();
    }

    Serial.println("Tare complete.");
}
