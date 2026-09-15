<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("admin");
include("../../backend/conn.php");
// paginação
$limit = 5;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$offset = ($page - 1) * $limit;

// query dispositivos
$result = $conn->query("
SELECT *
FROM dispositivos
ORDER BY id_dispositivo ASC
LIMIT $limit OFFSET $offset
");

// total
$totalResult = $conn->query("SELECT COUNT(*) as total FROM dispositivos");
$totalRow = $totalResult->fetch_assoc();
$totalPages = ceil($totalRow['total'] / $limit);
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SafeHealth - Dispositivos</title>

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
      <h1>Gestão de Dispositivos</h1>
      <p>Administração de dispositivos do sistema</p>
    </div>

    <button class="add-btn" onclick="abrirModalDispositivo()">
      + Novo Dispositivo
    </button>

  </div>

  <!-- TABELA -->
  <table class="patients-table">

    <thead>
      <tr>
        <th>ID</th>
        <th>Device Key</th>
        <th>Nome</th>
        <th>Estado</th>
        <th>Ações</th>
      </tr>
    </thead>

    <tbody>

    <?php while($row = $result->fetch_assoc()) { ?>

      <tr>

        <td><?= $row['id_dispositivo'] ?></td>
        <td><span aria-label="chave configurada">••••••••</span></td>
        <td><?= htmlspecialchars((string)$row['nome_dispositivo'], ENT_QUOTES, 'UTF-8') ?></td>

        <td>
          <?= $row['ativo'] ? "Ativo" : "Inativo" ?>
        </td>

        <td class="actions">

          <button class="view-btn"
            onclick="verDispositivo(<?= $row['id_dispositivo'] ?>)">
            Ver
          </button>

          <button class="edit-btn"
            onclick="editarDispositivo(<?= $row['id_dispositivo'] ?>)">
            Editar
          </button>

          <form action="../../backend/delete_dispositivo.php" method="POST" style="display:inline;">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">
            <input type="hidden" name="id_dispositivo" value="<?= $row['id_dispositivo'] ?>">
            <button type="submit" class="delete-btn"
              onclick="return confirm('Remover dispositivo?');">
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
MODAL DISPOSITIVO
========================= -->
<div class="modal" id="deviceModal">

  <div class="modal-content">

    <h2>Dispositivo</h2>

    <form action="../../backend/save_dispositivo.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">

      <input type="hidden" name="id_dispositivo" id="idDispositivo">

      <div class="form-group">
        <label>Device Key</label>
        <input type="password" name="device_key" id="deviceKey" autocomplete="new-password">
        <small>Na edição, deixe vazio para manter a chave atual.</small>
      </div>

      <div class="form-group">
        <label>Nome do Dispositivo</label>
        <input type="text" name="nome_dispositivo" id="nomeDispositivo">
      </div>

      <div class="form-group">
        <label>Ativo</label>
        <select name="ativo" id="ativo">
          <option value="1">Ativo</option>
          <option value="0">Inativo</option>
        </select>
      </div>

      <div class="modal-buttons">
        <button type="submit">Guardar</button>
        <button type="button" class="cancel-btn" onclick="fecharModalDispositivo()">
          Cancelar
        </button>
      </div>

    </form>

  </div>

</div>

<!-- =========================
MODAL DETALHES DISPOSITIVO
========================= -->
<div class="modal" id="deviceDetailsModal">

  <div class="modal-content">

    <h2>Detalhes do Dispositivo</h2>

    <div class="patient-details" id="deviceDetails"></div>

    <div class="modal-buttons">
      <button class="cancel-btn" onclick="fecharDetalhesDispositivo()">
        Fechar
      </button>
    </div>

  </div>

</div>

<script src="../../app.js"></script>

</body>
</html>
