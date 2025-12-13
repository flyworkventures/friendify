# Google Play Console'da AD_ID İzni Beyan Etme Rehberi

## AD_ID İzni Nedir?
`com.google.android.gms.permission.AD_ID` izni, Google Play Services'in reklam kimliği (Advertising ID) iznidir. Uygulamanızda RevenueCat (`purchases_flutter`) paketi bu izni kullanmaktadır.

## Google Play Console'da Beyan Etme Adımları

### 1. Google Play Console'a Giriş Yapın
- [Google Play Console](https://play.google.com/console) adresine gidin
- Uygulamanızı seçin

### 2. Veri Güvenliği Bölümüne Gidin
1. Sol menüden **"Uygulama içeriği"** (App content) veya **"Politika"** (Policy) bölümüne gidin
2. **"Veri güvenliği"** (Data safety) veya **"Uygulama içeriği"** (App content) sekmesine tıklayın

### 3. Reklam Kimliği Kullanımını Beyan Edin

#### Seçenek 1: Veri Güvenliği Bildirimi (Data Safety Section)
1. **"Toplanan veriler"** (Collected data) bölümüne gidin
2. **"Veri türü ekle"** (Add data type) butonuna tıklayın
3. **"Cihaz veya diğer kimlikler"** (Device or other IDs) kategorisini seçin
4. **"Reklam kimliği"** (Advertising ID) seçeneğini işaretleyin
5. Verinin nasıl kullanıldığını belirtin:
   - **Kullanım amacı**: "Analytics" ve/veya "Satın alma işlemleri"
   - **Toplanma amacı**: RevenueCat kullanıcı takibi ve analitik için kullanıldığını belirtin
   - **Veri paylaşımı**: RevenueCat ile paylaşıldığını belirtin (eğer paylaşılıyorsa)

#### Seçenek 2: Uygulama İçeriği (App Content)
1. **"Reklam kimliği"** (Advertising ID) veya **"Veri toplama"** (Data collection) bölümüne gidin
2. Reklam kimliği kullanıldığını belirtin

### 4. Kullanım Amacını Açıklayın

Aşağıdaki gibi bir açıklama yapabilirsiniz:

```
Reklam kimliği, RevenueCat SDK tarafından kullanıcı kimlik doğrulama 
ve satın alma işlemlerini izlemek için kullanılmaktadır. Bu veri, 
kullanıcıların premium aboneliklerini yönetmek ve analitik amaçlı 
kullanılmaktadır.
```

**Türkçe açıklama:**
```
Uygulamamız, RevenueCat SDK aracılığıyla reklam kimliğini kullanmaktadır. 
Bu kimlik, kullanıcıların premium abonelik durumlarını takip etmek, 
satın alma işlemlerini doğrulamak ve analitik amaçlar için kullanılmaktadır. 
Reklam veya kişiselleştirme amaçlı kullanılmamaktadır.
```

### 5. Kaydet ve Gönder
1. Tüm bilgileri doldurduktan sonra **"Kaydet"** (Save) butonuna tıklayın
2. Uygulama güncellemesini gönderdiğinizde bu beyan otomatik olarak uygulanacaktır

## Önemli Notlar

### ✅ Yapmanız Gerekenler:
- Reklam kimliği kullanıldığını açıkça beyan edin
- Kullanım amacını doğru şekilde açıklayın
- Verinin nasıl paylaşıldığını belirtin (RevenueCat ile)

### ❌ Yapmamanız Gerekenler:
- Reklam kimliği kullanıldığını gizlemeyin
- Yanlış bilgi vermeyin
- İzni kaldırmadan beyan etmeyi atlamayın

## Kontrol Listesi

- [ ] Google Play Console'a giriş yapıldı
- [ ] Veri Güvenliği bölümüne gidildi
- [ ] Reklam kimliği kullanıldığı beyan edildi
- [ ] Kullanım amacı açıklandı
- [ ] Veri paylaşımı belirtildi (RevenueCat ile)
- [ ] Bilgiler kaydedildi
- [ ] Uygulama güncellemesi gönderildi

## Sorun Giderme

### "İzin kullanılmıyor" uyarısı alıyorsanız:
1. AndroidManifest.xml'de iznin kaldırılmadığından emin olun
2. RevenueCat SDK'sının düzgün çalıştığını kontrol edin
3. Build çıktısında iznin olduğunu doğrulayın:
   ```
   build/app/intermediates/merged_manifests/debug/AndroidManifest.xml
   ```

### "İzin eksik" hatası alıyorsanız:
- AndroidManifest.xml'de izni manuel olarak eklemeyin (RevenueCat otomatik ekler)
- Build'i temizleyip yeniden derleyin:
  ```bash
  flutter clean
  flutter pub get
  flutter build apk
  ```

## Daha Fazla Bilgi

- [Google Play Veri Güvenliği Rehberi](https://support.google.com/googleplay/android-developer/answer/10787469)
- [RevenueCat Dokümantasyonu](https://www.revenuecat.com/docs)
- [Android Advertising ID Kullanımı](https://developer.android.com/training/articles/ad-id)

