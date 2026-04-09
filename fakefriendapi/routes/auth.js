const router = require('express').Router()
const { check, validationResult } = require('express-validator')
const users = require('../fakedb/users');
const UserModel = require('../models/user_model');
const bcrypt = require('bcrypt')
const JWT = require('jsonwebtoken')
const { getQuery , query} = require('../db')
const axios = require('axios')
const { getAppleClientSecret } = require('../utils/appleAuth')

// UUID generator for guest users
function guidGenerator() {
    var S4 = function() {
       return (((1+Math.random())*0x10000)|0).toString(16).substring(1);
    };
    return (S4()+S4()+"-"+S4()+"-"+S4()+"-"+S4()+"-"+S4()+S4()+S4());
}


router.post('/signup', [
    check("email").isEmail(),
    check("password").isLength({
        min: 8
    })
], async (req, res) => {
    const { password, email, credential } = req.body;

    if (credential == null) {
      return  res.status(400).json({
            "msg": "Credential is not null"
        })
    }else{

    if (credential == "email") {

        const errors = validationResult(req)

        if (!errors.isEmpty()) {
            return res.status(400).json({
                errors: errors.array()
            })
        }

        console.log("Email: " + email + " Password: " + password)
        let sqlQuery = await getQuery("SELECT * FROM `users` WHERE email = ?", [email]);

        if (sqlQuery.length > 0) {
            console.log("User var");
            res.status(400).json({
                "error": "User exists"
            })

        } else {
            let hashedPassword = await bcrypt.hash(password, 10);
            query("INSERT INTO `users` (`email`, `password`, `token`, `accountCreatedDate`, `memberships`, `ownAgents`, `verificated`, `credential`, `refreshToken`, `phoneNumber`, `lastLogins`) VALUES ( ?,?,?,?,?,?,?,?,?,?,?);",[ email,hashedPassword, null, null, null, null, null, credential, null, null, null])
            

            const token = await JWT.sign({
                email
            },
                "key",
                {
                    expiresIn: 3600000
                }
            );
            return res.json({
                token
            })
        }
    }else if(credential == "google" || credential == "facebook" || credential == "apple"){
       const { userModel } = req.body;
       const user = userModel;
        try {
            // Ensure userModel is a JSON object (parse if it's a string)
            let parsedUser = userModel;
            if (typeof parsedUser === 'string') {
                parsedUser = JSON.parse(parsedUser);
            }
            console.log("📝 Signup request - Parsed User:", parsedUser);

            const userEmail = parsedUser.email || email;
            const appleUserIdentifier = parsedUser.appleUserIdentifier || parsedUser.userIdentifier;
            const appleToken = parsedUser.appleToken || parsedUser.authorizationCode; // Apple token (authorizationCode)
            
            // Apple token logla
            if (credential === "apple") {
                console.log("🍎 Apple signup - appleUserIdentifier:", appleUserIdentifier || "N/A");
                console.log("🍎 Apple signup - appleToken exists:", !!appleToken);
                if (appleToken) {
                    console.log("🍎 Apple signup - appleToken length:", appleToken.length);
                }
            }
            
            // ✅ Apple için userIdentifier kontrolü
            if (credential === "apple" && appleUserIdentifier) {
                console.log("🍎 Checking if Apple user exists with identifier:", appleUserIdentifier);
                const existingAppleUser = await getQuery("SELECT * FROM `users` WHERE appleUserIdentifier = ?", [appleUserIdentifier]);
                
                if (existingAppleUser.length > 0) {
                    console.log("⚠️ Apple user already exists with this identifier!");
                    return res.status(400).json({ 
                        msg: "User already exists with this Apple identifier",
                        error: "User exists",
                        success: false
                    });
                }
            }
            
            // ✅ EMAIL KONTROLÜ EKLE - Kullanıcı zaten var mı? (Apple dışı için)
            if (credential !== "apple") {
                console.log("🔍 Checking if user already exists with email:", userEmail);
                const existingUser = await getQuery("SELECT * FROM `users` WHERE email = ?", [userEmail]);
                
                if (existingUser.length > 0) {
                    console.log("⚠️ User already exists with this email!");
                    return res.status(400).json({ 
                        msg: "User already exists with this email",
                        error: "User exists",
                        success: false
                    });
                }
            }
            
            console.log("✅ User is available, creating new user...");
            const birthdate = formatDateForMySQL(parsedUser.birthdate);
            const hashedPassword = null; // Social auth users won't have a local password
             const token = JWT.sign({ email: userEmail }, "key", { expiresIn: 3600000 });

            // Insert the user into the DB (Apple için appleUserIdentifier ve appleToken ekle)
            // Gender opsiyonel - Apple App Store gereksinimleri için
            const insertResult = await query(
                "INSERT INTO `users` (`username`, `email`, `password`, `token`, `memberships`, `ownAgents`, `verificated`, `credential`, `refreshToken`, `phoneNumber`, `lastLogins`, `country`, `gender` , `birthdate`, `appleUserIdentifier`, `appleToken`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                [parsedUser.username, userEmail, hashedPassword, token, null, null, "1", credential, null, null, null, parsedUser.counrty || null, parsedUser.gender || null, birthdate, credential === "apple" ? appleUserIdentifier : null, credential === "apple" ? appleToken : null]
            );

            console.log("📦 Full insertResult:", insertResult);
            
            // query() returns an array [ResultSetHeader, fields], we need the first element
            let result = insertResult;
            if (Array.isArray(insertResult)) {
                result = insertResult[0];
                console.log("✅ Extracted first element from array");
            }
            
            console.log("📝 Insert result type:", typeof result);
            console.log("📝 Insert result keys:", result ? Object.keys(result) : 'null');
            console.log("📝 Insert result:", { insertId: result?.insertId, affectedRows: result?.affectedRows });

            // Get the newly created user with ID (email sorgusu EN güvenilir yöntem)
            // insertId check'i kaldırdık çünkü user zaten oluşturuluyor, sadece bulmalıyız
            console.log("🔍 Fetching created user with email:", userEmail, "and credential:", credential);
            
            // Küçük bir delay ekle, DB'nin commit etmesini bekle
            await new Promise(resolve => setTimeout(resolve, 100));
            
            const newUser = await getQuery("SELECT * FROM `users` WHERE email = ? AND credential = ?", [userEmail, credential]);
            console.log("📊 Query result count:", newUser.length);
            
            if (newUser.length > 0) {
                console.log("✅ User created successfully with ID:", newUser[0].id);
                return res.json({ 
                    token,
                    user: newUser[0],
                    success: true
                });
            }
            
            // Eğer credential ile bulamazsak, sadece email ile dene
            console.log("⚠️ Not found with credential, trying email only...");
            const userByEmail = await getQuery("SELECT * FROM `users` WHERE email = ?", [userEmail]);
            console.log("📊 Email-only query result count:", userByEmail.length);
            
            if (userByEmail.length > 0) {
                console.log("✅ User found by email only with ID:", userByEmail[0].id);
                return res.json({ 
                    token,
                    user: userByEmail[0],
                    success: true
                });
            }
            
            // Son çare: insertId varsa onunla dene
            if (result?.insertId) {
                console.log("🔍 Last attempt: Trying direct ID query:", result.insertId);
                const userById = await getQuery("SELECT * FROM `users` WHERE id = ?", [result.insertId]);
                if (userById.length > 0) {
                    console.log("✅ User found by ID:", result.insertId);
                    return res.json({ 
                        token,
                        user: userById[0],
                        success: true
                    });
                }
            }
            
            console.log("❌ User created but could not be found in any way");
            return res.status(500).json({ 
                msg: "User created but not found", 
                success: false,
                debug: { 
                    insertId: result?.insertId, 
                    email: userEmail,
                    credential: credential,
                    hint: "User might exist, check database manually"
                }
            });
           
        } catch (err) {
            console.error("❌ Signup error:", err);
            return res.status(500).json({ msg: "Server error", error: err.message });
        }
    }
    }



})

