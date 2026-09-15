-- Modelo de observações clínicas + episódios + snapshots (executar no Supabase SQL Editor)

-- Tipos enumerados
DO $$ BEGIN
  CREATE TYPE observation_source AS ENUM ('lab', 'clinician', 'context', 'fhir');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE observation_field AS ENUM (
    'plgf', 'uta_pi', 'sflt1_plgf_ratio',
    'sbp', 'dbp', 'bmi',
    'diabetes', 'chronic_hypertension'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE assessment_case_status AS ENUM ('pending_lab', 'ready', 'computed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Observações clínicas (imutáveis — nunca DELETE)
CREATE TABLE IF NOT EXISTS clinical_observations (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies(id) ON DELETE CASCADE,
  field             observation_field NOT NULL,
  value             numeric NOT NULL,
  unit              text,
  source            observation_source NOT NULL,
  gestational_week  int NOT NULL CHECK (gestational_week BETWEEN 4 AND 42),
  recorded_at       timestamptz NOT NULL DEFAULT now(),
  fhir_id           text,
  fhir_provenance   jsonb,
  loinc_code        text,
  manual_lab_entry  boolean NOT NULL DEFAULT false,
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clinical_obs_pregnancy
  ON clinical_observations (pregnancy_id, gestational_week DESC, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_clinical_obs_field
  ON clinical_observations (pregnancy_id, field, recorded_at DESC);

-- Episódios de avaliação (por gravidez + semana)
CREATE TABLE IF NOT EXISTS assessment_cases (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies(id) ON DELETE CASCADE,
  gestational_week  int NOT NULL CHECK (gestational_week BETWEEN 4 AND 42),
  status            assessment_case_status NOT NULL DEFAULT 'pending_lab',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assessment_cases_pregnancy
  ON assessment_cases (pregnancy_id, gestational_week);

-- Snapshots de risco (imutáveis — nunca UPDATE nos valores calculados)
ALTER TABLE assessments
  ADD COLUMN IF NOT EXISTS assessment_case_id uuid REFERENCES assessment_cases(id),
  ADD COLUMN IF NOT EXISTS features_used jsonb,
  ADD COLUMN IF NOT EXISTS missing_fields jsonb,
  ADD COLUMN IF NOT EXISTS triggered_by text CHECK (triggered_by IN (
    'clinician', 'lab_arrival', 'recalc_request', 'partial_auto'
  )),
  ADD COLUMN IF NOT EXISTS computed_at timestamptz DEFAULT now();

-- Aplicar imediatamente o endurecimento seguro por omissão de
-- 002_rls_clinical_tables.sql. A secret key do backend autentica como
-- service_role; o backend valida pertença antes de aceder a estas tabelas.
-- Clientes anon/authenticated não recebem
-- acesso direto.
