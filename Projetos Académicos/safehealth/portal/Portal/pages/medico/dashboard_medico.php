<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("medico");
include("../../backend/conn.php");

$idPaciente = intval($_GET["id_paciente"] ?? 0);

if ($idPaciente <= 0 || !safehealth_patient_is_accessible($conn, $idPaciente)) {
    http_response_code(404);
    die("Paciente não encontrado");
}


// buscar medições
$sql = "
SELECT
    bpm_medio,
    spo2_medio,
    temperatura_media,
    data_medicao
FROM medicoes
WHERE id_paciente = ?
ORDER BY data_medicao ASC
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $idPaciente);
$stmt->execute();
$result = $stmt->get_result();

$data = [];

while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <title>Dashboard Médico</title>

  <link rel="stylesheet" href="../../styles/styles.css">
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
</head>

<body class="body-medico">

<nav class="navbar">
  <div class="logo">SafeHealth</div>
  <div class="nav-links">
    <a href="index_medico.php" class="logout">Voltar</a>
  </div>
</nav>

<div class="dashboard-container">

  <div class="top-bar">
    <div id="patientName">Dashboard do Paciente</div>

    <div class="filter-buttons">
      <button onclick="changePeriod('24h', this)" class="time-btn active">24h</button>
      <button onclick="changePeriod('3d', this)" class="time-btn">3 Dias</button>
      <button onclick="changePeriod('7d', this)" class="time-btn">1 Semana</button>
    </div>
  </div>

  <div class="charts-grid">

    <div class="chart-card">
      <h3>BPM</h3>
      <canvas id="bpmChart"></canvas>
    </div>

    <div class="chart-card">
      <h3>Temperatura</h3>
      <canvas id="tempChart"></canvas>
    </div>

    <div class="chart-card">
      <h3>SPO2</h3>
      <canvas id="spo2Chart"></canvas>
    </div>

  </div>
</div>

<script src="../../app.js"></script>
</body>
</html>
