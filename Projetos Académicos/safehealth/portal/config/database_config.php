<?php
$DB_HOST = getenv("SAFEHEALTH_DB_HOST") ?: "127.0.0.1";
$DB_PORT = getenv("SAFEHEALTH_DB_PORT") ?: "3306";
$DB_NAME = getenv("SAFEHEALTH_DB_NAME") ?: "sistema_monitorizacao_medica";
$DB_USER = getenv("SAFEHEALTH_DB_USER") ?: "";
$DB_PASS = getenv("SAFEHEALTH_DB_PASSWORD") ?: "";
?>
