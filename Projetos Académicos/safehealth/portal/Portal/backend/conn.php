<?php

require_once __DIR__ . "/../../config/database_config.php";

$conn = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME, (int)$DB_PORT);

if ($conn->connect_error) {
    die("Erro de ligação: " . $conn->connect_error);
}

$conn->set_charset("utf8mb4");

?>
