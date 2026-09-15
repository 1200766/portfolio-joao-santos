-- Endurecimento seguro por omissão para as tabelas clínicas novas.
--
-- O protótipo usa uma secret key exclusivamente no backend; ela autentica como
-- service_role e ignora RLS. Cada rota humana verifica a pertença do
-- paciente/gravidez. Estas instruções impedem acesso direto pelo browser.

ALTER TABLE clinical_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_cases ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE clinical_observations FROM anon, authenticated;
REVOKE ALL ON TABLE assessment_cases FROM anon, authenticated;

-- Não são publicadas políticas permissivas. Uma arquitetura sem secret key
-- tem de definir e testar políticas ligadas a auth.uid() antes de conceder acesso.
