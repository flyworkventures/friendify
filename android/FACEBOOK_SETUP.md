# Facebook Login Setup for Android

## Sorun: "Feature Unavailable" Hatası ve Package Visibility Uyarısı

Bu hata genellikle Facebook Developer Console'da yapılandırma eksikliğinden kaynaklanır.

**ÖNEMLİ NOT:** AndroidManifest.xml'de `<queries>` bölümüne Facebook paketleri eklendi. Ancak loglarda hala "Apps that target Android API 30+ cannot call Facebook native apps" uyarısı görünüyorsa, bu normal olabilir - Facebook SDK bu kontrolü runtime'da yapıyor ve web-based login'e geri dönebilir. Bu uyarı işlevselliği engellemez, sadece native app login kullanılamazsa web login kullanılır.

## Çözüm Adımları

### 1. Facebook Developer Console'da Uygulamayı Kontrol Edin

1. https://developers.facebook.com/ adresine gidin
2. Uygulamanızı seçin (App ID: 857430126746092)
3. **Settings > Basic** bölümüne gidin

### 2. Android Platformunu Ekleyin

1. **Settings > Basic** sayfasında aşağı kaydırın
2. **+ Add Platform** butonuna tıklayın
3. **Android** seçeneğini seçin
4. **Package Name** alanına şunu girin: `com.flywork.friendify`
5. **Class Name** alanına şunu girin: `com.flywork.friendify.MainActivity`
6. **Save Changes** butonuna tıklayın

### 3. Key Hash'leri Ekleyin

#### Debug Key Hash (Geliştirme için)

Terminal'de şu komutu çalıştırın:

```bash
cd android
./gradlew signingReport
```

Çıktıda `SHA1` değerini bulun ve aşağıdaki komutu çalıştırın:

```bash
keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

Veya Windows'ta:

```cmd
keytool -exportcert -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android | openssl sha1 -binary | openssl base64
```

#### Release Key Hash (Production için)

Release keystore için:

```bash
keytool -exportcert -alias friendify -keystore android/app/keystore.jks -storepass 1234567890 -keypass 1234567890 | openssl sha1 -binary | openssl base64
```

Windows'ta:

```cmd
keytool -exportcert -alias friendify -keystore android\app\keystore.jks -storepass 1234567890 -keypass 1234567890 | openssl sha1 -binary | openssl base64
```

#### Key Hash'i Facebook'a Ekleme

1. Facebook Developer Console > **Settings > Basic**
2. **Key Hashes** bölümüne gidin
3. **+ Add Key Hash** butonuna tıklayın
4. Yukarıda aldığınız hash değerini yapıştırın
5. Hem debug hem de release key hash'lerini ekleyin
6. **Save Changes** butonuna tıklayın

### 4. Uygulama Modunu Kontrol Edin

1. Facebook Developer Console'da **Settings > Basic** sayfasına gidin
2. **App Mode** bölümünü kontrol edin
3. **Development Mode** ise, yalnızca geliştirici hesapları giriş yapabilir
4. **Live Mode** yapmak için:
   - **App Review** sekmesine gidin
   - Gerekli izinleri gözden geçirin
   - **Switch Mode** butonuna tıklayarak Live moda geçin

### 5. Facebook Login Özelliğini Etkinleştirin

1. Facebook Developer Console'da **Products** menüsüne gidin
2. **Facebook Login** ürününü bulun ve **Set Up** butonuna tıklayın
3. **Settings** sayfasında:
   - **Valid OAuth Redirect URIs** alanına şunu ekleyin:
     - `fb857430126746092://authorize`
   - **Deep Linking** için:
     - **Client OAuth Login**: Enabled
     - **Web OAuth Login**: Enabled

### 6. Uygulamayı Yeniden Derleyin

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

## Doğrulama

1. Uygulamayı çalıştırın
2. Facebook login butonuna tıklayın
3. Debug console'da hata mesajlarını kontrol edin
4. Başarılı olursa, Facebook giriş sayfası açılmalı

## Hala Sorun Yaşıyorsanız

1. **Facebook App ID'yi kontrol edin**: `android/app/src/main/res/values/strings.xml`
   - `facebook_app_id`: 857430126746092
   - `fb_login_protocol_scheme`: fb857430126746092
   - `facebook_client_token`: 63175d721fb2a0742882d383c5f10476

2. **AndroidManifest.xml'i kontrol edin**:
   - MainActivity'de Facebook intent-filter var mı?
   - FacebookActivity ve CustomTabActivity tanımlı mı?
   - Meta-data'lar doğru mu?

3. **Logcat'te hataları kontrol edin**:
   ```bash
   flutter run
   # Başka bir terminalde:
   adb logcat | grep -i facebook
   ```

4. **Facebook Developer Console'da "Alerts" bölümünü kontrol edin**

