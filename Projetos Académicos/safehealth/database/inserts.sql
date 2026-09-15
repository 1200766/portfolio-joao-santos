USE sistema_monitorizacao_medica;

-- Dados inequivocamente fictícios para uma demonstração local descartável.
-- Os endereços example.invalid não recebem correio e os NIF ficam nulos.

INSERT INTO medicos
    (nome_medico, nif, email, hash_palavra_passe_medico, especialidade)
VALUES
    ('Profissional Demo', NULL, 'clinician@example.invalid', NULL, 'Demonstração');

INSERT INTO dispositivos
    (device_key, nome_dispositivo)
VALUES
    ('DEMO_DEVICE_001', 'Dispositivo fictício');

INSERT INTO pacientes
    (id_medico, nome_paciente, data_nascimento, genero, nif, email,
     hash_palavra_passe_paciente, telefone, id_dispositivo, aceitou_rgpd)
VALUES
    (1, 'Paciente Demo', '1990-01-01', 'Não especificado', NULL,
     'patient@example.invalid', NULL, NULL, 1, 'Sim');

INSERT INTO administradores
    (nome_admin, genero, nif, email, hash_palavra_passe_admin)
VALUES
    ('Administrador Demo', 'Não especificado', NULL,
     'admin@example.invalid', NULL);

INSERT INTO alertas (titulo, descricao, risco) VALUES
    ('SpO2 baixa', 'Limiar académico: SpO2 entre 92% e 94%.', 'MEDIO'),
    ('SpO2 critica', 'Limiar académico: SpO2 abaixo de 88%.', 'CRITICO'),
    ('Hipoxia moderada', 'Limiar académico: SpO2 entre 88% e 91%.', 'ALTO'),
    ('BPM elevado', 'Limiar académico: frequência acima de 100 bpm.', 'MEDIO'),
    ('BPM critico alto', 'Limiar académico: frequência acima de 140 bpm.', 'CRITICO'),
    ('BPM baixo', 'Limiar académico: frequência abaixo de 50 bpm.', 'MEDIO'),
    ('BPM critico baixo', 'Limiar académico: frequência abaixo de 40 bpm.', 'CRITICO'),
    ('Febre', 'Limiar académico: temperatura igual ou superior a 37,8 °C.', 'MEDIO'),
    ('Febre alta', 'Limiar académico: temperatura igual ou superior a 38,5 °C.', 'ALTO'),
    ('Febre critica', 'Limiar académico: temperatura igual ou superior a 39,5 °C.', 'CRITICO'),
    ('Hipoxia com taquicardia', 'Combinação académica de dois limiares.', 'CRITICO'),
    ('Febre com taquicardia', 'Combinação académica de dois limiares.', 'ALTO'),
    ('Hipoxia com febre', 'Combinação académica de dois limiares.', 'CRITICO'),
    ('Triade critica', 'Combinação académica de três limiares.', 'CRITICO'),
    ('Sinal instável', 'Valores inválidos ou insuficientes.', 'BAIXO'),
    ('Estado saudável', 'Valores dentro dos limiares demonstrativos.', 'BAIXO'),
    ('Estado estável', 'Pequenas variações nos limiares demonstrativos.', 'BAIXO');

INSERT INTO medicoes
    (id_paciente, id_alerta, bpm_medio, spo2_medio, temperatura_media,
     duracao_medicao_segundos, observacoes, data_medicao)
VALUES
    (1, 16, 72, 97, 36.6, 60, 'Medição totalmente fictícia.', '2026-01-01 12:00:00');
