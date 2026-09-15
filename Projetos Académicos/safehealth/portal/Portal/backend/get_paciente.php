<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin", "medico"]);
include("conn.php");

header('Content-Type: application/json');

$id = intval($_GET['id']);

if ($id <= 0 || !safehealth_patient_is_accessible($conn, $id)) {
    http_response_code(404);
    echo json_encode(null);
    exit;
}

$sql = "
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
WHERE pacientes.id_paciente = ?
";

$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $id);
$stmt->execute();

$result = $stmt->get_result();
$data = $result->fetch_assoc();

echo json_encode($data);
