<?php

require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin", "medico", "paciente"]);
safehealth_require_csrf();

$_SESSION = [];
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(),
        "",
        time() - 42000,
        $params["path"],
        $params["domain"],
        $params["secure"],
        $params["httponly"]
    );
}
session_destroy();

header("Location: ../pages/login.php");
exit;

?>
