<?php

function safehealth_start_session(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }

    session_set_cookie_params([
        "httponly" => true,
        "secure" => !empty($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off",
        "samesite" => "Strict",
        "path" => "/",
    ]);
    session_start();
}

function safehealth_require_roles(array $roles): void
{
    safehealth_start_session();
    $role = $_SESSION["role"] ?? null;
    $userId = $_SESSION["user_id"] ?? null;

    if (!$userId || !in_array($role, $roles, true)) {
        http_response_code(403);
        header("Content-Type: application/json; charset=UTF-8");
        echo json_encode(["success" => false, "message" => "Acesso negado."]);
        exit;
    }
}

function safehealth_require_page_role(string $role, string $loginLocation = "../login.php"): void
{
    safehealth_start_session();
    if (empty($_SESSION["user_id"]) || ($_SESSION["role"] ?? null) !== $role) {
        header("Location: " . $loginLocation);
        exit;
    }
}

function safehealth_csrf_token(): string
{
    safehealth_start_session();
    if (empty($_SESSION["csrf_token"])) {
        $_SESSION["csrf_token"] = bin2hex(random_bytes(32));
    }
    return $_SESSION["csrf_token"];
}

function safehealth_require_csrf(): void
{
    safehealth_start_session();
    $provided = $_POST["csrf_token"] ?? ($_SERVER["HTTP_X_CSRF_TOKEN"] ?? "");
    $expected = $_SESSION["csrf_token"] ?? "";

    if (!$expected || !$provided || !hash_equals($expected, $provided)) {
        http_response_code(403);
        echo "Pedido rejeitado.";
        exit;
    }
}

function safehealth_patient_is_accessible(mysqli $conn, int $patientId): bool
{
    $role = $_SESSION["role"] ?? null;
    $userId = (int)($_SESSION["user_id"] ?? 0);

    if ($role === "admin") {
        return true;
    }
    if ($role === "paciente") {
        return $patientId === $userId;
    }
    if ($role !== "medico") {
        return false;
    }

    $statement = $conn->prepare(
        "SELECT 1 FROM pacientes WHERE id_paciente = ? AND id_medico = ? LIMIT 1"
    );
    $statement->bind_param("ii", $patientId, $userId);
    $statement->execute();
    return $statement->get_result()->num_rows === 1;
}

?>
