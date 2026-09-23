-- P2/P3 · SELECT mínimo (por coluna) do intelligence_user em app.* — fecha #912
--
-- Base: grants_intelligence_user.sql enviado pelo Renan em 22/09 (gerado no
-- HML via pg_depend das views de compat das migrations 107/108 +
-- role_column_grants). Troca o SELECT table-level nas 97 tabelas de app.*
-- (P1, seções 4 e 7.5) por SELECT por coluna só no que as views de compat
-- dependem (21 tabelas) e mantém o UPDATE nas 53 colunas de enriquecimento
-- (p2-grants-enrichment-update.sql).
--
-- Correções sobre o arquivo original (revisão Amelia, 23/09):
--   1. "BP_verification_notes" entre aspas (SELECT e UPDATE). Sem aspas o
--      Postgres converte para bp_verification_notes, a coluna não existe,
--      o GRANT falha e a transação inteira é desfeita (nada seria aplicado).
--   2. REVOKE também nos DEFAULT PRIVILEGES do P1 (seção 4): sem isso, a
--      próxima tabela criada por db:migrate (owner app_user) volta a nascer
--      com SELECT table-level para o intelligence_user e a sonda regride.
--   3. Consultas de verificação no fim (esperado: zero SELECT table-level,
--      zero default ACL de app para intelligence_user, 53 UPDATE).
--
-- Executar conectado como a credencial DEFAULT (membro de app_user, owner
-- de app.* desde o item 6 de 10/09 — o REVOKE é feito "como" o owner):
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql
--
-- Idempotente. Ordem no runbook: DEPOIS de p2-owner-app.sql e de
-- p2-grants-enrichment-update.sql (este arquivo o substitui/contém).
-- Grant por coluna NÃO é coberto por ALTER DEFAULT PRIVILEGES: coluna nova
-- que uma view de compat passar a usar exige GRANT novo aqui.

\set ON_ERROR_STOP on

BEGIN;

REVOKE SELECT ON ALL TABLES IN SCHEMA app FROM intelligence_user;
REVOKE SELECT ON ALL SEQUENCES IN SCHEMA app FROM intelligence_user;

-- Default privileges do P1 (seção 4): as duas variantes
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  REVOKE SELECT ON TABLES FROM intelligence_user;
ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA app
  REVOKE SELECT ON TABLES FROM intelligence_user;

