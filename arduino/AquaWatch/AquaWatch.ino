// AquaWatch: Uno R3 and a 3-pin analog moisture/water sensor.
// + -> module's rated supply (5V for a 5V-compatible module)
// - -> GND; S -> A0. USB supplies the Uno.
// Set to 1 AFTER adding a suitable ESP power supply and RX level converter.
#ifndef AQUAWATCH_ENABLE_WIFI
#define AQUAWATCH_ENABLE_WIFI 0
#endif
#if AQUAWATCH_ENABLE_WIFI
#include <SoftwareSerial.h>
SoftwareSerial wifi(2, 3); // Uno RX <- ESP TX; Uno TX -> level shifter -> ESP RX.
#endif
const byte SENSOR_PIN = A0;
const byte RED_LED = 10;
const byte YELLOW_LED = 11;
const byte GREEN_LED = 12;
// Buzzer: + -> D8, - -> GND. D8 avoids D2/D3 (Wi-Fi serial) and the LEDs.
const byte BUZZER_PIN = 8;
// 1 = passive buzzer (driven with a tone; also works on an active one).
// 0 = active buzzer (has its own oscillator; just switched on and off).
#ifndef AQUAWATCH_PASSIVE_BUZZER
#define AQUAWATCH_PASSIVE_BUZZER 1
#endif
const unsigned int BEEP_HZ = 2000;
const unsigned long BEEP_MS = 200;
unsigned long beepStarted = 0;
bool beeping = false;
bool beepThisSample = false;
const unsigned long SAMPLE_INTERVAL_MS = 500;
unsigned long lastSample = 0;
int threshold = 400;
bool higherMeansWet = true;
bool wet = false;
bool firstReading = true;
char command[24];
byte commandLength = 0;
bool discardCommand = false;
#if AQUAWATCH_ENABLE_WIFI
char wifiCommand[24];
byte wifiCommandLength = 0;
bool discardWifiCommand = false;
#endif

void readSettings(Stream &source, char *buffer, byte &length, bool &discard) {
  while (source.available()) {
    const char c = source.read();
    if (c == '\n') {
      buffer[length] = '\0';
      int newThreshold, direction;
      if (!discard && sscanf(buffer, "CFG,%d,%d", &newThreshold, &direction) == 2 &&
          newThreshold >= 20 && newThreshold <= 1003 && (direction == 0 || direction == 1)) {
        threshold = newThreshold;
        higherMeansWet = direction == 1;
        firstReading = true;
      }
      length = 0;
      discard = false;
    } else if (c != '\r' && !discard) {
      if (length < 23) buffer[length++] = c;
      else discard = true;
    }
  }
}

void buzzer(bool on) {
#if AQUAWATCH_PASSIVE_BUZZER
  if (on) tone(BUZZER_PIN, BEEP_HZ);
  else noTone(BUZZER_PIN);
#else
  digitalWrite(BUZZER_PIN, on ? HIGH : LOW);
#endif
  beeping = on;
}

void setup() {
  pinMode(SENSOR_PIN, INPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(YELLOW_LED, HIGH);
  Serial.begin(9600);
#if AQUAWATCH_ENABLE_WIFI
  wifi.begin(9600);
#endif
}

void loop() {
  readSettings(Serial, command, commandLength, discardCommand);
#if AQUAWATCH_ENABLE_WIFI
  readSettings(wifi, wifiCommand, wifiCommandLength, discardWifiCommand);
#endif
  const unsigned long now = millis();
  if (beeping && now - beepStarted >= BEEP_MS) buzzer(false);
  if (now - lastSample < SAMPLE_INTERVAL_MS) return;
  lastSample = now;
  // Average eight samples to reduce small electrical fluctuations.
  long total = 0;
  for (byte i = 0; i < 8; i++) {
    total += analogRead(SENSOR_PIN);
    delay(2);
  }
  const int value = total / 8;
  // Same threshold and 20-point hysteresis as the Flutter app.
  if (firstReading) {
    wet = higherMeansWet ? value >= threshold : value <= threshold;
    firstReading = false;
  } else if (higherMeansWet) {
    if (value >= threshold) wet = true;
    if (value < threshold - 20) wet = false;
  } else {
    if (value <= threshold) wet = true;
    if (value > threshold + 20) wet = false;
  }
  const bool nearThreshold = !wet && abs(value - threshold) <= 40;
  digitalWrite(RED_LED, wet ? HIGH : LOW);
  digitalWrite(YELLOW_LED, nearThreshold ? HIGH : LOW);
  digitalWrite(GREEN_LED, !wet && !nearThreshold ? HIGH : LOW);
  // Short beep once a second (every other sample) while water is detected.
  beepThisSample = wet && !beepThisSample;
  if (beepThisSample) {
    buzzer(true);
    beepStarted = now;
  } else if (beeping && !wet) {
    buzzer(false);
  }
  // Versioned ASCII frame terminated by CRLF; no libraries required.
  // The app sends CFG,<threshold>,<1=higher-is-wet,0=lower-is-wet> to sync LEDs.
  Serial.print(F("AQ,1,"));
  Serial.println(value);
#if AQUAWATCH_ENABLE_WIFI
  // ESP receives the actual threshold and detection state from the Uno.
  wifi.print(F("AQ,2,"));
  wifi.print(value);
  wifi.print(','); wifi.print(threshold);
  wifi.print(','); wifi.print(higherMeansWet ? 1 : 0);
  wifi.print(','); wifi.println(wet ? 1 : 0);
#endif
}
