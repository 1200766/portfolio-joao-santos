<?php
// A aplicação lê estas variáveis do processo. Este ficheiro documenta os nomes;
// não deve conter credenciais reais.
$DB_HOST = getenv("SAFEHEALTH_DB_HOST") ?: "127.0.0.1";
$DB_PORT = getenv("SAFEHEALTH_DB_PORT") ?: "3306";
$DB_NAME = getenv("SAFEHEALTH_DB_NAME") ?: "sistema_monitorizacao_medica";
$DB_USER = getenv("SAFEHEALTH_DB_USER") ?: "YOUR_DATABASE_USER";
$DB_PASS = getenv("SAFEHEALTH_DB_PASSWORD") ?: "YOUR_DATABASE_PASSWORD";
?>
