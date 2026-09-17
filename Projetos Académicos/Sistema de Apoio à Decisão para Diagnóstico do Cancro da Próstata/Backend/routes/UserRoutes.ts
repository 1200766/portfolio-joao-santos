import { jwtSecret } from "../config";
import express = require('express');
import mongoose = require('mongoose');
import jwt = require('jsonwebtoken');
import bcrypt = require('bcryptjs');
import bodyParser = require("body-parser");

var userModel = require("../models/user");
var utenteModel = require("../models/utente");
var historicoModel = require("../models/historico");
var medicoModel = require("../models/medico");
var consultaModel = require("../models/consulta");
var questionarioModel = require("../models/questionario");
var VerifyToken = require("../auth/VerifyToken");
var respostaModel = require("../models/resposta")
var router = express.Router();

// rota para testar - GET http://localhost:8080/med)
router.get('/', VerifyToken, function (req, res) {
  res.json({ message: 'Bem-vindo ao Sistema de Apoio à Decisão para Diagnóstico do Cancro da Próstata!' });
});

// Rota para registar um utilizador - POST http://localhost:8080/med/Register/User
router.post('/Register/User', VerifyToken, async function (req, res) {
  try {
    const { username, email, password, isAdmin, nome, dataNascimento, contacto, genero } = req.body; // Extrair as variáveis do corpo da requisição

    // Criar uma nova instância do utilizador recorrendo ao modelo
    var newUser = new userModel({
      username,
      email,
      password,
      isAdmin,
      nome,
      dataNascimento,
      contacto,
      genero,
    });

    // Gravar o utilizador na base de dados
    await newUser.save();

    res.status(201).json({ message: 'Utilizador registado com sucesso!', utilizador: newUser });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor' });
  }
});





