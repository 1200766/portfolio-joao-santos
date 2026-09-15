<?php
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . "/../../db.php";

function responder(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function campoObrigatorio(array $data, string $field): void
{
    if (!isset($data[$field]) || $data[$field] === "") {
        responder(400, [
            "success" => false,
            "message" => "Campo obrigatório em falta: $field"
        ]);
    }
}

function procurarAlerta(PDO $pdo, string $titulo): ?int
{
    $aliases = [
        "SpO2 critica" => ["SpO2 critica", "SpO2 crítica"],
        "Hipoxia moderada" => ["Hipoxia moderada", "Hipóxia moderada"],
        "Hipoxia com taquicardia" => ["Hipoxia com taquicardia", "Hipóxia com taquicardia"],
        "Hipoxia com febre" => ["Hipoxia com febre", "Hipóxia com febre"],
        "Triade critica" => ["Triade critica", "Tríade crítica"],
        "Febre critica" => ["Febre critica", "Febre crítica"],
        "Estado saudavel" => ["Estado saudavel", "Estado saudável"],
    ];

    $titulos = $aliases[$titulo] ?? [$titulo];
    $placeholders = implode(",", array_fill(0, count($titulos), "?"));
    $stmt = $pdo->prepare("SELECT id_alerta FROM alertas WHERE titulo IN ($placeholders) LIMIT 1");
    $stmt->execute($titulos);
    $alerta = $stmt->fetch();

    return $alerta ? (int)$alerta["id_alerta"] : null;
}

function avaliarMedicao(PDO $pdo, float $bpm, float $spo2, float $temperatura): array
{
    $problemas = [];
    $tituloAlerta = "Estado saudável";
    $observacoes = "Parâmetros dentro dos valores esperados.";

    if ($spo2 <= 0 || $bpm <= 0 || $temperatura <= 0) {
        $tituloAlerta = "Sinal instável";
        $observacoes = "Medição recebida com valores inválidos ou insuficientes. Recomenda-se repetir a medição.";
        return [
            "id_alerta" => procurarAlerta($pdo, $tituloAlerta),
            "titulo_alerta" => $tituloAlerta,
            "observacoes" => $observacoes
        ];
    }

    if ($spo2 < 92) {
        $problemas[] = "SpO2 inferior a 92%";
    } elseif ($spo2 <= 94) {
        $problemas[] = "SpO2 ligeiramente baixa";
    }

    if ($temperatura >= 39.5) {
        $problemas[] = "febre crítica";
    } elseif ($temperatura >= 38.5) {
        $problemas[] = "febre alta";
    } elseif ($temperatura >= 37.8) {
        $problemas[] = "febre";
    }

    if ($bpm > 140) {
        $problemas[] = "frequência cardíaca criticamente elevada";
    } elseif ($bpm > 100) {
        $problemas[] = "frequência cardíaca elevada";
    } elseif ($bpm < 40) {
        $problemas[] = "frequência cardíaca criticamente baixa";
    } elseif ($bpm < 50) {
        $problemas[] = "frequência cardíaca baixa";
    }

    if ($spo2 < 92 && $temperatura >= 38 && $bpm > 110) {
        $tituloAlerta = "Triade critica";
        $observacoes = "SpO2 baixa, febre e taquicardia. Recomenda-se avaliação clínica urgente.";
    } elseif ($spo2 < 92 && $bpm > 110) {
        $tituloAlerta = "Hipoxia com taquicardia";
        $observacoes = "SpO2 baixa associada a frequência cardíaca elevada. Recomenda-se contacto clínico prioritário.";
    } elseif ($spo2 < 92 && $temperatura >= 38) {
        $tituloAlerta = "Hipoxia com febre";
        $observacoes = "SpO2 baixa associada a febre. Recomenda-se avaliação médica.";
    } elseif ($temperatura >= 38.5 && $bpm > 100) {
        $tituloAlerta = "Febre com taquicardia";
        $observacoes = "Temperatura elevada associada a frequência cardíaca elevada. Recomenda-se vigilância reforçada.";
    } elseif ($spo2 < 88) {
        $tituloAlerta = "SpO2 critica";
        $observacoes = "SpO2 em valor crítico. Recomenda-se avaliação clínica urgente.";
    } elseif ($temperatura >= 39.5) {
        $tituloAlerta = "Febre critica";
        $observacoes = "Temperatura corporal em valor crítico. Recomenda-se contacto clínico urgente.";
    } elseif ($bpm > 140) {
        $tituloAlerta = "BPM critico alto";
        $observacoes = "Frequência cardíaca criticamente elevada.";
    } elseif ($bpm < 40) {
        $tituloAlerta = "BPM critico baixo";
        $observacoes = "Frequência cardíaca criticamente baixa.";
    } elseif ($spo2 <= 91) {
        $tituloAlerta = "Hipoxia moderada";
        $observacoes = "SpO2 abaixo do intervalo desejável. Recomenda-se nova medição e vigilância.";
    } elseif ($temperatura >= 38.5) {
        $tituloAlerta = "Febre alta";
        $observacoes = "Temperatura corporal elevada. Recomenda-se vigilância.";
    } elseif ($spo2 <= 94) {
        $tituloAlerta = "SpO2 baixa";
        $observacoes = "SpO2 ligeiramente baixa. Recomenda-se repetir a medição se houver sintomas.";
    } elseif ($bpm > 100) {
        $tituloAlerta = "BPM elevado";
        $observacoes = "Frequência cardíaca acima do valor de referência em repouso.";
    } elseif ($bpm < 50) {
        $tituloAlerta = "BPM baixo";
        $observacoes = "Frequência cardíaca abaixo do valor de referência em repouso.";
    } elseif ($temperatura >= 37.8) {
        $tituloAlerta = "Febre";
        $observacoes = "Temperatura corporal ligeiramente elevada.";
    } elseif (!empty($problemas)) {
        $tituloAlerta = "Estado estável";
        $observacoes = "Pequenas variações detetadas: " . implode(", ", $problemas) . ".";
    }

    return [
        "id_alerta" => procurarAlerta($pdo, $tituloAlerta),
        "titulo_alerta" => $tituloAlerta,
        "observacoes" => $observacoes
    ];
}

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    responder(405, [
        "success" => false,
        "message" => "Este endpoint aceita apenas pedidos POST com JSON."
    ]);
}

