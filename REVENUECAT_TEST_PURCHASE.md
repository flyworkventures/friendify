# RevenueCat Test Alımı Rehberi

RevenueCat'te test alımı yapmak için adım adım rehber.

## 🎯 Test Alımı Yöntemleri

### 1. iOS - Sandbox Test Kullanıcısı ile

#### Adım 1: Sandbox Test Kullanıcısı Oluşturma

1. **App Store Connect'e giriş yapın:**
   - https://appstoreconnect.apple.com

2. **Users and Access → Sandbox Testers bölümüne gidin**

3. **"+" butonuna tıklayıp yeni test kullanıcısı oluşturun:**
   - Email: Test için özel bir email (örn: `test@example.com`)
   - Password: Güvenli bir şifre
   - First Name / Last Name: Herhangi bir isim

4. **Test kullanıcısını kaydedin**

#### Adım 2: Test Alımı Yapma

1. **iOS simülatör veya gerçek cihazda:**
   - Settings → App Store → Sign Out (varsa)

2. **Uygulamanızı çalıştırın**

3. **Premium ekranını açın:**
   - Premium butonuna tıklayın
   - RevenueCat Paywall görünecek

4. **Satın alma yapmayı deneyin:**
   - "Subscribe" veya "Buy" butonuna tıklayın
   - Sandbox test kullanıcısı ile giriş yapın:
     - Email: Oluşturduğunuz test email
     - Password: Test şifresi
   - Onaylayın

5. **Test alımı tamamlanır:**
   - RevenueCat listener otomatik tetiklenir
   - Premium backend'e gönderilir
   - Premium tanımlanır

#### Adım 3: Logları Kontrol Etme

Uygulamanızda şu logları göreceksiniz:

```
📦 RevenueCat customerInfo updated
💰 Purchase update işleniyor...
✅ Aktif entitlement bulundu: premium
📦 Product ID: premium_monthly
🌐 Backend'e premium bilgisi gönderiliyor...
✅ Premium backend'de güncellendi
✅ Kullanıcı bilgisi güncellendi
```

---

### 2. Android - Test Alımı

#### Adım 1: Google Play Console'da Test Kullanıcısı

1. **Google Play Console'a giriş yapın:**
   - https://play.google.com/console

2. **Testing → License Testing bölümüne gidin**

3. **Test kullanıcı email'lerini ekleyin:**
   - Test için kullanacağınız Google email adresini ekleyin

#### Adım 2: Test Alımı Yapma

1. **Test cihazda:**
   - Google Play Store'dan çıkış yapın (varsa)

2. **Uygulamanızı çalıştırın**

3. **Premium ekranını açın ve satın almayı deneyin**

4. **Test hesabı ile giriş yapın**

5. **Satın alma onaylayın**

---

### 3. RevenueCat Dashboard'da Test

#### RevenueCat Dashboard'da Test Alımı Kontrolü

1. **RevenueCat Dashboard'a giriş yapın:**
   - https://app.revenuecat.com

2. **Customers bölümüne gidin**

3. **Test kullanıcısını bulun:**
   - Email veya App User ID ile arayın

4. **Customer Info'yu kontrol edin:**
   - Entitlements (Premium durumu)
   - Active Subscriptions
   - Transaction History

---

## 🔧 Test Alımı Sırasında Kontrol Edilecekler

### 1. RevenueCat Listener Çalışıyor mu?

Uygulamada şu logları arayın:

```dart
✅ RevenueCat purchase listener eklendi
📦 RevenueCat customerInfo updated
💰 Purchase update işleniyor...
```

### 2. Premium Backend'e Gidiyor mu?

Backend loglarında şunu görmelisiniz:

```
💎 Premium update request for userId: 123
💎 Updating memberships: [{"startDate":"...","endDate":"...","productId":"...","type":"paid","isActive":true}]
✅ Premium updated successfully for userId: 123
```

### 3. Database'de Güncellendi mi?

Database'de `users` tablosunda `memberships` kolonunu kontrol edin:

