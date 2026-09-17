import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const RespostaSchema = new Schema({
  utilizador: { type: Schema.Types.ObjectId, ref: 'Utilizador', required: true },
  questionario: { type: Schema.Types.ObjectId, ref: 'Questionario', required: true },
  respostas: [
    {
      idpergunta: { type: mongoose.Schema.Types.ObjectId, required: true },
      idresposta: [{ type: mongoose.Schema.Types.ObjectId, required: true }]
    }
  ]
}, { timestamps: true });

const RespostaModel = mongoose.model('Resposta', RespostaSchema);

module.exports = RespostaModel;