if ((int)($_SERVER["CONTENT_LENGTH"] ?? 0) > 4096) {
    responder(413, [
        "success" => false,
        "message" => "Pedido demasiado grande"
    ]);
}

$rawData = file_get_contents("php://input");
$data = json_decode($rawData, true);

if (!is_array($data)) {
    responder(400, [
        "success" => false,
        "message" => "JSON inválido ou vazio"
    ]);
}

campoObrigatorio($data, "device_key");
campoObrigatorio($data, "bpm_medio");
campoObrigatorio($data, "spo2_medio");
campoObrigatorio($data, "temperatura_media");

$deviceKey = trim((string)$data["device_key"]);
$bpmMedio = (float)$data["bpm_medio"];
$spo2Medio = (float)$data["spo2_medio"];
$temperaturaMedia = (float)$data["temperatura_media"];
$duracaoMedicaoSegundos = isset($data["duracao_medicao_segundos"])
    ? (int)$data["duracao_medicao_segundos"]
    : 30;

if ($deviceKey === "" || strlen($deviceKey) < 12) {
    responder(400, [
        "success" => false,
        "message" => "device_key inválida"
    ]);
}

if (
    $bpmMedio < 20 || $bpmMedio > 250 ||
    $spo2Medio < 0 || $spo2Medio > 100 ||
    $temperaturaMedia < 20 || $temperaturaMedia > 45
) {
    responder(422, [
        "success" => false,
        "message" => "Valores fora dos limites da demonstração"
    ]);
}

if ($duracaoMedicaoSegundos <= 0) {
    responder(400, [
        "success" => false,
        "message" => "duracao_medicao_segundos inválida"
    ]);
}

$stmtDispositivo = $pdo->prepare("
    SELECT pacientes.id_paciente, dispositivos.ativo
    FROM dispositivos
    INNER JOIN pacientes ON pacientes.id_dispositivo = dispositivos.id_dispositivo
    WHERE dispositivos.device_key = ?
    LIMIT 1
");
$stmtDispositivo->execute([$deviceKey]);
$dispositivo = $stmtDispositivo->fetch();

if (!$dispositivo) {
    responder(404, [
        "success" => false,
        "message" => "Dispositivo não encontrado"
    ]);
}

if ((int)$dispositivo["ativo"] !== 1) {
    responder(403, [
        "success" => false,
        "message" => "Dispositivo inativo"
    ]);
}

$idPaciente = (int)$dispositivo["id_paciente"];
$avaliacao = avaliarMedicao($pdo, $bpmMedio, $spo2Medio, $temperaturaMedia);

$sql = "INSERT INTO medicoes
        (id_paciente, id_alerta, bpm_medio, spo2_medio, temperatura_media, duracao_medicao_segundos, observacoes)
        VALUES
        (:id_paciente, :id_alerta, :bpm_medio, :spo2_medio, :temperatura_media, :duracao_medicao_segundos, :observacoes)";

$stmt = $pdo->prepare($sql);
$stmt->bindValue(":id_paciente", $idPaciente, PDO::PARAM_INT);

if ($avaliacao["id_alerta"] === null) {
    $stmt->bindValue(":id_alerta", null, PDO::PARAM_NULL);
} else {
    $stmt->bindValue(":id_alerta", $avaliacao["id_alerta"], PDO::PARAM_INT);
}

$stmt->bindValue(":bpm_medio", $bpmMedio);
$stmt->bindValue(":spo2_medio", $spo2Medio);
$stmt->bindValue(":temperatura_media", $temperaturaMedia);
$stmt->bindValue(":duracao_medicao_segundos", $duracaoMedicaoSegundos, PDO::PARAM_INT);
$stmt->bindValue(":observacoes", $avaliacao["observacoes"]);

try {
    $stmt->execute();

    echo json_encode([
        "success" => true,
        "message" => "Medição inserida com sucesso",
        "id_medicao" => (int)$pdo->lastInsertId(),
        "titulo_alerta" => $avaliacao["titulo_alerta"],
        "id_alerta" => $avaliacao["id_alerta"],
        "observacoes" => $avaliacao["observacoes"]
    ], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    responder(500, [
        "success" => false,
        "message" => "Erro ao inserir medição"
    ]);
}
?>
