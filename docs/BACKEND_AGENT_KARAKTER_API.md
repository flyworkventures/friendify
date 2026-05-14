# Backend: Karakter API — mobil uygulama ile uyum

Bu doküman **Friendify Flutter** istemcisinin bugünkü davranışına göre sunucuda yapılması gereken değişiklikleri tanımlar. Uygulanınca: katalog karakteri düzenleme “Oluşturduklarım”a yeni kayıt açmadan aynı listede kalır; JWT ile `ownerId` doğrulaması tutarlı olur.

İstemci kaynağı: `lib/Controllers/ViewControllers/agent_profile_view_controller.dart`, `lib/View/VideoCallView/videocall_view.dart`, `lib/Models/agent_model.dart`, `lib/utils/app_constants.dart`.

---

## 1) Access JWT payload (zorunlu)

**Sorun:** Üretilen token içinde yalnızca `email`, `iat`, `exp` varsa, `update-agent` tarafında `req.user.id` çözülemez ve **401** oluşur.

**Yapılacak:** Login, refresh token ve guest login dahil **tüm access JWT** üretimlerinde payload’a sayısal kullanıcı kimliği ekleyin (en az biri):

- `id` (number) — tercih edilen
- veya `userId` (number)

Örnek payload:

```json
{
  "id": 12345,
  "email": "user@example.com",
  "iat": 1710000000,
  "exp": 1710086400
}
```

Auth middleware’de `req.user.id` bu claim’den doldurulmalı. Mevcut kullanıcılar **yeniden giriş** veya **token yenileme** sonrası yeni token almalı.

**Geçici uyumluluk (opsiyonel):** JWT’de hâlâ id yoksa, `update-agent` içinde `email` ile DB’den kullanıcı bulunup `userId` oradan türetilebilir; ardından body’deki `ownerId` ile aynı kullanıcı olduğu doğrulanır (`String(body.ownerId) === String(dbUser.id)`).

---

## 2) `POST /agent/update-agent`

### Kimlik

- Header: `x-auth-token`, `x-refresh-token` (istemci `HttpService` ile gönderir).
- Gövdede: **`ownerId`** (number veya parse edilebilir string) — oturumdaki kullanıcı ile eşleşmeli.
- Katalog düzenlemede istemci ayrıca **`userId`** alanını da gönderir; aynı anlama geliyorsa ikisinden birini kabul edin veya ikisini birbirine göre doğrulayın.

`ownerId` doğrulaması: **JWT’deki kullanıcı id** ile normalize karşılaştırma (`Number` / `String` tutarsızlığına izin vermeyin).

### İstemci dalları

| Senaryo | Koşul (istemci) | Beklenen backend |
|--------|------------------|------------------|
| A. Kendi karakteri | `agent.system === 0` ve `creatorId` oturum kullanıcı id’si ile eşleşir | Mevcut satırı güncelle (`agentId` = o bot). |
| B. Katalog düzenleme | `!isCreateFlow`, `system !== 0`, kullanıcı kendi karakteri değil | **Yeni satır oluşturma.** Şablon `agentId` için kullanıcıya özel override kaydet; `GET /agent/get-system-agents` cevabında **aynı `id`** ile birleştirilmiş / override’lı alanları dönün. |
| C. Arkadaş oluştur | `create-custom-agent` ile oluşturma | `create-custom-agent` ile yeni kayıt; `get-user-agents` listesinde görünsün. |

### Gövde alanları (istemci gönderir)

`name`, `character`, `age`, `gender`, `interests` (JSON string), `interestsType`, `photoURL`, `characterTags`, `speakingStyle`, `voiceId`, `country`, `ownerId`, ve güncellemede `agentId` (string).

Katalog dalında ek: `userId` (owner ile aynı anlam).

### HTTP kodları

- Başarı: **200**, gövde istemcinin beklediği JSON (mümkünse güncel agent veya en azından başarı bayrağı).
- Yetkisiz / owner uyuşmazlığı: anlamlı JSON; **401** yalnızca gerçekten kimlik doğrulanamadığında (geçersiz token), iş kuralı reddi için **403** + net `msg` tercih edilir.

---

## 3) `POST /agent/get-system-agents`

Kullanıcının katalogda yaptığı **B senaryosu** override’ları, liste cevabında şablon `id` korunarak uygulanmış alanlar olarak dönülmeli (isim, foto, karakter metni, yaş, ses, vb.). Böylece mobil `getAgents()` sonrası aynı kartta güncel veri görünür.

`system === 2` şablonları (rastgele şablon) mevcut filtre mantığıyla listede istemci tarafında ayrı kullanılabilir; backend şemasını bozmayın.

---

## 4) `POST /agent/get-user-agents`

Yalnızca **`create-custom-agent` ile oluşturulan** (C senaryosu — “Arkadaş oluştur”) kayıtlar listelenmeli. Katalogdan `update-agent` ile yapılan özelleştirme **bu listeye eklenmemeli** (B ile uyum).

Bunu ayırt etmek için DB’de örn. `origin: 'user_create' | 'catalog_override'` veya `isStandaloneCreation: boolean` tutulabilir; `get-user-agents` yalnızca `user_create` döner.

---

## 5) `POST /agent/create-custom-agent`

Değişmeden: gövde yine `ownerId` + alanlar. Sadece **yeni kullanıcı karakteri** için kullanılır (C).

