<?php

require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();

// Endpoint legado desativado: duplicava save_paciente.php e construía SQL com
// entrada do utilizador. O formulário atual usa exclusivamente save_paciente.php.
http_response_code(410);
echo "Endpoint desativado. Use save_paciente.php.";
exit;

?>
