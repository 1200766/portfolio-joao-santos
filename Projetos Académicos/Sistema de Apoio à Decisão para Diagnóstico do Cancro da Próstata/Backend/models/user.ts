import mongoose = require("mongoose");

var Schema = mongoose.Schema;

  const userSchema = new Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    email: { type: String, required: true },
    isAdmin: { type: Boolean},
    // Novos campos adicionados
  nome: {
    type: String,
    required: true
  },

  dataNascimento: {
    type: Date,
    required: true
  },

  contacto: {
    type: String,
    required: true
  },

  genero: {
    type: String,
    enum: ['Masculino', 'Feminino'],
    required: true
  },

    })

const userModel = mongoose.model('User', userSchema);

module.exports = userModel;








