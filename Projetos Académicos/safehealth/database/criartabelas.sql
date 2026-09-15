CREATE DATABASE sistema_monitorizacao_medica;

USE sistema_monitorizacao_medica;

-- =====================================================
-- TABELA MEDICOS
-- =====================================================
CREATE TABLE medicos (
    id_medico INT AUTO_INCREMENT PRIMARY KEY,

    nome_medico VARCHAR(150),
    nif INT UNIQUE,
    email VARCHAR(150) UNIQUE,
    hash_palavra_passe_medico VARCHAR(255),

    especialidade VARCHAR(100),

    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================
-- TABELA DISPOSITIVOS
-- =====================================================
CREATE TABLE dispositivos (
    id_dispositivo INT AUTO_INCREMENT PRIMARY KEY,
    device_key VARCHAR(100) UNIQUE NOT NULL,
    nome_dispositivo VARCHAR(100),
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

-- =====================================================
-- TABELA PACIENTES
-- =====================================================
CREATE TABLE pacientes (
    id_paciente INT AUTO_INCREMENT PRIMARY KEY,

    id_medico INT NOT NULL,

    nome_paciente VARCHAR(150),

    data_nascimento DATE,
    genero VARCHAR(20),
    nif INT UNIQUE,

    email VARCHAR(150) UNIQUE,
    hash_palavra_passe_paciente VARCHAR(255),

    telefone VARCHAR(20),

    id_dispositivo INT UNIQUE,

    aceitou_rgpd VARCHAR (3),

    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pacientes_medicos
        FOREIGN KEY (id_medico)
        REFERENCES medicos(id_medico),

    CONSTRAINT fk_pacientes_dispositivos
        FOREIGN KEY (id_dispositivo)
        REFERENCES dispositivos(id_dispositivo)
);

-- =====================================================
-- TABELA ADMINISTRADORES
-- =====================================================

CREATE TABLE administradores (
    id_admin INT AUTO_INCREMENT PRIMARY KEY,
    nome_admin VARCHAR(150),
    genero VARCHAR(20),
    nif INT UNIQUE,
    email VARCHAR(150) UNIQUE,
    hash_palavra_passe_admin VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- TABELA ALERTAS
-- =====================================================
CREATE TABLE alertas (
    id_alerta INT AUTO_INCREMENT PRIMARY KEY,
    titulo VARCHAR(30),
    descricao TEXT,
    risco VARCHAR(20)
);

-- =====================================================
-- TABELA MEDICOES
-- =====================================================
CREATE TABLE medicoes (
    id_medicao INT AUTO_INCREMENT PRIMARY KEY,

    id_paciente INT NOT NULL,
    id_alerta INT,

    bpm_medio FLOAT,
    spo2_medio FLOAT,
    temperatura_media FLOAT,

    duracao_medicao_segundos INT,

    observacoes TEXT,

    data_medicao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_medicoes_pacientes
        FOREIGN KEY (id_paciente)
        REFERENCES pacientes(id_paciente),

    CONSTRAINT fk_medicoes_alertas
        FOREIGN KEY (id_alerta)
        REFERENCES alertas(id_alerta)
);


ALTER TABLE medicos
ADD tentativas_login INT DEFAULT 0,
ADD bloqueado_ate DATETIME NULL;

ALTER TABLE pacientes
ADD tentativas_login INT DEFAULT 0,
ADD bloqueado_ate DATETIME NULL;

ALTER TABLE administradores
ADD tentativas_login INT DEFAULT 0,
ADD bloqueado_ate DATETIME NULL;



SELECT * FROM medicos;