<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin", "medico", "paciente"]);
include("conn.php");

$idPaciente = intval($_GET["id_paciente"] ?? 0);

if ($idPaciente <= 0 || !safehealth_patient_is_accessible($conn, $idPaciente)) {
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode([]);
    exit;
}

/* 1. buscar última data da BD */
$sqlUltima = "
SELECT data_medicao
FROM medicoes
WHERE id_paciente = ?
ORDER BY data_medicao DESC
LIMIT 1
";

$stmt = $conn->prepare($sqlUltima);
$stmt->bind_param("i", $idPaciente);
$stmt->execute();
$res = $stmt->get_result();
$ultima = $res->fetch_assoc();

if (!$ultima) {
    echo json_encode([]);
    exit;
}

$ultimaData = $ultima["data_medicao"];

/* 2. agora ir 24h para trás dessa última medição */
$sql = "
SELECT
    data_medicao,
    temperatura_media
FROM medicoes
WHERE id_paciente = ?
  AND data_medicao BETWEEN
      DATE_SUB(?, INTERVAL 24 HOUR)
      AND ?
ORDER BY data_medicao ASC
";

$stmt2 = $conn->prepare($sql);
$stmt2->bind_param("iss", $idPaciente, $ultimaData, $ultimaData);
$stmt2->execute();

$result = $stmt2->get_result();

$dados = [];

while ($row = $result->fetch_assoc()) {
    $dados[] = $row;
}

header('Content-Type: application/json');
echo json_encode($dados);
?>
