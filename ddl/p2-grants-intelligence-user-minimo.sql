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
--   3. Consultas de verificação no fim (esperado: SELECT table-level só nas
--      3 active_campaign_*, zero default ACL de app para intelligence_user,
--      53 UPDATE).
--
-- 24/09 (pedido do Renan, aceito pela Amelia): + SELECT table-level em
-- app.active_campaign_contacts / _campaigns / _contact_messages (22, 23 e 24
-- da allowlist). A migration 114 do Intelligence transformou
-- intelligence.ac_contacts / ac_campaigns / ac_contact_messages em views
-- (owner intelligence_user) sobre essas 3 tabelas; sem o grant o SELECT nas
-- views dá 42501. Tabela inteira: a única PII é o e-mail do contato, que a
-- ferramenta do MCP mascara, e o query_sql bloqueia as 3.
--
-- 13/10 (Renan, aplicado por ele em PROD e HML, registrado aqui para o
-- re-run não revogar): + SELECT table-level em app.page_views (25ª da
-- allowlist; métrica "acessos dos chiefs" do Intelligence, view nova em
-- intelligence.*) e + SELECT nas colunas role e approved_at de app.chiefs
-- (view intelligence.chief_engajamento, "Chief ativo"; sem elas 42501).
-- 15/10 (Renan): a view lê só chief_id, path, event_at, created_at → 17/10
-- page_views passa a SELECT por coluna (+ startup_id), fora user_agent e cookie
-- ids. 17/10: + view app.chief_status_versions (seção 26), sem SELECT em
-- app.versions.
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
-- chiefs: 99 colunas (views: ['chiefs_ativos', 'chiefs_platform', 'chiefs_todos'] + role/approved_at para intelligence.chief_engajamento, 13/10)
GRANT SELECT ("BP_verification_notes", all_job_titles, approved_at, attractiveness_classification, attractiveness_score, availability, availability_status, avatar_blob_key, avatar_url, avg_tenure_months, biggest_problems, biggest_team_responsibility, birth_at, business_model, business_moment, c_level_experience, capacidade_mentoria, career_start_date, chair, chair_inferred, city, comment, company, company_profiles, created_at, current_roles_count, deleted_at, deletion_reason, email, english_level, english_level_inferred, enrichment_claimed_at, enrichment_error, enrichment_meta, enrichment_status, exec_level_months, executive_competency, ferramentas_dominadas, field_confidence, gender, hard_skills, id, important_cases_connecting_customers, industries_experience, info_extracted, iqp_classification, iqp_score, is_deleted, is_potential_apt_tier1, job_title, job_title_normalized, linkedin, linkedin_enriched_at, longest_tenure_months, main_companies, mentorship_fee, momento_empresa_ideal, name, natureza_atuacao, needs_re_enrichment, others_language, perfil_atuacao, perfil_cultural, phone, porte_empresa_ideal, portuguese_level, prazo_disponivel, profile_completeness_score, profile_percentage, regiao_influencia_secundaria, registered_at, relevant_problems, resume_combined, resume_experience, resume_experience_synthetic, resume_project, role, salary, sector_experience_detail, sectors_experience, slug, spanish_level, stakeholder_mgmt, state, state_inferred, state_inferred_confidence, status, tags, tier, tolerancia_ambiguidade, total_career_months, unique_companies_count, updated_at, vectorization_status, work_model, work_model_inferred, years_career_inferred, years_executive_inferred, years_experience) ON app.chiefs TO intelligence_user;
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

-- 22–24 · ActiveCampaign (24/09): tabela inteira — views ac_* da migration 114
GRANT SELECT ON app.active_campaign_contacts,
                app.active_campaign_campaigns,
                app.active_campaign_contact_messages
  TO intelligence_user;

-- 25 · page_views (13/10 tabela inteira pelo Renan; 15/10 confirmado que a view
--      intelligence.chief_engajamento lê só chief_id, path, event_at, created_at
--      → por coluna desde 17/10, startup_id para uso futuro; sem user_agent/cookies)
GRANT SELECT (chief_id, startup_id, path, event_at, created_at) ON app.page_views TO intelligence_user;

