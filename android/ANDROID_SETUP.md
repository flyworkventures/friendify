# Android Setup Guide

Bu doküman, Android için gerekli package yapılandırmalarını açıklar.

## ✅ Tamamlanan Yapılandırmalar

### 1. Facebook Login
- ✅ `strings.xml` dosyasına Facebook App ID eklendi: `857430126746092`
- ✅ `AndroidManifest.xml`'e Facebook Activity ve meta-data eklendi
- ✅ URL Scheme eklendi: `fb857430126746092`
- ✅ Facebook queries eklendi (Facebook uygulaması için)

### 2. Google Sign-In
- ✅ Google Services plugin eklendi (`build.gradle.kts`)
- ✅ URL Scheme eklendi: `com.googleusercontent.apps.137535160742-vliktoiee2n5p70o5nts9rrahd0qrg03`
- ⚠️ **EKSIK:** `google-services.json` dosyası gerekiyor (Firebase Console'dan indirilmeli)

### 3. RevenueCat
- ✅ Package zaten ekli: `purchases_flutter: ^9.9.7`
- ✅ Android API Key tanımlı: `test_wtIfxKMxlDTSUssIwuSUWVsDiiK`
- ✅ `main.dart`'da initialize ediliyor

## 📋 Yapılması Gerekenler

### Google Sign-In için google-services.json

1. Firebase Console'a gidin: https://console.firebase.google.com/
2. Projenizi seçin veya yeni proje oluşturun
3. Android uygulaması ekleyin:
   - Package name: `com.flywork.friendify`
   - App nickname: Friendfy
4. `google-services.json` dosyasını indirin
5. Dosyayı `android/app/` klasörüne kopyalayın

### SHA-1 Certificate Fingerprint (Google Sign-In için)

Debug için SHA-1 fingerprint'ini alın ve Firebase Console'a ekleyin:

```bash
cd android
./gradlew signingReport
```

Çıktıdan SHA-1 değerini kopyalayıp Firebase Console > Project Settings > Your apps > Android app > Add fingerprint'a ekleyin.

## 📁 Yapılandırma Dosyaları

### AndroidManifest.xml
- Facebook App ID ve Client Token meta-data'ları
- Facebook Login Activity
- Google Sign-In URL Scheme
- Facebook URL Scheme

### strings.xml
- `facebook_app_id`: 857430126746092
- `facebook_client_token`: 015d731a1de8bf71bb6a11b2eef89687
- `fb_login_protocol_scheme`: fb857430126746092

### build.gradle.kts
- Google Services plugin eklendi
- Kotlin DSL kullanılıyor

## 🔍 Test Etme

### Facebook Login
1. Facebook Login butonuna tıklayın
2. Facebook hesabı seçin
3. İzinleri verin
4. Başarılı giriş yapılmalı

### Google Sign-In
1. Google Sign-In butonuna tıklayın
2. Google hesabı seçin
3. Başarılı giriş yapılmalı

### RevenueCat
1. Premium ekranını açın
2. Ürünler listelenmeli
3. Hata olmamalı

## ⚠️ Önemli Notlar

- Google Sign-In için `google-services.json` dosyası zorunludur
- Package name Firebase Console'da tanımlı olmalıdır
- SHA-1 fingerprint Firebase Console'a eklenmelidir
- Facebook App ID ve Client Token doğru olmalıdır