-- ca_acquittances: 6 colunas (views: ['ca_acquittances'])
GRANT SELECT (conta_azul_id, conta_financeira_uuid, data_baixa, parcela_uuid, updated_at, valor) ON app.ca_acquittances TO intelligence_user;
-- ca_categories: 8 colunas (views: ['ca_categories'])
GRANT SELECT (categoria_pai, considera_custo_dre, conta_azul_id, entrada_dre, nome, tipo, updated_at, versao) ON app.ca_categories TO intelligence_user;
-- ca_contracts: 16 colunas (views: ['ca_contracts'])
GRANT SELECT (cliente_nome, cliente_uuid, conta_azul_id, data_alteracao, data_criacao, data_fim, data_inicio, numero, periodicidade, status, tipo_negociacao, updated_at, valor_recorrente, valor_total, vendedor_nome, vendedor_uuid) ON app.ca_contracts TO intelligence_user;
-- ca_cost_centers: 4 colunas (views: ['ca_cost_centers'])
GRANT SELECT (conta_azul_id, nome, status, updated_at) ON app.ca_cost_centers TO intelligence_user;
-- ca_dre_categories: 8 colunas (views: ['ca_dre_categories'])
GRANT SELECT (codigo, conta_azul_id, descricao, indica_totalizador, parent_uuid, posicao, representa_soma_custo_medio, updated_at) ON app.ca_dre_categories TO intelligence_user;
-- ca_dre_category_categorias: 3 colunas (views: ['ca_dre_categories'])
GRANT SELECT (categoria_uuid, dre_node_uuid, id) ON app.ca_dre_category_categorias TO intelligence_user;
-- ca_event_apportionments: 5 colunas (views: ['ca_financial_events'])
GRANT SELECT (evento_uuid, id, nome, target_uuid, tipo) ON app.ca_event_apportionments TO intelligence_user;
-- ca_financial_accounts: 8 colunas (views: ['ca_financial_accounts'])
GRANT SELECT (banco, conta_azul_id, nome, saldo_atual, saldo_atualizado_em, status, tipo, updated_at) ON app.ca_financial_accounts TO intelligence_user;
-- ca_financial_events: 13 colunas (views: ['ca_financial_events'])
GRANT SELECT (categoria_uuid, centro_custo_uuid, conta_azul_id, conta_financeira_uuid, data_competencia, data_vencimento, descricao, pessoa_uuid, raw_payload, status, tipo, updated_at, valor) ON app.ca_financial_events TO intelligence_user;
-- ca_financial_installments: 10 colunas (views: ['ca_financial_events', 'ca_sales'])
GRANT SELECT (data_pagamento, data_vencimento, descricao, evento_uuid, id, numero_parcela, status, valor, valor_pago, venda_uuid) ON app.ca_financial_installments TO intelligence_user;
-- ca_people: 17 colunas (views: ['ca_people'])
GRANT SELECT (ativo, conta_azul_id, documento, email, endereco_bairro, endereco_cep, endereco_cidade, endereco_estado, endereco_logradouro, endereco_numero, endereco_pais, nome, perfis, raw_payload, telefone, tipo_pessoa, updated_at) ON app.ca_people TO intelligence_user;
-- ca_sale_items: 11 colunas (views: ['ca_sales'])
GRANT SELECT (centro_custo_uuid, custo, descricao, id, id_item, nome, quantidade, tipo, total, valor, venda_uuid) ON app.ca_sale_items TO intelligence_user;
-- ca_sales: 30 colunas (views: ['ca_sales'])
GRANT SELECT (categoria_uuid, centro_custo_uuid, cliente_nome, cliente_uuid, conta_azul_id, contrato_uuid, data, data_alteracao, data_criacao, desconto, evento_financeiro_uuid, id_legado, natureza_operacao_label, natureza_operacao_uuid, numero, origem, raw_payload, situacao_descricao, situacao_nome, status, template_operacao, tipo_negociacao, tipo_operacao, total, updated_at, valor_bruto, valor_liquido, vendedor_nome, vendedor_uuid, versao) ON app.ca_sales TO intelligence_user;
-- ca_sellers: 6 colunas (views: ['ca_sellers'])
GRANT SELECT (conta_azul_id, documento, email, nome, status, updated_at) ON app.ca_sellers TO intelligence_user;
-- ca_service_invoices: 14 colunas (views: ['ca_service_invoices'])
GRANT SELECT (chave_acesso, cliente_nome, cliente_uuid, conta_azul_id, contrato_uuid, data_competencia, data_emissao, numero, numero_rps, status, tipo_negociacao, updated_at, valor_total, venda_uuid) ON app.ca_service_invoices TO intelligence_user;
-- chiefs: 97 colunas (views: ['chiefs_ativos', 'chiefs_platform', 'chiefs_todos'])
GRANT SELECT ("BP_verification_notes", all_job_titles, attractiveness_classification, attractiveness_score, availability, availability_status, avatar_blob_key, avatar_url, avg_tenure_months, biggest_problems, biggest_team_responsibility, birth_at, business_model, business_moment, c_level_experience, capacidade_mentoria, career_start_date, chair, chair_inferred, city, comment, company, company_profiles, created_at, current_roles_count, deleted_at, deletion_reason, email, english_level, english_level_inferred, enrichment_claimed_at, enrichment_error, enrichment_meta, enrichment_status, exec_level_months, executive_competency, ferramentas_dominadas, field_confidence, gender, hard_skills, id, important_cases_connecting_customers, industries_experience, info_extracted, iqp_classification, iqp_score, is_deleted, is_potential_apt_tier1, job_title, job_title_normalized, linkedin, linkedin_enriched_at, longest_tenure_months, main_companies, mentorship_fee, momento_empresa_ideal, name, natureza_atuacao, needs_re_enrichment, others_language, perfil_atuacao, perfil_cultural, phone, porte_empresa_ideal, portuguese_level, prazo_disponivel, profile_completeness_score, profile_percentage, regiao_influencia_secundaria, registered_at, relevant_problems, resume_combined, resume_experience, resume_experience_synthetic, resume_project, salary, sector_experience_detail, sectors_experience, slug, spanish_level, stakeholder_mgmt, state, state_inferred, state_inferred_confidence, status, tags, tier, tolerancia_ambiguidade, total_career_months, unique_companies_count, updated_at, vectorization_status, work_model, work_model_inferred, years_career_inferred, years_executive_inferred, years_experience) ON app.chiefs TO intelligence_user;
-- companies: 5 colunas (views: ['accounts'])
GRANT SELECT (created_at, id, name, startup_id, updated_at) ON app.companies TO intelligence_user;
-- pipedrive_deals: 35 colunas (views: ['deal_quality_scores', 'pipedrive_deals'])
GRANT SELECT (activities_count, added_at, close_time, currency, deleted_at, expected_close_date, files, label_ids, last_activity_date, lost_reason, next_activity_date, notes, org_id, org_name, origem_oportunidade, owner_id, owner_name, person_email, person_name, person_phone, pipedrive_id, pipeline_id, pipeline_name, probability, raw_payload, source_name, stage_id, stage_name, status, title, updated_at, updated_at_remote, utm_source, value, weighted_value) ON app.pipedrive_deals TO intelligence_user;
-- startup_ads: 11 colunas (views: ['accounts', 'companies'])
GRANT SELECT (city, company_id, created_at, expires_at, external_id, id, model_of_work, state, status, title, updated_at) ON app.startup_ads TO intelligence_user;
-- startup_companies: 2 colunas (views: ['accounts', 'companies'])
GRANT SELECT (company_id, startup_id) ON app.startup_companies TO intelligence_user;
-- startups: 31 colunas (views: ['companies'])
GRANT SELECT (city, cnpj, company_stage, contact_email, contact_job_title, contact_linkedin, contact_name, contact_phone, created_at, customers, description, email, founders, fulltime_team, fundation_year, id, investment_stage, linkedin, linkedin_founders, market, monetization, name, revenue, revenue_last_month, sector, service_type, site, slug, status, target, updated_at) ON app.startups TO intelligence_user;

