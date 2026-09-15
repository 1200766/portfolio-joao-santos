function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#039;"
  })[character]);
}

document.addEventListener("DOMContentLoaded", () => {

  // =========================
  // DASHBOARD MÉDICO (INFO PACIENTE)
  // =========================

  const params = new URLSearchParams(window.location.search);
  const idPaciente = params.get("id_paciente");

  const paciente = params.get("paciente");

  if (
    paciente &&
    pacientes[paciente] &&
    document.getElementById("nome-paciente")
  ) {
    document.getElementById("nome-paciente").innerText =
      pacientes[paciente].nome;

    document.getElementById("estado").innerText =
      "Estado: " + pacientes[paciente].estado;

    document.getElementById("info").innerText =
      pacientes[paciente].info;
  }

  // =========================
  // GRÁFICOS
  // =========================

  let medicoes = [];

  let bpmChart;
  let tempChart;
  let spo2Chart;

  function carregarMedicoes(idPaciente) {
    fetch(`../../backend/get_medicoes.php?id_paciente=${idPaciente}`)
      .then(res => res.json())
      .then(data => {
        medicoes = data || [];
        createCharts("24h");
      })
      .catch(err => {
        console.error("Erro ao carregar medições:", err);
        medicoes = [];
      });
  }

function agruparDados(periodo) {

  if (!medicoes.length) {
    return { labels: [], bpm: [], temp: [], spo2: [] };
  }

  const ordenadas = [...medicoes].sort(
    (a, b) => new Date(a.data_medicao) - new Date(b.data_medicao)
  );

  const ultimaData = new Date(ordenadas[ordenadas.length - 1].data_medicao);

  let modo = "hora";
  let limite = new Date(ultimaData);

  if (periodo === "24h") {
    modo = "hora";
    limite.setHours(limite.getHours() - 24);
  }

  if (periodo === "3d") {
    modo = "dia";
    limite.setDate(limite.getDate() - 3);
  }

  if (periodo === "7d") {
    modo = "dia";
    limite.setDate(limite.getDate() - 7);
  }

  const filtrados = ordenadas.filter(m => {
    const data = new Date(m.data_medicao);
    return data >= limite && data <= ultimaData;
  });

  const grupos = new Map();

  filtrados.forEach(m => {

    const data = new Date(m.data_medicao);

    let chave;
    let label;

    if (modo === "hora") {
      chave = data.getFullYear() + "-" +
              data.getMonth() + "-" +
              data.getDate() + "-" +
              data.getHours();

      label = data.toLocaleString("pt-PT", {
        day: "2-digit",
        month: "2-digit",
        hour: "2-digit"
      });
    } else {
      chave = data.toISOString().split("T")[0];
      label = data.toLocaleDateString("pt-PT");
    }

    if (!grupos.has(chave)) {
      grupos.set(chave, {
        label,
        bpm: [],
        temp: [],
        spo2: []
      });
    }

    const g = grupos.get(chave);

    g.bpm.push(Number(m.bpm_medio));
    g.temp.push(Number(m.temperatura_media));
    g.spo2.push(Number(m.spo2_medio));
  });

  const valores = [...grupos.values()];

  const avg = arr => arr.reduce((a, b) => a + b, 0) / arr.length;

  return {
    labels: valores.map(v => v.label),
    bpm: valores.map(v => avg(v.bpm).toFixed(1)),
    temp: valores.map(v => avg(v.temp).toFixed(1)),
    spo2: valores.map(v => avg(v.spo2).toFixed(1))
  };
}
  function createCharts(periodo) {

    const data = agruparDados(periodo);

    if (bpmChart) bpmChart.destroy();
    if (tempChart) tempChart.destroy();
    if (spo2Chart) spo2Chart.destroy();

    bpmChart = new Chart(document.getElementById("bpmChart"), {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: "BPM",
          data: data.bpm,
          borderColor: "#e53935",
          fill: true,
          tension: 0.4
        }]
      }
    });

    tempChart = new Chart(document.getElementById("tempChart"), {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: "Temperatura",
          data: data.temp,
          borderColor: "#fb8c00",
          fill: true,
          tension: 0.4
        }]
      }
    });

    spo2Chart = new Chart(document.getElementById("spo2Chart"), {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: "SpO2",
          data: data.spo2,
          borderColor: "#43a047",
          fill: true,
          tension: 0.4
        }]
      }
    });
  }

  // =========================
  // BOTÃO PERÍODO
  // =========================

  window.changePeriod = function(period, button) {
    createCharts(period);

    document.querySelectorAll('.time-btn').forEach(btn => {
      btn.classList.remove('active');
    });

    button.classList.add('active');
  };

  // =========================
  // INICIALIZAÇÃO
  // =========================

  if (idPaciente) {
    carregarMedicoes(idPaciente);
  }

});


