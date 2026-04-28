# Mobile Voices API (Flutter)

Bu dokuman mobil tarafta ses listesini cekmek icin kullanilir.

## Endpoint

- Method: `GET`
- Path: `/voices/list`
- Auth: gerekli (`x-auth-token`, opsiyonel `x-refresh-token`)

Ornek URL:

`{baseURL}/voices/list`

## Basarili response

```json
{
  "success": true,
  "count": 6,
  "voices": [
    {
      "id": 1,
      "name": "Aylin",
      "elevenlabsId": "dKmdJ8jq2hPAyWUBHu3C",
      "mp3Url": "",
      "gender": "female"
    }
  ]
}
```

## Flutter model

```dart
class VoiceModel {
  final int id;
  final String name;
  final String elevenlabsId;
  final String mp3Url;
  final String gender; // female | male

  VoiceModel({
    required this.id,
    required this.name,
    required this.elevenlabsId,
    required this.mp3Url,
    required this.gender,
  });

  factory VoiceModel.fromJson(Map<String, dynamic> json) {
    return VoiceModel(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      elevenlabsId: (json['elevenlabsId'] ?? '') as String,
      mp3Url: (json['mp3Url'] ?? '') as String,
      gender: (json['gender'] ?? '') as String,
    );
  }
}
```

## Flutter response model

```dart
class VoicesResponse {
  final bool success;
  final int count;
  final List<VoiceModel> voices;

  VoicesResponse({
    required this.success,
    required this.count,
    required this.voices,
  });

  factory VoicesResponse.fromJson(Map<String, dynamic> json) {
    final voicesJson = (json['voices'] as List<dynamic>? ?? []);
    return VoicesResponse(
      success: (json['success'] ?? false) as bool,
      count: (json['count'] ?? 0) as int,
      voices: voicesJson
          .map((e) => VoiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

## Flutter API cagrisi (http paketi)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List<VoiceModel>> fetchVoices({
  required String baseUrl,
  required String accessToken,
  String? refreshToken,
}) async {
  final uri = Uri.parse('$baseUrl/voices/list');
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'x-auth-token': accessToken,
  };

  if (refreshToken != null && refreshToken.isNotEmpty) {
    headers['x-refresh-token'] = refreshToken;
  }

  final res = await http.get(uri, headers: headers);
  if (res.statusCode != 200) {
    throw Exception('Voices request failed: ${res.statusCode} ${res.body}');
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final parsed = VoicesResponse.fromJson(data);
  return parsed.voices;
}
```

## Mobil notlar

- `mp3Url` bos gelebilir; bos ise UI preview butonunu disable edin.
- `gender` alanini filtreleme icin kullanabilirsiniz (`female` / `male`).
- `elevenlabsId` backend tarafinda TTS secimi icin kullanilacak ana id degeridir.