-- 26 · chief_status_versions (view sem PII sobre app.versions/PaperTrail, owner
--      app_user — ddl/p3-view-chief-status-versions.sql; pedido Renan 15/10):
--      marcos de status do Chief para a rotina engajamento-refresh. Só a view;
--      NUNCA SELECT em app.versions (object_changes carrega PII).
GRANT SELECT ON app.chief_status_versions TO intelligence_user;

-- 27 · chief_ads (tabela de Oportunidades do Rails, 16 colunas; lida pela view
--      intelligence.chief_ads). Grant dado pela Chiefs em 15/10 nos 2 bancos e
--      DERRUBADO pelo re-run deste arquivo na HML em 17/10 (não estava aqui);
--      reaplicado pelo Renan em 19/10. Lição: todo grant novo entra aqui na
--      mesma volta.
GRANT SELECT ON app.chief_ads TO intelligence_user;

-- 28 · chief_versions_meta (2ª view sobre app.versions, só item_id/event/
--      created_at de item_type = 'Chief', sem object_changes/whodunnit — "o chief
--      salvou o perfil" mesmo sem mudar status; pedido opcional do Renan 19/10;
--      mesmo arquivo da 26).
GRANT SELECT ON app.chief_versions_meta TO intelligence_user;

-- UPDATE por coluna nas 53 colunas de enriquecimento (= p2-grants-enrichment-update.sql)
GRANT UPDATE ("BP_verification_notes", all_job_titles, attractiveness_classification, attractiveness_score, avatar_blob_key, avatar_url, avg_tenure_months, capacidade_mentoria, career_start_date, chair_inferred, current_roles_count, deleted_at, deletion_reason, english_level_inferred, enrichment_claimed_at, enrichment_error, enrichment_meta, enrichment_status, exec_level_months, executive_competency, ferramentas_dominadas, field_confidence, iqp_classification, iqp_score, is_deleted, is_potential_apt_tier1, job_title_normalized, linkedin_enriched_at, longest_tenure_months, momento_empresa_ideal, natureza_atuacao, needs_re_enrichment, perfil_atuacao, perfil_cultural, porte_empresa_ideal, prazo_disponivel, profile_completeness_score, regiao_influencia_secundaria, registered_at, resume_combined, resume_experience_synthetic, sector_experience_detail, stakeholder_mgmt, state_inferred, state_inferred_confidence, tolerancia_ambiguidade, total_career_months, unique_companies_count, vectorization_status, work_model_inferred, years_career_inferred, years_executive_inferred, years_experience) ON app.chiefs TO intelligence_user;
-- #911 FECHADO em 07/11 (cadastro ciclo 3, item 003): updated_at entra no UPDATE
-- (seção 29) — sem ele o INSERT do chief novo dá 500.

-- ============================================================
-- Cadastro do chief, ciclo 3 (Chiefs na fluffy 04–05/11/2026; e-mail do Renan
-- 07/11; arquivos ddl/app/001–008 no repo do Intelligence, 008 = UPDATE em
-- hard_skills, 06/11). Listas = ACL real da fluffy lida em 07/11
-- (rascunhos/leitura-cadastro-2026-11-07.sql), ajustada pelo retorno do Renan
-- de 10/11 (linkedin_* write-only; ticket_comments sem UPDATE). No PINK
-- só depois do release do Rails com a migration plataforma#416 (4 colunas novas
-- em app.chiefs: entry_source, vinculo, horas_semana_livres, a_partir_de) — a
-- seção 29 avisa e pula coluna que ainda não exista; re-rodar após o release.
-- ============================================================

-- 29 · app.chiefs (001/002/003/004): SELECT +12 colunas — entram na allowlist e
--      portanto na cópia aos agentes (seção 2a do p2-roles-agentes.sql), EXCETO
--      document (CPF: SELECT só para checar duplicidade no cadastro; §5.1).
--      linkedin_token/linkedin_expires são WRITE-ONLY (Renan 10/11: nenhuma
--      leitura no código) — ficam só em INSERT/UPDATE. INSERT em 14 colunas (fluxo de criação + 003:
--      created_at/updated_at NOT NULL sem default) e USAGE em chiefs_id_seq.
--      UPDATE +41 colunas (telas de perfil + 004 + 003 updated_at).
DO $$
DECLARE
  sel text[] := ARRAY['a_partir_de','contact_email','document','email_optin','entry_source','horas_semana_livres','picture_url','provider','terms_accepted','terms_accepted_at','uid','vinculo'];
  ins text[] := ARRAY['contact_email','created_at','email','entry_source','linkedin_expires','linkedin_token','name','picture_url','provider','role','slug','status','uid','updated_at'];
  upd text[] := ARRAY['a_partir_de','availability_status','biggest_problems','biggest_team_responsibility','birth_at','business_model','business_moment','c_level_experience','chair','city','company','company_profiles','contact_email','document','email_optin','entry_source','gender','hard_skills','horas_semana_livres','important_cases_connecting_customers','industries_experience','job_title','linkedin','linkedin_expires','linkedin_token','main_companies','phone','picture_url','profile_percentage','provider','relevant_problems','salary','sectors_experience','state','status','terms_accepted','terms_accepted_at','uid','updated_at','vinculo','work_model'];
  faltam text[] := '{}';
  lista text;
  r record;
