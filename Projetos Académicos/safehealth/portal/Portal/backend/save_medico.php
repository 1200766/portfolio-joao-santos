<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

$id = $_POST['id_medico'] ?? null;
$nome = $_POST['nome_medico'] ?? null;
$email = $_POST['email'] ?? null;
$nif = $_POST['nif'] ?? null;
$especialidade = $_POST['especialidade'] ?? null;
$password = $_POST['password'] ?? null;

if (!$nome || !$email || !$nif) {
    die("Campos obrigatórios em falta.");
}

// hash da password (se existir)
$hash = $password ? password_hash($password, PASSWORD_DEFAULT) : null;

if ($id) {

    // UPDATE
    if ($hash) {
        $stmt = $conn->prepare("
            UPDATE medicos
            SET nome_medico=?, email=?, nif=?, especialidade=?, hash_palavra_passe_medico=?
            WHERE id_medico=?
        ");

        $stmt->bind_param("ssissi", $nome, $email, $nif, $especialidade, $hash, $id);

    } else {
        $stmt = $conn->prepare("
            UPDATE medicos
            SET nome_medico=?, email=?, nif=?, especialidade=?
            WHERE id_medico=?
        ");

        $stmt->bind_param("ssisi", $nome, $email, $nif, $especialidade, $id);
    }

} else {

    // INSERT
    $stmt = $conn->prepare("
        INSERT INTO medicos (nome_medico, email, nif, especialidade, hash_palavra_passe_medico)
        VALUES (?, ?, ?, ?, ?)
    ");

    $stmt->bind_param("ssiss", $nome, $email, $nif, $especialidade, $hash);
}

$stmt->execute();

header("Location: ../pages/administrador/gestao_medicos.php");
exit;
