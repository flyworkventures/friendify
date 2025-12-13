const JWT = require('jsonwebtoken')
const { getQuery } = require('../db');

module.exports = async (req,res, next) => {
  try {
       const token = req.header('x-auth-token');
       console.log("Token" + token)
    if (!token) {
        return res.status(400).json({
            "msg": "Access Denied"
        });
    }
   let decodedUser = await JWT.verify(token,"key");
   console.log("JWT TOKEN ", decodedUser["email"])
   
   if (decodedUser) {
     // Token'dan gelen email ile kullanıcıyı bul ve req.user'a ekle
     const userFromDb = await getQuery("SELECT id, email, credential FROM `users` WHERE email = ?", [decodedUser.email]);
     if (userFromDb && userFromDb.length > 0) {
       req.user = userFromDb[0]; // Kullanıcı bilgilerini req.user'a ekle
       console.log("✅ req.user set:", req.user.id, req.user.credential);
     }
     next();
   }else{
    res.status(400).json({
        "msg": "Invalid credential"
    })
   }
  } catch (error) {
    return res.status(500).json({
        "msg": `Error on middleware ${error}`
    })
  }
}