function formatDateForMySQL(dateString) {
  const date = new Date(dateString);
  const pad = (n) => (n < 10 ? "0" + n : n);

  return (
    date.getFullYear() +
    "-" +
    pad(date.getMonth() + 1) +
    "-" +
    pad(date.getDate()) +
    " " +
    pad(date.getHours()) +
    ":" +
    pad(date.getMinutes()) +
    ":" +
    pad(date.getSeconds())
  );
}




router.post('/login', async (req, res) => {
 const { credential , password, email} = req.body;
 if (credential == null) {
    return   res.status(400).json({
            "msg": "Credential is not null",
        })
 }else{
if (credential == "email") {
        let sqlQuery = await getQuery("SELECT * FROM `users` WHERE email = ?", [email]);
        if (sqlQuery.length === 0) {
                 res.status(404).json({
             "msg": "Invalid "
        })
        }else{

             console.log("User Query: ", sqlQuery)
        let user = sqlQuery[0];
        console.log("User: ", user)
        let isMatch = await bcrypt.compare(password,user["password"]);
        if (!isMatch) {
            res.status(404).json({
                "msg": "Invalid credentials"
            })
        } 
        const token = await JWT.sign({email},"key",{expiresIn: 360000});
        return res.json({
            token
        })   
        }
   
     
  
}
 }

   



}),


