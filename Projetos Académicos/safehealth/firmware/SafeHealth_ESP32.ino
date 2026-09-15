#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <OneWire.h>
#include <DallasTemperature.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "config.h"

MAX30105 particleSensor;

// ==== Configuracao Wi-Fi / Servidor ====
// Criar config.h a partir de config.example.h. O ficheiro config.h não é versionado.
const char* WIFI_SSID = SAFEHEALTH_WIFI_SSID;
const char* WIFI_PASSWORD = SAFEHEALTH_WIFI_PASSWORD;
const char* SERVER_URL = SAFEHEALTH_SERVER_URL;
const char* DEVICE_KEY = SAFEHEALTH_DEVICE_KEY;
const unsigned long WIFI_TIMEOUT_MS = 30000;
const char* FIRMWARE_VERSION = "TMTS-PORTAL-BACKEND-2026-06-04";

// ==== MAX30102 ====
#define MAX30102_ADDR 0x57
#define REG_PART_ID 0xFF
#define REG_REV_ID 0xFE

// ==== DS18B20 ====
const int oneWireBus = 23;
OneWire oneWire(oneWireBus);
DallasTemperature sensors(&oneWire);

// ---- Configuração da medição ----
const unsigned long STABILIZATION_MS = 12000;  // 12 s para estabilizar melhor o sinal
const unsigned long ACQUISITION_MS = 45000;    // 45 s para recolher mais amostras
const long FINGER_THRESHOLD = 50000;

// ---- BPM ----
const byte RATE_SIZE = 8;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute = 0;
int beatAvg = 0;

// ---- Armazenamento da sessão: BPM ----
const int MAX_SESSION_BEATS = 100;
float sessionBpms[MAX_SESSION_BEATS];
int sessionBeatCount = 0;

// ---- Armazenamento da sessão: SpO2 ----
const int MAX_SPO2_SAMPLES = 120;
float sessionSpo2[MAX_SPO2_SAMPLES];
int sessionSpo2Count = 0;

// ---- Armazenamento da sessão: Temperatura ----
const int MAX_TEMP_SAMPLES = 120;
float sessionTemps[MAX_TEMP_SAMPLES];
int sessionTempCount = 0;

// ---- Estatísticas / temporização ----
unsigned long phaseStart = 0;
unsigned long lastPrint = 0;
unsigned long lastTempRead = 0;
unsigned long lastSpo2Store = 0;

// ---- Valores correntes ----
float currentTemperature = DEVICE_DISCONNECTED_C;
float currentSpo2 = 0.0;

// ---- Janela para cálculo de SpO2 por AC/DC ----
const int SPO2_WINDOW_SIZE = 100;  // ajustar depois; começa aqui
long redWindow[SPO2_WINDOW_SIZE];
long irWindow[SPO2_WINDOW_SIZE];
int spo2WindowIndex = 0;
bool spo2WindowFilled = false;

// ---- Estados ----
enum MeasureState {
  WAIT_FINGER,
  STABILIZING,
  ACQUIRING,
  FINISHED
};

float finalBpm = -1.0;

float finalSpo2 = -1.0;

float finalTemp = -1.0;



MeasureState state = WAIT_FINGER;

const char* wifiStatusName(wl_status_t status) {
  switch (status) {
    case WL_IDLE_STATUS:
      return "WL_IDLE_STATUS";
    case WL_NO_SSID_AVAIL:
      return "WL_NO_SSID_AVAIL";
    case WL_SCAN_COMPLETED:
      return "WL_SCAN_COMPLETED";
    case WL_CONNECTED:
      return "WL_CONNECTED";
    case WL_CONNECT_FAILED:
      return "WL_CONNECT_FAILED";
    case WL_CONNECTION_LOST:
      return "WL_CONNECTION_LOST";
    case WL_DISCONNECTED:
      return "WL_DISCONNECTED";
    default:
      return "ESTADO_DESCONHECIDO";
  }
}

bool readRegister8(uint8_t reg, uint8_t &value) {
  Wire.beginTransmission(MAX30102_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) {
    return false;
  }

  if (Wire.requestFrom(MAX30102_ADDR, (uint8_t)1) != 1) {
    return false;
  }

  value = Wire.read();
  return true;
}