// =========================
// ABRIR DASHBOARD PACIENTE
// =========================

function abrirDashboard(paciente) {

  window.location.href =
    `dashboard_medico.html?paciente=${paciente}`;

}

//grafico paciente - visao paciente
if (document.getElementById("patientChart")) {

  new Chart(document.getElementById("patientChart"), {
    type: "line",
    data: {
      labels: ["Seg", "Ter", "Qua", "Qui", "Sex"],
      datasets: [{
        label: "BPM",
        data: [72, 75, 78, 74, 76],
        borderColor: "#007bff",
        fill: true,
        tension: 0.4
      }]
    }
  });

}

// =========================================================
// MODAL
// =========================================================
let linhaEmEdicao = null;
function abrirModal() {

  document.getElementById("patientModal").style.display = "flex";

  document.getElementById("idPaciente").value = "";
  document.getElementById("idMedico").value = "";
  document.getElementById("nomePaciente").value = "";
  document.getElementById("dataNascimento").value = "";
  document.getElementById("genero").value = "";
  document.getElementById("emailPaciente").value = "";
  document.getElementById("nifPaciente").value = "";
  document.getElementById("passwordPaciente").value = "";
  document.getElementById("telefonePaciente").value = "";


  document.getElementById("idDispositivo").value = "";
}

function fecharModal() {

  document.getElementById("patientModal").style.display =
    "none";

}


// =========================================================
// ADICIONAR PACIENTE
// =========================================================

function adicionarPaciente() {

  const idMedico = document.getElementById("idMedico").value;
  const nome = document.getElementById("nomePaciente").value;
  const nascimento = document.getElementById("dataNascimento").value;
  const genero = document.getElementById("genero").value;
  const nif = document.getElementById("nifPaciente").value;
  const email = document.getElementById("emailPaciente").value;
  const password = document.getElementById("passwordPaciente").value;
  const telefone = document.getElementById("telefonePaciente").value;

  if (
    !idMedico ||
    !nome ||
    !nascimento ||
    !genero ||
    !nif ||
    !email ||
    !password ||
    !telefone
  ) {
    alert("Preenche todos os campos!");
    return;
  }

  // =========================
  // CASO ESTEJA A EDITAR
  // =========================
  if (linhaEmEdicao) {

    linhaEmEdicao.dataset.idmedico = idMedico;
    linhaEmEdicao.dataset.nome = nome;
    linhaEmEdicao.dataset.nascimento = nascimento;
    linhaEmEdicao.dataset.genero = genero;
    linhaEmEdicao.dataset.nif = nif;
    linhaEmEdicao.dataset.email = email;
    linhaEmEdicao.dataset.telefone = telefone;

    linhaEmEdicao.innerHTML = `
      <td>${nome}</td>
      <td>${nif}</td>
      <td class="actions">

        <button class="view-btn"
                onclick="verMais(this)">
          Ver Mais
        </button>

        <button class="edit-btn"
                onclick="editarPaciente(this)">
          Editar
        </button>

        <button class="delete-btn"
                onclick="removerPaciente(this)">
          Remover
        </button>

      </td>
    `;

    linhaEmEdicao = null;

  }

  // =========================
  // CASO SEJA NOVO
  // =========================
  else {

    const row = `
      <tr
        data-idmedico="${idMedico}"
        data-nome="${nome}"
        data-nascimento="${nascimento}"
        data-genero="${genero}"
        data-nif="${nif}"
        data-email="${email}"
        data-telefone="${telefone}"
      >

        <td>${nome}</td>
        <td>${nif}</td>

        <td class="actions">

          <button class="view-btn"
                  onclick="verMais(this)">
            Ver Mais
          </button>

          <button class="edit-btn"
                  onclick="editarPaciente(this)">
            Editar
          </button>

          <button class="delete-btn"
                  onclick="removerPaciente(this)">
            Remover
          </button>

        </td>

      </tr>
    `;

    document.getElementById("patientsBody")
      .insertAdjacentHTML("beforeend", row);
  }

  fecharModal();
  limparFormulario();
}


