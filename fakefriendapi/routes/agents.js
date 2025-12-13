const routes = require('express').Router();
const middleware = require('../middleware/checkAuth')
const { getQuery , query} = require('../db')




routes.post('/get-user-agents',middleware,async (req,res)=>{
    try {
        const { userId } = req.body;
        
        if (!userId) {
            return res.status(400).json({
                "msg": "User ID is required",
                "success": false
            });
        }
        
        // Get user's custom agents (system = 0 and creatorId matches)
        const userAgents = await getQuery("SELECT * FROM `bots` WHERE system = ? AND creatorId = ?", [0, userId]);
        
        if (userAgents.length === 0) {
            return res.status(200).json([]);
        }
        
        return res.status(200).json(userAgents);
        
    } catch (error) {
        console.log("Error getting user agents:", error);
        res.status(500).json({
            "msg": "Server error",
            "success": false
        });
    }
})




routes.post('/get-system-agents',middleware,async (req,res)=>{
console.log("middleware working");
const agents = await getQuery("SELECT * FROM `bots` WHERE system = ?",[1]);
console.log(agents)
if (agents.length === 0) {
    res.status(404).json({
        "msg": "Agents is empty",
        "success": false
    })
}else{
return res.json(agents)
}

})


routes.post('/get-agent-data',middleware,async( req ,res )=>{
try {
       const { id }  = req.body;
   const agents = await getQuery("SELECT * FROM `bots` WHERE id = ?",[id]); 
   if (agents.length === 0) {
    res.status(404).json({
        "msg": "Agent not found",
        "success": false
    })
   } else {
        res.status(200).json({
        "success": true,
        "agent": agents[0]
    })
   }
} catch (error) {
    console.log(error);
       res.status(400).json({
        "msg": "server error",
        "success": false
    })
}

})


routes.post('/create-custom-agent', middleware, async (req, res) => {
    try {
        const {
            name,
            character,
            age,
            gender,
            interests,
            interestsType,
            photoURL,
            characterTags,
            speakingStyle,
            voiceId,
            country,
            ownerId
        } = req.body;

        // Validate required fields
        if (!name || !character || !age || !gender || !ownerId) {
            return res.status(400).json({
                "msg": "Missing required fields",
                "success": false
            });
        }

        // Insert the new custom agent into the database
        const insertQuery = `
            INSERT INTO bots 
            (name, \`character\`, age, gender, interests, interestsType, photoURL, 
             characterTags, speakingStyle, voiceId, country, creatorId, system)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

        const values = [
            name,
            character,
            age,
            gender,
            interests || '[]',
            interestsType || '[]',
            photoURL || '',
            characterTags || '',
            speakingStyle || '',
            voiceId || '',
            country || '',
            ownerId,
            0  // system = 0 means it's a user-created agent
        ];

        const result = await query(insertQuery, values);

        if (result) {
            res.status(200).json({
                "msg": "Custom agent created successfully",
                "success": true
            });
        } else {
            res.status(500).json({
                "msg": "Failed to create custom agent",
                "success": false
            });
        }

    } catch (error) {
        console.log('Error creating custom agent:', error);
        res.status(500).json({
            "msg": "Server error",
            "success": false,
            "error": error.message
        });
    }
});

// Update existing agent (only if user owns it)
routes.post('/update-agent', middleware, async (req, res) => {
    try {
        const {
            agentId,
            name,
            character,
            age,
            gender,
            interests,
            interestsType,
            photoURL,
            characterTags,
            speakingStyle,
            voiceId,
            country,
            ownerId
        } = req.body;

        // Validate required fields
        if (!agentId || !name || !character || !age || !gender || !ownerId) {
            return res.status(400).json({
                "msg": "Missing required fields",
                "success": false
            });
        }

        // Check if agent exists and user owns it
        const agentCheck = await getQuery(
            "SELECT * FROM `bots` WHERE id = ? AND creatorId = ? AND system = ?",
            [agentId, ownerId, 0]
        );

        if (agentCheck.length === 0) {
            return res.status(403).json({
                "msg": "Agent not found or you don't have permission to update it",
                "success": false
            });
        }

        // Update the agent
        const updateQuery = `
            UPDATE bots 
            SET name = ?, \`character\` = ?, age = ?, gender = ?, 
                interests = ?, interestsType = ?, photoURL = ?,
                characterTags = ?, speakingStyle = ?, voiceId = ?, country = ?
            WHERE id = ? AND creatorId = ? AND system = ?
        `;

        const values = [
            name,
            character,
            age,
            gender,
            interests || '[]',
            interestsType || '[]',
            photoURL || '',
            characterTags || '',
            speakingStyle || '',
            voiceId || '',
            country || '',
            agentId,
            ownerId,
            0
        ];

        const result = await query(updateQuery, values);

        if (result) {
            res.status(200).json({
                "msg": "Agent updated successfully",
                "success": true
            });
        } else {
            res.status(500).json({
                "msg": "Failed to update agent",
                "success": false
            });
        }

    } catch (error) {
        console.log('Error updating agent:', error);
        res.status(500).json({
            "msg": "Server error",
            "success": false,
            "error": error.message
        });
    }
});

// Delete agent (only if user owns it)
routes.post('/delete-agent', middleware, async (req, res) => {
    try {
        const { agentId, ownerId } = req.body;

        if (!agentId || !ownerId) {
            return res.status(400).json({
                "msg": "Agent ID and Owner ID are required",
                "success": false
            });
        }

        // Check if agent exists and user owns it
        const agentCheck = await getQuery(
            "SELECT * FROM `bots` WHERE id = ? AND creatorId = ? AND system = ?",
            [agentId, ownerId, 0]
        );

        if (agentCheck.length === 0) {
            return res.status(403).json({
                "msg": "Agent not found or you don't have permission to delete it",
                "success": false
            });
        }

        // Delete the agent
        const deleteQuery = "DELETE FROM `bots` WHERE id = ? AND creatorId = ? AND system = ?";
        const result = await query(deleteQuery, [agentId, ownerId, 0]);

        if (result) {
            res.status(200).json({
                "msg": "Agent deleted successfully",
                "success": true
            });
        } else {
            res.status(500).json({
                "msg": "Failed to delete agent",
                "success": false
            });
        }

    } catch (error) {
        console.log('Error deleting agent:', error);
        res.status(500).json({
            "msg": "Server error",
            "success": false,
            "error": error.message
        });
    }
});


// Son eklenen 5 sistem botunu çeker
routes.post('/get-recent-bots', middleware, async (req, res) => {
    try {
        // Son eklenen 5 SİSTEM botunu çek (system = 1)
        // Tarih filtresi yok, sadece en son eklenen 5 taneyi getir
        const recentBots = await getQuery(
            "SELECT * FROM `bots` WHERE system = ? ORDER BY id DESC LIMIT 5", 
            [1]
        );
        
        if (recentBots.length === 0) {
            return res.status(200).json({
                "msg": "Son eklenen bot bulunamadı",
                "success": true,
                "data": []
            });
        }
        
        return res.status(200).json({
            "msg": "Son eklenen botlar başarıyla getirildi",
            "success": true,
            "count": recentBots.length,
            "data": recentBots
        });
        
    } catch (error) {
        console.log("Error getting recent bots:", error);
        res.status(500).json({
            "msg": "Server error",
            "success": false,
            "error": error.message
        });
    }
});


module.exports = routes;