void resetMeasurementSession() {
  rateSpot = 0;
  lastBeat = 0;
  beatsPerMinute = 0;
  beatAvg = 0;
  finalBpm = -1.0;
  finalSpo2 = -1.0;
  finalTemp = -1.0;
  sessionBeatCount = 0;
  sessionSpo2Count = 0;
  sessionTempCount = 0;
  currentSpo2 = 0.0;
  spo2WindowIndex = 0;

  spo2WindowFilled = false;

  for (int i = 0; i < SPO2_WINDOW_SIZE; i++) {

    redWindow[i] = 0;

    irWindow[i] = 0;
  }

  for (byte i = 0; i < RATE_SIZE; i++) {
    rates[i] = 0;
  }

  for (int i = 0; i < MAX_SESSION_BEATS; i++) {
    sessionBpms[i] = 0;
  }

  for (int i = 0; i < MAX_SPO2_SAMPLES; i++) {
    sessionSpo2[i] = 0;
  }

  for (int i = 0; i < MAX_TEMP_SAMPLES; i++) {
    sessionTemps[i] = 0;
  }
}

float computeSpo2FromWindow() {
  if (!spo2WindowFilled) return -1.0;

  long redMin = redWindow[0], redMax = redWindow[0];
  long irMin = irWindow[0], irMax = irWindow[0];

  double redSum = 0.0;
  double irSum = 0.0;

  for (int i = 0; i < SPO2_WINDOW_SIZE; i++) {
    long r = redWindow[i];
    long ir = irWindow[i];

    redSum += r;
    irSum += ir;

    if (r < redMin) redMin = r;
    if (r > redMax) redMax = r;

    if (ir < irMin) irMin = ir;
    if (ir > irMax) irMax = ir;
  }

  double dcRed = redSum / SPO2_WINDOW_SIZE;
  double dcIr = irSum / SPO2_WINDOW_SIZE;

  double acRed = redMax - redMin;
  double acIr = irMax - irMin;

  if (dcRed <= 0 || dcIr <= 0 || acIr <= 0) return -1.0;

  double R = (acRed / dcRed) / (acIr / dcIr);
  double spo2 = 104.0 - 17.0 * R;

  if (spo2 < 0.0 || spo2 > 100.0) return -1.0;

  return (float)spo2;
}

void storeTemperatureSample(float tempC) {
  if (tempC != DEVICE_DISCONNECTED_C && sessionTempCount < MAX_TEMP_SAMPLES) {
    sessionTemps[sessionTempCount] = tempC;
    sessionTempCount++;
  }
}

void storeSpo2Sample(float spo2) {
  if (spo2 >= 85.0 && spo2 <= 100.0 && sessionSpo2Count < MAX_SPO2_SAMPLES) {
    sessionSpo2[sessionSpo2Count] = spo2;
    sessionSpo2Count++;
  }
}

void computeMeanMinMax(float arr[], int count, float &meanVal, float &minVal, float &maxVal) {
  if (count <= 0) {
    meanVal = 0;
    minVal = 0;
    maxVal = 0;
    return;
  }

  float sum = 0.0;
  minVal = arr[0];
  maxVal = arr[0];

  for (int i = 0; i < count; i++) {
    sum += arr[i];
    if (arr[i] < minVal) minVal = arr[i];
    if (arr[i] > maxVal) maxVal = arr[i];
  }

  meanVal = sum / count;
}

void sortFloatArray(float arr[], int count) {
  for (int i = 0; i < count - 1; i++) {
    for (int j = i + 1; j < count; j++) {
      if (arr[j] < arr[i]) {
        float temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
      }
    }
  }
}

float computeTrimmedMean(float arr[], int count, float trimFraction) {
  if (count <= 0) return -1.0;

  float copy[120];
  int copyCount = min(count, 120);

  for (int i = 0; i < copyCount; i++) {
    copy[i] = arr[i];
  }

  sortFloatArray(copy, copyCount);

  int trimCount = (int)(copyCount * trimFraction);
  if (copyCount - (2 * trimCount) < 3) {
    trimCount = 0;
  }

  float sum = 0.0;
  int usedCount = 0;

  for (int i = trimCount; i < copyCount - trimCount; i++) {
    sum += copy[i];
    usedCount++;
  }

  if (usedCount <= 0) return -1.0;

  return sum / usedCount;
}

