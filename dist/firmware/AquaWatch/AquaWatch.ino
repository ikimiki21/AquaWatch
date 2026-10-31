// AquaWatch: Uno R3 and a 3-pin analog water level sensor.
// - -> GND; S -> A0. USB supplies the Uno; there is no battery.
const byte SENSOR_PIN = A0;
// Pins follow the documented layout: LEDs on D10/D11/D12, buzzer on D9.
// Red marks low water, which is the state worth warning about in a tank.
const byte RED_LED = 10;
const byte YELLOW_LED = 11;
const byte GREEN_LED = 12;
// Buzzer: + -> D9, - -> GND. tone() drives it from Timer2, which only costs
// analogWrite on D3/D11; the LEDs here are switched with digitalWrite.
const byte BUZZER_PIN = 9;
// The sensor "+" is driven from D7 rather than 5V, so the probe is energised
// only while a sample is taken. Constant DC across an immersion probe corrodes
// it. The module must draw no more than the 20 mA a pin is rated to supply.
const byte SENSOR_POWER_PIN = 7;
// Settling time for the probe and the ADC input after powering up.
const unsigned long SENSOR_WARMUP_MS = 10;
// 1 = passive buzzer (driven with a tone; also works on an active one).
// 0 = active buzzer (has its own oscillator; just switched on and off).
#ifndef AQUAWATCH_PASSIVE_BUZZER
#define AQUAWATCH_PASSIVE_BUZZER 1
#endif
const unsigned int BEEP_HZ = 1000;
const unsigned long BEEP_MS = 100;
unsigned long beepStarted = 0;
bool beeping = false;
bool beepThisSample = false;
const unsigned long SAMPLE_INTERVAL_MS = 500;
unsigned long lastSample = 0;
// Empirical baselines: dry contacts read about 50, full immersion about 550.
// The app overrides both with CAL after it connects.
int emptyRaw = 50;
int fullRaw = 550;
// Level 3 and level 7 begin here, in thousandths of the calibrated span.
const int LOW_EDGE = 300;
const int FULL_EDGE = 700;
// A band holds until the reading clears its boundary by this much, so a level
// resting on an edge cannot flicker the LEDs.
const int BAND_MARGIN = 20;
const byte BAND_NONE = 0;
const byte BAND_LOW = 1;
const byte BAND_HALFWAY = 2;
const byte BAND_FULL = 3;
byte band = BAND_NONE;
char command[24];
byte commandLength = 0;
bool discardCommand = false;

void readSettings(Stream &source, char *buffer, byte &length, bool &discard) {
  while (source.available()) {
    const char c = source.read();
    if (c == '\n') {
      buffer[length] = '\0';
      int newEmpty, newFull;
      if (!discard && sscanf(buffer, "CAL,%d,%d", &newEmpty, &newFull) == 2 &&
          newEmpty >= 0 && newEmpty <= 1023 && newFull >= 0 &&
          newFull <= 1023 && abs(newFull - newEmpty) >= 10) {
        emptyRaw = newEmpty;
        fullRaw = newFull;
        band = BAND_NONE;
      }
      length = 0;
      discard = false;
    } else if (c != '\r' && !discard) {
      if (length < 23) buffer[length++] = c;
      else discard = true;
    }
  }
}

// Thousandths of the way from empty to full; works whichever way the sensor
// reads, because the span carries the sign.
long permilleOf(int value) {
  const long span = (long)fullRaw - emptyRaw;
  if (span == 0) return 0;
  return ((long)value - emptyRaw) * 1000L / span;
}

byte bandFor(long permille) {
  if (band == BAND_LOW && permille < LOW_EDGE + BAND_MARGIN) return BAND_LOW;
  if (band == BAND_FULL && permille >= FULL_EDGE - BAND_MARGIN) return BAND_FULL;
  if (band == BAND_HALFWAY && permille >= LOW_EDGE - BAND_MARGIN &&
      permille < FULL_EDGE + BAND_MARGIN)
    return BAND_HALFWAY;
  if (permille < LOW_EDGE) return BAND_LOW;
  if (permille < FULL_EDGE) return BAND_HALFWAY;
  return BAND_FULL;
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
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, LOW);
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(YELLOW_LED, HIGH);
  Serial.begin(9600);
}

void loop() {
  readSettings(Serial, command, commandLength, discardCommand);
  const unsigned long now = millis();
  if (beeping && now - beepStarted >= BEEP_MS) buzzer(false);
  if (now - lastSample < SAMPLE_INTERVAL_MS) return;
  lastSample = now;
  // Energise the probe only for the sample, then average eight readings to
  // reduce small electrical fluctuations.
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  delay(SENSOR_WARMUP_MS);
  long total = 0;
  for (byte i = 0; i < 8; i++) {
    total += analogRead(SENSOR_PIN);
    delay(2);
  }
  digitalWrite(SENSOR_POWER_PIN, LOW);
  const int value = total / 8;
  // Same scale and boundaries the app uses, so the LEDs and the screen agree.
  const long permille = permilleOf(value);
  long level = permille / 100;
  if (level < 0) level = 0;
  if (level > 9) level = 9;
  band = bandFor(permille);
  digitalWrite(RED_LED, band == BAND_LOW ? HIGH : LOW);
  digitalWrite(YELLOW_LED, band == BAND_HALFWAY ? HIGH : LOW);
  digitalWrite(GREEN_LED, band == BAND_FULL ? HIGH : LOW);
  // Short beep once a second (every other sample) while the tank runs low.
  // Level 0 beeps too: an empty tank is the most urgent case, not a quiet one.
  beepThisSample = band == BAND_LOW && !beepThisSample;
  if (beepThisSample) {
    buzzer(true);
    beepStarted = now;
  } else if (beeping && band != BAND_LOW) {
    buzzer(false);
  }
  // Versioned ASCII frame terminated by CRLF; no libraries required.
  // The app sends CAL,<empty>,<full> to keep the LEDs on the same scale.
  Serial.print(F("AQ,1,"));
  Serial.println(value);
}
