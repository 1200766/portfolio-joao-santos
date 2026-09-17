import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const medicoSchema = new Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  specialty: {
    type: String,
    required: true
  },

  alerts: [{
    alertNumber: { type: Number, default: 0 },
    patientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Patient' },
    message: [{ type: String }]
  }]
});

const MedicoModel = mongoose.model('Medico', medicoSchema);

module.exports = MedicoModel;












