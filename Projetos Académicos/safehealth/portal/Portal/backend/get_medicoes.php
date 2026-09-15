<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin", "medico", "paciente"]);
include("conn.php");

header('Content-Type: application/json');

$id = intval($_GET['id_paciente'] ?? 0);

if ($id <= 0 || !safehealth_patient_is_accessible($conn, $id)) {
    http_response_code(404);
    echo json_encode([]);
    exit;
}

$stmt = $conn->prepare("
    SELECT
        data_medicao,
        bpm_medio,
        temperatura_media,
        spo2_medio
    FROM medicoes
    WHERE id_paciente = ?
    ORDER BY data_medicao ASC
");

$stmt->bind_param("i", $id);
$stmt->execute();

$result = $stmt->get_result();

$data = $result->fetch_all(MYSQLI_ASSOC);

echo json_encode($data);