router.post('/verify-token', async (req, res) => {
    const { token } = req.body;
    try {
        let user = await JWT.verify(token, "key");
        let userModel = await getUserData(user["email"]);
       
        console.log("Verified User: ", user)
        if (user) {

            return res.status(200).json({
                "msg": "Valid Token",
                "user": userModel
            })
        } else {
            return res.status(400).json({
                "msg": "Invalid Token 400"
            })
        }
    } catch (err) {
        console.log(err)
        return res.status(400).json({
            "msg": "Invalid Token "
        })
    }
})


async function getUserData(email){
let sqlQuery = await getQuery("SELECT * FROM `users` WHERE email = ?", [email]);
console.log("Tetiklendi")
if (sqlQuery.length === 0) {
           return null;
        }else{
            console.log("User: " + sqlQuery[0])
            return sqlQuery[0];
        }
}





router.post('/check-mail', async(req,res)=>{
   const  {email, appleUserIdentifier} = req.body;
   
   // Apple için userIdentifier kontrolü
   if (appleUserIdentifier) {
       console.log("🍎 Checking Apple user with identifier:", appleUserIdentifier);
       let sqlQuery = await getQuery("SELECT * FROM `users` WHERE appleUserIdentifier = ?", [appleUserIdentifier]);

       if (sqlQuery.length > 0) {
           console.log("✅ Apple user found with identifier");
           return res.status(400).json({
               "msg": "User exists",
               "model": sqlQuery
           });
       } else {
           console.log("✅ Apple user not found, available for registration");
           return res.status(200).json({
               "msg": "Available"
           });
       }
   }
   
   // Normal email kontrolü
   if (email) {
       let sqlQuery = await getQuery("SELECT * FROM `users` WHERE email = ?", [email]);

        if (sqlQuery.length > 0) {
           return res.status(400).json({
                "msg": "User exists",
                "model": sqlQuery
           });
       } else {
           return res.status(200).json({
               "msg": "Available"
           });
       }
        }
   
   // Hiçbir parametre yoksa hata döndür
   return res.status(400).json({
       "msg": "email or appleUserIdentifier is required"
   });
})


const middleware = require('../middleware/checkAuth');

