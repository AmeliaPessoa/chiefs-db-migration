-- P2 ETL · 00 — Conexão read-only com a intelligence via postgres_fdw
-- Vereditos 13/08: importa as 49 tabelas que migram (48 + chief_perfil_perguntas, 08/09) + as 3 fontes do merge
-- (chiefs_ativos, chiefs_todos, pipedrive_deals — usadas só pelo 02-merge-main.sql).
-- Uso: psql <main> -f 00-fdw-setup.sql \
--        -v src_host=... -v src_port=... -v src_db=... -v src_user=... -v src_pass=...
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
DROP SCHEMA IF EXISTS intel_src CASCADE;
DROP SERVER IF EXISTS intel_srv CASCADE;
CREATE SERVER intel_srv FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host :'src_host', port :'src_port', dbname :'src_db', fetch_size '10000');
CREATE USER MAPPING FOR CURRENT_USER SERVER intel_srv
  OPTIONS (user :'src_user', password :'src_pass');
CREATE SCHEMA intel_src;
IMPORT FOREIGN SCHEMA public LIMIT TO (alembic_version, allocation_history, allocation_history_shortlist, attractiveness_snapshots, backtest_jobs, benchmark_market_cache, benchmark_qa, chief_career_history, chief_contextual_qa, chief_embeddings, chief_enrichment_history, chief_field_history, chief_improvement_event, chief_laudo, chief_laudo_modal_state, chief_perfil_perguntas, chief_platform_history, chief_rerank_cache, chief_reverse_matches, chief_reverse_profile, chief_snapshot_before_op, chief_stimulus_event, chiefs_ativos, chiefs_todos, deal_enrichment_jobs, deal_enrichments, deal_sales_ops, governance_conflicts, ingestion_logs, iqp_snapshots, jd_briefing_embeddings, jd_chief_alerts, jd_chief_match_comments, jd_chief_stages, jd_extracted_metadata, jd_list_quality, jd_results, job_descriptions, job_embeddings, mcp_query_log, mql_candidates, novo_funil_pipedrive, pipedrive_deals, pipedrive_write_log, pipeline_runs, platform_sync_state, system_prompts, ui_access_grant, uploaded_files, user_activity_log, user_favorites, users)
  FROM SERVER intel_srv INTO intel_src;
