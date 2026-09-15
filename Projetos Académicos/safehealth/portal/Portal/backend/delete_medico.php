<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

$id = $_POST['id_medico'] ?? null;

if (!$id) {
    die("ID inválido.");
}

$stmt = $conn->prepare("DELETE FROM medicos WHERE id_medico = ?");
$stmt->bind_param("i", $id);

$stmt->execute();

header("Location: ../pages/administrador/gestao_medicos.php");
exit;
