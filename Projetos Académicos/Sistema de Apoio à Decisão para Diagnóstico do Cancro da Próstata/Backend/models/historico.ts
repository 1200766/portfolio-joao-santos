import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const historicoSchema = new Schema({


  consultas: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Consulta'
  }],

  respostas_questionario: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Resposta'
  }]
});

const HistoricoModel = mongoose.model('Historico', historicoSchema);

module.exports = HistoricoModel;
