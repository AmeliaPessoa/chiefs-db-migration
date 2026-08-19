-- P2 ETL · 02 — Merge das híbridas no MAIN (vereditos 13/08, Renan)
-- Pré-requisitos: 00-fdw-setup.sql aplicado (usa intel_src.chiefs_ativos,
-- intel_src.chiefs_todos, intel_src.pipedrive_deals) e ddl-main-enrichment.sql
-- aplicado no schema do main.
--
-- Regras fechadas:
--   · merge NUNCA sobrescreve colunas que já existiam no main — o UPDATE só
--     escreve as colunas novas (53 em chiefs, 4 em pipedrive_deals);
--   · chiefs: fonte = chiefs_ativos ∪ chiefs_todos; em conflito vale SEMPRE
--     chiefs_ativos (prio 1); UPDATE por id;
--   · pipedrive_deals: UPDATE casando main.pipedrive_id = intel.id;
--   · ids sem match: DESCARTADOS (decisão 18/08) — apenas contabilizados.
--
-- Idempotente (re-executar reaplica os mesmos valores). Transação única.
-- Uso: psql "<url>" -v app_schema=app -f 02-merge-main.sql
--      (validação local: -v app_schema=public)
\set ON_ERROR_STOP on
BEGIN;

-- ===== chiefs: enriquecimento (+53 colunas), ativos ∪ todos ==================
CREATE TEMP TABLE tmp_chiefs_fonte ON COMMIT DROP AS
SELECT 1::smallint AS prio, id, years_experience, enrichment_status, vectorization_status, is_deleted, deleted_at, executive_competency, state_inferred, state_inferred_confidence, english_level_inferred, is_potential_apt_tier1, work_model_inferred, profile_completeness_score, regiao_influencia_secundaria, "BP_verification_notes", enrichment_meta, enrichment_error, enrichment_claimed_at, natureza_atuacao, prazo_disponivel, perfil_atuacao, stakeholder_mgmt, porte_empresa_ideal, momento_empresa_ideal, ferramentas_dominadas, tolerancia_ambiguidade, perfil_cultural, capacidade_mentoria, iqp_score, iqp_classification, years_career_inferred, years_executive_inferred, sector_experience_detail, job_title_normalized, resume_combined, resume_experience_synthetic, avatar_blob_key, avatar_url, needs_re_enrichment, field_confidence, total_career_months, exec_level_months, unique_companies_count, current_roles_count, longest_tenure_months, avg_tenure_months, career_start_date, linkedin_enriched_at, all_job_titles, deletion_reason, attractiveness_score, attractiveness_classification, chair_inferred, registered_at
  FROM intel_src.chiefs_ativos
UNION ALL
SELECT 2::smallint AS prio, id, years_experience, enrichment_status, vectorization_status, is_deleted, deleted_at, executive_competency, state_inferred, state_inferred_confidence, english_level_inferred, is_potential_apt_tier1, work_model_inferred, profile_completeness_score, regiao_influencia_secundaria, "BP_verification_notes", enrichment_meta, enrichment_error, enrichment_claimed_at, natureza_atuacao, prazo_disponivel, perfil_atuacao, stakeholder_mgmt, porte_empresa_ideal, momento_empresa_ideal, ferramentas_dominadas, tolerancia_ambiguidade, perfil_cultural, capacidade_mentoria, iqp_score, iqp_classification, years_career_inferred, years_executive_inferred, sector_experience_detail, job_title_normalized, resume_combined, resume_experience_synthetic, avatar_blob_key, avatar_url, needs_re_enrichment, field_confidence, total_career_months, exec_level_months, unique_companies_count, current_roles_count, longest_tenure_months, avg_tenure_months, career_start_date, linkedin_enriched_at, all_job_titles, deletion_reason, NULL::double precision AS attractiveness_score, NULL::character varying(20) AS attractiveness_classification, chair_inferred, registered_at
  FROM intel_src.chiefs_todos;

-- id na intel é character varying; no main é bigint. Cast seguro: id
-- não-numérico vira NULL → sem match → descartado (decisão 18/08).
CREATE TEMP TABLE tmp_chiefs_dedup ON COMMIT DROP AS
SELECT DISTINCT ON (id) *,
       CASE WHEN id ~ '^[0-9]+$' THEN id::bigint END AS id_bigint
