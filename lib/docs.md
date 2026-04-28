# Mobile Cursor AI Handoff (Algılama Modu, Bas-Konuş Değil)

Bu doküman mobil Cursor AI ajanına **doğrudan** verilsin.
Bu projede hedef: **push-to-talk kapalı**, **sürekli algılama + barge-in açık**.

## Kritik karar (değişmez)

- **Bas-konuş BUTONU ile konuşma başlatma/bırakma YOK.**
- Mikrofon oturumu aktifken ses sürekli akar.
- VAD/algılama ile otomatik:
  - konuşma başlayınca `speech.start`
  - konuşma bitince `speech.stop`
- AI konuşurken kullanıcı tekrar konuşursa:
  - `speech.start` gönder
  - server `tts.stop` + `ai.interrupted` döner

## Backend hazır eventler

- WS endpoint: `/ws/voice`
- Server -> Client:
  - `connection.ready`
  - `session.ready`
  - `turn.state` (`listening|thinking|speaking`)
  - `stt.partial`
  - `stt.final`
  - `ai.response`
  - `tts.start` / `tts.chunk` / `tts.end`
  - `tts.stop`
  - `ai.interrupted`
  - `error`
- Client -> Server:
  - `session.start`
  - `webrtc.offer`, `webrtc.ice` (transport=webrtc)
  - `audio.chunk` (transport=ws fallback)
  - `speech.start`, `speech.stop`
  - `utterance.end` (opsiyonel, speech.stop yerine)

Detay kontrat: `docs/voice-streaming-contract.md`

## Flutter implementasyon kuralı

## 1) WS aç

`wss://api-domain/ws/voice?token=<jwt>`

`connection.ready` bekle.

## 2) Session aç (algılama modu)

```json
{
  "type": "session.start",
  "requestId": "r1",
  "payload": {
    "sessionId": "sess-uuid",
    "conversationId": 555,
    "transport": "webrtc",
    "language": "tr-TR",
    "audio": {
      "codec": "pcm16le",
      "sampleRate": 16000,
      "channels": 1,
      "frameMs": 20
    }
  }
}
```

## 3) WebRTC signaling

1. `flutter_webrtc` ile `RTCPeerConnection` oluştur
2. mic track ekle
3. offer -> `webrtc.offer`
4. `webrtc.answer` al -> `setRemoteDescription`
5. ICE candidate -> `webrtc.ice`

## 4) Algılama (VAD) akışı

Mobilde VAD/enerji tabanlı detector kullanılacak.

Kurallar:
- Ses eşiği üstüne çıkınca ve en az X ms sürdüyse:
  - yeni `utteranceId` üret
  - `speech.start` gönder
- Sessizlik Y ms üstünde kalırsa:
  - `speech.stop` gönder

Örnek:

```json
{ "type": "speech.start", "payload": { "utteranceId": "utt-1001" } }
```

```json
{ "type": "speech.stop", "payload": { "utteranceId": "utt-1001" } }
```

## 5) Barge-in (zorunlu)

AI TTS oynarken VAD konuşma algılarsa:
1. Hemen `speech.start` gönder
2. Gelen `tts.stop` event’inde player’ı anında durdur
3. `ai.interrupted` event’ini logla/UI’a yansıt

## 6) UI davranışı

- Mikrofon butonu sadece `call start/end` için olsun.
- **Press-and-hold kaldırılacak.**
- `turn.state` ile animasyon:
  - `listening`: dinliyor
  - `thinking`: düşünüyor
  - `speaking`: konuşuyor
- `stt.partial`: canlı altyazı
- `stt.final`: kullanıcı nihai metni
- `ai.response`: bot metni
- `tts.chunk`: oynatma buffer

## 7) Reconnect / retry

1. WS koparsa exponential backoff (0.5, 1, 2, 4, max 10s)
2. aynı `sessionId` ile yeniden `session.start`
3. gerekiyorsa son `utteranceId+chunkSeq` paketlerini tekrar yolla (idempotent)

## 8) Fallback (geçici)

WebRTC/WS başarısızsa:
- mevcut `/chat/send-audio-message` fallback akışına dön
- kullanıcıya “anlık mod yerine kayıt modu” bilgisi göster

## 9) Backend env checklist

- `VOICE_STREAMING_ENABLED=true`
- `WEBRTC_ENABLED=true`
- `STT_PROVIDER=deepgram` (veya testte `mock`)
- `DEEPGRAM_API_KEY=...`
- `ELEVENLABS_API_KEY=...`
- `ELEVENLABS_DEFAULT_VOICE_ID=...`
- `VOICE_DEFAULT_LANGUAGE=tr-TR`

## 10) Önemli not

Node’da gerçek WebRTC media ingestion için:

```bash
npm i wrtc
```

`wrtc` yoksa signaling çalışır ama media ingestion tarafında `WEBRTC_RUNTIME_MISSING` alırsınız.