void printFinalResult() {
  Serial.println();
  Serial.println("===== RESULTADO FINAL =====");

  // =========================
  // 1) BPM
  // =========================
  if (sessionBeatCount < 5) {
    Serial.println("BPM: sinal insuficiente para calcular com confiança.");
  } else {
    float rawSum = 0.0;
    float rawMin = 1000.0;
    float rawMax = 0.0;

    for (int i = 0; i < sessionBeatCount; i++) {
      float bpm = sessionBpms[i];
      rawSum += bpm;
      if (bpm < rawMin) rawMin = bpm;
      if (bpm > rawMax) rawMax = bpm;
    }

    float rawMean = rawSum / sessionBeatCount;

    float cleanSum = 0.0;
    float cleanMin = 1000.0;
    float cleanMax = 0.0;
    int cleanCount = 0;
    int rejectedCount = 0;

    for (int i = 0; i < sessionBeatCount; i++) {
      float bpm = sessionBpms[i];

      if (abs(bpm - rawMean) <= 20.0) {
        cleanSum += bpm;
        cleanCount++;

        if (bpm < cleanMin) cleanMin = bpm;
        if (bpm > cleanMax) cleanMax = bpm;
      } else {
        rejectedCount++;
      }
    }

    if (cleanCount < 5) {
      Serial.println("BPM: após remoção de outliers ficaram poucos valores válidos.");
      Serial.print("Batimentos válidos iniciais: ");
      Serial.println(sessionBeatCount);
      Serial.print("Outliers rejeitados: ");
      Serial.println(rejectedCount);
    } else {
      float cleanMean = cleanSum / cleanCount;

      Serial.println("---- BPM ----");
      Serial.print("Batimentos válidos iniciais: ");
      Serial.println(sessionBeatCount);
      Serial.print("Média preliminar: ");
      Serial.println(rawMean, 1);
      Serial.print("Outliers rejeitados: ");
      Serial.println(rejectedCount);
      Serial.print("Batimentos usados no cálculo final: ");
      Serial.println(cleanCount);
      Serial.print("BPM médio final: ");
      Serial.println(cleanMean, 1);
      Serial.print("BPM mínimo final (sem outliers): ");
      Serial.println(cleanMin, 1);
      Serial.print("BPM máximo final (sem outliers): ");
      Serial.println(cleanMax, 1);
      finalBpm = cleanMean;
    }
  }

  // =========================
  // 2) SpO2
  // =========================
  Serial.println("---- SpO2 ----");
  if (sessionSpo2Count > 0) {
    float spo2Mean, spo2Min, spo2Max;
    computeMeanMinMax(sessionSpo2, sessionSpo2Count, spo2Mean, spo2Min, spo2Max);
    float spo2TrimmedMean = computeTrimmedMean(sessionSpo2, sessionSpo2Count, 0.20);

    Serial.print("Número de amostras SpO2: ");
    Serial.println(sessionSpo2Count);
    Serial.print("SpO2 média simples: ");
    Serial.println(spo2Mean, 1);
    Serial.print("SpO2 média filtrada: ");
    Serial.println(spo2TrimmedMean, 1);
    Serial.print("SpO2 mínima: ");
    Serial.println(spo2Min, 1);
    Serial.print("SpO2 máxima: ");
    Serial.println(spo2Max, 1);
    Serial.print("Amplitude SpO2: ");
    Serial.println(spo2Max - spo2Min, 1);
    finalSpo2 = spo2TrimmedMean;
  } else {
    Serial.println("Sem amostras válidas de SpO2.");
  }

  // =========================
  // 3) Temperatura
  // =========================
  Serial.println("---- Temperatura ----");
  if (sessionTempCount > 0) {
    float tempMean, tempMin, tempMax;
    computeMeanMinMax(sessionTemps, sessionTempCount, tempMean, tempMin, tempMax);
    float tempTrimmedMean = computeTrimmedMean(sessionTemps, sessionTempCount, 0.20);

    Serial.print("Número de amostras de temperatura: ");
    Serial.println(sessionTempCount);
    Serial.print("Temperatura média simples: ");
    Serial.println(tempMean, 2);
    Serial.print("Temperatura média filtrada: ");
    Serial.println(tempTrimmedMean, 2);
    Serial.print("Temperatura mínima: ");
    Serial.println(tempMin, 2);
    Serial.print("Temperatura máxima: ");
    Serial.println(tempMax, 2);
    finalTemp = tempTrimmedMean;
  } else {
    Serial.println("Sem amostras válidas de temperatura.");
  }

  Serial.println("===========================");
  Serial.println();
}