FROM tmp_chiefs_fonte ORDER BY id, prio;

UPDATE :"app_schema".chiefs c
SET years_experience = f.years_experience,
    enrichment_status = f.enrichment_status,
    vectorization_status = f.vectorization_status,
    is_deleted = f.is_deleted,
    deleted_at = f.deleted_at,
    executive_competency = f.executive_competency,
    state_inferred = f.state_inferred,
    state_inferred_confidence = f.state_inferred_confidence,
    english_level_inferred = f.english_level_inferred,
    is_potential_apt_tier1 = f.is_potential_apt_tier1,
    work_model_inferred = f.work_model_inferred,
    profile_completeness_score = f.profile_completeness_score,
    regiao_influencia_secundaria = f.regiao_influencia_secundaria,
    "BP_verification_notes" = f."BP_verification_notes",
    enrichment_meta = f.enrichment_meta,
    enrichment_error = f.enrichment_error,
    enrichment_claimed_at = f.enrichment_claimed_at,
    natureza_atuacao = f.natureza_atuacao,
    prazo_disponivel = f.prazo_disponivel,
    perfil_atuacao = f.perfil_atuacao,
    stakeholder_mgmt = f.stakeholder_mgmt,
    porte_empresa_ideal = f.porte_empresa_ideal,
    momento_empresa_ideal = f.momento_empresa_ideal,
    ferramentas_dominadas = f.ferramentas_dominadas,
    tolerancia_ambiguidade = f.tolerancia_ambiguidade,
    perfil_cultural = f.perfil_cultural,
    capacidade_mentoria = f.capacidade_mentoria,
    iqp_score = f.iqp_score,
    iqp_classification = f.iqp_classification,
    years_career_inferred = f.years_career_inferred,
    years_executive_inferred = f.years_executive_inferred,
    sector_experience_detail = f.sector_experience_detail,
    job_title_normalized = f.job_title_normalized,
    resume_combined = f.resume_combined,
    resume_experience_synthetic = f.resume_experience_synthetic,
    avatar_blob_key = f.avatar_blob_key,
    avatar_url = f.avatar_url,
    needs_re_enrichment = f.needs_re_enrichment,
    field_confidence = f.field_confidence,
    total_career_months = f.total_career_months,
    exec_level_months = f.exec_level_months,
    unique_companies_count = f.unique_companies_count,
    current_roles_count = f.current_roles_count,
    longest_tenure_months = f.longest_tenure_months,
    avg_tenure_months = f.avg_tenure_months,
    career_start_date = f.career_start_date,
    linkedin_enriched_at = f.linkedin_enriched_at,
    all_job_titles = f.all_job_titles,
    deletion_reason = f.deletion_reason,
    attractiveness_score = f.attractiveness_score,
    attractiveness_classification = f.attractiveness_classification,
    chair_inferred = f.chair_inferred,
    registered_at = f.registered_at
FROM tmp_chiefs_dedup f
WHERE c.id = f.id_bigint;

-- ===== pipedrive_deals: 4 colunas preservadas ================================
UPDATE :"app_schema".pipedrive_deals p
SET notes               = i.notes,
    files               = i.files,
    origem_oportunidade = i.origem_oportunidade,
    utm_source          = i.utm_source
FROM intel_src.pipedrive_deals i
WHERE p.pipedrive_id = i.id;

-- ===== relatório + validação =================================================
CREATE TEMP TABLE r(item text, origem bigint, destino bigint, ok text) ON COMMIT DROP;

-- contagens de match (sem-match = descartado por decisão de 18/08, não é erro)
INSERT INTO r
SELECT 'chiefs · ids na fonte (ativos ∪ todos)', count(*), NULL, '—' FROM tmp_chiefs_dedup;
INSERT INTO r
SELECT 'chiefs · com match (atualizados)',
       (SELECT count(*) FROM tmp_chiefs_dedup f JOIN :"app_schema".chiefs c ON c.id = f.id_bigint),
       (SELECT count(*) FROM tmp_chiefs_dedup f JOIN :"app_schema".chiefs c ON c.id = f.id_bigint), 'OK';
