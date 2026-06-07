const express=require('express');const app=express();app.get('/',(_,res)=>res.json({service:'api'}));app.listen(3000);
