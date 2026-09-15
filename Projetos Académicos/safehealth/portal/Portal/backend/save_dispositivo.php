<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

$id = $_POST['id_dispositivo'] ?? null;
$key = trim((string)($_POST['device_key'] ?? ""));
$nome = trim((string)($_POST['nome_dispositivo'] ?? ""));
$ativo = intval($_POST['ativo'] ?? 0);

if (!$nome || (!$id && strlen($key) < 16) || ($key && strlen($key) < 16)) {
    http_response_code(422);
    echo "Nome obrigatório; uma chave nova deve ter pelo menos 16 caracteres.";
    exit;
}

if ($id) {

    if ($key) {
        $stmt = $conn->prepare("
            UPDATE dispositivos
            SET device_key=?, nome_dispositivo=?, ativo=?
            WHERE id_dispositivo=?
        ");
        $stmt->bind_param("ssii", $key, $nome, $ativo, $id);
    } else {
        $stmt = $conn->prepare("
            UPDATE dispositivos
            SET nome_dispositivo=?, ativo=?
            WHERE id_dispositivo=?
        ");
        $stmt->bind_param("sii", $nome, $ativo, $id);
    }

} else {

    $stmt = $conn->prepare("
        INSERT INTO dispositivos (device_key, nome_dispositivo, ativo)
        VALUES (?, ?, ?)
    ");

    $stmt->bind_param("ssi", $key, $nome, $ativo);
}

$stmt->execute();

header("Location: ../pages/administrador/gestao_dispositivos.php");
exit;
