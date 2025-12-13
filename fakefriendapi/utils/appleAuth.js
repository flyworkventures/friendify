const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');

/**
 * Apple Sign In için client_secret (JWT) oluşturur
 * @param {string} teamId - Apple Team ID (ör: "JK42R39DT5")
 * @param {string} clientId - Apple Client ID / Bundle ID (ör: "com.flywork.friendify")
 * @param {string} keyId - Apple Key ID (p8 dosyasının Key ID'si)
 * @param {string} privateKeyPath - .p8 dosyasının yolu (ör: "./certs/AuthKey_XXXXX.p8")
 * @returns {string} JWT client_secret token
 */
function generateAppleClientSecret(teamId, clientId, keyId, privateKeyPath) {
    try {
        // .p8 dosyasını oku
        const privateKey = fs.readFileSync(path.resolve(privateKeyPath), 'utf8');
        
        // JWT payload oluştur
        const payload = {
            iss: teamId,        // Issuer (Team ID)
            iat: Math.floor(Date.now() / 1000), // Issued at (current time)
            exp: Math.floor(Date.now() / 1000) + (6 * 30 * 24 * 60 * 60), // Expiration (6 months)
            aud: 'https://appleid.apple.com',
            sub: clientId       // Subject (Client ID / Bundle ID)
        };
        
        // JWT header
        const header = {
            alg: 'ES256',
            kid: keyId          // Key ID
        };
        
        // JWT oluştur
        const token = jwt.sign(payload, privateKey, {
            algorithm: 'ES256',
            header: header
        });
        
        return token;
    } catch (error) {
        console.error('❌ Error generating Apple client_secret:', error.message);
        throw error;
    }
}

/**
 * Environment variables veya varsayılan değerlerle Apple client_secret oluşturur
 * @returns {string|null} JWT client_secret token veya null
 */
function getAppleClientSecret() {
    try {
        // Environment variables
        const teamId = process.env.APPLE_TEAM_ID || 'JK42R39DT5';
        const clientId = process.env.APPLE_CLIENT_ID || 'com.flywork.friendify';
        const keyId = "J228M39BVZ"; // p8 dosyasının Key ID'si (ör: "ABC123DEF4")
        const privateKeyPath = "./certs/AuthKey.p8";
        
        // Key ID kontrolü
        if (!keyId) {
            console.log('⚠️ APPLE_KEY_ID environment variable not set');
            console.log('⚠️ Apple client_secret generation skipped');
            return null;
        }
        
        // .p8 dosyası kontrolü
        if (!fs.existsSync(path.resolve(privateKeyPath))) {
            console.log('⚠️ Apple private key file not found at:', privateKeyPath);
            console.log('⚠️ Apple client_secret generation skipped');
            return null;
        }
        
        // Client secret oluştur
        const clientSecret = generateAppleClientSecret(teamId, clientId, keyId, privateKeyPath);
        console.log('✅ Apple client_secret generated successfully');
        
        return clientSecret;
    } catch (error) {
        console.error('❌ Error getting Apple client_secret:', error.message);
        return null;
    }
}

module.exports = {
    generateAppleClientSecret,
    getAppleClientSecret
};