INSERT INTO r
SELECT 'chiefs · sem match (descartados)',
       (SELECT count(*) FROM tmp_chiefs_dedup f LEFT JOIN :"app_schema".chiefs c ON c.id = f.id_bigint WHERE c.id IS NULL),
       NULL, 'INFO';
INSERT INTO r
SELECT 'pipedrive_deals · ids na fonte', count(*), NULL, '—' FROM intel_src.pipedrive_deals;
INSERT INTO r
SELECT 'pipedrive_deals · com match (atualizados)',
       (SELECT count(*) FROM intel_src.pipedrive_deals i JOIN :"app_schema".pipedrive_deals p ON p.pipedrive_id = i.id),
       (SELECT count(*) FROM intel_src.pipedrive_deals i JOIN :"app_schema".pipedrive_deals p ON p.pipedrive_id = i.id), 'OK';
INSERT INTO r
SELECT 'pipedrive_deals · sem match (descartados)',
       (SELECT count(*) FROM intel_src.pipedrive_deals i LEFT JOIN :"app_schema".pipedrive_deals p ON p.pipedrive_id = i.id WHERE p.id IS NULL),
       NULL, 'INFO';

-- fidelidade: toda linha com match deve ter as colunas novas IDÊNTICAS à fonte
INSERT INTO r
SELECT 'chiefs · linhas com match divergentes da fonte',
       0,
       (SELECT count(*) FROM :"app_schema".chiefs c JOIN tmp_chiefs_dedup f ON c.id = f.id_bigint
         WHERE ROW(c.years_experience, c.enrichment_status, c.vectorization_status, c.is_deleted, c.deleted_at, c.executive_competency, c.state_inferred, c.state_inferred_confidence, c.english_level_inferred, c.is_potential_apt_tier1, c.work_model_inferred, c.profile_completeness_score, c.regiao_influencia_secundaria, c."BP_verification_notes", c.enrichment_meta, c.enrichment_error, c.enrichment_claimed_at, c.natureza_atuacao, c.prazo_disponivel, c.perfil_atuacao, c.stakeholder_mgmt, c.porte_empresa_ideal, c.momento_empresa_ideal, c.ferramentas_dominadas, c.tolerancia_ambiguidade, c.perfil_cultural, c.capacidade_mentoria, c.iqp_score, c.iqp_classification, c.years_career_inferred, c.years_executive_inferred, c.sector_experience_detail, c.job_title_normalized, c.resume_combined, c.resume_experience_synthetic, c.avatar_blob_key, c.avatar_url, c.needs_re_enrichment, c.field_confidence, c.total_career_months, c.exec_level_months, c.unique_companies_count, c.current_roles_count, c.longest_tenure_months, c.avg_tenure_months, c.career_start_date, c.linkedin_enriched_at, c.all_job_titles, c.deletion_reason, c.attractiveness_score, c.attractiveness_classification, c.chair_inferred, c.registered_at) IS DISTINCT FROM ROW(f.years_experience, f.enrichment_status, f.vectorization_status, f.is_deleted, f.deleted_at, f.executive_competency, f.state_inferred, f.state_inferred_confidence, f.english_level_inferred, f.is_potential_apt_tier1, f.work_model_inferred, f.profile_completeness_score, f.regiao_influencia_secundaria, f."BP_verification_notes", f.enrichment_meta, f.enrichment_error, f.enrichment_claimed_at, f.natureza_atuacao, f.prazo_disponivel, f.perfil_atuacao, f.stakeholder_mgmt, f.porte_empresa_ideal, f.momento_empresa_ideal, f.ferramentas_dominadas, f.tolerancia_ambiguidade, f.perfil_cultural, f.capacidade_mentoria, f.iqp_score, f.iqp_classification, f.years_career_inferred, f.years_executive_inferred, f.sector_experience_detail, f.job_title_normalized, f.resume_combined, f.resume_experience_synthetic, f.avatar_blob_key, f.avatar_url, f.needs_re_enrichment, f.field_confidence, f.total_career_months, f.exec_level_months, f.unique_companies_count, f.current_roles_count, f.longest_tenure_months, f.avg_tenure_months, f.career_start_date, f.linkedin_enriched_at, f.all_job_titles, f.deletion_reason, f.attractiveness_score, f.attractiveness_classification, f.chair_inferred, f.registered_at)),
       CASE WHEN (SELECT count(*) FROM :"app_schema".chiefs c JOIN tmp_chiefs_dedup f ON c.id = f.id_bigint
         WHERE ROW(c.years_experience, c.enrichment_status, c.vectorization_status, c.is_deleted, c.deleted_at, c.executive_competency, c.state_inferred, c.state_inferred_confidence, c.english_level_inferred, c.is_potential_apt_tier1, c.work_model_inferred, c.profile_completeness_score, c.regiao_influencia_secundaria, c."BP_verification_notes", c.enrichment_meta, c.enrichment_error, c.enrichment_claimed_at, c.natureza_atuacao, c.prazo_disponivel, c.perfil_atuacao, c.stakeholder_mgmt, c.porte_empresa_ideal, c.momento_empresa_ideal, c.ferramentas_dominadas, c.tolerancia_ambiguidade, c.perfil_cultural, c.capacidade_mentoria, c.iqp_score, c.iqp_classification, c.years_career_inferred, c.years_executive_inferred, c.sector_experience_detail, c.job_title_normalized, c.resume_combined, c.resume_experience_synthetic, c.avatar_blob_key, c.avatar_url, c.needs_re_enrichment, c.field_confidence, c.total_career_months, c.exec_level_months, c.unique_companies_count, c.current_roles_count, c.longest_tenure_months, c.avg_tenure_months, c.career_start_date, c.linkedin_enriched_at, c.all_job_titles, c.deletion_reason, c.attractiveness_score, c.attractiveness_classification, c.chair_inferred, c.registered_at) IS DISTINCT FROM ROW(f.years_experience, f.enrichment_status, f.vectorization_status, f.is_deleted, f.deleted_at, f.executive_competency, f.state_inferred, f.state_inferred_confidence, f.english_level_inferred, f.is_potential_apt_tier1, f.work_model_inferred, f.profile_completeness_score, f.regiao_influencia_secundaria, f."BP_verification_notes", f.enrichment_meta, f.enrichment_error, f.enrichment_claimed_at, f.natureza_atuacao, f.prazo_disponivel, f.perfil_atuacao, f.stakeholder_mgmt, f.porte_empresa_ideal, f.momento_empresa_ideal, f.ferramentas_dominadas, f.tolerancia_ambiguidade, f.perfil_cultural, f.capacidade_mentoria, f.iqp_score, f.iqp_classification, f.years_career_inferred, f.years_executive_inferred, f.sector_experience_detail, f.job_title_normalized, f.resume_combined, f.resume_experience_synthetic, f.avatar_blob_key, f.avatar_url, f.needs_re_enrichment, f.field_confidence, f.total_career_months, f.exec_level_months, f.unique_companies_count, f.current_roles_count, f.longest_tenure_months, f.avg_tenure_months, f.career_start_date, f.linkedin_enriched_at, f.all_job_titles, f.deletion_reason, f.attractiveness_score, f.attractiveness_classification, f.chair_inferred, f.registered_at)) = 0 THEN 'OK' ELSE 'DIVERGE' END;
INSERT INTO r
SELECT 'pipedrive_deals · linhas com match divergentes da fonte',
       0,
       (SELECT count(*) FROM :"app_schema".pipedrive_deals p JOIN intel_src.pipedrive_deals i ON p.pipedrive_id = i.id
         WHERE ROW(p.notes, p.files, p.origem_oportunidade, p.utm_source)
               IS DISTINCT FROM ROW(i.notes, i.files, i.origem_oportunidade, i.utm_source)),
       CASE WHEN (SELECT count(*) FROM :"app_schema".pipedrive_deals p JOIN intel_src.pipedrive_deals i ON p.pipedrive_id = i.id
         WHERE ROW(p.notes, p.files, p.origem_oportunidade, p.utm_source)
               IS DISTINCT FROM ROW(i.notes, i.files, i.origem_oportunidade, i.utm_source)) = 0
       THEN 'OK' ELSE 'DIVERGE' END;

SELECT * FROM r;
SELECT CASE WHEN EXISTS (SELECT 1 FROM r WHERE ok = 'DIVERGE')
       THEN 'MERGE: HÁ DIVERGÊNCIAS' ELSE 'MERGE: ZERO DIVERGÊNCIAS' END;

COMMIT;