void connectWiFi() {
  Serial.println("A procurar redes Wi-Fi disponiveis...");
  int networkCount = WiFi.scanNetworks();

  if (networkCount <= 0) {
    Serial.println("Nenhuma rede Wi-Fi encontrada pelo ESP32.");
  } else {
    for (int i = 0; i < networkCount; i++) {
      Serial.print("Rede encontrada: ");
      Serial.print(WiFi.SSID(i));
      Serial.print(" | RSSI=");
      Serial.print(WiFi.RSSI(i));
      Serial.print(" dBm | Canal=");
      Serial.println(WiFi.channel(i));
    }
  }

  Serial.print("A ligar ao Wi-Fi: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true);
  delay(1000);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long startAttempt = millis();

  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < WIFI_TIMEOUT_MS) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi ligado. IP do ESP32: ");
    Serial.println(WiFi.localIP());
    Serial.print("Gateway: ");
    Serial.println(WiFi.gatewayIP());
    Serial.print("RSSI: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("Nao foi possivel ligar ao Wi-Fi. A medicao local continua disponivel.");
    Serial.print("Codigo WiFi.status(): ");
    Serial.println(WiFi.status());
    Serial.print("Estado Wi-Fi: ");
    Serial.println(wifiStatusName(WiFi.status()));
    Serial.println("Confirma SSID, password e se a rede e 2.4 GHz. O ESP32 normalmente nao liga a redes apenas 5 GHz.");
  }
}

void sendMeasurementToServer() {
  if (finalBpm <= 0 || finalSpo2 <= 0 || finalTemp <= 0) {
    Serial.println("Valores finais invalidos. A enviar mesmo assim para registo de sinal instavel.");
  }

  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(SERVER_URL);
    http.addHeader("Content-Type", "application/json");

    String json = "{";
    json += "\"device_key\":\"" + String(DEVICE_KEY) + "\",";
    json += "\"bpm_medio\":" + String(finalBpm, 1) + ",";
    json += "\"spo2_medio\":" + String(finalSpo2, 1) + ",";
    json += "\"temperatura_media\":" + String(finalTemp, 2) + ",";
    json += "\"duracao_medicao_segundos\":" + String(ACQUISITION_MS / 1000);
    json += "}";

    Serial.print("URL do servidor: ");
    Serial.println(SERVER_URL);
    Serial.println("A enviar medicao ao servidor (conteudo sensivel ocultado no log).");

    int httpResponseCode = http.POST(json);

    Serial.print("Codigo HTTP: ");
    Serial.println(httpResponseCode);

    // Consumir a resposta sem imprimir payloads potencialmente sensíveis.
    http.getString();

    http.end();
  } else {
    Serial.println("WiFi desligado");
  }
}

void setup() {
  Serial.begin(115200);
  delay(3000);

  Serial.println();
  Serial.println("==== TESTE MAX30102 + DS18B20 ====");
  Serial.print("Firmware: ");
  Serial.println(FIRMWARE_VERSION);
  Serial.print("Endpoint configurado: ");
  Serial.println(SERVER_URL);
  Serial.println("Device key: configurada (valor ocultado)");

  connectWiFi();

  Wire.begin(21, 22);
  Wire.setClock(100000);
  delay(200);

  uint8_t partId = 0, revId = 0;

  Serial.println("A ler registos diretamente por I2C...");

  if (readRegister8(REG_PART_ID, partId)) {
    Serial.print("PART_ID = 0x");
    Serial.println(partId, HEX);
  } else {
    Serial.println("Falha a ler PART_ID");
  }

  if (readRegister8(REG_REV_ID, revId)) {
    Serial.print("REV_ID  = 0x");
    Serial.println(revId, HEX);
  } else {
    Serial.println("Falha a ler REV_ID");
  }

  delay(200);

  Serial.println("A iniciar MAX30102...");
  if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    Serial.println("Falha no particleSensor.begin()");
    while (1)
      ;
  }

  Serial.println("MAX30102 OK");

  particleSensor.setup(80, 1, 2, 200, 411, 4096);
  particleSensor.setPulseAmplitudeRed(0x1A);
  particleSensor.setPulseAmplitudeIR(0x2A);
  particleSensor.setPulseAmplitudeGreen(0);

  Serial.println("A iniciar DS18B20...");
  sensors.begin();

  Serial.println("Setup concluido");
  Serial.println();
  Serial.println("Coloca o dedo no sensor e o DS18B20 em contacto para iniciar.");
}

