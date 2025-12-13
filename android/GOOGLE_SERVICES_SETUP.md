# Google Sign-In Android Setup

## ⚠️ ÖNEMLİ: google-services.json Dosyası Gerekli

**Şu anda placeholtder bir `google-services.json` dosyası kullanılıyor. Google Sign-In'in çalışması için gerçek dosyayı Firebase Console'dan indirmeniz gerekiyor.**

## 1. Google Services JSON Dosyası

Google Sign-In için `google-services.json` dosyası gereklidir.

### Adımlar:

1. **Firebase Console'a gidin:** https://console.firebase.google.com/
2. **Projenizi seçin** veya yeni bir proje oluşturun
3. **Android uygulaması ekleyin:**
   - Sol menüden ⚙️ **Project Settings** > **Your apps** bölümüne gidin
   - **Add app** > **Android** seçin
   - **Package name:** `com.flywork.friendify` (AndroidManifest.xml'deki applicationId ile aynı olmalı)
   - **App nickname (optional):** Friendfy
   - **Debug signing certificate SHA-1 (optional):** Debug build için SHA-1 ekleyin (aşağıya bakın)
   - **Register app** butonuna tıklayın
4. **`google-services.json` dosyasını indirin**
5. **Dosyayı `android/app/` klasörüne kopyalayın** (mevcut placeholder dosyanın üzerine yazın)

### Önemli Notlar:

- iOS'ta kullanılan Google Client ID: `137535160742-vliktoiee2n5p70o5nts9rrahd0qrg03.apps.googleusercontent.com`
- Android için aynı Firebase projesini kullanın veya Google Cloud Console'da Android client ID oluşturun
- Package name'in Firebase Console'da tanımlı olması gerekiyor
- **Placeholder dosya build için yeterli ancak Google Sign-In çalışmayacak!**

## 2. Google Sign-In Package Name

AndroidManifest.xml'de package name şu şekilde tanımlı:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.flywork.friendify">
```

Bu package name Firebase Console'da tanımlı olmalıdır.

## 3. SHA-1 Certificate Fingerprint

### Debug SHA-1 Fingerprint (Şu anki):
```
C7:A6:48:26:D6:91:7C:31:B6:3E:0E:A9:3D:0A:44:90:EE:9A:5F:FA
```

**Firebase Console'da eklemek için:**
1. Firebase Console > Project Settings > Your apps > Android app
2. "Add fingerprint" butonuna tıklayın
3. Yukarıdaki SHA-1 değerini yapıştırın

### SHA-256 Fingerprint (isteğe bağlı):
```
2C:A9:D3:C7:E1:47:E3:D8:88:E3:FC:70:8B:79:71:10:97:FE:EE:18:F3:FC:84:8B:CC:DE:BC:B4:7F:EB:6F:C0
```

### Yeniden SHA-1 almak için:
```bash
cd android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
$JAVA_HOME/bin/keytool -list -v -keystore ~/.android/debug.keystore -alias AndroidDebugKey -storepass android -keypass android | grep SHA1
```

**Production için:**
Production build için SHA-1 fingerprint'ini release keystore'dan alın ve Firebase Console'a ekleyin.

## 4. Test

Google Sign-In testi için:
- Google Sign-In butonuna tıklayın
- Google hesabı seçin
- Başarılı giriş yapılmalı

