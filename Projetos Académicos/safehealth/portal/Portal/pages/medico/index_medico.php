<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("medico");
include("../../backend/conn.php");

$idMedico = $_SESSION["user_id"];

// pacientes + última medição
$sql = "
SELECT
    p.id_paciente,
    p.nome_paciente,
    m.spo2_medio,
    m.bpm_medio,
    m.temperatura_media

FROM pacientes p

LEFT JOIN medicoes m ON m.id_medicao = (
    SELECT id_medicao
    FROM medicoes
    WHERE id_paciente = p.id_paciente
    ORDER BY data_medicao DESC
    LIMIT 1
)

WHERE p.id_medico = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $idMedico);
$stmt->execute();
$result = $stmt->get_result();
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeHealth</title>

  <link rel="stylesheet" href="../../styles/styles.css">
</head>

<body class="body-medico">

<nav class="navbar">
  <div class="logo">SafeHealth</div>

  <div class="nav-links">
    <form action="../../backend/logout.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
      <button type="submit" class="logout">Terminar sessão</button>
    </form>
  </div>
</nav>

<div class="patients-container">

  <div class="doctor-welcome">
    Bem-vindo <?= htmlspecialchars($_SESSION["nome"]) ?>
  </div>

  <h2>Lista de Pacientes</h2>

  <table class="patients-table">
    <thead>
      <tr>
        <th>Nome</th>
        <th>Estado de Saúde</th>
        <th>Descrição</th>
        <th>Ações</th>
      </tr>
    </thead>

    <tbody>

    <?php while($row = $result->fetch_assoc()) { ?>

      <?php

      $estado = "Estado saudável";
      $descricao = "Todos os sinais vitais dentro dos valores normais";
      $classe = "good";

      $spo2 = $row["spo2_medio"];
      $bpm = $row["bpm_medio"];
      $temp = $row["temperatura_media"];

      if ($spo2 === null) {

          $estado = "Sem dados";
          $descricao = "Ainda não existem medições para este paciente";
          $classe = "warning";
      }

      elseif ($spo2 < 92 && $bpm > 110 && $temp >= 38) {

          $estado = "Tríade crítica";
          $descricao = "SpO₂ < 92%, febre ≥ 38°C e BPM > 110";
          $classe = "danger";
      }

      elseif ($spo2 < 92 && $bpm > 110) {

          $estado = "Hipóxia com taquicardia";
          $descricao = "SpO₂ < 92% e BPM > 110";
          $classe = "danger";
      }

      elseif ($temp >= 39.5) {

          $estado = "Febre crítica";
          $descricao = "Temperatura ≥ 39.5°C";
          $classe = "danger";
      }

      elseif ($bpm > 140) {

          $estado = "BPM crítico alto";
          $descricao = "Frequência cardíaca acima de 140 bpm";
          $classe = "danger";
      }

      elseif ($spo2 < 88) {

          $estado = "SpO2 crítica";
          $descricao = "SpO₂ abaixo de 88%";
          $classe = "danger";
      }

      elseif ($temp >= 38.5) {

          $estado = "Febre alta";
          $descricao = "Temperatura ≥ 38.5°C";
          $classe = "warning";
      }

      elseif ($bpm > 100) {

          $estado = "BPM elevado";
          $descricao = "Frequência cardíaca acima de 100 bpm";
          $classe = "warning";
      }

      elseif ($temp >= 37.8) {

          $estado = "Febre leve";
          $descricao = "Temperatura entre 37.8°C e 38.4°C";
          $classe = "warning";
      }

      elseif ($spo2 < 94) {

          $estado = "SpO2 baixa";
          $descricao = "SpO₂ entre 92% e 94%";
          $classe = "warning";
      }

      ?>

      <tr>

        <td><?= htmlspecialchars($row["nome_paciente"]) ?></td>

        <td>
          <span class="status <?= $classe ?>">
            <?= htmlspecialchars($estado) ?>
          </span>
        </td>

        <td>
          <?= htmlspecialchars($descricao) ?>
        </td>

        <td class="actions">

          <button
            class="view-btn"
            onclick="verMais(<?= $row['id_paciente'] ?>)">
            Ver Mais
          </button>

          <button
            class="graph-btn"
            onclick="window.location.href='dashboard_medico.php?id_paciente=<?= $row['id_paciente'] ?>'">
            Ver Gráficos
          </button>

        </td>

      </tr>

    <?php } ?>

    </tbody>

  </table>

  <!-- MODAL DETALHES -->
  <div class="modal" id="detailsModal">

    <div class="modal-content">

      <h2>Detalhes do Paciente</h2>

      <div class="patient-details" id="patientDetails"></div>

      <div class="modal-buttons">

        <button
          class="cancel-btn"
          onclick="fecharDetalhes()">
          Fechar
        </button>

      </div>

    </div>

  </div>

</div>

<script src="../../app.js"></script>
</body>
</html>
