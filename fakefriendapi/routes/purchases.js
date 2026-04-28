const router = require('express').Router();
const middleware = require('../middleware/checkAuth');
const axios = require('axios');
const { getQuery, query } = require('../db');

// Apple Receipt Validation URLs
const APPLE_PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

/**
 * Apple Receipt Validation - Production ve Sandbox fallback mantığı
 * Apple App Store Review için gerekli: Önce Production'a istek at, 21007 hatası dönerse Sandbox'a geç
 */
async function verifyAppleReceipt(receiptData) {
    try {
        // 1️⃣ Önce Production URL'ine istek at
        console.log('📦 Verifying receipt with Apple Production...');
        
        const productionResponse = await axios.post(
            APPLE_PRODUCTION_URL,
            {
                'receipt-data': receiptData,
                'password': process.env.APPLE_SHARED_SECRET || '', // App Store Connect'ten alınan shared secret (opsiyonel)
                'exclude-old-transactions': false
            },
            {
                headers: {
                    'Content-Type': 'application/json'
                },
                timeout: 30000 // 30 saniye timeout
            }
        );

        const productionResult = productionResponse.data;
        console.log('📦 Production response status:', productionResult.status);

        // Status 0 = başarılı
        if (productionResult.status === 0) {
            console.log('✅ Receipt verified successfully in Production');
            return {
                success: true,
                environment: 'Production',
                receipt: productionResult
            };
        }

        // Status 21007 = Bu bir sandbox faturasıdır, sandbox URL'ine istek atmalıyız
        if (productionResult.status === 21007) {
            console.log('🔄 Status 21007: Sandbox receipt detected, switching to Sandbox URL...');
            
            // 2️⃣ Sandbox URL'ine istek at
            const sandboxResponse = await axios.post(
                APPLE_SANDBOX_URL,
                {
                    'receipt-data': receiptData,
                    'password': process.env.APPLE_SHARED_SECRET || '',
                    'exclude-old-transactions': false
                },
                {
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    timeout: 30000
                }
            );

            const sandboxResult = sandboxResponse.data;
            console.log('📦 Sandbox response status:', sandboxResult.status);

            if (sandboxResult.status === 0) {
                console.log('✅ Receipt verified successfully in Sandbox');
                return {
                    success: true,
                    environment: 'Sandbox',
                    receipt: sandboxResult
                };
            } else {
                console.error('❌ Sandbox verification failed:', sandboxResult.status);
                return {
                    success: false,
                    error: `Sandbox verification failed with status: ${sandboxResult.status}`,
                    receipt: sandboxResult
                };
            }
        }

        // Diğer hata kodları
        console.error('❌ Production verification failed:', productionResult.status);
        return {
            success: false,
            error: `Production verification failed with status: ${productionResult.status}`,
            receipt: productionResult
        };

    } catch (error) {
        console.error('❌ Receipt verification error:', error.message);
        if (error.response) {
            console.error('❌ Response status:', error.response.status);
            console.error('❌ Response data:', error.response.data);
        }
        return {
            success: false,
            error: error.message,
            receipt: null
        };
    }
}

/**
 * Receipt doğrulama endpoint'i
 * POST /purchases/verify-receipt
 */