BEGIN
  SELECT coalesce(array_agg(DISTINCT c), '{}') INTO faltam
    FROM unnest(sel || ins || upd) c
   WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema = 'app' AND table_name = 'chiefs' AND column_name = c);
  IF cardinality(faltam) > 0 THEN
    RAISE WARNING 'app.chiefs sem as colunas % (migration plataforma#416 ainda não aplicada?) — grants dessas colunas PULADOS; re-rodar depois do release do Rails', faltam;
  END IF;
  FOR r IN SELECT * FROM (VALUES ('SELECT', sel), ('INSERT', ins), ('UPDATE', upd)) v(priv, cols) LOOP
    SELECT string_agg(quote_ident(c), ', ' ORDER BY c) INTO lista FROM unnest(r.cols) c WHERE c <> ALL (faltam);
    IF lista IS NOT NULL THEN
      EXECUTE format('GRANT %s (%s) ON app.chiefs TO intelligence_user', r.priv, lista);
    END IF;
  END LOOP;
END $$;
GRANT USAGE ON SEQUENCE app.chiefs_id_seq TO intelligence_user;

-- 30 · app.legal_pages (005): Termos de Uso e Política de Privacidade dentro do
--      cadastro. Conteúdo público; copiado aos agentes pela 2a (sem problema).
GRANT SELECT (slug, title, content, updated_at) ON app.legal_pages TO intelligence_user;

-- 31 · app.chief_ads (007): INSERT dos serviços da etapa "oferta" do cadastro +
--      sequence. SELECT já na seção 27.
GRANT INSERT ON app.chief_ads TO intelligence_user;
GRANT USAGE ON SEQUENCE app.chief_ads_id_seq TO intelligence_user;

-- 32 · app.chief_accounts (006) — dados de recebimento PJ do chief (empresa,
--      CNPJ em holder_document, dados bancários), gravados pelo cadastro sem
--      Pagar.me (decisão do Renan 05/11). Tabela da lista PII/financeiro do
--      contrato. DECISÃO 09/11 (Amelia): por coluna; a seção roda só com
--      -v cadastro_pj=1, flag FIXA do re-run (HML e PINK). Desenho: por coluna (13 — sem external_id = id do
--      Pagar.me, sem transfer_interval/transfer_day/transfer_enabled =
--      configuração de repasse do financeiro), SELECT/INSERT/UPDATE sem DELETE,
--      USAGE na sequence; EXCLUÍDA da cópia aos agentes (2a) e da intelligence_ro.
--      Sem a variável esta seção é pulada e o REVOKE do topo derruba o SELECT
--      table-level que a Chiefs deu na fluffy (INSERT/UPDATE table-level ficam):
--      sempre rodar com a variável.
\if :{?cadastro_pj}
REVOKE ALL ON app.chief_accounts FROM intelligence_user;   -- zera o table-level da Chiefs
GRANT SELECT (id, chief_id, holder_name, bank, branch_number, branch_check_digit, account_number, account_check_digit, holder_type, holder_document, account_type, created_at, updated_at),
      INSERT (id, chief_id, holder_name, bank, branch_number, branch_check_digit, account_number, account_check_digit, holder_type, holder_document, account_type, created_at, updated_at),
      UPDATE (id, chief_id, holder_name, bank, branch_number, branch_check_digit, account_number, account_check_digit, holder_type, holder_document, account_type, created_at, updated_at)
   ON app.chief_accounts TO intelligence_user;
