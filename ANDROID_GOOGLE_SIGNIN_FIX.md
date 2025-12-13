# Android Google Sign-In Sorun Giderme (Play Store)

## Sorun
Play Store'dan yüklenen uygulamada Google ile giriş çalışmıyor.

## Neden?
Release build için kullanılan keystore'un SHA-1 ve SHA-256 fingerprint'leri Google Cloud Console'da kayıtlı değil.

## Çözüm

### 1. Release Keystore'un SHA-1 Fingerprint'ini Alın

**Release keystore** (`android/app/keystore.jks`) için SHA-1 fingerprint'ini almak için:

```bash
cd android/app
keytool -list -v -keystore keystore.jks -alias friendify
```

Şifre sorulduğunda: `1234567890`

Çıktıdan **SHA1** ve **SHA256** değerlerini kopyalayın:
```
Certificate fingerprints:
     SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
     SHA256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

### 2. Google Cloud Console'da Fingerprint'leri Ekleyin

1. [Google Cloud Console](https://console.cloud.google.com/) adresine gidin
2. Projenizi seçin (veya yeni bir proje oluşturun)
3. Sol menüden **APIs & Services** > **Credentials** seçin
4. OAuth 2.0 Client ID'nizi bulun (veya oluşturun):
   - **Android Client ID**: `137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com`
   - **Web Client ID (Server)**: `137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com`

5. **Android Client ID**'yi düzenleyin:
   - **Package name**: `com.flywork.friendify`
   - **SHA-1 certificate fingerprint**: Release keystore'un SHA-1 değerini ekleyin
   - **SHA-256 certificate fingerprint**: Release keystore'un SHA-256 değerini ekleyin (opsiyonel ama önerilir)

6. **Save** butonuna tıklayın

### 3. Debug Keystore Fingerprint'i (Geliştirme için)

Geliştirme sırasında debug keystore kullanılıyorsa, debug fingerprint'ini de eklemeniz gerekir:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Bu SHA-1 değerini de Google Cloud Console'a ekleyin.

### 4. Bekleme Süresi

Fingerprint'leri ekledikten sonra **değişikliklerin aktif olması 1-2 saat sürebilir**. Bu yüzden hemen test etmek isterseniz, Google Play Console'dan uygulamanızın kapalı test sürümünü kullanabilirsiniz.

### 5. Test Etme

1. Release APK/AAB oluşturun:
   ```bash
   flutter build appbundle --release
   ```
   veya
   ```bash
   flutter build apk --release
   ```

2. Play Store'dan uygulamayı yükleyin veya kapalı test kanalından test edin
3. Google Sign-In'i test edin

## Önemli Notlar

### ⚠️ Keystore Güvenliği
- `keystore.jks` dosyasını **asla kaybetmeyin** - kaybederseniz uygulama güncellemeleri yapamazsınız
- Keystore şifresini güvenli bir yerde saklayın
- Keystore'u yedekleyin

### 🔐 Mevcut Keystore Bilgileri
- **Keystore Path**: `android/app/keystore.jks`
- **Alias**: `friendify`
- **Keystore Password**: `1234567890`
- **Key Password**: `1234567890`

### 📱 Package Name
- **Application ID**: `com.flywork.friendify`
- Bu package name Google Cloud Console'daki OAuth Client ID ile eşleşmeli

### 🔄 OAuth Client ID'leri
- **Android Client ID**: `137535160742-pai7kjdb0nlr4lm9r1j4tc0o7ulpinli.apps.googleusercontent.com`
  - Bu ID AndroidManifest.xml'de intent-filter'da kullanılıyor
  - Bu ID'ye release keystore'un SHA-1/SHA-256 fingerprint'leri eklenmeli

- **Server Client ID**: `137535160742-let1k5rhqu6ecqmlpj91g7336gctc8mt.apps.googleusercontent.com`
  - Bu ID backend için kullanılıyor (auth_repository.dart'ta serverClientId olarak)

## Sorun Giderme

### "DEVELOPER_ERROR" hatası alıyorsanız:
1. SHA-1 fingerprint'in doğru eklendiğinden emin olun (iki nokta üst üste ile ayrılmış olmalı)
2. Package name'in `com.flywork.friendify` olduğundan emin olun
3. Google Cloud Console'da değişikliklerin kaydedildiğinden emin olun
4. 1-2 saat bekleyin (değişikliklerin aktif olması zaman alabilir)

### "10" hatası alıyorsanız:
- OAuth Client ID yapılandırması yanlış olabilir
- Package name uyumsuzluğu olabilir

### "12500" hatası alıyorsanız:
- Google Sign-In kullanıcı tarafından iptal edilmiş olabilir
- İnternet bağlantısı sorunu olabilir

## Adım Adım Google Cloud Console Rehberi

1. **Google Cloud Console'a gidin**: https://console.cloud.google.com/
2. **Proje seçin** veya yeni proje oluşturun
3. **APIs & Services** > **Credentials** menüsüne gidin
4. **OAuth 2.0 Client IDs** listesinde Android client ID'yi bulun
5. **Edit** (kalem ikonu) butonuna tıklayın
6. **SHA-1 certificate fingerprints** bölümüne release keystore'un SHA-1 değerini ekleyin
7. **SHA-256 certificate fingerprints** bölümüne release keystore'un SHA-256 değerini ekleyin (opsiyonel)
8. **Save** butonuna tıklayın
9. Değişikliklerin aktif olması için 1-2 saat bekleyin

## Doğrulama

Fingerprint'lerin doğru eklendiğini kontrol etmek için:

1. Google Cloud Console'da OAuth Client ID'yi açın
2. **SHA-1 certificate fingerprints** bölümünde release keystore'un SHA-1 değerinin göründüğünden emin olun
3. Package name'in `com.flywork.friendify` olduğundan emin olun

## Destek

Sorun devam ederse:
- Google Cloud Console'da OAuth consent screen'in "Published" durumunda olduğundan emin olun
- Uygulama signing key'in Google Play Console'da doğru yapılandırıldığından emin olun (Play App Signing kullanıyorsanız, Google Play Console'dan SHA-1'i almanız gerekebilir)