---

## 6) Özet kontrol listesi

- [ ] JWT’ye `id` veya `userId` (number) eklendi; middleware `req.user.id` set ediyor.
- [ ] `update-agent`: `ownerId` ↔ JWT kullanıcı id normalize doğrulama.
- [ ] Katalog (`system !== 0`): override persist + `get-system-agents` birleşik cevap.
- [ ] `get-user-agents`: yalnızca `create-custom-agent` kaynaklı kayıtlar (veya eşdeğer bayrak).
- [ ] Eski “katalogdan create ile oluşmuş” hayalet kayıtlar için (opsiyonel) migration / temizlik.
- [ ] Kullanıcı oluşturma / listeleme cevaplarında `rive_avatar` (Bölüm 8) görüntülü arama ile uyumlu.

---

## Referans: mobil endpoint sabitleri

`lib/utils/app_constants.dart`:

- `GET` benzeri POST: `/agent/get-system-agents`
- `/agent/get-user-agents`
- `/agent/create-custom-agent`
- `/agent/update-agent`
- `/agent/delete-agent` — gövde `agentId`, `ownerId` (istemci JWT öncelikli `ownerId` çözer)

Bu doküman backend deposuna kopyalanabilir veya PR açıklamasına yapıştırılabilir.

---

## 7) `CREATE_AGENT_FAILED` (create-custom-agent)

Mobil tarafta yeni karakter akışında gönderilen gövde özeti:

- `name`, `character`, `age`, `gender`
- `interests` ve `interestsType`: **aynı** JSON dizi string’i (`jsonEncode` ile tek kaynak)
- `photoURL`: seçilen veya şablondan; boşsa `photoURLs` içinden ilk dolu URL
- `characterTags`: string değilse `jsonEncode` ile stringe çevrilir
- `speakingStyle`: null-safe string (trim)
- `voiceId`: zorunlu (create ekranında kullanıcı seçmeden kayıt engellenir)
- `country`: boşsa `TR`
- `ownerId`, `userId`: oturum kullanıcı id (JWT `id` / `userId` öncelikli, yoksa `UserModel.id`)

**Backend beklentisi:** `CREATE_AGENT_FAILED` dönülürken sadece genel mesaj yerine geliştirme ortamında `details` / `cause` alanında **Prisma / SQL / validasyon** iç hatasını loglayın veya JSON’a ekleyin; aksi halde mobil tarafta kök nedeni görmek mümkün değildir.

Olası sunucu kaynakları: benzersiz kısıt, zorunlu FK, `voiceId` whitelist’te yok, `interests` şema doğrulaması, veritabanı bağlantısı.

---

## 8) Görüntülü arama: `rive_avatar` eksikliği (kullanıcı oluşturduğu karakter)

### Sorun (ürün)

Kullanıcı **kendi oluşturduğu** karakterle görüntülü aramaya girdiğinde ekranda **Rive animasyonu değil, statik fotoğraf** (`photoURL`) görünüyor. Katalog / sistem karakterlerinde Rive düzgün görünüyorsa sebep büyük olasılıkla **API cevabında Rive URL’sinin boş gelmesi**dir.

### İstemci davranışı (değişiklik talebi değil, mevcut mantık)

`videocall_view.dart` içinde avatar şu sırayla seçilir:

1. `rive_avatar` (veya aşağıdaki alias’lardan biri) **dolu ve geçerli bir HTTPS URL** ise → Rive `FileLoader.fromUrl` ile yüklenir.
2. **Boş / null** ise veya Rive yükleme **başarısız** olursa → doğrudan `photoURL` fallback.

Mobil model bu alanları okur (`agent_model.dart` → `_parseRiveAvatar`):

- `rive_avatar` (tercih edilen)
- `riveAvatar`, `rive_avatar_url`, `riveAvatarUrl`, `avatar_rive`, `avatarRive`

### Backend’den beklenen

- **`create-custom-agent`** ve **`get-user-agents`** (ve görüntülü aramaya giden agent’ı dönen her endpoint) cevabında, o karakter için kullanılacak **.riv dosyasına işaret eden tam URL** `rive_avatar` (veya yukarıdaki alias’lardan biri) ile dönmelidir.
  - Karakter bir **şablondan** türetiliyorsa: şablondaki Rive URL’si yeni kullanıcı kaydına **kopyalanmalı** veya şablon `id` üzerinden çözülüp her zaman doldurulmalıdır.
  - URL **HTTPS** olmalı, istemci tarafında `FileLoader.fromUrl` kullanıldığı için erişilebilir ve CORS / imza süresi vb. mobil için uygun olmalıdır.
- **`update-agent`** ile güncellenen kullanıcı karakterinde de `rive_avatar` kaybolmamalı; gövdede istemci göndermese bile DB’deki değer korunmalı veya şablondan yeniden bağlanmalıdır.

### Kontrol

- [ ] `get-user-agents` ve create/update cevaplarında `system === 0` (veya sizin “kullanıcı karakteri” tanımınız) kayıtlar için `rive_avatar` sistem karakterleriyle aynı dolulukta mı?
- [ ] Boş bırakılan kayıtlar için ürün kararı “yalnızca foto” ise bu bilinçli; aksi halde Rive URL’si zorunlu kabul edilmeli.