-- UPDATE por coluna nas 53 colunas de enriquecimento (= p2-grants-enrichment-update.sql)
GRANT UPDATE ("BP_verification_notes", all_job_titles, attractiveness_classification, attractiveness_score, avatar_blob_key, avatar_url, avg_tenure_months, capacidade_mentoria, career_start_date, chair_inferred, current_roles_count, deleted_at, deletion_reason, english_level_inferred, enrichment_claimed_at, enrichment_error, enrichment_meta, enrichment_status, exec_level_months, executive_competency, ferramentas_dominadas, field_confidence, iqp_classification, iqp_score, is_deleted, is_potential_apt_tier1, job_title_normalized, linkedin_enriched_at, longest_tenure_months, momento_empresa_ideal, natureza_atuacao, needs_re_enrichment, perfil_atuacao, perfil_cultural, porte_empresa_ideal, prazo_disponivel, profile_completeness_score, regiao_influencia_secundaria, registered_at, resume_combined, resume_experience_synthetic, sector_experience_detail, stakeholder_mgmt, state_inferred, state_inferred_confidence, tolerancia_ambiguidade, total_career_months, unique_companies_count, vectorization_status, work_model_inferred, years_career_inferred, years_executive_inferred, years_experience) ON app.chiefs TO intelligence_user;
-- #911 (a decidir, cliente): updated_at fora da lista de UPDATE — começar restrito.
-- GRANT UPDATE (updated_at) ON app.chiefs TO intelligence_user;

COMMIT;

-- ============================================================
-- Verificação (evidência em evidencias/feedback-2026-09-22/)
-- ============================================================

-- 1. SELECT table-level em app: esperado 0 linhas
--    (se sobrar alguma, o grantor não é app_user — revogar como o grantor)
SELECT table_name, grantor
  FROM information_schema.role_table_grants
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND privilege_type = 'SELECT';

-- 2. Default privileges de app que ainda citam intelligence_user: esperado 0
SELECT pg_get_userbyid(d.defaclrole) AS criador, d.defaclobjtype, d.defaclacl
  FROM pg_default_acl d
 WHERE d.defaclnamespace = 'app'::regnamespace
   AND d.defaclacl::text LIKE '%intelligence_user=%';

-- 3. Tabelas de app com SELECT por coluna: esperado 21 tabelas
SELECT count(DISTINCT table_name) AS tabelas_com_select_coluna,
       count(*)                   AS colunas_com_select
  FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND privilege_type = 'SELECT';

-- 4. UPDATE em app.chiefs: esperado 53
SELECT count(*) AS colunas_com_update
  FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND table_name = 'chiefs' AND privilege_type = 'UPDATE';

-- 5. Amostra do que a sonda de segurança deve ver como negado: esperado tudo false
SELECT has_table_privilege('intelligence_user', 'app.schema_migrations', 'SELECT')    AS schema_migrations,
       has_table_privilege('intelligence_user', 'app.ar_internal_metadata', 'SELECT') AS ar_internal_metadata,
       -- não existe app.users no main: encrypted_password vive em chiefs, startups e chiefs_start
       has_column_privilege('intelligence_user', 'app.chiefs', 'encrypted_password', 'SELECT')   AS chiefs_encrypted_password,
       has_column_privilege('intelligence_user', 'app.startups', 'encrypted_password', 'SELECT') AS startups_encrypted_password,
       has_table_privilege('intelligence_user', 'app.chief_accounts', 'SELECT')      AS chief_accounts,
       has_table_privilege('intelligence_user', 'app.credit_cards', 'SELECT')        AS credit_cards;
