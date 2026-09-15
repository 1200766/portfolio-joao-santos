<?php
require_once __DIR__ . "/../backend/security.php";
safehealth_start_session();
?>

<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Login</title>

  <!-- ligação correta ao CSS -->
  <link rel="stylesheet" href="../styles/styles.css">
</head>

<body class="body-login">

  <div class="login-container">
    <h2>Login</h2>

  <form action="../backend/login.php" method="POST">
      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(safehealth_csrf_token(), ENT_QUOTES, 'UTF-8') ?>">

      <label for="email">Email</label>
      <input type="email" id="email" name="email" required>

      <label for="password">Password</label>
      <input type="password" id="password" name="password" required>

      <?php
      if (isset($_SESSION["login_error"])) {
          echo "<p style='color:red; margin-top:10px; margin-bottom:10px;'>"
              . htmlspecialchars($_SESSION["login_error"], ENT_QUOTES, 'UTF-8') .
              "</p>";

          unset($_SESSION["login_error"]);
      }
      ?>

      <button type="submit">Entrar</button>

  </form>
  </div>

<script src="../app.js"></script>
</body>
</html>