router.post('/update-profile', middleware, async (req, res) => {
    try {
        const { userId, username, photoURL, birthdate, gender } = req.body;

        if (!userId) {
            return res.status(400).json({
                msg: "User ID is required",
                success: false
            });
        }

        // Kullanıcının var olup olmadığını kontrol et
        const userCheck = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        
        if (userCheck.length === 0) {
            return res.status(404).json({
                msg: "User not found",
                success: false
            });
        }

        // Güncelleme işlemi
        let updateQuery = "UPDATE `users` SET ";
        let updateValues = [];
        let updateFields = [];

        if (username !== undefined && username !== null) {
            updateFields.push("username = ?");
            updateValues.push(username);
        }

        if (photoURL !== undefined && photoURL !== null) {
            updateFields.push("photoURL = ?");
            updateValues.push(photoURL);
        }

        if (birthdate !== undefined && birthdate !== null) {
            updateFields.push("birthdate = ?");
            updateValues.push(birthdate);
        }

        if (gender !== undefined) {
            // gender null olabilir (kullanıcı "belirtmeyi tercih etmiyorum" seçebilir)
            // null değerini de güncelleyebilmek için undefined kontrolü yeterli
            updateFields.push("gender = ?");
            updateValues.push(gender === null ? null : gender);
        }

        if (updateFields.length === 0) {
            return res.status(400).json({
                msg: "No fields to update",
                success: false
            });
        }

        updateQuery += updateFields.join(", ");
        updateQuery += " WHERE id = ?";
        updateValues.push(userId);

        await query(updateQuery, updateValues);

        // Güncellenmiş kullanıcı bilgilerini al
        const updatedUser = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);

        return res.status(200).json({
            msg: "Profile updated successfully",
            success: true,
            user: updatedUser[0]
        });

    } catch (error) {
        console.error("update-profile error:", error);
        return res.status(500).json({
            msg: "Server error",
            success: false,
            error: error.message
        });
    }
});


router.post('/update-premium', middleware, async (req, res) => {
    try {
        const { userId, memberships } = req.body;

        if (!userId) {
            return res.status(400).json({
                msg: "User ID is required",
                success: false
            });
        }
        
        if (!memberships) {
            return res.status(400).json({
                msg: "Memberships data is required",
                success: false
            });
        }
        
        console.log("💎 Premium update request for userId:", userId);

        // Kullanıcının var olup olmadığını kontrol et
        const userCheck = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        
        if (userCheck.length === 0) {
            return res.status(404).json({
                msg: "User not found",
                success: false
            });
        }
        
        // Memberships'i güncelle
        // Eğer string ise direkt kullan, değilse JSON'a çevir
        let membershipsJson = memberships;
        if (typeof memberships !== 'string') {
            membershipsJson = JSON.stringify(memberships);
        }
        
        console.log("💎 Updating memberships:", membershipsJson);
        
        await query(
            "UPDATE `users` SET `memberships` = ? WHERE id = ?",
            [membershipsJson, userId]
        );
        
        // Güncellenmiş kullanıcı bilgilerini al
        const updatedUser = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        
        console.log("✅ Premium updated successfully for userId:", userId);
        
        return res.status(200).json({
            msg: "Premium updated successfully",
            success: true,
            user: updatedUser[0]
        });
        
    } catch (error) {
        console.error("❌ update-premium error:", error);
        return res.status(500).json({
            msg: "Server error",
            success: false,
            error: error.message
        });
    }
});

