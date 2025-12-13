# Google Sign-In Android Yapılandırması

## 🔍 Server Client ID Nasıl Bulunur?

### 1. Google Cloud Console'a Gidin
1. https://console.cloud.google.com/ adresine gidin
2. Projenizi seçin (iOS'ta kullandığınız aynı proje)

### 2. OAuth 2.0 Client ID'leri Kontrol Edin
1. Sol menüden **APIs & Services** > **Credentials** seçin
2. **OAuth 2.0 Client IDs** bölümüne gidin

### 3. Gerekli Client ID'ler:

#### ✅ **Server Client ID** (Kodda kullanılacak):
- **Tipi:** "Web client" veya "Web application"
- **Kullanım:** Flutter kodunda `serverClientId` parametresi olarak
- **Örnek:** `137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com`

#### ✅ **Android Client ID** (AndroidManifest.xml'de URL scheme):
- **Tipi:** "Android"
- **Package name:** `com.flywork.friendify`
- **SHA-1:** Debug keystore'un SHA-1'i eklenmiş olmalı
- **Kullanım:** AndroidManifest.xml'de `<data android:scheme="..." />` olarak

#### ✅ **iOS Client ID** (iOS Info.plist'te):
- **Tipi:** "iOS"
- **Bundle ID:** iOS uygulamanızın bundle ID'si
- **Kullanım:** iOS Info.plist'te `GIDClientID` olarak

---

## 📝 Mevcut Yapılandırma

### iOS Info.plist:
```xml
<key>GIDClientID</key>
<string>137535160742-vliktoiee2n5p70o5nts9rrahd0qrg03.apps.googleusercontent.com</string>
<key>GIDServerClientID</key>
<string>137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com</string>
```

### Android AndroidManifest.xml:
```xml
<data android:scheme="137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com"/>
```

### Flutter Kod (auth_repository.dart):
```dart
GoogleSignIn signIn = GoogleSignIn(
  serverClientId: '137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com',
  scopes: ['email', 'profile'],
);
```

---

## ⚠️ Önemli Notlar

1. **Server Client ID genellikle iOS ve Android için AYNIDIR** çünkü bu bir "Web Client" ID'sidir.

2. **Android'de Google Sign-In çalışması için:**
   - ✅ Android Client ID Google Cloud Console'da tanımlı olmalı
   - ✅ Package name: `com.flywork.friendify` doğru olmalı
   - ✅ SHA-1 fingerprint eklenmiş olmalı
   - ✅ AndroidManifest.xml'de URL scheme doğru olmalı
   - ✅ Kodda `serverClientId` Server Client ID olmalı

3. **Eğer hata alıyorsanız:**
   - Google Cloud Console'da Android Client ID'nin package name ve SHA-1'inin doğru olduğundan emin olun
   - Server Client ID'nin "Web application" tipinde olduğundan emin olun
   - Android Client ID'nin SHA-1 fingerprint'inin eklenmiş olduğundan emin olun

---

## 🔧 Kontrol Listesi

- [ ] Google Cloud Console'da Android OAuth Client ID var mı?
- [ ] Package name: `com.flywork.friendify` doğru mu?
- [ ] SHA-1 fingerprint eklenmiş mi?
- [ ] AndroidManifest.xml'de URL scheme Android Client ID ile eşleşiyor mu?
- [ ] Flutter kodunda serverClientId Server Client ID mi?

---

## 🐛 Hata: "serverClientId must be provided on Android"

Bu hata, Android'de Google Sign-In'in `serverClientId` parametresine ihtiyaç duyduğunu gösterir. 

**Çözüm:**
1. Google Cloud Console'da **Server Client ID**'yi (Web Client) bulun
2. Bu ID'yi `auth_repository.dart` dosyasında kullanın (zaten yapılmış ✅)
3. Android Client ID'nin doğru yapılandırıldığından emin olun

**Mevcut serverClientId:** `137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com`

Bu ID iOS'teki `GIDServerClientID` ile aynı. Eğer hata devam ediyorsa, Google Cloud Console'da bu ID'nin "Web application" tipinde olduğundan emin olun.

---

## 📱 SHA-1 Fingerprint Alma

Debug build için SHA-1:
```bash
cd android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
$JAVA_HOME/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias AndroidDebugKey -storepass android -keypass android | grep SHA1
```

**Mevcut SHA-1:**
```
C7:A6:48:26:D6:91:7C:31:B6:3E:0E:A9:3D:0A:44:90:EE:9A:5F:FA
```

Bu SHA-1'in Google Cloud Console'da Android Client ID'ye eklenmiş olduğundan emin olun.


