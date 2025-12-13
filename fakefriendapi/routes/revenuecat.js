const router = require('express').Router();
const axios = require('axios');
const { getQuery, query } = require('../db');

// RevenueCat webhook handler - Apple'ın receipt validation gereksinimi için
// RevenueCat webhook'ları zaten Production/Sandbox fallback'i içerir

/**
 * RevenueCat Webhook Events:
 * - INITIAL_PURCHASE: İlk satın alma
 * - RENEWAL: Abonelik yenileme
 * - CANCELLATION: İptal
 * - UNCANCELLATION: İptal geri alma
 * - NON_RENEWING_PURCHASE: Yenilenmeyen satın alma
 * - SUBSCRIPTION_PAUSED: Abonelik duraklatıldı
 * - EXPIRATION: Süre doldu
 * - BILLING_ISSUE: Faturalama sorunu
 */

// RevenueCat webhook endpoint (middleware olmadan - RevenueCat'ten gelecek)
router.post('/webhook', async (req, res) => {
    try {
        // RevenueCat webhook doğrulama (opsiyonel ama önerilir)
        // RevenueCat Authorization header'ı ile doğrulama yapılabilir
        
        const event = req.body;
        console.log('📦 RevenueCat webhook received:', event.type);
        console.log('📦 Event data:', JSON.stringify(event, null, 2));

        // RevenueCat webhook event type'ına göre işlem yap
        switch (event.type) {
            case 'INITIAL_PURCHASE':
            case 'RENEWAL':
            case 'UNCANCELLATION':
                await handlePurchaseEvent(event);
                break;
            
            case 'CANCELLATION':
            case 'EXPIRATION':
                await handleCancellationEvent(event);
                break;
            
            default:
                console.log('ℹ️ Unhandled webhook event type:', event.type);
        }

        // RevenueCat'e 200 döndür (webhook başarılı)
        return res.status(200).json({ received: true });

    } catch (error) {
        console.error('❌ RevenueCat webhook error:', error);
        // Hata olsa bile 200 döndür (RevenueCat tekrar göndermesin)
        return res.status(200).json({ received: false, error: error.message });
    }
});

/**
 * Satın alma event'ini handle eder
 */
async function handlePurchaseEvent(event) {
    try {
        const appUserId = event.app_user_id; // Kullanıcı ID (backend'deki user ID olmalı)
        const productId = event.product_id;
        const purchasedAt = new Date(event.purchased_at_ms || Date.now());
        const expiresDate = event.expires_date ? new Date(event.expires_date) : null;
        
        console.log('💰 Processing purchase event for user:', appUserId);
        console.log('💰 Product ID:', productId);
        console.log('💰 Purchased at:', purchasedAt);
        console.log('💰 Expires at:', expiresDate);

        // Receipt validation (Apple'ın gereksinimi için)
        // RevenueCat zaten receipt validation yapmış, ama yine de loglayalım
        const receiptData = event.transaction_id; // RevenueCat transaction ID
        
        // Kullanıcıyı bul
        const user = await getQuery("SELECT * FROM `users` WHERE id = ?", [appUserId]);
        
        if (user.length === 0) {
            console.error('❌ User not found for purchase event:', appUserId);
            return;
        }

        const currentUser = user[0];
        console.log('✅ User found for purchase event');

        // Premium bilgilerini güncelle
        // memberships array'ine yeni premium ekle
        const premiumData = {
            startDate: purchasedAt.toISOString(),
            endDate: expiresDate ? expiresDate.toISOString() : null,
            productId: productId,
            type: 'paid',
            isActive: true,
            purchasedAt: purchasedAt.toISOString()
        };

        // Mevcut memberships'i al
        let memberships = [];
        if (currentUser.memberships) {
            try {
                memberships = typeof currentUser.memberships === 'string' 
                    ? JSON.parse(currentUser.memberships) 
                    : currentUser.memberships;
            } catch (e) {
                console.error('⚠️ Error parsing memberships:', e);
                memberships = [];
            }
        }

        // Eski aktif premium'ları pasif yap
        memberships = memberships.map(m => {
            if (m.isActive) {
                return { ...m, isActive: false };
            }
            return m;
        });

        // Yeni premium'u ekle
        memberships.push(premiumData);

        // DB'yi güncelle
        await query(
            "UPDATE `users` SET `memberships` = ? WHERE id = ?",
            [JSON.stringify(memberships), appUserId]
        );

        console.log('✅ Premium membership updated successfully');

    } catch (error) {
        console.error('❌ Error handling purchase event:', error);
        throw error;
    }
}

/**
 * İptal/Expiration event'ini handle eder
 */
async function handleCancellationEvent(event) {
    try {
        const appUserId = event.app_user_id;
        
        console.log('🚫 Processing cancellation/expiration event for user:', appUserId);

        // Kullanıcıyı bul
        const user = await getQuery("SELECT * FROM `users` WHERE id = ?", [appUserId]);
        
        if (user.length === 0) {
            console.error('❌ User not found for cancellation event:', appUserId);
            return;
        }

        const currentUser = user[0];

        // Aktif premium'ları pasif yap
        let memberships = [];
        if (currentUser.memberships) {
            try {
                memberships = typeof currentUser.memberships === 'string' 
                    ? JSON.parse(currentUser.memberships) 
                    : currentUser.memberships;
            } catch (e) {
                console.error('⚠️ Error parsing memberships:', e);
                memberships = [];
            }
        }

        // Tüm aktif premium'ları pasif yap
        memberships = memberships.map(m => {
            if (m.isActive) {
                return { ...m, isActive: false };
            }
            return m;
        });

        // DB'yi güncelle
        await query(
            "UPDATE `users` SET `memberships` = ? WHERE id = ?",
            [JSON.stringify(memberships), appUserId]
        );

        console.log('✅ Premium membership cancelled/expired');

    } catch (error) {
        console.error('❌ Error handling cancellation event:', error);
        throw error;
    }
}

module.exports = router;


