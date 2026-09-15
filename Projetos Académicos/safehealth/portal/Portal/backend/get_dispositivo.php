<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
include("conn.php");

$id = intval($_GET['id'] ?? 0);

$statement = $conn->prepare(
    "SELECT id_dispositivo, nome_dispositivo, ativo, criado_em " .
    "FROM dispositivos WHERE id_dispositivo = ?"
);
$statement->bind_param("i", $id);
$statement->execute();
$result = $statement->get_result();

echo json_encode($result->fetch_assoc());