router.post('/delete-account', middleware, async (req, res) => {
    try {
        const { userId } = req.body;
        console.log("🗑️ Delete account request for userId:", userId);

        if (!userId) {
            console.log("❌ No userId provided");
            return res.status(400).json({
                msg: "User ID is required",
                success: false
            });
        }

        // Kullanıcının var olup olmadığını kontrol et
        const userCheck = await getQuery("SELECT * FROM `users` WHERE id = ?", [userId]);
        console.log("👤 User check result:", userCheck.length > 0 ? "User found" : "User not found");
        
        if (userCheck.length === 0) {
            return res.status(404).json({
                msg: "User not found",
                success: false
            });
        }

        const user = userCheck[0];
        
        // ✅ Apple kullanıcısı ise, Apple token'ını revoke et
        if (user.credential === "apple") {
            console.log("🍎 Apple user detected for deletion");
            console.log("🍎 User credential:", user.credential);
            console.log("🍎 AppleToken exists:", !!user.appleToken);
            console.log("🍎 AppleUserIdentifier:", user.appleUserIdentifier || "N/A");
            
            if (user.appleToken) {
                console.log("🍎 Attempting to revoke Apple token...");
                
                // Apple'ın revoke endpoint'i için client_secret gerekli (JWT tabanlı)
                // Önce environment variable'dan kontrol et, yoksa .p8 dosyasından oluştur
                let clientSecret = process.env.APPLE_CLIENT_SECRET;
                
                if (!clientSecret) {
                    console.log("⚠️ APPLE_CLIENT_SECRET env variable not found, attempting to generate from .p8 file...");
                    clientSecret = getAppleClientSecret();
                }
                
                if (!clientSecret) {
                    console.log("⚠️ Apple client_secret could not be generated");
                    console.log("⚠️ Token revoke will be skipped - Apple requires client_secret (JWT) for revoke");
                    console.log("ℹ️ Note: This is acceptable per Apple guidelines - authorizationCode expires in ~10 minutes anyway");
                    console.log("ℹ️ Account deletion will continue without token revoke");
                } else {
                    try {
                        const clientId = process.env.APPLE_CLIENT_ID || 'com.flywork.friendify';
                        console.log("🍎 Using Apple Client ID:", clientId);
                        console.log("🍎 Client secret ready (length:", clientSecret.length, "chars)");
                        
                        // Apple'ın revoke endpoint'ine istek gönder
                        // authorizationCode tek kullanımlık ve süresi dolmuş olabilir (10 dakika),
                        // ama yine de Apple'ın kurallarına uygun olarak deniyoruz
                        const revokeParams = new URLSearchParams({
                            client_id: clientId,
                            client_secret: clientSecret,
                            token: user.appleToken,
                            token_type_hint: 'authorization_code'
                        });
                        
                        console.log("🍎 Sending revoke request to Apple...");
                        const revokeResponse = await axios.post(
                            'https://appleid.apple.com/auth/revoke',
                            revokeParams,
                            {
                                headers: {
                                    'Content-Type': 'application/x-www-form-urlencoded'
                                },
                                timeout: 10000 // 10 saniye timeout
                            }
                        );
                        
                        console.log("✅ Apple token revoked successfully!");
                        console.log("✅ Revoke response status:", revokeResponse.status);
                        console.log("✅ Revoke response data:", revokeResponse.data || "(empty response - normal)");
                    } catch (revokeError) {
                        // Token revoke hatası detaylı logla
                        console.error("❌ Apple token revoke failed!");
                        console.error("❌ Error message:", revokeError.message);
                        
                        if (revokeError.response) {
                            const errorData = revokeError.response.data;
                            console.error("❌ Response status:", revokeError.response.status);
                            console.error("❌ Response data:", JSON.stringify(errorData));
                            
                            // invalid_client hatası - client_secret yanlış veya geçersiz
                            if (errorData && errorData.error === 'invalid_client') {
                                console.error("❌ Invalid client_secret - check APPLE_CLIENT_SECRET env variable");
                                console.error("❌ Client secret must be a valid JWT token");
                            }
                            
                            // invalid_grant hatası - token süresi dolmuş veya zaten revoke edilmiş
                            if (errorData && errorData.error === 'invalid_grant') {
                                console.log("ℹ️ Token already expired or revoked (this is normal for old tokens)");
                            }
                        }
                        
                        if (revokeError.code) {
                            console.error("❌ Error code:", revokeError.code);
                        }
                        
                        // AuthorizationCode süresi dolmuş olabilir veya zaten revoke edilmiş olabilir
                        // Bu durumda normal sayılır, hesap silme işlemine devam et
                        console.log("⚠️ Continuing with account deletion despite revoke failure...");
                        console.log("⚠️ Note: authorizationCode expires in ~10 minutes, so this is expected for older accounts");
                    }
                }
            } else {
                console.log("⚠️ Apple user but no appleToken found in database");
                console.log("⚠️ Token revoke will be skipped - token not saved during signup");
                console.log("ℹ️ This is acceptable - authorizationCode expires quickly anyway");
            }
        }

        // Kullanıcının mesajlarını sil
        console.log("🔄 Deleting user messages...");
        const messagesResult = await query("DELETE FROM `messages` WHERE conversationId IN (SELECT id FROM `coversations` WHERE userId = ?)", [userId]);
        console.log("✅ Messages deleted:", messagesResult.affectedRows);
        
        // Kullanıcının konuşmalarını sil
        console.log("🔄 Deleting user conversations...");
        const conversationsResult = await query("DELETE FROM `coversations` WHERE userId = ?", [userId]);
        console.log("✅ Conversations deleted:", conversationsResult.affectedRows);
        
        // Kullanıcının oluşturduğu botları sil
        console.log("🔄 Deleting user's custom bots...");
        const botsResult = await query("DELETE FROM `bots` WHERE creatorId = ?", [userId]);
        console.log("✅ Bots deleted:", botsResult.affectedRows);
        
        // Kullanıcıyı sil
        console.log("🔄 Deleting user account...");
        const userResult = await query("DELETE FROM `users` WHERE id = ?", [userId]);
        console.log("✅ User deleted:", userResult.affectedRows);

        if (userResult.affectedRows === 0) {
            console.log("⚠️ User was not deleted - affectedRows = 0");
            return res.status(500).json({
                msg: "Failed to delete user",
                success: false
            });
        }

        console.log("✅ Account deleted successfully");
        return res.status(200).json({
            msg: "Account deleted successfully",
            success: true
        });

    } catch (error) {
        console.error("❌ delete-account error:", error);
        return res.status(500).json({
            msg: "Server error",
            success: false,
            error: error.message
        });
    }
});

