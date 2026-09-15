<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("admin");
include("../../backend/conn.php");

// paginação
$limit = 5;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$offset = ($page - 1) * $limit;

// query médicos
$result = $conn->query("
SELECT *
FROM medicos
ORDER BY id_medico ASC
LIMIT $limit OFFSET $offset
");

// total
$totalResult = $conn->query("SELECT COUNT(*) as total FROM medicos");
$totalRow = $totalResult->fetch_assoc();
$totalPages = ceil($totalRow['total'] / $limit);
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeHealth - Médicos</title>

  <link rel="stylesheet" href="../../styles/styles.css">
</head>

<body class="body-admin">

<!-- NAVBAR -->
<nav class="navbar">
  <div class="logo">SafeHealth</div>

  <div class="nav-links">
    <a href="../administrador/index_administrador.php" class="logout">Voltar</a>
  </div>
</nav>

<!-- CONTAINER -->
<div class="admin-container">

  <!-- TOPO -->
  <div class="admin-top">

    <div>
      <h1>Gestão de Médicos</h1>
      <p>Administração de médicos do sistema</p>
    </div>

    <button class="add-btn" onclick="abrirModalMedico()">
      + Novo Médico
    </button>

  </div>

  <!-- TABELA -->
  <table class="patients-table">

    <thead>
      <tr>
        <th>ID</th>
        <th>Nome</th>
        <th>Email</th>
        <th>Especialidade</th>
        <th>Ações</th>
      </tr>
    </thead>

    <tbody>

    <?php while($row = $result->fetch_assoc()) { ?>

      <tr>

        <td><?= $row['id_medico'] ?></td>
        <td><?= htmlspecialchars((string)$row['nome_medico'], ENT_QUOTES, 'UTF-8') ?></td>
        <td><?= htmlspecialchars((string)($row['email'] ?? ''), ENT_QUOTES, 'UTF-8') ?></td>
        <td><?= htmlspecialchars((string)($row['especialidade'] ?? ''), ENT_QUOTES, 'UTF-8') ?></td>

        <td class="actions">

          <button class="view-btn"
            onclick="verMedico(<?= $row['id_medico'] ?>)">
            Ver Mais
          </button>

          <button class="edit-btn"
            onclick="editarMedico(<?= $row['id_medico'] ?>)">
            Editar
          </button>

          <form action="../../backend/delete_medico.php" method="POST" style="display:inline;">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
            <input type="hidden" name="id_medico" value="<?= $row['id_medico'] ?>">
            <button type="submit" class="delete-btn"
              onclick="return confirm('Remover médico?');">
              Remover
            </button>
          </form>

        </td>

      </tr>

    <?php } ?>

    </tbody>

  </table>

  <!-- PAGINAÇÃO -->
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
MODAL MÉDICO
========================= -->
<div class="modal" id="medicoModal">

  <div class="modal-content">

    <h2>Médico</h2>

        <form action="../../backend/save_medico.php" method="POST">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">

        <input type="hidden" name="id_medico" id="idMedico">

        <div class="form-group">
            <label>Nome</label>
            <input type="text" name="nome_medico" id="nomeMedico" required>
        </div>

        <div class="form-group">
            <label>Email</label>
            <input type="email" name="email" id="emailMedico" required>
        </div>

        <div class="form-group">
            <label>NIF</label>
            <input type="number" name="nif" id="nifMedico" required>
        </div>

        <div class="form-group">
            <label>Especialidade</label>
            <input type="text" name="especialidade" id="especialidadeMedico">
        </div>

        <div class="form-group">
            <label>Password</label>
            <input type="password" name="password" id="passwordMedico" required>
        </div>

        <div class="modal-buttons">
            <button type="submit">Guardar</button>
            <button type="button" onclick="fecharModalMedico()">Cancelar</button>
        </div>

        </form>

  </div>

</div>

<!-- =========================
MODAL DETALHES MÉDICO
========================= -->
<div class="modal" id="medicoDetailsModal">

  <div class="modal-content">

    <h2>Detalhes do Médico</h2>

    <div class="patient-details" id="medicoDetails"></div>

    <div class="modal-buttons">
      <button class="cancel-btn" onclick="fecharDetalhesMedico()">
        Fechar
      </button>
    </div>

  </div>

</div>

<script src="../../app.js"></script>

</body>
</html>
