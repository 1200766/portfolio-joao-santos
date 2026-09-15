<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

$id = intval($_POST['id_dispositivo'] ?? 0);

$statement = $conn->prepare("DELETE FROM dispositivos WHERE id_dispositivo = ?");
$statement->bind_param("i", $id);
$statement->execute();

header("Location: ../pages/administrador/gestao_dispositivos.php");
exit;
