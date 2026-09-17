import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const QuestionarioSchema = new Schema({
  titulo: { type: String, required: true },

  perguntas: [
    {
      pergunta: { type: String, required: true },
      opcoes: [
        {
          texto: { type: String, required: true }, // Texto da opção
        }
      ]
    }
  ]
});

const QuestionarioModel = mongoose.model('Questionario', QuestionarioSchema);

module.exports = QuestionarioModel;