// =========================================================
// EDITAR PACIENTE
// =========================================================

function abrirModalEditar() {
  document.getElementById("patientModal").style.display = "flex";
}

function editarPaciente(id) {

  fetch(`../../backend/get_paciente.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      if (!data) {
        alert("Erro ao carregar paciente");
        return;
      }

      document.getElementById("idPaciente").value = data.id_paciente ?? "";
      document.getElementById("idMedico").value = data.id_medico ?? "";
      document.getElementById("nomePaciente").value = data.nome_paciente ?? "";
      document.getElementById("dataNascimento").value = data.data_nascimento ?? "";
      document.getElementById("genero").value = data.genero ?? "";
      document.getElementById("emailPaciente").value = data.email ?? "";
      document.getElementById("nifPaciente").value = data.nif ?? "";
      document.getElementById("telefonePaciente").value = data.telefone ?? "";
      document.getElementById("idDispositivo").value = data.id_dispositivo ?? "";

      document.getElementById("patientModal").style.display = "flex";
    })
    .catch(err => {
      console.error("Erro fetch:", err);
    });
}

// =========================================================
// LIMPAR FORMULÁRIO
// =========================================================

function limparFormulario() {

  document.getElementById("idMedico").value = "";

  document.getElementById("nomePaciente").value = "";

  document.getElementById("dataNascimento").value = "";

  document.getElementById("genero").value = "";

  document.getElementById("nifPaciente").value = "";

  document.getElementById("emailPaciente").value = "";

  document.getElementById("passwordPaciente").value = "";

  document.getElementById("telefonePaciente").value = "";

}


// =========================================================
// REMOVER PACIENTE
// =========================================================

function removerPaciente(button) {

  button.closest("tr").remove();

}


// =========================================================
// VER MAIS
// =========================================================

function verMais(id) {

  fetch(`../../backend/get_paciente.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      if (!data) {
        alert("Paciente não encontrado");
        return;
      }

      const details = `
        <p><strong>Nome:</strong> ${escapeHtml(data.nome_paciente)}</p>
        <p><strong>NIF:</strong> ${escapeHtml(data.nif)}</p>
        <p><strong>Data Nascimento:</strong> ${escapeHtml(data.data_nascimento)}</p>
        <p><strong>Género:</strong> ${escapeHtml(data.genero)}</p>
        <p><strong>Email:</strong> ${escapeHtml(data.email)}</p>
        <p><strong>Telefone:</strong> ${escapeHtml(data.telefone)}</p>
        <p><strong>Médico:</strong> ${escapeHtml(data.nome_medico)}</p>
        <p><strong>ID Dispositivo:</strong> ${escapeHtml(data.id_dispositivo)}</p>
        <p><strong>Aceitou RGPD:</strong> ${escapeHtml(data.aceitou_rgpd || 'Não definido')}</p>
      `;

      const container = document.getElementById("patientDetails");

      if (!container) {
        console.error("Modal patientDetails não existe no HTML");
        return;
      }

      container.innerHTML = details;

      document.getElementById("detailsModal").style.display = "flex";
    })
    .catch(err => {
      console.error("Erro fetch:", err);
    });
}


