const express = require('express')
const router = require('./routes/auth')
const config = require('./server/config')
const agents = require('./routes/agents')
const chat = require('./routes/chat')
const purchases = require('./routes/purchases')
const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));


app.use('/auth',router)
app.use('/server',config)
app.use('/agent',agents)
app.use('/chat',chat)
app.use('/purchases',purchases)


app.listen(3000,()=>{
    console.log("Server started.");
});