// Flash THIS sketch to the ESP-01, not to the Uno.
// Arduino IDE board: Generic ESP8266 Module (match flash size to your module).
// Requires the ESP8266 Arduino board package, no additional libraries.
#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

const char *AP_NAME = "AquaWatch";
const char *AP_PASSWORD = "AquaWatch123"; // WPA2 network password, at least 8 chars.
ESP8266WebServer server(80);
int sensorValue = 0;
int threshold = 400;
bool higherMeansWet = true;
bool waterDetected = false;
bool hasReading = false;
unsigned long lastReading = 0;
char frame[64];
byte frameLength = 0;
bool discardFrame = false;

void readUno() {
  while (Serial.available()) {
    const char c = Serial.read();
    if (c == '\n') {
      frame[frameLength] = '\0';
      int value, limit, direction, wet;
      char trailing;
      if (!discardFrame && sscanf(frame, "AQ,2,%d,%d,%d,%d%c", &value, &limit, &direction, &wet, &trailing) == 4 &&
          value >= 0 && value <= 1023 && limit >= 20 && limit <= 1003 &&
          (direction == 0 || direction == 1) && (wet == 0 || wet == 1)) {
        sensorValue = value;
        threshold = limit;
        higherMeansWet = direction == 1;
        waterDetected = wet == 1;
        hasReading = true;
        lastReading = millis();
      }
      frameLength = 0;
      discardFrame = false;
    } else if (c != '\r' && !discardFrame) {
      if (frameLength < sizeof(frame) - 1) frame[frameLength++] = c;
      else discardFrame = true;
    }
  }
}

void headers() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
  server.sendHeader("Cache-Control", "no-store");
}

void reading() {
  headers();
  if (!hasReading || millis() - lastReading > 3000) {
    server.send(503, "application/json", "{\"error\":\"No fresh Uno reading\"}");
    return;
  }
  char body[200];
  snprintf(body, sizeof(body),
    "{\"device\":\"AquaWatch\",\"version\":1,\"value\":%d,\"threshold\":%d,\"higherMeansWet\":%s,\"waterDetected\":%s,\"sampleAgeMs\":%lu}",
    sensorValue, threshold, higherMeansWet ? "true" : "false",
    waterDetected ? "true" : "false", millis() - lastReading);
  server.send(200, "application/json", body);
}

bool decimalNumber(const String &text) {
  if (text.length() == 0 || text.length() > 4) return false;
  for (unsigned int i = 0; i < text.length(); i++) {
    if (text[i] < '0' || text[i] > '9') return false;
  }
  return true;
}

void configure() {
  headers();
  const String limitText = server.arg("threshold");
  const String directionText = server.arg("higherMeansWet");
  const int limit = limitText.toInt();
  if (!decimalNumber(limitText) || limit < 20 || limit > 1003 ||
      (directionText != "1" && directionText != "0")) {
    server.send(400, "application/json", "{\"error\":\"Invalid settings\"}");
    return;
  }
  // Do not change the reported settings until the Uno confirms in telemetry.
  Serial.print("CFG,"); Serial.print(limit); Serial.print(','); Serial.println(directionText);
  server.send(202, "application/json", "{\"pending\":true}");
}

void setup() {
  Serial.begin(9600); // Normal runtime UART, not the ESP boot-ROM baud rate.
  WiFi.persistent(false);
  WiFi.mode(WIFI_AP); // Own hotspot; no router, cloud, or internet needed.
  const IPAddress address(192, 168, 4, 1);
  WiFi.softAPConfig(address, address, IPAddress(255, 255, 255, 0));
  if (!WiFi.softAP(AP_NAME, AP_PASSWORD)) {
    // Let the watchdog restart the ESP if hotspot startup fails.
    ESP.restart();
    return;
  }
  server.on("/api/reading", HTTP_GET, reading);
  server.on("/api/config", HTTP_POST, configure);
  server.onNotFound([]() {
    headers();
    if (server.method() == HTTP_OPTIONS) server.send(204, "text/plain", "");
    else server.send(404, "application/json", "{\"error\":\"Not found\"}");
  });
  server.begin();
}

void loop() {
  readUno();
  server.handleClient();
  yield();
}
