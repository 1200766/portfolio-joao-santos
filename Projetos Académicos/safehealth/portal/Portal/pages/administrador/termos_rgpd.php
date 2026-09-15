<?php
require_once __DIR__ . "/../../backend/security.php";
safehealth_require_page_role("admin");
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Termos RGPD - SafeHealth</title>

  <link rel="stylesheet" href="../../styles/styles.css">
</head>

<body class="body-admin">


<nav class="navbar">
  <div class="logo">SafeHealth</div>
</nav>

<!-- CONTEÚDO -->
<div class="admin-container">

  <h1>Termos de Consentimento RGPD</h1>

  <div class="card" style="text-align:left; padding:25px;">

    <h3>1. Recolha de Dados</h3>
    <p>
      O sistema SafeHealth recolhe dados pessoais necessários para a gestão clínica,
      incluindo nome, NIF, contacto, e dados médicos associados.
    </p>

    <h3>2. Finalidade</h3>
    <p>
      Os dados são utilizados exclusivamente para acompanhamento médico,
      gestão de pacientes e suporte ao funcionamento da plataforma.
    </p>

    <h3>3. Armazenamento</h3>
    <p>
      Os dados são armazenados de forma segura em servidores protegidos
      e não são partilhados com terceiros sem consentimento.
    </p>

    <h3>4. Direitos do Utilizador</h3>
    <p>
      O utilizador pode solicitar a correção, exportação ou eliminação dos seus dados
      a qualquer momento, conforme o RGPD.
    </p>

    <h3>5. Consentimento</h3>
    <p>
      Ao marcar a opção “Aceito os termos de RGPD”, o utilizador declara que leu
      e compreendeu estas condições e autoriza o tratamento dos seus dados.
    </p>

  </div>

</div>

</body>
</html>
