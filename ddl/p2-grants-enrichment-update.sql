-- P2/P3 · GRANT UPDATE por coluna em app.chiefs para intelligence_user
-- (feedback Chiefs 08/09, item 1 — teste de cutover Variante D-2 em homolog)
--
-- O enrichment worker do Intelligence passa a gravar DIRETO em app.chiefs,
-- e só nas 53 colunas de enriquecimento adicionadas por ddl-main-enrichment.sql
-- (nenhuma coluna do Rails). A lista abaixo é gerada a partir daquele DDL —
-- idêntica à enviada pelo cliente em 08/09 (53 = 53, conferido).
-- avatar_blob_key/avatar_url ficam: são colunas de chiefs_ativos (origem
-- Intelligence), não do ETL.
--
-- Executar conectado como a credencial DEFAULT (membro de app_user, owner de
-- app.chiefs desde o item 6 de 10/09 — GRANT por membro do owner é permitido):
--   psql "$(heroku pg:credentials:url DATABASE_URL --name default -a <app> | grep -oE 'postgres://[^ ]+')" \
--        -v ON_ERROR_STOP=1 -f ddl/p2-grants-enrichment-update.sql
--
-- Nota: grant por coluna NÃO é coberto por ALTER DEFAULT PRIVILEGES — se o
-- enrichment ganhar coluna nova em app.chiefs, repetir o GRANT para ela.
-- Idempotente (GRANT repetido é no-op).

\set ON_ERROR_STOP on

GRANT UPDATE (
  all_job_titles,
  attractiveness_classification,
  attractiveness_score,
  avatar_blob_key,
  avatar_url,
  avg_tenure_months,
  "BP_verification_notes",
  capacidade_mentoria,
  career_start_date,
  chair_inferred,
  current_roles_count,
  deleted_at,
  deletion_reason,
  english_level_inferred,
  enrichment_claimed_at,
  enrichment_error,
  enrichment_meta,
  enrichment_status,
  exec_level_months,
  executive_competency,
  ferramentas_dominadas,
  field_confidence,
  iqp_classification,
  iqp_score,
  is_deleted,
  is_potential_apt_tier1,
  job_title_normalized,
  linkedin_enriched_at,
  longest_tenure_months,
  momento_empresa_ideal,
  natureza_atuacao,
  needs_re_enrichment,
  perfil_atuacao,
  perfil_cultural,
  porte_empresa_ideal,
  prazo_disponivel,
  profile_completeness_score,
  regiao_influencia_secundaria,
  registered_at,
  resume_combined,
  resume_experience_synthetic,
  sector_experience_detail,
  stakeholder_mgmt,
  state_inferred,
  state_inferred_confidence,
  tolerancia_ambiguidade,
  total_career_months,
  unique_companies_count,
  vectorization_status,
  work_model_inferred,
  years_career_inferred,
  years_executive_inferred,
  years_experience
) ON app.chiefs TO intelligence_user;

-- Verificação: espera-se 53 colunas com UPDATE e nenhuma fora da lista
SELECT count(*) AS colunas_com_update
  FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND table_name = 'chiefs' AND privilege_type = 'UPDATE';

SELECT column_name AS fora_da_lista_de_enriquecimento
  FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND table_name = 'chiefs' AND privilege_type = 'UPDATE'
   AND column_name NOT IN ('all_job_titles', 'attractiveness_classification', 'attractiveness_score', 'avatar_blob_key', 'avatar_url', 'avg_tenure_months', 'BP_verification_notes', 'capacidade_mentoria', 'career_start_date', 'chair_inferred', 'current_roles_count', 'deleted_at', 'deletion_reason', 'english_level_inferred', 'enrichment_claimed_at', 'enrichment_error', 'enrichment_meta', 'enrichment_status', 'exec_level_months', 'executive_competency', 'ferramentas_dominadas', 'field_confidence', 'iqp_classification', 'iqp_score', 'is_deleted', 'is_potential_apt_tier1', 'job_title_normalized', 'linkedin_enriched_at', 'longest_tenure_months', 'momento_empresa_ideal', 'natureza_atuacao', 'needs_re_enrichment', 'perfil_atuacao', 'perfil_cultural', 'porte_empresa_ideal', 'prazo_disponivel', 'profile_completeness_score', 'regiao_influencia_secundaria', 'registered_at', 'resume_combined', 'resume_experience_synthetic', 'sector_experience_detail', 'stakeholder_mgmt', 'state_inferred', 'state_inferred_confidence', 'tolerancia_ambiguidade', 'total_career_months', 'unique_companies_count', 'vectorization_status', 'work_model_inferred', 'years_career_inferred', 'years_executive_inferred', 'years_experience');
