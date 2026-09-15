<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("admin");
$data = $_SESSION["form_data"] ?? [];
include("../../backend/conn.php");


// número de pacientes por página
$limit = 5;

// página atual (default = 1)
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;

// cálculo do offset
$offset = ($page - 1) * $limit;

// query com paginação
$result = $conn->query("
SELECT
    pacientes.id_paciente,
    pacientes.nome_paciente,
    pacientes.nif,
    pacientes.data_nascimento,
    pacientes.genero,
    pacientes.email,
    pacientes.telefone,
    pacientes.id_dispositivo,
    pacientes.id_medico,
    pacientes.aceitou_rgpd,
    medicos.nome_medico
FROM pacientes
INNER JOIN medicos
ON pacientes.id_medico = medicos.id_medico
LIMIT $limit OFFSET $offset
");

// total de pacientes (para saber nº de páginas)
$totalResult = $conn->query("SELECT COUNT(*) as total FROM pacientes");
$totalRow = $totalResult->fetch_assoc();
$totalPages = ceil($totalRow['total'] / $limit);
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeHealth - Administrador</title>

  <link rel="stylesheet" href="../../styles/styles.css">
</head>

<body class="body-admin">

<!-- NAVBAR -->
<nav class="navbar">
  <div class="logo">SafeHealth</div>

  <div class="nav-links">
    <form action="../../backend/logout.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
      <button type="submit" class="logout">Terminar sessão</button>
    </form>
  </div>
</nav>

<!-- CONTAINER -->
<div class="admin-container">

  <!-- TOPO -->
  <div class="admin-top">

    <div>
      <h1>Painel de Administração</h1>
      <p>Gestão de pacientes do sistema</p>
    </div>

    <div class="admin-buttons">

      <button class="add-btn" onclick="abrirModal()">
        + Novo Paciente
      </button>

      <button class="add-btn" onclick="window.location.href='gestao_medicos.php'">
        Médicos
      </button>

      <button class="add-btn" onclick="window.location.href='gestao_dispositivos.php'">
        Dispositivos
      </button>

    </div>

  </div>

  <!-- TABELA -->
  <table class="patients-table">

    <thead>
      <tr>
        <th>Nome</th>
        <th>NIF</th>
        <th>Médico</th>
        <th>Ações</th>
      </tr>
    </thead>

    <tbody id="patientsBody">

    <?php while($row = $result->fetch_assoc()) { ?>

    <tr>

      <td><?= htmlspecialchars((string)$row['nome_paciente'], ENT_QUOTES, 'UTF-8') ?></td>
      <td><?= htmlspecialchars((string)$row['nif'], ENT_QUOTES, 'UTF-8') ?></td>
      <td><?= htmlspecialchars((string)$row['nome_medico'], ENT_QUOTES, 'UTF-8') ?></td>

      <td class="actions">

        <!-- VER MAIS -->
        <button class="view-btn"
          onclick="verMais(<?= $row['id_paciente'] ?>)">
          Ver Mais
        </button>

        <!-- EDITAR -->
        <button class="edit-btn"
          onclick="editarPaciente(<?= $row['id_paciente'] ?>)">
          Editar
        </button>

        <!-- REMOVER -->
        <form action="../../backend/delete_paciente.php" method="POST" style="display:inline;">
          <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
          <input type="hidden" name="id_paciente" value="<?= $row['id_paciente'] ?>">
          <button type="submit" class="delete-btn"
            onclick="return confirm('Tens a certeza que queres remover este paciente?');">
            Remover
          </button>
        </form>

      </td>

    </tr>

    <?php } ?>

    </tbody>

  </table>

  <div class="pagination">

<?php for ($i = 1; $i <= $totalPages; $i++) { ?>

    <a href="?page=<?= $i ?>"
       class="<?= ($i == $page) ? 'active' : '' ?>">
        <?= $i ?>
    </a>

<?php } ?>

</div>

</div>

<!-- =========================
MODAL ADD / EDIT
========================= -->
<div class="modal" id="patientModal">

  <div class="modal-content">

    <h2>Paciente</h2>

    <?php if (!empty($_SESSION["error"])) { ?>
      <div class="error-box">
        <?= htmlspecialchars((string)$_SESSION["error"], ENT_QUOTES, 'UTF-8') ?>
      </div>
    <?php unset($_SESSION["error"]); } ?>

    <form action="../../backend/save_paciente.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">

      <input type="hidden" name="id_paciente" id="idPaciente"
        value="<?= htmlspecialchars((string)($data['id_paciente'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">

      <div class="form-group">
        <label for="idMedico">ID Médico</label>
        <input type="number" name="idMedico" id="idMedico" required
          value="<?= htmlspecialchars((string)($data['idMedico'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="nomePaciente">Nome do Paciente</label>
        <input type="text" name="nomePaciente" id="nomePaciente" required
          value="<?= htmlspecialchars((string)($data['nomePaciente'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="dataNascimento">Data de Nascimento</label>
        <input type="date" name="dataNascimento" id="dataNascimento" required
          value="<?= htmlspecialchars((string)($data['dataNascimento'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="genero">Género</label>
        <select name="genero" id="genero" required>
          <option value="">Selecionar Género</option>
          <option value="Masculino" <?= ($data['genero'] ?? '') == 'Masculino' ? 'selected' : '' ?>>Masculino</option>
          <option value="Feminino" <?= ($data['genero'] ?? '') == 'Feminino' ? 'selected' : '' ?>>Feminino</option>
          <option value="Outro" <?= ($data['genero'] ?? '') == 'Outro' ? 'selected' : '' ?>>Outro</option>
        </select>
      </div>

      <div class="form-group">
        <label for="emailPaciente">Email</label>
        <input type="email" name="emailPaciente" id="emailPaciente" required
          value="<?= htmlspecialchars((string)($data['emailPaciente'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="nifPaciente">NIF</label>
        <input type="number" name="nif" id="nifPaciente" required
          value="<?= htmlspecialchars((string)($data['nif'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="passwordPaciente">Palavra-passe</label>
        <input type="password" name="passwordPaciente" id="passwordPaciente">
      </div>

      <div class="form-group">
        <label for="telefonePaciente">Telefone</label>
        <input type="text" name="telefonePaciente" id="telefonePaciente" required
          value="<?= htmlspecialchars((string)($data['telefonePaciente'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group">
        <label for="idDispositivo">ID Dispositivo</label>
        <input type="number" name="id_dispositivo" id="idDispositivo" required
          value="<?= htmlspecialchars((string)($data['id_dispositivo'] ?? ''), ENT_QUOTES, 'UTF-8') ?>">
      </div>

      <div class="form-group rgpd-group">

        <div class="rgpd-row">
          <span>Li e aceito os termos de RGPD</span>
          <input type="checkbox" name="aceitou_rgpd" id="aceitouRgpd" required>
        </div>

        <div class="rgpd-subtext">
          <a href="termos_rgpd.php" target="_blank">
            Ver termos de RGPD
          </a>
        </div>

      </div>

      <div class="modal-buttons">
        <button type="submit">Guardar</button>
        <button type="button" class="cancel-btn" onclick="fecharModal()">
          Cancelar
        </button>
      </div>

    </form>

  </div>

</div>

<!-- =========================
MODAL DETALHES
========================= -->
<div class="modal" id="detailsModal">

  <div class="modal-content">

    <h2>Detalhes do Paciente</h2>

    <div class="patient-details" id="patientDetails"></div>

    <div class="modal-buttons">

      <button class="cancel-btn" onclick="fecharDetalhes()">
        Fechar
      </button>

    </div>

  </div>

</div>

<script src="../../app.js"></script>
<?php if (isset($_GET['modal'])) { ?>
<script>
  window.addEventListener("DOMContentLoaded", () => {
    setTimeout(() => {
      abrirModal();
    }, 50);
  });
</script>
<?php } ?>
</body>
</html>
<?php unset($_SESSION["form_data"]); ?>
