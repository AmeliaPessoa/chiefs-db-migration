--
-- P2 · DDL — enriquecimento das tabelas do MAIN (vereditos de 13/08, Renan)
-- Contraparte do ddl-intelligence-schema.sql: as tabelas híbridas não migram
-- inteiras; só as colunas abaixo entram no main via ALTER TABLE
-- (via de alteração confirmada pelo Renan em 18/08).
--
-- Este arquivo é só DDL (ADD COLUMN, idempotente via IF NOT EXISTS).
-- O UPDATE de merge (por id) é do ETL, com a regra fechada de 13/08:
--   · merge NUNCA sobrescreve o main — só preenche as colunas novas;
--   · chiefs: UPDATE por id; origem chiefs_ativos ∪ chiefs_todos,
--     em conflito vale SEMPRE chiefs_ativos;
--   · pipedrive_deals: UPDATE casando app.pipedrive_deals.pipedrive_id
--     = intelligence.pipedrive_deals.id (PKs diferentes);
--   · ids sem match: descartados no primeiro teste (decisão 18/08).
--
-- Se as tabelas do monolito ainda estiverem em `public` (pré-P1),
-- trocar o search_path abaixo.
--

SET search_path = app;

-- ============================================================
-- app.chiefs — +53 colunas de enriquecimento
-- (extras de chiefs_ativos vs. chiefs do main; chiefs_todos tem as mesmas
--  exceto attractiveness_score/attractiveness_classification)
-- Tipos copiados 1:1 do dump da intelligence (11/08).
-- ============================================================

ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS years_experience character varying;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS enrichment_status character varying(20) DEFAULT 'pending'::character varying;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS vectorization_status character varying(20) DEFAULT 'pending'::character varying;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS executive_competency character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS state_inferred character varying(10);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS state_inferred_confidence character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS english_level_inferred character varying(30);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS is_potential_apt_tier1 boolean;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS work_model_inferred character varying[];
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS profile_completeness_score numeric(5,2);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS regiao_influencia_secundaria character varying[];
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS "BP_verification_notes" text;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS enrichment_meta jsonb;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS enrichment_error text;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS enrichment_claimed_at timestamp with time zone;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS natureza_atuacao character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS prazo_disponivel character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS perfil_atuacao character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS stakeholder_mgmt character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS porte_empresa_ideal character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS momento_empresa_ideal character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS ferramentas_dominadas character varying[];
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS tolerancia_ambiguidade character varying(30);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS perfil_cultural character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS capacidade_mentoria character varying(30);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS iqp_score numeric(5,2);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS iqp_classification character varying(20);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS years_career_inferred integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS years_executive_inferred integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS sector_experience_detail jsonb;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS job_title_normalized character varying;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS resume_combined text;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS resume_experience_synthetic text;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS avatar_blob_key character varying;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS needs_re_enrichment boolean DEFAULT false;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS field_confidence jsonb;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS total_career_months integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS exec_level_months integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS unique_companies_count integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS current_roles_count integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS longest_tenure_months integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS avg_tenure_months integer;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS career_start_date date;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS linkedin_enriched_at timestamp with time zone;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS all_job_titles text[] DEFAULT '{}'::text[];
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS deletion_reason character varying(50);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS attractiveness_score double precision;
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS attractiveness_classification character varying(20);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS chair_inferred character varying(30);
ALTER TABLE chiefs ADD COLUMN IF NOT EXISTS registered_at timestamp with time zone;

-- ============================================================
-- app.pipedrive_deals — +4 colunas preservadas (veredito 13/08)
-- (as demais extras da intel — notes_count, files_count, synced_at —
--  NÃO são preservadas; notes_count é derivável de jsonb_array_length(notes))
-- ============================================================

ALTER TABLE pipedrive_deals ADD COLUMN IF NOT EXISTS notes jsonb DEFAULT '[]'::jsonb;
ALTER TABLE pipedrive_deals ADD COLUMN IF NOT EXISTS files jsonb DEFAULT '[]'::jsonb;
ALTER TABLE pipedrive_deals ADD COLUMN IF NOT EXISTS origem_oportunidade jsonb;
ALTER TABLE pipedrive_deals ADD COLUMN IF NOT EXISTS utm_source text;

RESET search_path;
