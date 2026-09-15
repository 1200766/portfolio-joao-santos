<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

$id = intval($_POST['id_paciente'] ?? 0);

$statement = $conn->prepare("DELETE FROM pacientes WHERE id_paciente = ?");
$statement->bind_param("i", $id);

if ($statement->execute()) {
    header("Location: ../pages/administrador/index_administrador.php");
} else {
    echo "Erro ao remover paciente.";
}
?>
