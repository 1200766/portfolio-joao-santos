<?php

require_once __DIR__ . "/security.php";
safehealth_start_session();
safehealth_require_csrf();
include "conn.php";

$email = trim((string)($_POST["email"] ?? ""));
$password = (string)($_POST["password"] ?? "");

if ($_SERVER["REQUEST_METHOD"] !== "POST" || !$email || !$password) {
    $_SESSION["login_error"] = "Email ou password inválidos";
    header("Location: ../pages/login.php");
    exit;
}


// =====================================================
// FUNÇÃO AUXILIAR (evita repetição)
// =====================================================
function verificarBloqueio($user, $tipo) {

    if (
        !empty($user["bloqueado_ate"]) &&
        strtotime($user["bloqueado_ate"]) > time()
    ) {
        $_SESSION["login_error"] = "Conta bloqueada. Tente novamente mais tarde.";
        header("Location: ../pages/login.php");
        exit;
    }
}


// =====================================================
// 1. MÉDICO
// =====================================================
$sql = "SELECT * FROM medicos WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();

$user = $stmt->get_result()->fetch_assoc();

if ($user) {

    verificarBloqueio($user, "medico");

    if (password_verify($password, $user["hash_palavra_passe_medico"])) {

        session_regenerate_id(true);

        // reset tentativas
        $reset = $conn->prepare("
            UPDATE medicos
            SET tentativas_login = 0,
                bloqueado_ate = NULL
            WHERE id_medico = ?
        ");
        $reset->bind_param("i", $user["id_medico"]);
        $reset->execute();

        $_SESSION["user_id"] = $user["id_medico"];
        $_SESSION["nome"] = $user["nome_medico"];
        $_SESSION["role"] = "medico";

        header("Location: ../pages/medico/index_medico.php");
        exit;
    }

    // password errada
    $tentativas = $user["tentativas_login"] + 1;

    if ($tentativas >= 3) {

        $update = $conn->prepare("
            UPDATE medicos
            SET tentativas_login = ?,
                bloqueado_ate = DATE_ADD(NOW(), INTERVAL 15 MINUTE)
            WHERE id_medico = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_medico"]);

    } else {

        $update = $conn->prepare("
            UPDATE medicos
            SET tentativas_login = ?
            WHERE id_medico = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_medico"]);
    }

    $update->execute();
}


// =====================================================
// 2. PACIENTE
// =====================================================
$sql = "SELECT * FROM pacientes WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();

$user = $stmt->get_result()->fetch_assoc();

if ($user) {

    verificarBloqueio($user, "paciente");

    if (password_verify($password, $user["hash_palavra_passe_paciente"])) {

        session_regenerate_id(true);

        $reset = $conn->prepare("
            UPDATE pacientes
            SET tentativas_login = 0,
                bloqueado_ate = NULL
            WHERE id_paciente = ?
        ");
        $reset->bind_param("i", $user["id_paciente"]);
        $reset->execute();

        $_SESSION["user_id"] = $user["id_paciente"];
        $_SESSION["nome"] = $user["nome_paciente"];
        $_SESSION["role"] = "paciente";

        header("Location: ../pages/paciente/index_paciente.php");
        exit;
    }

    $tentativas = $user["tentativas_login"] + 1;

    if ($tentativas >= 3) {

        $update = $conn->prepare("
            UPDATE pacientes
            SET tentativas_login = ?,
                bloqueado_ate = DATE_ADD(NOW(), INTERVAL 15 MINUTE)
            WHERE id_paciente = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_paciente"]);

    } else {

        $update = $conn->prepare("
            UPDATE pacientes
            SET tentativas_login = ?
            WHERE id_paciente = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_paciente"]);
    }

    $update->execute();
}


// =====================================================
// 3. ADMIN
// =====================================================
$sql = "SELECT * FROM administradores WHERE email = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $email);
$stmt->execute();

$user = $stmt->get_result()->fetch_assoc();

if ($user) {

    verificarBloqueio($user, "admin");

    if (password_verify($password, $user["hash_palavra_passe_admin"])) {

        session_regenerate_id(true);

        $reset = $conn->prepare("
            UPDATE administradores
            SET tentativas_login = 0,
                bloqueado_ate = NULL
            WHERE id_admin = ?
        ");
        $reset->bind_param("i", $user["id_admin"]);
        $reset->execute();

        $_SESSION["user_id"] = $user["id_admin"];
        $_SESSION["nome"] = $user["nome_admin"];
        $_SESSION["role"] = "admin";

        header("Location: ../pages/administrador/index_administrador.php");
        exit;
    }

    $tentativas = $user["tentativas_login"] + 1;

    if ($tentativas >= 3) {

        $update = $conn->prepare("
            UPDATE administradores
            SET tentativas_login = ?,
                bloqueado_ate = DATE_ADD(NOW(), INTERVAL 15 MINUTE)
            WHERE id_admin = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_admin"]);

    } else {

        $update = $conn->prepare("
            UPDATE administradores
            SET tentativas_login = ?
            WHERE id_admin = ?
        ");

        $update->bind_param("ii", $tentativas, $user["id_admin"]);
    }

    $update->execute();
}


// =====================================================
// ERRO FINAL
// =====================================================
$_SESSION["login_error"] = "Email ou password inválidos";
header("Location: ../pages/login.php");
exit;

?>
