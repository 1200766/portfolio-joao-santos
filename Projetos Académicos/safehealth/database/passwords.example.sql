USE sistema_monitorizacao_medica;

-- Gerar um hash local:
-- php -r 'echo password_hash("escolha-uma-password-local", PASSWORD_DEFAULT), PHP_EOL;'
-- Copiar este ficheiro para passwords.local.sql e substituir YOUR_PASSWORD_HASH.

UPDATE administradores
SET hash_palavra_passe_admin = 'YOUR_PASSWORD_HASH'
WHERE email = 'admin@example.invalid';

UPDATE medicos
SET hash_palavra_passe_medico = 'YOUR_PASSWORD_HASH'
WHERE email = 'clinician@example.invalid';

UPDATE pacientes
SET hash_palavra_passe_paciente = 'YOUR_PASSWORD_HASH'
WHERE email = 'patient@example.invalid';