// =========================================================
// FECHAR DETALHES
// =========================================================

function fecharDetalhes() {

  document.getElementById("detailsModal").style.display =
    "none";

}



// =========================================================
// MODAL DISPOSITIVOS
// =========================================================

function abrirModalDispositivo() {
  document.getElementById("deviceModal").style.display = "flex";

  document.getElementById("idDispositivo").value = "";
  document.getElementById("deviceKey").value = "";
  document.getElementById("nomeDispositivo").value = "";
  document.getElementById("ativo").value = "1";
}

function fecharModalDispositivo() {
  document.getElementById("deviceModal").style.display = "none";
}


function editarDispositivo(id) {

  fetch(`../../backend/get_dispositivo.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      document.getElementById("idDispositivo").value = data.id_dispositivo;
      document.getElementById("deviceKey").value = "";
      document.getElementById("nomeDispositivo").value = data.nome_dispositivo;
      document.getElementById("ativo").value = data.ativo;

      document.getElementById("deviceModal").style.display = "flex";
    });
}

// =========================
// VER DISPOSITIVO (MODAL)
// =========================
function verDispositivo(id) {

  fetch(`../../backend/get_dispositivo.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      if (!data) {
        alert("Dispositivo não encontrado");
        return;
      }

      const details = `
        <p><strong>ID:</strong> ${escapeHtml(data.id_dispositivo)}</p>
        <p><strong>Device Key:</strong> configurada e ocultada</p>
        <p><strong>Nome:</strong> ${escapeHtml(data.nome_dispositivo)}</p>
        <p><strong>Ativo:</strong> ${data.ativo == 1 ? "Sim" : "Não"}</p>
        <p><strong>Criado em:</strong> ${escapeHtml(data.criado_em)}</p>
      `;

      document.getElementById("deviceDetails").innerHTML = details;
      document.getElementById("deviceDetailsModal").style.display = "flex";
    });
}

function fecharDetalhesDispositivo() {
  document.getElementById("deviceDetailsModal").style.display = "none";
}

// =========================
// VER MEDICO (MODAL)
// =========================
window.verMedico = function(id) {
  fetch(`../../backend/get_medico.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      if (!data || !data.id_medico) {
        alert("Médico não encontrado");
        return;
      }

      document.getElementById("medicoDetails").innerHTML = `
        <p><strong>Nome:</strong> ${escapeHtml(data.nome_medico)}</p>
        <p><strong>NIF:</strong> ${escapeHtml(data.nif)}</p>
        <p><strong>Email:</strong> ${escapeHtml(data.email)}</p>
        <p><strong>Especialidade:</strong> ${escapeHtml(data.especialidade)}</p>
      `;

      document.getElementById("medicoDetailsModal").style.display = "flex";
    });
};

window.fecharDetalhesMedico = function () {
  document.getElementById("medicoDetailsModal").style.display = "none";
};


function abrirModalMedico() {
  document.getElementById("idMedico").value = "";
  document.getElementById("nomeMedico").value = "";
  document.getElementById("emailMedico").value = "";
  document.getElementById("especialidadeMedico").value = "";
  document.getElementById("nifMedico").value = "";

  document.getElementById("medicoModal").style.display = "flex";
}

function fecharModalMedico() {
  document.getElementById("medicoModal").style.display = "none";
}


function editarMedico(id) {

  fetch(`../../backend/get_medico.php?id=${id}`)
    .then(res => res.json())
    .then(data => {

      if (!data || !data.id_medico) {
        alert("Médico não encontrado");
        return;
      }

      // preencher modal
      document.getElementById("idMedico").value = data.id_medico;
      document.getElementById("nomeMedico").value = data.nome_medico;
      document.getElementById("emailMedico").value = data.email;
      document.getElementById("nifMedico").value = data.nif;
      document.getElementById("especialidadeMedico").value = data.especialidade;

      // abrir modal
      document.getElementById("medicoModal").style.display = "flex";
    })
    .catch(err => console.error(err));
}