```sql
SELECT id, email, memberships FROM users WHERE id = YOUR_USER_ID;
```

`memberships` kolonunda şöyle bir JSON görmelisiniz:

```json
[
  {
    "startDate": "2024-01-01T00:00:00.000Z",
    "endDate": "2024-02-01T00:00:00.000Z",
    "productId": "premium_monthly",
    "type": "paid",
    "isActive": true,
    "purchasedAt": "2024-01-01T00:00:00.000Z"
  }
]
```

---

## 🐛 Sorun Giderme

### Test Alımı Yapılamıyor

1. **RevenueCat API Key kontrolü:**
   - iOS: `appl_pOEGBUSRqhfvvHeqqhIwBImdKlO`
   - Android: `test_wtIfxKMxlDTSUssIwuSUWVsDiiK`
   - `lib/main.dart` dosyasında doğru mu kontrol edin

2. **Product ID kontrolü:**
   - RevenueCat Dashboard → Products
   - Product ID'lerin doğru tanımlı olduğundan emin olun

3. **Sandbox Test Kullanıcısı:**
   - Test kullanıcısının aktif olduğundan emin olun
   - Email ve şifrenin doğru olduğundan emin olun

### Premium Tanımlanmıyor

1. **Backend loglarını kontrol edin:**
   - `/auth/update-premium` endpoint'ine istek geliyor mu?
   - Response 200 dönüyor mu?

2. **Frontend loglarını kontrol edin:**
   - RevenueCat listener çalışıyor mu?
   - CustomerInfo güncellendi mi?

3. **Database kontrolü:**
   - `memberships` kolonu güncellenmiş mi?
   - JSON formatı doğru mu?

---

## 📝 Test Senaryoları

### Senaryo 1: İlk Premium Alımı

1. Yeni bir test kullanıcısı ile giriş yap
2. Premium ekranını aç
3. Premium satın al
4. Backend'de premium tanımlandığını kontrol et
5. Uygulamada premium özelliklerin aktif olduğunu kontrol et

### Senaryo 2: Premium Yenileme

1. Mevcut premium üyeliği olan bir kullanıcı ile
2. Premium süresi dolduğunda
3. Otomatik yenilenme veya manuel yenileme test et

### Senaryo 3: Premium İptal

1. Premium üyeliği olan bir kullanıcı ile
2. Premium'u iptal et
3. Premium'un pasif olduğunu kontrol et

---

## 🎯 Hızlı Test Checklist

- [ ] Sandbox test kullanıcısı oluşturuldu
- [ ] RevenueCat API Key'ler doğru yapılandırıldı
- [ ] Products RevenueCat Dashboard'da tanımlı
- [ ] Uygulamada premium ekranı açılıyor
- [ ] Test alımı yapılabiliyor
- [ ] RevenueCat listener çalışıyor
- [ ] Premium backend'e gönderiliyor
- [ ] Database'de güncelleniyor
- [ ] Kullanıcı bilgisi yenileniyor
- [ ] Premium özellikler aktif oluyor

---

## 📚 Kaynaklar

- [RevenueCat Testing Guide](https://www.revenuecat.com/docs/testing)
- [App Store Connect Sandbox Testing](https://developer.apple.com/app-store-connect/sandbox-testing/)
- [Google Play Console Testing](https://support.google.com/googleplay/android-developer/answer/6062777)

---

## 💡 İpuçları

1. **Test Kullanıcısı:**
   - Gerçek Apple/Google hesabı kullanmayın
   - Test için özel bir email oluşturun

2. **Test Ortamı:**
   - iOS: Simülatör veya gerçek cihaz
   - Android: Test cihaz veya emülatör

3. **Logları İzleyin:**
   - Frontend: Flutter debug console
   - Backend: Server logs
   - RevenueCat: Dashboard → Customers

4. **Hızlı Test:**
   - RevenueCat Dashboard'da test alımları yapabilirsiniz
   - Customer Info'yu manuel güncelleyebilirsiniz

---

**Test alımı yaparken yukarıdaki adımları takip edin ve logları kontrol edin! 🚀**


