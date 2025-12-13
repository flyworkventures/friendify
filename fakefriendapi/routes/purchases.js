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

module.exports = router;