void loop() {
  long ir = particleSensor.getIR();
  long red = particleSensor.getRed();
  bool fingerDetected = (ir > FINGER_THRESHOLD);
  unsigned long now = millis();

  // ---- Temperatura: leitura periódica ----
  if (now - lastTempRead >= 2000) {
    lastTempRead = now;
    sensors.requestTemperatures();
    currentTemperature = sensors.getTempCByIndex(0);

    if (state == ACQUIRING) {
      storeTemperatureSample(currentTemperature);
    }
  }

  // ---- SpO2: cálculo por janela AC/DC ----
  if (fingerDetected) {
    redWindow[spo2WindowIndex] = red;
    irWindow[spo2WindowIndex] = ir;
    spo2WindowIndex++;

    if (spo2WindowIndex >= SPO2_WINDOW_SIZE) {
      spo2WindowIndex = 0;
      spo2WindowFilled = true;
    }

    float spo2Calc = computeSpo2FromWindow();
    if (spo2Calc >= 0.0) {
      currentSpo2 = spo2Calc;

      if (state == ACQUIRING && now - lastSpo2Store >= 1000) {
        lastSpo2Store = now;
        storeSpo2Sample(currentSpo2);
      }
    }
  } else {
    currentSpo2 = 0.0;
    spo2WindowIndex = 0;
    spo2WindowFilled = false;
  }

  switch (state) {

    case WAIT_FINGER:
      if (fingerDetected) {
        resetMeasurementSession();
        phaseStart = now;
        lastPrint = 0;
        lastSpo2Store = 0;
        state = STABILIZING;
        Serial.print("Dedo detetado. A iniciar estabilizacao de ");
        Serial.print(STABILIZATION_MS / 1000);
        Serial.println(" s...");
      } else {
        if (now - lastPrint >= 1000) {
          lastPrint = now;
          Serial.println("Aguardando dedo...");
        }
      }
      break;

    case STABILIZING:
      if (!fingerDetected) {
        state = WAIT_FINGER;
        Serial.println("Dedo removido durante a estabilizacao. Reiniciar.");
        break;
      }

      if (checkForBeat(ir)) {
        lastBeat = now;
      }

      if (now - lastPrint >= 1000) {
        lastPrint = now;
        unsigned long remaining = (STABILIZATION_MS - (now - phaseStart)) / 1000;

        Serial.print("Estabilizando... faltam ");
        Serial.print(remaining);
        Serial.print(" s | IR=");
        Serial.print(ir);
        Serial.print(" | RED=");
        Serial.print(red);
        Serial.print(" | SpO2=");
        Serial.print(currentSpo2, 1);
        Serial.print(" | Temp=");
        if (currentTemperature == DEVICE_DISCONNECTED_C) {
          Serial.println("Erro");
        } else {
          Serial.println(currentTemperature, 2);
        }
      }

      if (now - phaseStart >= STABILIZATION_MS) {
        phaseStart = now;
        lastPrint = 0;
        lastBeat = 0;
        lastTempRead = 0;
        lastSpo2Store = 0;
        Serial.print("Estabilizacao concluida. A adquirir durante ");
        Serial.print(ACQUISITION_MS / 1000);
        Serial.println(" s...");
        state = ACQUIRING;
      }
      break;

    case ACQUIRING:
      if (!fingerDetected) {
        state = WAIT_FINGER;
        Serial.println("Dedo removido durante a aquisicao. Medicao cancelada.");
        Serial.println("Coloca novamente o dedo para reiniciar.");
        break;
      }

      if (checkForBeat(ir)) {
        if (lastBeat > 0) {
          long delta = now - lastBeat;
          float bpm = 60.0 / (delta / 1000.0);

          if (bpm >= 45 && bpm <= 140) {
            beatsPerMinute = bpm;

            rates[rateSpot++] = (byte)bpm;
            rateSpot %= RATE_SIZE;

            int sum = 0;
            for (byte i = 0; i < RATE_SIZE; i++) {
              sum += rates[i];
            }
            beatAvg = sum / RATE_SIZE;

            if (sessionBeatCount < MAX_SESSION_BEATS) {
              sessionBpms[sessionBeatCount] = bpm;
              sessionBeatCount++;
            }
          }
        }
        lastBeat = now;
      }

      if (now - lastPrint >= 1000) {
        lastPrint = now;
        unsigned long remaining = (ACQUISITION_MS - (now - phaseStart)) / 1000;

        Serial.print("A adquirir... faltam ");
        Serial.print(remaining);
        Serial.print(" s | IR=");
        Serial.print(ir);
        Serial.print(" | RED=");
        Serial.print(red);
        Serial.print(" | BPM inst=");
        Serial.print(beatsPerMinute, 1);
        Serial.print(" | SpO2=");
        Serial.print(currentSpo2, 1);
        Serial.print(" | Temp=");
        if (currentTemperature == DEVICE_DISCONNECTED_C) {
          Serial.println("Erro");
        } else {
          Serial.println(currentTemperature, 2);
        }
      }

      if (now - phaseStart >= ACQUISITION_MS) {
        state = FINISHED;
        printFinalResult();
        sendMeasurementToServer();
        Serial.println("Remove e volta a colocar o dedo para nova medicao.");
      }
      break;

    case FINISHED:
      if (!fingerDetected) {
        state = WAIT_FINGER;
        lastPrint = 0;
      }
      break;
  }
}
