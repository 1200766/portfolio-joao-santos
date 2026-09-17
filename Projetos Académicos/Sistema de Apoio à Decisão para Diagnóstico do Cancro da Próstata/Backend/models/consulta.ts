import mongoose = require("mongoose");

const Schema = mongoose.Schema;

const consultaSchema = new Schema({
  data: {
    type: Date,
    required: true
  },

  medico: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Medico',
    required: true
  },


});

const ConsultaModel = mongoose.model('Consulta', consultaSchema);

module.exports = ConsultaModel;
