<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("paciente");
include("../../backend/conn.php");

$idPaciente = $_SESSION["user_id"];

/* =========================
   DADOS DO PACIENTE
========================= */

$sql = "
SELECT *
FROM pacientes
WHERE id_paciente = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $idPaciente);
$stmt->execute();

$paciente = $stmt->get_result()->fetch_assoc();

/* =========================
   ÚLTIMA MEDIÇÃO
========================= */

$sqlUltima = "
SELECT *
FROM medicoes
WHERE id_paciente = ?
ORDER BY data_medicao DESC
LIMIT 1
";

$stmt2 = $conn->prepare($sqlUltima);
$stmt2->bind_param("i", $idPaciente);
$stmt2->execute();

$ultima = $stmt2->get_result()->fetch_assoc();

/* =========================
   ESTADO DE SAÚDE
========================= */

$estado = "Estado saudável";
$statusClass = "ok";

if ($ultima) {

    $spo2 = $ultima["spo2_medio"];
    $bpm = $ultima["bpm_medio"];
    $temp = $ultima["temperatura_media"];

    if ($spo2 < 92 && $temp >= 38 && $bpm > 110) {
        $estado = "Tríade crítica";
        $statusClass = "danger";
    }

    elseif ($spo2 < 92 && $bpm > 110) {
        $estado = "Hipóxia com taquicardia";
        $statusClass = "danger";
    }

    elseif ($spo2 < 95) {
        $estado = "Hipóxia";
        $statusClass = "warning";
    }

    elseif ($spo2 < 88) {
        $estado = "SpO₂ crítica";
        $statusClass = "danger";
    }
    elseif ($temp >= 39.5) {
        $estado = "Febre crítica";
        $statusClass = "danger";
    }
    elseif ($temp >= 38.5) {
        $estado = "Febre alta";
        $statusClass = "warning";
    }
    elseif ($bpm > 140) {
        $estado = "BPM crítico alto";
        $statusClass = "danger";
    }
    elseif ($temp >= 37.8) {
    $estado = "Febre leve";
    $statusClass = "warning";
    }
    elseif ($bpm > 100) {
        $estado = "BPM elevado";
        $statusClass = "warning";
    }
}
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <title>SafeHealth - Paciente</title>

  <link rel="stylesheet" href="../../styles/styles.css">

  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
</head>

<body class="body-paciente">

<!-- NAVBAR -->
<nav class="navbar">

  <div class="logo">
    SafeHealth
  </div>

  <div class="nav-links">
    <form action="../../backend/logout.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
      <button type="submit" class="logout">Terminar sessão</button>
    </form>
  </div>

</nav>

<!-- DASHBOARD -->
<div class="patient-dashboard">

  <!-- HEADER -->
  <div class="patient-header">

    <h1>
      Olá, <?= htmlspecialchars($paciente["nome_paciente"]) ?>
    </h1>

    <p class="status <?= $statusClass ?>">
      Estado atual: <?= htmlspecialchars($estado) ?>
    </p>

  </div>

  <!-- CARDS -->
  <div class="patient-cards">

    <div class="card">
      <h3>BPM</h3>
      <p>
        <?= $ultima ? $ultima["bpm_medio"] : "--" ?> bpm
      </p>
    </div>

    <div class="card">
      <h3>Temperatura</h3>
      <p>
        <?= $ultima ? $ultima["temperatura_media"] : "--" ?> °C
      </p>
    </div>

    <div class="card">
      <h3>SpO₂</h3>
      <p>
        <?= $ultima ? $ultima["spo2_medio"] : "--" ?> %
      </p>
    </div>

  </div>

  <!-- GRÁFICO -->
  <div class="chart-box">

    <h2>Evolução da Temperatura Corporal</h2>

    <canvas id="tempChart"></canvas>

  </div>

  <!-- ALERTAS -->
  <div class="alerts">

    <h2>Estado Atual</h2>

    <div class="alert ok">
      <?= htmlspecialchars($estado) ?>
    </div>

  </div>

</div>

<script>

const idPaciente = <?= $idPaciente ?>;

fetch(`../../backend/get_temperaturas.php?id_paciente=${idPaciente}`)
.then(response => response.json())
.then(data => {

    const labels = data.map(item =>
        new Date(item.data_medicao).toLocaleString("pt-PT")
    );

    const temperaturas = data.map(item =>
        item.temperatura_media
    );

    new Chart(
        document.getElementById("tempChart"),
        {
            type: "line",

            data: {
                labels: labels,

                datasets: [{
                    label: "Temperatura (°C)",
                    data: temperaturas,
                    borderColor: "#fb8c00",
                    backgroundColor: "rgba(251,140,0,0.2)",
                    tension: 0.4,
                    fill: true
                }]
            },

            options: {
                responsive: true,

                scales: {
                    y: {
                        beginAtZero: false
                    }
                }
            }
        }
    );

})
.catch(error => {
    console.error("Erro ao carregar temperaturas:", error);
});

</script>

</body>
</html>
