<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
include("conn.php");

header('Content-Type: application/json');

$id = intval($_GET['id']);

if ($id <= 0) {
    http_response_code(404);
    echo json_encode(null);
    exit;
}

$sql = "
SELECT
    id_medico,
    nome_medico,
    nif,
    email,
    especialidade
FROM medicos
WHERE id_medico = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $id);
$stmt->execute();

$result = $stmt->get_result();
$data = $result->fetch_assoc();

echo json_encode($data);
