# Voice Streaming CMD Kullanım Kılavuzu

Bu doküman `fakefriendapi` içindeki voice streaming modülünü **Windows CMD** üzerinden çalıştırma ve test etme adımlarını içerir.

## 1) Projeye gir ve bağımlılıkları kur

```cmd
cd C:\path\to\fakefriendapi
npm install
```

## 2) `.env` kullanmadan ortam değişkenlerini ayarla (CMD)

CMD’de (aynı terminal oturumunda) minimum aşağıdaki değişkenleri set et:

```cmd
set PORT=3000
set JWT_SECRET=key

set VOICE_STREAMING_ENABLED=true
set TTS_STREAMING_ENABLED=false

set STT_PROVIDER=mock
set VOICE_DEFAULT_LANGUAGE=tr-TR

set VOICE_AI_MODE=echo
set VOICE_AI_WEBHOOK_URL=
```

## 3) Sunucuyu başlat

```cmd
npm start
```

Beklenen log:

- `Voice streaming gateway active at /ws/voice`
- `Server started.`

## 4) Otomatik testleri çalıştır

```cmd
npm test
```

Beklenen: voice testleri dahil tüm testlerin `pass` olması.

---

## 5) WebSocket bağlantısını CMD’den manuel test et

### 5.1) `wscat` kur

```cmd
npm i -g wscat
```

### 5.2) Test JWT üret

```cmd
node -e "const jwt=require('jsonwebtoken'); console.log(jwt.sign({userId:42,email:'test@example.com'}, 'key'))"
```

Komut çıktısındaki token’ı kopyala.

### 5.3) WS’e bağlan

```cmd
wscat -c "ws://127.0.0.1:3000/ws/voice?token=BURAYA_TOKEN"
```

Bağlantı sonrası önce `connection.ready` event’i gelmelidir.

---

## 6) Event akışı (copy/paste)

### 6.1) Session başlat

```json
{"type":"session.start","requestId":"r1","payload":{"sessionId":"sess-1","conversationId":555,"language":"tr-TR","sampleRate":16000}}
```

Beklenen:

- `session.ready`

### 6.2) Ses chunk gönder

> Mock provider kullandığımız için `textHint` ile test edebilirsin.

```json
{"type":"audio.chunk","requestId":"r2","payload":{"utteranceId":"utt-1","chunkSeq":1,"textHint":"merhaba nasılsın","language":"tr-TR"}}
```

Beklenen:

- `ack` (`ackType: audio.chunk`)
- `stt.partial`

### 6.3) Utterance bitir

```json
{"type":"utterance.end","requestId":"r3","payload":{"utteranceId":"utt-1"}}
```

Beklenen:

- `stt.final`
- `ai.response`

---

## 7) TTS event/chunk testi (opsiyonel)

CMD’de:

```cmd
set TTS_STREAMING_ENABLED=true
```

Sunucuyu yeniden başlat:

```cmd
npm start
```

WS’de gönder:

```json
{"type":"tts.request","requestId":"r4","payload":{"utteranceId":"utt-1","text":"Merhaba, size nasıl yardımcı olabilirim?"}}
```

Beklenen:

- `tts.start`
- `tts.chunk` (bir veya daha fazla)
- `tts.end`

---

## 8) Hata formatı (frontend için referans)

Server hata event’i şu formatta döner:

```json
{
  "type": "error",
  "payload": {
    "code": "BAD_CHUNK_SEQ",
    "message": "chunkSeq integer olmalı",
    "retryable": true,
    "stage": "vad|ai_pipeline|...",
    "requestId": "r2"
  }
}
```

- `retryable: true` => yeniden denenebilir
- `retryable: false` => kritik hata, yeni session önerilir

---

## 9) Kısa troubleshoot

- `401 Unauthorized`: token yanlış veya süresi dolmuş.
- `503 Service Unavailable`: `VOICE_STREAMING_ENABLED=false`.
- Japonca/Korece karakterlerde bozulma varsa DB/connection `utf8mb4` kontrol et.
- Testte port izni hatası varsa terminali admin olarak aç veya farklı port kullan.

