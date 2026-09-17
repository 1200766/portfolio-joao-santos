import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const utenteSchema = new Schema({
  medico: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Medico'
  },

  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  numeroUtenteSaude: {
    type: String,
    required: true,
    unique: true
  },


  grupoSanguineo: {
    type: String,
    enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',null],
    required: false
  },

  alergias: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Alergia'
  }],

  historico: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Historico'
  },

  alerts: [{
    alertNumber: { type: Number, default: 0 },
    message: [{ type: String }]
  }],

  alerts2: [{
    alertNumber: { type: Number, default: 0 },
    message: [{ type: String }]
  }]
});

const UtenteModel = mongoose.model('Utente', utenteSchema);

module.exports = UtenteModel;