// Guest login endpoint - iOS için misafir giriş
router.post('/guest-login', async (req, res) => {
    try {
        const { deviceId } = req.body;
        
        if (!deviceId) {
            return res.status(400).json({
                msg: "deviceId is required",
                success: false
            });
        }
        
        console.log("👤 Guest login attempt with deviceId:", deviceId);
        
        // Misafir kullanıcı için email oluştur
        const guestEmail = `guest_${deviceId}@guest.friendfy.com`;
        
        // Önce bu deviceId ile bir misafir kullanıcı var mı kontrol et
        let existingGuest = await getQuery(
            "SELECT * FROM `users` WHERE email = ? AND credential = 'guest'",
            [guestEmail]
        );
        
        if (existingGuest && existingGuest.length > 0) {
            // Mevcut misafir kullanıcıyı döndür
            console.log("✅ Existing guest user found");
            const user = existingGuest[0];
            
            // Token oluştur
            const token = JWT.sign({ email: guestEmail }, "key", { expiresIn: 3600000 });
            
            // Token'ı güncelle
            await query("UPDATE `users` SET `token` = ? WHERE `id` = ?", [token, user.id]);
            user.token = token;
            
            return res.status(200).json({
                token,
                user: user,
                success: true,
                msg: "Guest user logged in"
            });
        }
        
        // Yeni misafir kullanıcı oluştur
        console.log("🆕 Creating new guest user");
        
        // Default tarihler (birthdate required olduğu için)
        const now = new Date();
        const defaultBirthdate = new Date(now.getFullYear() - 20, now.getMonth(), now.getDate());
        const birthdateStr = formatDateForMySQL(defaultBirthdate.toISOString());
        
        // Token oluştur
        const token = JWT.sign({ email: guestEmail }, "key", { expiresIn: 3600000 });
        
        // Yeni misafir kullanıcıyı veritabanına ekle
        // Gender opsiyonel - Apple App Store gereksinimleri için null gönderiyoruz
        const insertResult = await query(
            "INSERT INTO `users` (`username`, `email`, `password`, `token`, `memberships`, `ownAgents`, `verificated`, `credential`, `refreshToken`, `phoneNumber`, `lastLogins`, `country`, `gender`, `birthdate`, `accountCreatedDate`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())",
            ["Guest User", guestEmail, null, token, null, null, "1", "guest", null, null, null, "", null, birthdateStr]
        );
        
        // Küçük bir delay ekle
        await new Promise(resolve => setTimeout(resolve, 100));
        
        // Yeni oluşturulan kullanıcıyı getir
        const newGuest = await getQuery(
            "SELECT * FROM `users` WHERE email = ? AND credential = 'guest'",
            [guestEmail]
        );
        
        if (newGuest && newGuest.length > 0) {
            console.log("✅ Guest user created successfully with ID:", newGuest[0].id);
            return res.status(200).json({
                token,
                user: newGuest[0],
                success: true,
                msg: "Guest user created"
            });
        }
        
        return res.status(500).json({
            msg: "Failed to create guest user",
            success: false
        });
        
    } catch (error) {
        console.error("❌ guest-login error:", error);
        return res.status(500).json({
            msg: "Server error",
            success: false,
            error: error.message
        });
    }
});

module.exports = router