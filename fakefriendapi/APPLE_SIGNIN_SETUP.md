# Apple Sign In Setup - Client Secret (JWT) Oluşturma

Apple hesap silme işlemi sırasında token revoke için `client_secret` (JWT) gereklidir. Bu dosya `.p8` private key dosyasından oluşturulur.

## 1. Apple Developer Console'dan .p8 Dosyası İndirme

1. [Apple Developer Console](https://developer.apple.com/account/resources/authkeys/list) sayfasına gidin
2. **Keys** bölümünden yeni bir key oluşturun veya mevcut bir key'i kullanın
3. Key oluştururken:
   - **Key Name**: Örn: "Apple Sign In Key"
   - **Services**: "Sign in with Apple" seçeneğini işaretleyin
4. Key oluşturulduktan sonra `.p8` dosyasını indirin (sadece bir kez indirilebilir!)
5. Key ID'yi not edin (ör: "ABC123DEF4")

## 2. .p8 Dosyasını Projeye Ekleme

1. İndirdiğiniz `.p8` dosyasını `fakefriendapi/certs/` klasörüne kopyalayın
2. Dosya adını basit bir isme çevirin: `AuthKey.p8` (veya mevcut adını koruyabilirsiniz)

```
fakefriendapi/
  └── certs/
      └── AuthKey.p8  (veya AuthKey_XXXXX.p8)
```

## 3. Environment Variables Ayarlama

### Option 1: Environment Variables (Önerilen)

Aşağıdaki environment variables'ları ayarlayın:

```bash
# Apple Team ID (Apple Developer hesabınızdan bulabilirsiniz)
APPLE_TEAM_ID=JK42R39DT5

# Apple Client ID / Bundle ID
APPLE_CLIENT_ID=com.flywork.friendify

# Apple Key ID (p8 dosyasının Key ID'si - Apple Developer Console'dan)
APPLE_KEY_ID=ABC123DEF4

# .p8 dosyasının yolu (opsiyonel, varsayılan: ./certs/AuthKey.p8)
APPLE_PRIVATE_KEY_PATH=./certs/AuthKey.p8
```

### Option 2: Direkt .p8 Dosyası Kullanımı

Eğer environment variables ayarlamak istemiyorsanız, `fakefriendapi/certs/AuthKey.p8` dosyasını oluşturun ve aşağıdaki bilgileri `utils/appleAuth.js` dosyasında varsayılan değerler olarak ayarlayın:

```javascript
const teamId = 'JK42R39DT5';  // Apple Team ID
const clientId = 'com.flywork.friendify';  // Bundle ID
const keyId = 'ABC123DEF4';  // Key ID (p8 dosyasının Key ID'si)
```

## 4. Team ID ve Key ID Bulma

### Team ID
- Apple Developer Console → Membership bölümünden bulabilirsiniz
- Mevcut Team ID: `JK42R39DT5` (project.pbxproj'den)

### Key ID
- Apple Developer Console → Keys bölümünden oluşturduğunuz key'in ID'si
- Key oluştururken gösterilir, sonradan da Keys listesinden görebilirsiniz

### Bundle ID (Client ID)
- Mevcut Bundle ID: `com.flywork.friendify`

## 5. Test Etme

Hesap silme işlemi sırasında loglarda şunları göreceksiniz:

```
🍎 Apple user detected for deletion
🍎 Attempting to revoke Apple token...
✅ Apple client_secret generated successfully
🍎 Using Apple Client ID: com.flywork.friendify
🍎 Client secret ready (length: XXX chars)
🍎 Sending revoke request to Apple...
✅ Apple token revoked successfully!
```

## Önemli Notlar

1. **.p8 Dosyası Güvenliği**: `.p8` dosyasını **ASLA** git'e commit etmeyin (`.gitignore` zaten ekli)
2. **Key ID**: Key ID, `.p8` dosyasının adında da bulunur: `AuthKey_ABC123DEF4.p8`
3. **Token Süresi**: Oluşturulan JWT token 6 ay geçerlidir, otomatik olarak yenilenir
4. **Fallback**: Eğer `client_secret` oluşturulamazsa, hesap silme işlemi yine de devam eder (Apple'ın kurallarına uygun)

## Sorun Giderme

### "Apple private key file not found" Hatası
- `.p8` dosyasının `certs/` klasöründe olduğundan emin olun
- `APPLE_PRIVATE_KEY_PATH` environment variable'ını kontrol edin

### "APPLE_KEY_ID environment variable not set" Hatası
- `APPLE_KEY_ID` environment variable'ını ayarlayın
- Veya `utils/appleAuth.js` dosyasında varsayılan değer olarak ekleyin

### "invalid_client" Hatası
- Key ID'nin doğru olduğundan emin olun
- Team ID'nin doğru olduğundan emin olun
- Bundle ID'nin doğru olduğundan emin olun


