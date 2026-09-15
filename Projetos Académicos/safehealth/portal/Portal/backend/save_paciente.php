<?php
require_once __DIR__ . "/security.php";
safehealth_require_roles(["admin"]);
safehealth_require_csrf();
include("conn.php");

// =========================
// DADOS
// =========================
$id = $_POST['id_paciente'] ?? null;

$idMedico = $_POST['idMedico'] ?? null;
$nome = $_POST['nomePaciente'] ?? null;
$data = $_POST['dataNascimento'] ?? null;
$genero = $_POST['genero'] ?? null;
$email = $_POST['emailPaciente'] ?? null;
$nif = $_POST['nif'] ?? null;
$password = $_POST['passwordPaciente'] ?? null;
$telefone = $_POST['telefonePaciente'] ?? null;
$id_dispositivo = $_POST['id_dispositivo'] ?? null;

// RGPD CORRETO
$aceitou_rgpd = isset($_POST['aceitou_rgpd']) ? 'Sim' : 'Não';

$formData = $_POST;
unset($formData["passwordPaciente"], $formData["csrf_token"]);
$_SESSION["form_data"] = $formData;

// limpa erro anterior
unset($_SESSION["error"]);

// =========================
// VALIDAR CAMPOS
// =========================
if (
    empty($idMedico) || empty($nome) || empty($data) ||
    empty($genero) || empty($email) || empty($nif) ||
    empty($telefone) || empty($id_dispositivo)
) {
    $_SESSION["error"] = "Preenche todos os campos obrigatórios.";
    header("Location: ../pages/administrador/index_administrador.php?modal=1");
    exit;
}

// =========================
// VALIDAR MÉDICO
// =========================
$check = $conn->prepare("SELECT id_medico FROM medicos WHERE id_medico = ?");
$check->bind_param("i", $idMedico);
$check->execute();

if ($check->get_result()->num_rows == 0) {
    $_SESSION["error"] = "ID Médico não existe.";
    header("Location: ../pages/administrador/index_administrador.php?modal=1");
    exit;
}

// =========================
// VALIDAR DISPOSITIVO
// =========================
$check = $conn->prepare("SELECT id_dispositivo FROM dispositivos WHERE id_dispositivo = ?");
$check->bind_param("i", $id_dispositivo);
$check->execute();

if ($check->get_result()->num_rows == 0) {
    $_SESSION["error"] = "ID Dispositivo não existe.";
    header("Location: ../pages/administrador/index_administrador.php?modal=1");
    exit;
}

// =========================
// VALIDAR NIF DUPLICADO
// =========================
if ($id) {
    $check = $conn->prepare("SELECT id_paciente FROM pacientes WHERE nif = ? AND id_paciente != ?");
    $check->bind_param("si", $nif, $id);
} else {
    $check = $conn->prepare("SELECT id_paciente FROM pacientes WHERE nif = ?");
    $check->bind_param("s", $nif);
}

$check->execute();

if ($check->get_result()->num_rows > 0) {
    $_SESSION["error"] = "Já existe um paciente com esse NIF.";
    header("Location: ../pages/administrador/index_administrador.php?modal=1");
    exit;
}

// =========================
// HASH PASSWORD
// =========================
$hash = $password ? password_hash($password, PASSWORD_DEFAULT) : null;

// =========================
// TRY CATCH
// =========================
try {

    if ($id) {

        // =========================
        // UPDATE COM PASSWORD
        // =========================
        if ($hash) {

            $sql = "UPDATE pacientes SET
                id_medico=?,
                nome_paciente=?,
                data_nascimento=?,
                genero=?,
                email=?,
                nif=?,
                telefone=?,
                id_dispositivo=?,
                hash_palavra_passe_paciente=?,
                aceitou_rgpd=?
                WHERE id_paciente=?";

            $stmt = $conn->prepare($sql);

            $stmt->bind_param(
                "issssssissi",
                $idMedico,
                $nome,
                $data,
                $genero,
                $email,
                $nif,
                $telefone,
                $id_dispositivo,
                $hash,
                $aceitou_rgpd,
                $id
            );

        } else {

            // =========================
            // UPDATE SEM PASSWORD
            // =========================
            $sql = "UPDATE pacientes SET
                id_medico=?,
                nome_paciente=?,
                data_nascimento=?,
                genero=?,
                email=?,
                nif=?,
                telefone=?,
                id_dispositivo=?,
                aceitou_rgpd=?
                WHERE id_paciente=?";

            $stmt = $conn->prepare($sql);

            $stmt->bind_param(
                "issssssisi",
                $idMedico,
                $nome,
                $data,
                $genero,
                $email,
                $nif,
                $telefone,
                $id_dispositivo,
                $aceitou_rgpd,
                $id
            );
        }

    } else {

        // =========================
        // INSERT
        // =========================
        $sql = "INSERT INTO pacientes
            (id_medico,nome_paciente,data_nascimento,genero,email,nif,hash_palavra_passe_paciente,telefone,id_dispositivo,aceitou_rgpd)
            VALUES (?,?,?,?,?,?,?,?,?,?)";

        $stmt = $conn->prepare($sql);

        $stmt->bind_param(
            "isssssssis",
            $idMedico,
            $nome,
            $data,
            $genero,
            $email,
            $nif,
            $hash,
            $telefone,
            $id_dispositivo,
            $aceitou_rgpd
        );
    }

    $stmt->execute();

    $_SESSION["success"] = "Paciente guardado com sucesso!";
    header("Location: ../pages/administrador/index_administrador.php");
    exit;

} catch (mysqli_sql_exception $e) {

    if (str_contains($e->getMessage(), 'Duplicate entry')) {
        $_SESSION["error"] = "Este ID de dispositivo já está em uso.";
    } else {
        $_SESSION["error"] = "Erro ao guardar paciente.";
    }

    header("Location: ../pages/administrador/index_administrador.php?modal=1");
    exit;
}
?>