GRANT USAGE ON SEQUENCE app.chief_accounts_id_seq TO intelligence_user;
\else
\echo 'AVISO: seção 32 (app.chief_accounts) PULADA — faltou -v cadastro_pj=1 (flag fixa desde 09/11); o SELECT table-level foi revogado pelo topo'
\endif

-- 33 · app.tickets / app.ticket_comments — tela "Suporte" do cadastro novo
--      (issue #1308 do Intelligence; confirmado pelo Renan em 10/11, faltou no
--      e-mail de 07/11). Mínimo do código: tickets SELECT/INSERT/UPDATE (status,
--      admin_unread, chief_unread, updated_at); ticket_comments SELECT/INSERT
--      (sem UPDATE — a fluffy tinha, reduzido aqui); sem DELETE; USAGE nas 2
--      sequences. Table-level (sem PII além do chief_id). Excluídos da cópia
--      aos agentes (2a).
REVOKE ALL ON app.tickets, app.ticket_comments FROM intelligence_user;   -- zera o table-level da Chiefs (tinha UPDATE em ticket_comments)
GRANT SELECT, INSERT, UPDATE ON app.tickets TO intelligence_user;
GRANT SELECT, INSERT ON app.ticket_comments TO intelligence_user;
GRANT USAGE ON SEQUENCE app.tickets_id_seq, app.ticket_comments_id_seq TO intelligence_user;

COMMIT;

-- ============================================================
-- Verificação (evidência em evidencias/feedback-2026-09-22/)
-- ============================================================

-- 1. SELECT table-level em app: esperado 8 linhas (3 active_campaign_* + chief_ads + views chief_status_versions e chief_versions_meta + tickets + ticket_comments, seção 33)
--    (se sobrar outra, o grantor não é app_user — revogar como o grantor)
SELECT table_name, grantor
  FROM information_schema.role_table_grants
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND privilege_type = 'SELECT';

-- 2. Default privileges de app que ainda citam intelligence_user: esperado 0
SELECT pg_get_userbyid(d.defaclrole) AS criador, d.defaclobjtype, d.defaclacl
  FROM pg_default_acl d
 WHERE d.defaclnamespace = 'app'::regnamespace
   AND d.defaclacl::text LIKE '%intelligence_user=%';

-- 3. Tabelas de app com SELECT por coluna: esperado 32 relações / 496 colunas
--    (até 19/10: 28 / 448 = 21 da allowlist 342, page_views 5, chief_ads 16,
--    chief_status_versions 8, chief_versions_meta 3, + as 3 active_campaign_*
--    inteiras; ciclo 3 (07/11, ajuste 10/11): + chiefs 12, legal_pages 4,
--    tickets 13, ticket_comments 6, chief_accounts 13 [só com cadastro_pj; sem
--    ela 31 / 483]. PINK antes da migration #416: −4 colunas de chiefs → 492 / 479).
SELECT count(DISTINCT table_name) AS tabelas_com_select_coluna,
       count(*)                   AS colunas_com_select
  FROM information_schema.column_privileges
 WHERE grantee = 'intelligence_user' AND table_schema = 'app'
   AND privilege_type = 'SELECT';

-- 4. UPDATE em app.chiefs: esperado 94 (53 enriquecimento + 41 do ciclo 3; PINK antes da #416: 90)
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
       has_table_privilege('intelligence_user', 'app.chief_accounts', 'SELECT')      AS chief_accounts,   -- table-level f mesmo com a seção 32 (por coluna)
       has_column_privilege('intelligence_user', 'app.chief_accounts', 'external_id', 'SELECT') AS chief_accounts_external_id,
       has_table_privilege('intelligence_user', 'app.chief_accounts', 'DELETE')      AS chief_accounts_delete,
       has_column_privilege('intelligence_user', 'app.chiefs', 'linkedin_token', 'SELECT') AS chiefs_linkedin_token_select,   -- write-only (10/11)
       has_table_privilege('intelligence_user', 'app.ticket_comments', 'UPDATE')    AS ticket_comments_update,
       has_table_privilege('intelligence_user', 'app.credit_cards', 'SELECT')        AS credit_cards,
       has_table_privilege('intelligence_user', 'app.versions', 'SELECT') AS versions_tabela,
       has_table_privilege('intelligence_user', 'app.page_views', 'SELECT') AS page_views_tabela;
