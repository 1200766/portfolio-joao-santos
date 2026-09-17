"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
// Importações
import { mongodbUri } from "./config";
import express = require("express");
import bodyParser = require("body-parser");
var app = express(); // Definir a app através do express
// Configurações para o uso do bodyParser()
// Permite a extraçao dos dados obtidos com o método POST
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

const cors = require('cors');
const CorsOptions = { origin: '*' };
app.use(cors(CorsOptions));
var port = process.env.PORT || 8080; // Definir a porta

var mongoose   = require('mongoose'); // Conexão com a base de dados (MongoDB)
mongoose.connect(mongodbUri);
// Registar as rotas (defininas no ficheiro UserRoutes)
var UserRoutes = require('./routes/UserRoutes');
app.use('/med', UserRoutes);

// Iniciar o servidor
app.listen(port);
console.log('Aplicação iniciada na porta ' + port);