// Rota para registar um médico e criar automaticamente um utilizador associado
router.post('/Register/Medico', VerifyToken, async function (req, res) {
  try {
    const {
      username, email, password, isAdmin,
      nome, dataNascimento, contacto, genero,
      specialty
    } = req.body;

    // Primeiro, criar o utilizador
    const newUser = new userModel({
      username,
      email,
      password,
      isAdmin: isAdmin || false,
      nome,
      dataNascimento,
      contacto,
      genero,
    });

    // Guardar o utilizador na base de dados
    await newUser.save();

    // Depois, criar o médico associado a esse utilizador
    const newMedico = new medicoModel({
      specialty,
      user: newUser._id
    });

    // Guardar o médico na base de dados
    await newMedico.save();

    res.status(201).json({
      message: 'Médico  registado com sucesso!',
      medico: newMedico,
      utilizador: newUser
    });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

// Rota para registar um paciente - POST http://localhost:8080/med/Register/Patient
router.post('/Register/Utente', VerifyToken, async function (req, res) {
  try {
    const { medico, numeroUtenteSaude, username,
      email, password, isAdmin, nome, dataNascimento, contacto, genero } = req.body;
    // Primeiro, criar o utilizador
    const newUser = new userModel({
      username,
      email,
      password,
      isAdmin: isAdmin || false,
      nome,
      dataNascimento,
      contacto,
      genero,
    });

    // Guardar o utilizador na base de dados
    await newUser.save();

    const newHistorico = new historicoModel({
      consultas: [],
      questionarios: []
    });
    await newHistorico.save();


    // Criar uma nova instância do paciente recorrendo ao modelo
    var newUtente = new utenteModel({
      medico,
      numeroUtenteSaude,
      grupoSanguineo: null,
      alergias: null,
      user: newUser._id,
      historico: newHistorico

    });

    // Gravar o novo paciente na base de dados
    await newUtente.save();

    res.status(201).json({ message: 'Paciente registado com sucesso!', utente: newUtente });
  } catch (err) {
    res.status(501).json({ error: err });
  }
});


const Questionario = require("../models/questionario");

// POST http://localhost:8080/med/Register/Questionario
router.post('/Register/Questionario',VerifyToken,  async (req, res) => {
  try {
    const { titulo, perguntas } = req.body;

    const novoQuestionario = new questionarioModel({
      titulo,
      perguntas: perguntas || []
    });

    await novoQuestionario.save();

    res.status(201).json({ message: 'Questionário criado com sucesso!', questionario: novoQuestionario });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao criar o questionário', detalhes: err });
  }
});

// PUT http://localhost:8080/med/Pergunta
router.put('/Register/Pergunta', VerifyToken, async (req, res) => {
  try {
    const { questionarioId, pergunta, opcoes } = req.body;

    const questionario = await Questionario.findById(questionarioId);
    console.log("questionário", questionarioId);
    if (!questionario) {
      res.status(400).json({ error: 'Questionario Inválido' })

    }

    const novaPergunta = {
      pergunta,
      opcoes
    };

    questionario.perguntas.push(novaPergunta);
    await questionario.save();

    res.status(200).json({ message: 'Pergunta adicionada com sucesso!', questionario });
  } catch (err) {
    res.status(500).json({ error: 'Erro ao adicionar pergunta', detalhes: err });
  }
});




// Rota para registar um paciente - POST http://localhost:8080/med/Register/Patient
router.post('/Register/Consulta',VerifyToken,  async function (req, res) {

  try {
    const { utenteId, data, medico } = req.body;
    // Primeiro, criar o utilizador
    const dataRecebida = new Date(data);
    const offsetEmMs = dataRecebida.getTimezoneOffset() * 60000;
    const dataCorrigida = new Date(dataRecebida.getTime() - offsetEmMs);
    const newConsulta = new consultaModel({
      data: dataCorrigida,
      medico,
    })

    // Guardar o utilizador na base de dados
    await newConsulta.save();

    const utente = await utenteModel.findById(utenteId).populate('historico');
    if (!utente) {
      res.status(400).json({ error: 'Utente Inválido' })
    }
    let historico = utente.historico;
    if (!historico) {
      historico = new historicoModel();
      await historico.save();
      utente.historico = historico._id;
      await utente.save();
    } else {
      historico = await historicoModel.findById(historico._id);
    }

    if (!historico.consultas) {
      historico.consultas = [];
    }

    historico.consultas.push(newConsulta._id);
    await historico.save();


    res.status(201).json({ message: 'Consulta registado com sucesso!', Consulta: newConsulta });
  } catch (err) {
    res.status(500).json({ error: err });
  }
});


// Rota para registar as respostas do questionário
// POST http://localhost:8080/med/Register/Resposta
router.post('/Register/Resposta', VerifyToken, async function (req: any, res: any) {
  try {
    const { userId, questionarioId, respostas } = req.body;

    // Validação básica
    if (!userId || !questionarioId || !Array.isArray(respostas)) {
      return res.status(400).json({ error: 'Dados incompletos ou inválidos.' });
    }

    // (Opcional) Verificar se o questionário e o utilizador existem
    const questionario = await questionarioModel.findById(questionarioId);
    if (!questionario) return res.status(404).json({ error: 'Questionário não encontrado.' });

    const utilizador = await userModel.findById(userId);
    if (!utilizador) return res.status(404).json({ error: 'Utilizador não encontrado.' });

    // (Opcional) Validar se perguntas e opções existem no questionário
    const perguntasMap = new Map();
    questionario.perguntas.forEach((p: { _id: any }) => perguntasMap.set(String(p._id), p));

    for (const r of respostas) {
      if (!perguntasMap.has(String(r.idpergunta))) {
        return res.status(400).json({ error: `Pergunta ${r.idpergunta} não encontrada.` });
      }

      const pergunta = perguntasMap.get(String(r.idpergunta));
      const opcaoIds = pergunta.opcoes.map((o: { _id: any }) => String(o._id));
      for (const opId of r.idresposta) {
        if (!opcaoIds.includes(String(opId))) {
          return res.status(400).json({ error: `Opção inválida para a pergunta ${r.idpergunta}.` });
        }
      }
    }

    // Criar nova resposta
    const novaResposta = new respostaModel({
      utilizador: utilizador,
      questionario: questionario,
      respostas
    });

    await novaResposta.save();

    res.status(201).json({ message: 'Respostas registadas com sucesso!', resposta: novaResposta });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erro no servidor.' });
  }
});

//Apenas para o questionário do perfil
router.post('/Register/Alerta', VerifyToken, async function (req: any, res: any) {
  try {
    const { userId, questionarioId } = req.body;

    if (!userId || !questionarioId) {
      return res.status(400).json({ error: 'Dados incompletos ou inválidos.' });
    }

    const questionario = await questionarioModel.findById(questionarioId);
    if (!questionario) {
      return res.status(404).json({ error: 'Questionário não encontrado.' });
    }

    const utilizador = await userModel.findById(userId);
    if (!utilizador) {
      return res.status(404).json({ error: 'Utilizador não encontrado.' });
    }

    const utente = await utenteModel.findOne({ user: utilizador._id });
    if (!utente) {
      return res.status(404).json({ error: 'Utente não encontrado.' });
    }

    const resposta = await respostaModel.findOne({
      utilizador: utilizador._id,
      questionario: questionario._id
    }).sort({ createdAt: -1 });  // ordena do mais recente para o mais antigo

    if (!resposta || resposta.length === 0) {
      return res.status(404).json({ error: 'Respostas não encontradas.' });
    }

    const respostaList = resposta[0].respostas;

    const alertas: string[] = [];

    const respostasMap: Record<string, string[]> = {};
    for (const r of respostaList) {
      const perguntaId = r.idpergunta.toString();
      const respostaIds = r.idresposta.map((id: any) => id.toString());
      respostasMap[perguntaId] = respostaIds;
    }

    const ids = {
      q1: "68470dbe3c04b156695e8112",
      q1_1: "68470df13c04b156695e811e",
      q2: "68470e003c04b156695e812b",
      q3: "68470e0e3c04b156695e813b",
      q3_1: "68470e193c04b156695e814e",
      q3_2: "68470e263c04b156695e8164",
      q4: "68470e473c04b156695e817d",
      q5: "68470e663c04b156695e8199",
      q5_1: "68470f0b3c04b156695e81ba",
      q6: "68470f3a3c04b156695e81e7",
      q7: "68470fce3c04b156695e8214",
      q7_1: "6847107c3c04b156695e824b",
      q8: "684710bc3c04b156695e828b",
      q9: "684710d93c04b156695e82cd",
      q9_1: "684711393c04b156695e8310"
    };

    const respostas = {
      r1_0: "68470dbe3c04b156695e8113",
      r1_1: "68470dbe3c04b156695e8114",
      r1_2: "68470dbe3c04b156695e8115",
      r1_3: "68470dbe3c04b156695e8116",
      sim_11: "68470df13c04b156695e811f",
      nao_11: "68470df13c04b156695e8120",
      sim_2: "68470e003c04b156695e812c",
      nao_2: "68470e003c04b156695e812d",
      sim_3: "68470e0e3c04b156695e813c",
      nao_3: "68470e0e3c04b156695e813d",
      sim_31: "68470e193c04b156695e814f",
      nao_31: "68470e193c04b156695e8150",
      sim_32: "68470e263c04b156695e8165",
      nao_32: "68470e263c04b156695e8166",
      sim_4: "68470e473c04b156695e817e",
      nao_4: "68470e473c04b156695e817f",
      sim_5: "68470e663c04b156695e819a",
      nao_5: "68470e663c04b156695e819b",
      semconhecimento_5: "68470e663c04b156695e819c",
      BRCA1: "68470f0b3c04b156695e81bb",
      BRCA2: "68470f0b3c04b156695e81bc",
      HOXB13: "68470f0b3c04b156695e81bd",
      ATM: "68470f0b3c04b156695e81be",
      MSH1: "68470f0b3c04b156695e81bf",
      MSH2: "68470f0b3c04b156695e81c0",
      Outra: "68470f0b3c04b156695e81c1",
      r6_0: "68470f3a3c04b156695e81e8",
      r6_1: "68470f3a3c04b156695e81e9",
      r6_2: "68470f3a3c04b156695e81ea",
      r7_IECA: "68470fce3c04b156695e8215",
      r7_BRA: "68470fce3c04b156695e8216",
      r7_BCC: "68470fce3c04b156695e8217",
      r7_Beta: "68470fce3c04b156695e8218",
      r7_Diureticos: "68470fce3c04b156695e8219",
      r7_Nenhum: "68470fce3c04b156695e821a",
      r71_Amlodipina: "6847107c3c04b156695e824c",
      r71_Nifedipina: "6847107c3c04b156695e824d",
      r71_Felodipina: "6847107c3c04b156695e824e",
      r71_Isradipina: "6847107c3c04b156695e824f",
      r71_Diltiazem: "6847107c3c04b156695e8250",
      r71_Verapamilo: "6847107c3c04b156695e8251",
      r71_Outro: "6847107c3c04b156695e8252",
      r8_Sjögren: "684710bc3c04b156695e828c",
      r8_Colite: "684710bc3c04b156695e828d",
      r8_Crohn: "684710bc3c04b156695e828e",
      r8_Nenhuma: "684710bc3c04b156695e828f",
      sim_9: "684710d93c04b156695e82ce",
      nao_9: "684710d93c04b156695e82cf",
      r91_Finasterida: "684711393c04b156695e8311",
      r91_Dutasterida: "684711393c04b156695e8312",
      r91_Alfatradiol: "684711393c04b156695e8313",
      r91_Outro: "684711393c04b156695e8314"
    };

    // Avaliação de alertas
    let alerta: string | null = null;

    if (respostasMap[ids.q1_1]?.includes(respostas.nao_11)) {
      alertas.push("Paciente enquadra-se na faixa etária recomendada para rastreio do cancro da próstata, sem PSA recente realizado. Considerar agendamento de rastreio.");
    }
    else if (
      respostasMap[ids.q3]?.includes(respostas.sim_3) &&
      respostasMap[ids.q3_1]?.includes(respostas.sim_31) &&
      respostasMap[ids.q3_2]?.includes(respostas.sim_32) &&
      respostasMap[ids.q5]?.includes(respostas.nao_5)
    ) {
      alerta = "Histórico familiar de cancro da próstata com diagnóstico precoce e desfecho fatal. Risco hereditário elevado pelo que se aconselha estudo genético prioritário. Encaminhar para consulta de genética médica e marcação de consulta para avaliação urológica.";
    }
    else if (
      respostasMap[ids.q3]?.includes(respostas.sim_3) &&
      respostasMap[ids.q5]?.includes(respostas.nao_5)
    ) {
      alerta = "Histórico familiar de cancro da próstata, aconselha–se estudo genético prioritário com marcação consulta de genética médica e consulta para avaliação urológica.";
    }
    else if (
      respostasMap[ids.q3]?.includes(respostas.sim_3) &&
      respostasMap[ids.q3_2]?.includes(respostas.sim_32)
    ) {
      alerta = "Histórico familiar de cancro da próstata com desfecho fatal. Aconselha-se marcação de consulta para avaliação urológica.";
    }
    else if (
      respostasMap[ids.q3]?.includes(respostas.sim_3) &&
      respostasMap[ids.q4]?.includes(respostas.sim_4)
    ) {
      alerta = "Forte histórico familiar associado a diversos tipos de cancro. Aconselhado consulta de rotina e avaliação urológica. Considerar agendamento de rastreio.";
    }
    else if (
      respostasMap[ids.q3]?.includes(respostas.sim_3) &&
      respostasMap[ids.q5_1]?.includes(respostas.BRCA2)
    ) {
      alerta = "Forte histórico familiar associado e evidência científica de risco hereditário elevado apoiado por mutações genéticas encontradas. Aconselha-se vigilância regular com marcação de consulta para avaliação urológica e rastreio.";
    }
    else if (
      respostasMap[ids.q5_1]?.includes(respostas.BRCA2)
    ) {
      alerta = "Evidência científica de risco hereditário elevado. Risco até oito vezes maior de desenvolver cancro da próstata. Marcação de consulta para avaliação urológica juntamente com vigilância regular apoiada por exames médicos.";
    }
    else if (
      respostasMap[ids.q5]?.includes(respostas.sim_5)
    ) {
      alerta = "Mutações genéticas encontradas. Aconselha-se vigilância regular apoiada por exames médicos.";
    }
    else if (
      respostasMap[ids.q5]?.includes(respostas.sim_5) &&
      respostasMap[ids.q2]?.includes(respostas.sim_2)
    ) {
      alerta = "Associação de fatores genéticos e ambientais (tabagismo) identificada. Recomendado rastreio e avaliação clínica rigorosa.";
    }
    else if (
      respostasMap[ids.q4]?.includes(respostas.sim_4) &&
      (
        respostasMap[ids.q5_1]?.includes(respostas.MSH1) ||
        respostasMap[ids.q5_1]?.includes(respostas.MSH2)
      )
    ) {
      alerta = "Mutações genéticas e histórico familiar associado ao Síndrome de Lynch. Risco aumentado para diversos tipos de cancro, incluindo próstata. Aconselha-se consulta de genética médica.";
    }
    else if (
      respostasMap[ids.q6]?.includes(respostas.r6_0) &&
      respostasMap[ids.q1_1]?.includes(respostas.nao_11)
    ) {
      alerta = "Paciente afrodescendente com idade de rastreio sem testes ao PSA nos últimos anos. Iniciar rastreio com urgência.";
    }
    else if (
      respostasMap[ids.q6]?.includes(respostas.r6_0) &&
      respostasMap[ids.q1]?.includes(respostas.r1_1)
    ) {
      alerta = "Paciente afrodescendente apresenta risco aumentado de desenvolvimento precoce de cancro da próstata. Aconselha-se início antecipado do rastreio.";
    }
    else if (
      respostasMap[ids.q6]?.includes(respostas.r6_0)
    ) {
      alerta = "Paciente com etnia mais suscetível a surgimento de metástases em fases avançadas da doença. Aconselha-se vigilância.";
    }
    else if (
      respostasMap[ids.q7_1]?.includes(respostas.r71_Verapamilo) &&
      (respostasMap[ids.q7_1].length > 1)
    ) {
      alerta = "Identificado uso de fármacos com associação descrita ao risco aumentado de cancro da próstata. Considerar reavaliação terapêutica e vigilância clínica.";
    }
    else if (
      respostasMap[ids.q7_1]?.includes(respostas.r71_Verapamilo)
    ) {
      alerta = "Uso de Verapamilo associado em alguns estudos a risco elevado de cancro da próstata. Reavaliação periódica e rastreio clínico aconselhado.";
    }
    else if (
      respostasMap[ids.q7_1]?.some(r => [respostas.r71_Nifedipina, respostas.r71_Diltiazem].includes(r))
    ) {
      alerta = "Uso de medicamento associado com possível relação com o aparecimento de cancro na próstata. Reavaliação periódica e rastreio clínico aconselhado.";
    }
    else if (
      respostasMap[ids.q7_1]?.includes(respostas.r71_Outro)
    ) {
      alerta = "Paciente recorre a medicações com substâncias ativas bloqueadoras de cálcio. Rastreio clínico aconselhado.";
    }
    else if (
      respostasMap[ids.q8]?.includes(respostas.r8_Sjögren)
    ) {
      alerta = "Paciente com Síndrome de Sjögren identificado. Doença autoimune associada a elevados níveis de PSA. Rastreio clínico aconselhado juntamente com vigilância regular apoiada por exames médicos.";
    }
    else if (
      respostasMap[ids.q8]?.some(r => [respostas.r8_Crohn, respostas.r8_Colite, respostas.r8_Nenhuma].includes(r))
    ) {
      alerta = "Doença inflamatória/autoimune presente. Aconselha-se vigilância regular.";
    }
    else if (
      respostasMap[ids.q9]?.some(r => [respostas.r91_Finasterida, respostas.r91_Dutasterida].includes(r))
    ) {
      alerta = "O paciente encontra-se a tomar medicação que pode alterar artificialmente os níveis de PSA. Aconselha-se vigilância apertada com avaliação clínica e rastreio imagiológico complementar.";
    }

    // Push alerta único se for definido
    if (alerta) {
      alertas.push(alerta);
    }

    // Inicializa alerts se necessário
    if (!Array.isArray(utente.alerts)) {
      utente.alerts = [];
    }

    if (alertas.length > 0) {
      utente.alerts.push({
        alertNumber: utente.alerts.length + 1,
        message: alertas
      });

      await utente.save();

      return res.status(201).json({ message: 'Alerta atualizado com sucesso!', utente });
    } else {
      return res.status(200).json({ message: 'Nenhuma condição de alerta foi encontrada.', utente });
    }

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Erro no servidor.' });
  }
});

//Delete de alertas
router.delete('/Delete/Alertas',VerifyToken,  async function (req: any, res: any) {
  try {
    const { username } = req.body;

    // 1. Encontrar o utilizador
    const user = await userModel.findOne({ username: username });
    if (!user) {
      return res.status(404).json({ error: 'Utilizador não encontrado', detalhes: username });
    }

    // 2. Encontrar o utente correspondente
    const utente = await utenteModel.findOne({ user: user._id });
    if (!utente) {
      return res.status(404).json({ error: 'Utente não encontrado para o utilizador fornecido.' });
    }

    // 3. Apagar os alertas (resetar o array)
    utente.alerts = [];
    await utente.save();

    res.status(200).json({ message: 'Alertas apagados com sucesso!' });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor' });
  }
});


router.post('/Get/Respostas',VerifyToken,  async function (req: any, res: any) {
  const { userId, questionarioId } = req.body;

  try {
    const utilizador = await userModel.findById(userId);
    if (!utilizador) {
      return res.status(404).json({ error: 'Utilizador não encontrado.' });
    }

    const questionario = await questionarioModel.findById(questionarioId);
    if (!questionario) {
      return res.status(404).json({ error: 'Questionário não encontrado.' });
    }

    const respostas = await respostaModel.find({
      utilizador: userId,
      questionario: questionarioId
    })
      .populate('respostas.idpergunta')        // Popula as perguntas
      .populate('respostas.idresposta')        // Popula as respostas
      .exec();

    const resultado = respostas.map((resposta: any) => ({
      id: resposta._id,
      dataResposta: resposta.createdAt,
      respostas: resposta.respostas.map((r: any) => ({
        perguntaId: r.idpergunta?._id,
        idresposta: r.idresposta?.map((op: any) => op?._id)
      }))
    }));

    return res.status(200).json({ message: 'Respostas obtidas com sucesso.', respostas: resultado });

  } catch (error) {
    console.error('Erro ao obter respostas do utilizador:', error);
    return res.status(500).json({ message: 'Erro interno do servidor.' });
  }
});
// Obter o texto (String) relativo a cada pergunta e resposta
router.post('/Get/Questionario',VerifyToken,  async function (req: any, res: any) {
  const { questionarioId, perguntaId, respostaId } = req.body;

  try {
    const questionario = await questionarioModel.findById(questionarioId);
    if (!questionario) {
      return res.status(404).json({ error: 'Questionário não encontrado.' });
    }

    // Encontra a pergunta dentro do array de perguntas
    const pergunta = questionario.perguntas.find((p: any) => p._id.toString() === perguntaId);
    if (!pergunta) {
      return res.status(404).json({ error: 'Pergunta não encontrada.' });
    }

    // Encontra a resposta dentro da pergunta
    const resposta = pergunta.opcoes.find((o: any) => o._id.toString() === respostaId);
    if (!resposta) {
      return res.status(404).json({ error: 'Resposta não encontrada.' });
    }

    // Retorna os textos
    return res.status(200).json({
      perguntaTexto: pergunta.pergunta,
      respostaTexto: resposta.texto
    });

  } catch (error) {
    console.error('Erro ao obter pergunta/resposta:', error);
    return res.status(500).json({ message: 'Erro interno do servidor.' });
  }
});




router.delete('/Delete/User', VerifyToken, async function (req, res) {

  try {
    const { username } = req.body;
    // Primeiro, criar o utilizador

    // Primeiro, encontrar o utilizador pelo username
    const user = await userModel.findOne({ username: username });
    if (!user) {
      res.status(404).json({ error: 'Erro do servidor', detalhes: username });
    }

    // Depois, encontrar o médico associado a esse utilizador
    const medico = await medicoModel.findOne({ user: user._id });
    const utente = await utenteModel.findOne({ user: user._id });
    // Apagar o médico
    if (medico) {
      await medicoModel.findByIdAndDelete(medico._id);
    } if (utente) {
      await utenteModel.findByIdAndDelete(utente._id);
    }
    // Apagar o utilizador
    await userModel.findByIdAndDelete(user._id);

    res.status(200).json({ message: 'Utilizador eliminado com sucesso!' });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

router.delete('/Delete/Consulta', VerifyToken, async function (req, res) {
  try {
    const { consultaId } = req.body;

    // Primeiro, encontrar a consulta
    const consulta = await consultaModel.findById(consultaId);
    if (!consulta) {
      res.status(404).json({ message: 'Consulta não encontrada.' });
    }

    // Agora, remover a consulta de todos os históricos onde ela esteja
    await historicoModel.updateMany(
      { consultas: consultaId },
      { $pull: { consultas: consultaId } }
    );

    // Finalmente, deletar a consulta
    await consultaModel.findByIdAndDelete(consultaId);

    res.status(200).json({ message: 'Consulta eliminada com sucesso.' });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

router.get('/Get/User', VerifyToken, async function (req, res) {
  try {
    const { userId } = req.body;

    // Buscar o utilizador pelo ID
    const user = await userModel.findById(userId);
    if (!user) {
      res.status(404).json({ message: 'Utilizador não encontrado.' });
    }

    res.status(200).json({ utilizador: user });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

router.get('/Get/Utente', VerifyToken, async function (req, res) {
  try {
    const { utenteId } = req.body;

    // Buscar o utilizador pelo ID
    const utente = await utenteModel.findById(utenteId);
    if (!utente) {
      res.status(404).json({ message: 'Utilizador não encontrado.' });
    }

    res.status(200).json({ utilizador: utente });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

router.get('/Get/Medico',VerifyToken,  async function (req, res) {
  try {
    const { medicoId } = req.body;

    // Buscar o utilizador pelo ID
    const medico = await medicoModel.findById(medicoId);
    if (!medico) {
      res.status(404).json({ message: 'Utilizador não encontrado.' });
    }

    res.status(200).json({ utilizador: medico });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

function formatarData(dataISO: string | undefined): string {
  if (!dataISO) return 'Sem consulta';

  const data = new Date(dataISO);
  const dia = String(data.getUTCDate()).padStart(2, '0');
  const mes = String(data.getUTCMonth() + 1).padStart(2, '0');
  const ano = data.getUTCFullYear();
  const horas = String(data.getUTCHours()).padStart(2, '0');
  const minutos = String(data.getUTCMinutes()).padStart(2, '0');

  return `${dia}/${mes}/${ano} ${horas}:${minutos}h`;
}

router.get('/Get/Utentes',VerifyToken,  async (req, res) => {
  try {
    const utentes = await utenteModel.find()
      .populate('user', 'nome contacto genero dataNascimento username email')
      .populate({
        path: 'historico',
        select: '_id consultas'
      })
      .populate({
        path: 'medico',
        populate: { path: 'user', select: 'nome' }
      });

    const resultado = await Promise.all(
      utentes.map(async (utente: any) => {
        let proximaConsulta = null;

        if (utente.historico?.consultas?.length > 0) {
          proximaConsulta = await consultaModel
            .findOne({
              _id: { $in: utente.historico.consultas },
              data: { $gte: new Date() }
            })
            .sort({ data: 1 })
            .exec();
        }

        return {
          id: utente._id,
          nome: utente.user?.nome,
          numeroUtente: utente.numeroUtenteSaude,
          contacto: utente.user?.contacto,
          genero: utente.user?.genero,
          nascimento: utente.user?.dataNascimento
            ? new Date(utente.user.dataNascimento).toISOString().slice(0, 10)
            : null,
          proximaConsulta: proximaConsulta ? formatarData(proximaConsulta.data) : "Sem Consulta",
          medico: utente.medico?.user?.nome,
          medicoid: utente.medico?._id,
          username: utente.user?.username,
          email: utente.user?.email,
          historicoId: utente.historico?._id,
          userId: utente.user?._id,
          alert: utente.alerts,
          alert2: utente.alerts2
        };
      })
    );

    res.status(200).json(resultado);
  } catch (err) {
    console.error('Erro ao obter utentes:', err);
    res.status(500).json({ error: 'Erro ao obter utentes' });
  }
});

router.put('/Update/Utente', VerifyToken, async function (req, res) {
  try {
    const {
      utenteId, nome, dataNascimento, contacto, genero,
      numeroUtenteSaude, medico
    } = req.body;

    // Buscar o utente e popular os dados do utilizador
    const utente = await utenteModel.findById(utenteId).populate('user');
    if (!utente) {
      res.status(404).json({ message: 'Utilizador não encontrado.' });
    }
    if (utente.user) {
      utente.user.nome = nome || utente.user.nome;
      utente.user.dataNascimento = dataNascimento || utente.user.dataNascimento;
      utente.user.contacto = contacto || utente.user.contacto;
      utente.user.genero = genero || utente.user.genero;
      await utente.user.save();
    }
    utente.numeroUtenteSaude = numeroUtenteSaude || utente.numeroUtenteSaude;
    utente.medico = medico || utente.medico;

    await utente.save();


    res.status(201).json({ message: 'Paciente atualizado com sucesso!', utente: utente });
  } catch (err) {
    res.status(500).json({ error: err });
  }
});
router.put('/Update/Medico', VerifyToken, async function (req, res) {
  try {
    const {
      id, nome, dataNascimento, contacto, genero,
      specialty
    } = req.body;

    // Buscar o utente e popular os dados do utilizador
    // Buscar o médico pelo ID fornecido
    const medico = await medicoModel.findById(id);
    if (!medico) {
      res.status(404).json({ message: 'Médico não encontrado.' });
    }

    // Buscar o utilizador associado, se existir
    const user = await userModel.findById(medico.user);
    if (!user) {
      res.status(404).json({ message: 'Utilizador associado não encontrado.' });
    }
    // Atualizar os dados do utilizador
    user.nome = nome || user.nome;
    user.dataNascimento = dataNascimento || user.dataNascimento;
    user.contacto = contacto || user.contacto;
    user.genero = genero || user.genero;
    await user.save();

    // Atualizar os dados do médico
    medico.specialty = specialty || medico.specialty;
    await medico.save();


    res.status(201).json({ message: 'medico atualizado com sucesso!', medico: medico });
  } catch (err) {
    res.status(500).json({ error: err });
  }
});


router.get('/Get/Medicos',VerifyToken,  async (req, res) => {
  try {
    const medicos = await medicoModel.find()
      .populate('user', 'nome contacto genero dataNascimento email username')


    const resultado = medicos.map((medico: any) => ({
      id: medico._id,
      nome: medico.user?.nome,
      username: medico.user?.username,
      email: medico.user?.email,
      specialty: medico.specialty,
      contacto: medico.user?.contacto,
      genero: medico.user?.genero,
      nascimento: medico.user?.dataNascimento
        ? new Date(medico.user.dataNascimento).toISOString().slice(0, 10)
        : null
    }));

    res.status(200).json(resultado);
  } catch (err) {
    console.error('Erro ao obter medicos:', err);
    res.status(500).json({ error: 'Erro ao obter medicos' });
  }
});

router.get('/Get/Adminitradores', VerifyToken, async (req, res) => {
  try {
    const users = await userModel.find()
    const resultado = users
      .filter((user: any) => user.isAdmin === true)
      .map((user: any) => ({
        id: user._id,
        nome: user.nome,
        contacto: user.contacto,
        genero: user.genero,
        nascimento: user.dataNascimento
          ? new Date(user.dataNascimento).toISOString().slice(0, 10)
          : null,
        username: user.username,
        email: user.email,

      }));

    res.status(200).json(resultado);
  } catch (err) {
    console.error('Erro ao obter utentes:', err);
    res.status(500).json({ error: 'Erro ao obter utentes' });
  }
});


router.get('/Get/Users', VerifyToken, async (req, res) => {
  try {
    const users = await userModel.find()
    const resultado = users
      .map((user: any) => ({
        id: user._id,
        nome: user.nome,
        contacto: user.contacto,
        genero: user.genero,
        nascimento: user.dataNascimento
          ? new Date(user.dataNascimento).toISOString().slice(0, 10)
          : null,
        username: user.username,
        email: user.email,
        isAdmin: user.isAdmin

      }));

    res.status(200).json(resultado);
  } catch (err) {
    console.error('Erro ao obter utentes:', err);
    res.status(500).json({ error: 'Erro ao obter utentes' });
  }
});

//Rota para listar Utentes associadas ao um médico - POST http://localhost:8080/med/Get/ListaUtentes
router.post('/Get/ListaUtentes', VerifyToken, async function (req: any, res: any) {

  const { medicoId } = req.body;

  try {

    const medico = await medicoModel.findById(medicoId);
    if (!medico) {
      return res.status(404).json({ message: 'Médico não encontrado ou id não corresponde a um médico' });
    }

    const utentes = await utenteModel.find({ medico: medicoId }).exec();

    const resultado = utentes.map((utente: any) => ({
      id: utente._id,
      historico: utente.historico,
      medico: utente.medico,
    }));

    res.status(201).json({ message: 'Utentes listados com sucesso!', utentes: utentes });

  } catch (error) {
    console.error('Erro ao obter pacientes do médico:', error);
    res.status(500).json({ message: 'Erro do servidor.' });
  }

});


// Rota para listar consultas associadas ao um médico - POST http://localhost:8080/med/Get/ListaConsultas
router.post('/Get/ListaConsultas',VerifyToken,  async function (req: any, res: any) {
  try {
    const { medicoId } = req.body;
    // Buscar o utilizador pelo ID
    const medico = await medicoModel.findById(medicoId);
    if (!medico) {
      return res.status(404).json({ message: 'Médico não encontrado ou id não corresponde a um médico' });
    }

    const consultas = await consultaModel.find({ medico: medicoId }).exec();

    const resultado = consultas.map((consulta: any) => ({
      id: consulta._id,
      data: consulta.data ? new Date(consulta.data).toISOString().replace('T', ' ').slice(0, 16) : null,
      medico: consulta.medico,
    }));

    res.status(200).json({ message: 'Consultas listadas com sucesso!', resultado });
  } catch (error) {
    console.error('Erro ao obter pacientes do médico:', error);
    res.status(500).json({ message: 'Erro do servidor.' });
  }
});

module.exports = router;

// Rota para listar consultas associadas a um historico - POST http://localhost:8080/med/Get/Consultas
router.post('/Get/Consultas',VerifyToken,  async function (req: any, res: any) {

  try {
    const { historicoId } = req.body;

    if (!historicoId) {
      return res.status(400).json({ message: 'historicoId é obrigatório.' });
    }

    // Buscar o histórico e popular as consultas
    const historico = await historicoModel.findById(historicoId).populate('consultas');

    if (!historico) {
      return res.status(404).json({ message: 'Histórico não encontrado.' });
    }

    const resultado = historico.consultas.map((consulta: any) => ({
      id: consulta._id,
      data: consulta.data ? new Date(consulta.data).toISOString().replace('T', ' ').slice(0, 16) : null,
      medico: consulta.medico, // ajuste conforme campos do seu model de Consulta
    }));

    res.status(200).json({ message: 'Consultas listadas com sucesso!', resultado });
  } catch (error) {
    console.error('Erro ao obter Consultas do utente:', error);
    res.status(500).json({ message: 'Erro do servidor.' });
  }
});

module.exports = router;
//Rota para listar Histórico associado ao um utente - POST http://localhost:8080/med/Get/Historico
router.post('/Get/Historico', VerifyToken, async function (req: any, res: any) {

  const { historicoId } = req.body;

  try {

    const historico = await historicoModel.findById(historicoId);
    if (!historicoId) {
      return res.status(404).json({ message: 'Histórico não encontrado ou id não corresponde a um histórico' });
    }

    res.status(201).json({ message: 'Histórico listado com sucesso!', historico: historico });

  } catch (error) {
    console.error('Erro ao obter historico do utente:', error);
    res.status(500).json({ message: 'Erro do servidor.' });
  }

});
module.exports = router;



// Rota para registar um utilizador - POST http://localhost:8080/med/Register/User
router.put('/Update/User',VerifyToken,  async function (req, res) {
  try {
    const { userid, nome, dataNascimento, contacto, genero } = req.body; // Extrair as variáveis do corpo da requisição

    const user = await userModel.findById(userid)
    if (!user) {
      res.status(404).json({ message: 'Utilizador associado não encontrado.' });
    }
    // Criar uma nova instância do utilizador recorrendo ao modelo
    user.nome = nome || user.nome;
    user.dataNascimento = dataNascimento || user.dataNascimento;
    user.contacto = contacto || user.contacto;
    user.genero = genero || user.genero;
    await user.save();



    res.status(201).json({ message: 'Utilizador registado com sucesso!', utilizador: user });
  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor' });
  }
});


router.post('/login', async function (req: any, res: any) {
  try {
    const user = await userModel.findOne({
      $or: [
        { email: req.body.identificador },
        { username: req.body.identificador }
      ],
      password: req.body.password
    }).exec();

    if (!user) {
      return res.status(401).json({ success: false, message: 'Utilizador não encontrado!' });
    }

    let role = 'indefinido';
    let id = '';

    if (user.isAdmin) {
      role = 'admin';
    } else {
      const medico = await medicoModel.findOne({ user: user._id }).exec();
      if (medico) {
        role = 'medico';
      } else {
        const utente = await utenteModel.findOne({ user: user._id }).exec();
        if (utente) {
          role = 'utente';
        } else {
          return res.status(403).json({ success: false, message: 'Utilizador sem função atribuída.' });
        }
      }
    }

    const payload = { user: user.email };
    const theToken = jwt.sign(payload, jwtSecret, { expiresIn: 86400 });

    res.json({
      success: true,
      message: 'Token gerado!',
      token: theToken,
      role: role,
      user: user
    });
  } catch (err) {
    console.error('Erro ao realizar login:', err);
    res.status(500).json({ success: false, message: 'Erro do servidor.' });
  }
});

// POST http://localhost:8080/med/getAssociation
router.post('/getAssociation', VerifyToken, async function (req, res) {
  const { userId } = req.body;

  try {
    const utente = await utenteModel.findOne({ user: userId }).select('_id');
    let tipo = '';
    let id = '';
    if (utente) {
      tipo = "utente";
      id = utente._id;
    }

    const medico = await medicoModel.findOne({ user: userId }).select('_id');
    if (medico) {
      tipo = "medico";
      id = medico._id;
    }

    // Nenhum encontrado
    res.status(200).json({ tipo: tipo, id: id });

  } catch (err) {
    res.status(500).json({ error: 'Erro do servidor', detalhes: err });
  }
});

// Rota para obter o ID do médico a partir do ID do utilizador -- NOVA ROTA
router.get('/medicos/user/:userId', VerifyToken, async (req: any, res: any) => {

  try {
    const medico = await medicoModel.findOne({ user: req.params.userId }).exec();
    if (!medico) {
      return res.status(404).json({ message: 'Médico não encontrado.' });
    }
    res.json({ medicoId: medico._id });
  } catch (err) {
    console.error('Erro ao obter o médico:', err);
    res.status(500).json({ message: 'Erro do servidor.' });
  }
});
router.get('/consultas/utente/:id',  VerifyToken,async (req: any, res: any) => {
  try {
    const idUtente = req.params.id;

    const utente = await utenteModel.findById(idUtente).populate({
      path: 'historico',
      populate: {
        path: 'consultas',
        populate: {
          path: 'medico',
          populate: {
            path: 'user',
            model: 'User'
          }
        }
      }
    });

    if (!utente || !utente.historico) {
      return res.status(404).json({ mensagem: 'Utente ou histórico não encontrado' });
    }

    const consultas = utente.historico.consultas.map((consulta: any) => ({
      id: consulta._id,
      data: formatarData(consulta.data),
      medico: consulta.medico?.user?.nome || "Nome não disponível",
      especialidade: consulta.medico?.specialty || "Especialidade não disponível"
    }));

    res.status(200).json(consultas);

  } catch (error) {
    console.error("Erro ao buscar consultas do utente:", error);
    res.status(500).json({ mensagem: 'Erro ao obter consultas', erro: error });
  }
});



module.exports = router;