router.post('/verify-receipt', middleware, async (req, res) => {
    try {
        const { receiptData, userId } = req.body;

        if (!receiptData) {
            return res.status(400).json({
                msg: 'receiptData is required',
                success: false
            });
        }

        if (!userId) {
            return res.status(400).json({
                msg: 'userId is required',
                success: false
            });
        }

        console.log('📝 Receipt verification request received for userId:', userId);

        // Apple'dan receipt'i doğrula
        const verificationResult = await verifyAppleReceipt(receiptData);

        if (!verificationResult.success) {
            return res.status(400).json({
                msg: 'Receipt verification failed',
                success: false,
                error: verificationResult.error,
                receipt: verificationResult.receipt
            });
        }

        // Receipt doğrulandı, abonelik bilgilerini çıkar
        const receipt = verificationResult.receipt;
        const latestReceiptInfo = receipt.latest_receipt_info || [];
        const inAppPurchases = receipt.receipt?.in_app || [];

        console.log('✅ Receipt verified successfully in', verificationResult.environment);
        console.log('📦 Latest receipt info count:', latestReceiptInfo.length);
        console.log('📦 In-app purchases count:', inAppPurchases.length);

        // Abonelik bilgilerini işle (isterseniz DB'ye kaydedebilirsiniz)
        // Burada sadece doğrulama sonucunu döndürüyoruz

        return res.status(200).json({
            msg: 'Receipt verified successfully',
            success: true,
            environment: verificationResult.environment,
            receipt: {
                bundle_id: receipt.receipt?.bundle_id,
                application_version: receipt.receipt?.application_version,
                latest_receipt_info: latestReceiptInfo,
                pending_renewal_info: receipt.pending_renewal_info || []
            }
        });

    } catch (error) {
        console.error('❌ verify-receipt error:', error);
        return res.status(500).json({
            msg: 'Server error',
            success: false,
            error: error.message
        });
    }
});

/**
 * RevenueCat memberships sync endpoint
 * POST /purchases/sync-memberships
 *
 * Beklenen body:
 * {
 *   "userId": 123,
 *   "source": "revenuecat_client",
 *   "memberships": [
 *     {
 *       "startDate": "2025-12-16T14:08:42.000Z",
 *       "endDate": "2026-12-16T14:08:42.000Z",
 *       "productId": "friendify_pro",
 *       "type": "paid",
 *       "isActive": true,
 *       "purchasedAt": "2025-12-16T14:08:42.000Z"
 *     }
 *   ],
 *   "revenuecat": { ...opsiyonel metadata... }
 * }
 */
router.post('/sync-memberships', middleware, async (req, res) => {
    try {
        const { userId, source, memberships, revenuecat } = req.body || {};

        if (!userId) {
            return res.status(400).json({
                msg: 'userId is required',
                success: false
            });
        }

        if (!Array.isArray(memberships)) {
            return res.status(400).json({
                msg: 'memberships must be an array',
                success: false
            });
        }

        const userCheck = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        if (userCheck.length === 0) {
            return res.status(404).json({
                msg: 'User not found',
                success: false
            });
        }

        const normalizeDate = (value) => {
            if (!value) return null;
            const parsed = new Date(value);
            if (Number.isNaN(parsed.getTime())) return null;
            return parsed.toISOString();
        };

        const normalizedMemberships = memberships
            .map((item) => ({
                startDate: normalizeDate(item.startDate) || new Date().toISOString(),
                endDate: normalizeDate(item.endDate),
                productId: String(item.productId || ''),
                type: String(item.type || 'paid'),
                isActive: Boolean(item.isActive),
                purchasedAt: normalizeDate(item.purchasedAt),
            }))
            .filter((item) => item.productId.length > 0);

        await query(
            "UPDATE `users` SET `memberships` = ? WHERE id = ?",
            [JSON.stringify(normalizedMemberships), userId]
        );

        const updatedUserResult = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        const updatedUser = updatedUserResult[0];

        console.log("✅ Memberships synced", {
            userId,
            source: source || 'unknown',
            membershipsCount: normalizedMemberships.length,
            hasRevenueCatMeta: !!revenuecat
        });

        return res.status(200).json({
            msg: 'Memberships synced successfully',
            success: true,
            format: {
                source: source || 'unknown',
                membershipsCount: normalizedMemberships.length
            },
            user: updatedUser
        });
    } catch (error) {
        console.error('❌ sync-memberships error:', error);
        return res.status(500).json({
            msg: 'Server error',
            success: false,
            error: error.message
        });
    }
});

module.exports = router;


