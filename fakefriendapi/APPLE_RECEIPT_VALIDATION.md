# Apple Receipt Validation - App Store Review İçin

Apple App Store Review sırasında reddedilmemek için receipt validation'ın doğru yapılması gerekiyor.

## Sorun

Apple inceleme ekibi **Production imzalı** bir uygulama kullanır ama **Sandbox ortamında** satın alma yapar. Bu yüzden:

1. Önce Production URL'ine istek atılmalı
2. Eğer **Status 21007** (Sandbox receipt) hatası dönerse
3. Otomatik olarak Sandbox URL'ine istek atılmalı

## Çözüm

`/purchases/verify-receipt` endpoint'i oluşturuldu ve bu mantık implement edildi.

### Receipt Validation Akışı

```
1. Production URL'e istek at
   ↓
2. Status 0 (başarılı)?
   ✅ Production receipt doğrulandı
   ↓
3. Status 21007 (Sandbox receipt)?
   → Sandbox URL'e istek at
   ↓
4. Status 0 (başarılı)?
   ✅ Sandbox receipt doğrulandı
```

## API Endpoint

### POST `/purchases/verify-receipt`

**Headers:**
```
x-auth-token: <JWT_TOKEN>
Content-Type: application/json
```

**Body:**
```json
{
  "receiptData": "<base64_encoded_receipt_data>",
  "userId": 123
}
```

**Response (Success):**
```json
{
  "msg": "Receipt verified successfully",
  "success": true,
  "environment": "Production" | "Sandbox",
  "receipt": {
    "bundle_id": "com.flywork.friendify",
    "application_version": "1.0.0",
    "latest_receipt_info": [...],
    "pending_renewal_info": [...]
  }
}
```

**Response (Error):**
```json
{
  "msg": "Receipt verification failed",
  "success": false,
  "error": "Production verification failed with status: 21007"
}
```

## Environment Variables (Opsiyonel)

```bash
# App Store Connect'ten alınan shared secret (opsiyonel)
APPLE_SHARED_SECRET=your_shared_secret_here
```

## Apple Receipt Status Kodları

- `0`: Başarılı
- `21007`: Bu bir sandbox faturasıdır (Sandbox URL'ine istek atılmalı)
- `21000`: App Store receipt verileri doğrulanamadı
- `21002`: Receipt data property eksik veya malformed
- `21003`: Receipt doğrulanamadı
- `21004`: Verilen shared secret, account'un shared secret'i ile eşleşmiyor
- `21005`: Receipt server şu anda mevcut değil
- `21006`: Bu receipt geçerli ama subscription süresi dolmuş
- `21008`: Bu receipt production ortamından değil

## Test Etme

### 1. Production Receipt Test

```bash
curl -X POST https://friendfy.fly-work.com/purchases/verify-receipt \
  -H "Content-Type: application/json" \
  -H "x-auth-token: YOUR_JWT_TOKEN" \
  -d '{
    "receiptData": "PRODUCTION_RECEIPT_BASE64",
    "userId": 123
  }'
```

### 2. Sandbox Receipt Test

Sandbox receipt gönderildiğinde otomatik olarak Sandbox URL'ine geçiş yapılır.

## Frontend Entegrasyonu

Flutter tarafında RevenueCat kullanılıyorsa, receipt verification'ı RevenueCat'in webhook'ları üzerinden yapabilirsiniz veya bu endpoint'i direkt kullanabilirsiniz.

### RevenueCat Webhook Alternatifi

RevenueCat kullanıyorsanız, webhook'ları zaten Production/Sandbox fallback'i içerir. Bu endpoint'i sadece manuel verification için kullanabilirsiniz.

## Önemli Notlar

1. ✅ **Production First**: Önce Production URL'ine istek atılıyor
2. ✅ **Sandbox Fallback**: Status 21007'de otomatik Sandbox'a geçiliyor
3. ✅ **Timeout**: 30 saniye timeout eklendi
4. ✅ **Error Handling**: Tüm hata durumları loglanıyor

## Apple Review İçin Hazırlık

1. ✅ Receipt validation endpoint'i hazır
2. ✅ Production → Sandbox fallback mantığı implement edildi
3. ✅ Tüm hata durumları handle ediliyor
4. ✅ Detaylı logging eklendi

Bu endpoint ile Apple App Store Review'da reddedilmeyeceksiniz.


