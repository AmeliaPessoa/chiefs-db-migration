-- P2 ETL · 01 — Carga integral das 48 tabelas da intelligence no schema intelligence
-- (vereditos 13/08: espelhos ficam de fora; as híbridas entram via 02-merge-main.sql)
-- Fonte: intel_src (postgres_fdw, read-only). Idempotente (TRUNCATE ... CASCADE).
\set ON_ERROR_STOP on
BEGIN;
TRUNCATE intelligence.alembic_version, intelligence.allocation_history, intelligence.allocation_history_shortlist, intelligence.attractiveness_snapshots, intelligence.backtest_jobs, intelligence.benchmark_market_cache, intelligence.benchmark_qa, intelligence.chief_career_history, intelligence.chief_contextual_qa, intelligence.chief_enrichment_history, intelligence.chief_improvement_event, intelligence.chief_laudo, intelligence.chief_laudo_modal_state, intelligence.chief_platform_history, intelligence.chief_rerank_cache, intelligence.chief_reverse_matches, intelligence.chief_reverse_profile, intelligence.chief_snapshot_before_op, intelligence.chief_stimulus_event, intelligence.deal_enrichment_jobs, intelligence.deal_enrichments, intelligence.deal_sales_ops, intelligence.governance_conflicts, intelligence.ingestion_logs, intelligence.iqp_snapshots, intelligence.jd_chief_alerts, intelligence.jd_chief_match_comments, intelligence.jd_chief_stages, intelligence.jd_list_quality, intelligence.mcp_query_log, intelligence.mql_candidates, intelligence.novo_funil_pipedrive, intelligence.pipedrive_write_log, intelligence.pipeline_runs, intelligence.platform_sync_state, intelligence.system_prompts, intelligence.ui_access_grant, intelligence.uploaded_files, intelligence.user_activity_log, intelligence.user_favorites, intelligence.users, intelligence.chief_embeddings, intelligence.chief_field_history, intelligence.job_descriptions, intelligence.job_embeddings, intelligence.jd_briefing_embeddings, intelligence.jd_extracted_metadata, intelligence.jd_results RESTART IDENTITY CASCADE;
INSERT INTO intelligence.alembic_version (version_num)
SELECT version_num FROM intel_src.alembic_version;
INSERT INTO intelligence.allocation_history (startup_ad_id, title, ad_status, chief_id, chief_selected_at, outcome_at, outcome_source, startup_id, company_id, ad_created_at, jd_chars, jd_degenerate, excluded, excluded_reason, snapshot_at, raw)
SELECT startup_ad_id, title, ad_status, chief_id, chief_selected_at, outcome_at, outcome_source, startup_id, company_id, ad_created_at, jd_chars, jd_degenerate, excluded, excluded_reason, snapshot_at, raw FROM intel_src.allocation_history;
INSERT INTO intelligence.allocation_history_shortlist (id, startup_ad_id, chief_id, stage, escolhido, chief_registered_at)
SELECT id, startup_ad_id, chief_id, stage, escolhido, chief_registered_at FROM intel_src.allocation_history_shortlist;
INSERT INTO intelligence.attractiveness_snapshots (id, snapshot_name, table_name, chief_id, attractiveness_score, attractiveness_classification, captured_at)
SELECT id, snapshot_name, table_name, chief_id, attractiveness_score, attractiveness_classification, captured_at FROM intel_src.attractiveness_snapshots;
INSERT INTO intelligence.backtest_jobs (id, job_id, status, created_by, input_data, result_data, error, created_at, updated_at)
SELECT id, job_id, status, created_by, input_data, result_data, error, created_at, updated_at FROM intel_src.backtest_jobs;
INSERT INTO intelligence.benchmark_market_cache (id, job_title_normalized, sectors_key, result_json, cached_at, expires_at)
SELECT id, job_title_normalized, sectors_key, result_json, cached_at, expires_at FROM intel_src.benchmark_market_cache;
INSERT INTO intelligence.benchmark_qa (id, chief_id, reviewed_by, reviewed_at, quality_score, notes, created_at)
SELECT id, chief_id, reviewed_by, reviewed_at, quality_score, notes, created_at FROM intel_src.benchmark_qa;
INSERT INTO intelligence.chief_career_history (id, chief_id, company, role, start_date, end_date, is_current, duration_months, source, raw_data, ingested_at)
SELECT id, chief_id, company, role, start_date, end_date, is_current, duration_months, source, raw_data, ingested_at FROM intel_src.chief_career_history;
INSERT INTO intelligence.chief_contextual_qa (id, chief_id, jd_id, pergunta, resposta, status, respondido_por, asked_at, answered_at, generation_batch_id, gaps_abordados, re_enriched)
SELECT id, chief_id, jd_id, pergunta, resposta, status, respondido_por, asked_at, answered_at, generation_batch_id, gaps_abordados, re_enriched FROM intel_src.chief_contextual_qa;
INSERT INTO intelligence.chief_enrichment_history (id, chief_id, table_name, field_name, old_value, new_value, old_source, new_source, actor, created_at)
SELECT id, chief_id, table_name, field_name, old_value, new_value, old_source, new_source, actor, created_at FROM intel_src.chief_enrichment_history;
INSERT INTO intelligence.chief_improvement_event (id, chief_id, source, source_ref, occurred_at, changed_fields, chief_age_days, payload, synced_at)
SELECT id, chief_id, source, source_ref, occurred_at, changed_fields, chief_age_days, payload, synced_at FROM intel_src.chief_improvement_event;
INSERT INTO intelligence.chief_laudo (id, chief_id, curriculo_id, status, laudo_json, score_geral, scores_internos, classificacao, prompt_version, error, requested_at, completed_at, cv_text, cv_blob_url, enriched_at, answers, answers_at, devolutiva, answers_enriched_at)
SELECT id, chief_id, curriculo_id, status, laudo_json, score_geral, scores_internos, classificacao, prompt_version, error, requested_at, completed_at, cv_text, cv_blob_url, enriched_at, answers, answers_at, devolutiva, answers_enriched_at FROM intel_src.chief_laudo;
INSERT INTO intelligence.chief_laudo_modal_state (chief_id, first_shown_at, last_shown_at, responded_at, dismissed_at, dismiss_count, updated_at)
SELECT chief_id, first_shown_at, last_shown_at, responded_at, dismissed_at, dismiss_count, updated_at FROM intel_src.chief_laudo_modal_state;
INSERT INTO intelligence.chief_platform_history (id, chief_id, event_type, source_event_id, occurred_at, startup_ad_id, startup_ad_match_id, vaga, stage, status, result, content, author, visible_to_chief, payload, synced_at)
SELECT id, chief_id, event_type, source_event_id, occurred_at, startup_ad_id, startup_ad_match_id, vaga, stage, status, result, content, author, visible_to_chief, payload, synced_at FROM intel_src.chief_platform_history;
INSERT INTO intelligence.chief_rerank_cache (id, chief_id, fact_key, fact_value, confidence, source_jd_ids, extracted_at, updated_at)
SELECT id, chief_id, fact_key, fact_value, confidence, source_jd_ids, extracted_at, updated_at FROM intel_src.chief_rerank_cache;
INSERT INTO intelligence.chief_reverse_matches (id, chief_id, jd_id, similarity, aderencia_atingida, batch_run_id, calculated_at)
SELECT id, chief_id, jd_id, similarity, aderencia_atingida, batch_run_id, calculated_at FROM intel_src.chief_reverse_matches;
INSERT INTO intelligence.chief_reverse_profile (id, chief_id, setor_ideal, porte_empresa_ideal, modelo_trabalho_ideal, faixa_remuneracao, tipo_desafio_ideal, momento_empresa_ideal, natureza_atuacao_ideal, icp_narrative, plano_interno_bp, plano_externo_chief, gaps_snapshot, model_version, prompt_version, generated_at, created_at, updated_at)
SELECT id, chief_id, setor_ideal, porte_empresa_ideal, modelo_trabalho_ideal, faixa_remuneracao, tipo_desafio_ideal, momento_empresa_ideal, natureza_atuacao_ideal, icp_narrative, plano_interno_bp, plano_externo_chief, gaps_snapshot, model_version, prompt_version, generated_at, created_at, updated_at FROM intel_src.chief_reverse_profile;
INSERT INTO intelligence.chief_snapshot_before_op (id, chief_id, operation, snapshot, actor, created_at)
SELECT id, chief_id, operation, snapshot, actor, created_at FROM intel_src.chief_snapshot_before_op;
INSERT INTO intelligence.chief_stimulus_event (id, chief_id, stimulus_type, stimulus_ref, channel, sent_at, payload, created_at)
SELECT id, chief_id, stimulus_type, stimulus_ref, channel, sent_at, payload, created_at FROM intel_src.chief_stimulus_event;
INSERT INTO intelligence.deal_enrichment_jobs (id, job_id, status, created_by, input_data, result_data, error, created_at, updated_at)
SELECT id, job_id, status, created_by, input_data, result_data, error, created_at, updated_at FROM intel_src.deal_enrichment_jobs;
INSERT INTO intelligence.deal_enrichments (id, deal_id, prospect_name, company, cargo, email, email_type, perplexity_raw, chiefs_matches, briefing_json, briefing_text, score_total, score_chief, score_seniority, score_multithread, score_email_quality, score_event_lead, score_engagement, score_company_size, tier, enrichment_source, enrichment_version, slack_message_ts, slack_channel_id, created_at, updated_at, is_active, grade_score, grade_band, has_whatsapp, has_chief_bridge, chief_bridge_names, contact_is_decisor, contact_count)
SELECT id, deal_id, prospect_name, company, cargo, email, email_type, perplexity_raw, chiefs_matches, briefing_json, briefing_text, score_total, score_chief, score_seniority, score_multithread, score_email_quality, score_event_lead, score_engagement, score_company_size, tier, enrichment_source, enrichment_version, slack_message_ts, slack_channel_id, created_at, updated_at, is_active, grade_score, grade_band, has_whatsapp, has_chief_bridge, chief_bridge_names, contact_is_decisor, contact_count FROM intel_src.deal_enrichments;
INSERT INTO intelligence.deal_sales_ops (id, deal_id, contact_name, contact_email, cargo, area, nivel, decisor_comercial, cargo_confianca, cargo_fonte, estagio, dias_sem_mov, atividades_count, notas_count, sub_segmento, bizdev_responsavel, chief_a_id, chief_a_nome, chief_a_motivo, chief_b_id, chief_b_nome, gancho, assunto, nba_text, source, version, is_active, created_at, updated_at, conta, flag_observacao, origem, utm_source, setor, dor_setor, contexto_desafio_cliente, chief_b_motivo, chief_a_sim, chief_b_sim, dor_nota_anonimizada)
SELECT id, deal_id, contact_name, contact_email, cargo, area, nivel, decisor_comercial, cargo_confianca, cargo_fonte, estagio, dias_sem_mov, atividades_count, notas_count, sub_segmento, bizdev_responsavel, chief_a_id, chief_a_nome, chief_a_motivo, chief_b_id, chief_b_nome, gancho, assunto, nba_text, source, version, is_active, created_at, updated_at, conta, flag_observacao, origem, utm_source, setor, dor_setor, contexto_desafio_cliente, chief_b_motivo, chief_a_sim, chief_b_sim, dor_nota_anonimizada FROM intel_src.deal_sales_ops;
INSERT INTO intelligence.governance_conflicts (id, chief_id, table_name, field_name, current_value, current_source, incoming_value, incoming_source, conflict_type, actor, detected_at)
SELECT id, chief_id, table_name, field_name, current_value, current_source, incoming_value, incoming_source, conflict_type, actor, detected_at FROM intel_src.governance_conflicts;
INSERT INTO intelligence.ingestion_logs (id, run_id, source_file, source_type, started_at, finished_at, records_processed, records_imported, records_updated, records_rejected, error_detail, status)
SELECT id, run_id, source_file, source_type, started_at, finished_at, records_processed, records_imported, records_updated, records_rejected, error_detail, status FROM intel_src.ingestion_logs;
INSERT INTO intelligence.iqp_snapshots (id, snapshot_name, table_name, chief_id, iqp_score, iqp_classification, captured_at)
SELECT id, snapshot_name, table_name, chief_id, iqp_score, iqp_classification, captured_at FROM intel_src.iqp_snapshots;
INSERT INTO intelligence.jd_chief_alerts (id, jd_id, chief_id, chief_name, estimated_iqt, threshold_iqt, created_at, resolved_at, resolved_by, resolution_run_id)
SELECT id, jd_id, chief_id, chief_name, estimated_iqt, threshold_iqt, created_at, resolved_at, resolved_by, resolution_run_id FROM intel_src.jd_chief_alerts;
INSERT INTO intelligence.jd_chief_match_comments (id, jd_id, run_id, chief_id, rails_comment_id, author_chief_id, author_name, content, visible_to_chief, commented_at, received_at)
SELECT id, jd_id, run_id, chief_id, rails_comment_id, author_chief_id, author_name, content, visible_to_chief, commented_at, received_at FROM intel_src.jd_chief_match_comments;
INSERT INTO intelligence.jd_chief_stages (id, jd_id, run_id, chief_id, chief_name, stage, source, moved_at, moved_by, triagem_notes, transcription_text, transcription_filename, elsa_output, matching_report, feedback_notes, chief_review_text, chief_review_video_url, client_decision, client_feedback, client_rating, client_stage, client_verdict_at, is_chosen, manual_add_reason, manual_add_reason_note, delivery_position, is_deprioritized, is_deprioritized_reason, manual_add_by, manual_add_at)
SELECT id, jd_id, run_id, chief_id, chief_name, stage, source, moved_at, moved_by, triagem_notes, transcription_text, transcription_filename, elsa_output, matching_report, feedback_notes, chief_review_text, chief_review_video_url, client_decision, client_feedback, client_rating, client_stage, client_verdict_at, is_chosen, manual_add_reason, manual_add_reason_note, delivery_position, is_deprioritized, is_deprioritized_reason, manual_add_by, manual_add_at FROM intel_src.jd_chief_stages;
INSERT INTO intelligence.jd_list_quality (id, job_description_id, pipeline_run_id, consultor_responsavel, n_chiefs, iqt_mean, iqt_median, iqt_p25, pct_apto, pct_parcial, delivery_top_n, computed_at)
SELECT id, job_description_id, pipeline_run_id, consultor_responsavel, n_chiefs, iqt_mean, iqt_median, iqt_p25, pct_apto, pct_parcial, delivery_top_n, computed_at FROM intel_src.jd_list_quality;
INSERT INTO intelligence.mcp_query_log (id, service_name, tool_name, user_email, access_level, input_summary, result_count, execution_ms, created_at)
SELECT id, service_name, tool_name, user_email, access_level, input_summary, result_count, execution_ms, created_at FROM intel_src.mcp_query_log;
INSERT INTO intelligence.mql_candidates (id, cnpj, org_name, person_name, person_email, person_phone, title, stage_novo, zona, tipo_origem, status, origem, email_status, cargo, area, nivel, decisor_comercial, decisor_motivo, setor, setor_confianca, dor_setor, custo_lead, custo_fonte, setor_driva, subsetor_driva, setor_fonte, cnae_secao, cnae_divisao, cnae_subclasse, faturamento, funcionarios, natureza_juridica, capital_social, uf, municipio, linkedin_empresa, person_linkedin, contato_rank, contato_primario, is_mql_completo, dados_pendentes, driva_snapshot, source, version, is_active, deal_id, created_at, updated_at, chief_sugerido_a, chief_sugerido_b, gancho_direto, gancho_exploratorio)
SELECT id, cnpj, org_name, person_name, person_email, person_phone, title, stage_novo, zona, tipo_origem, status, origem, email_status, cargo, area, nivel, decisor_comercial, decisor_motivo, setor, setor_confianca, dor_setor, custo_lead, custo_fonte, setor_driva, subsetor_driva, setor_fonte, cnae_secao, cnae_divisao, cnae_subclasse, faturamento, funcionarios, natureza_juridica, capital_social, uf, municipio, linkedin_empresa, person_linkedin, contato_rank, contato_primario, is_mql_completo, dados_pendentes, driva_snapshot, source, version, is_active, deal_id, created_at, updated_at, chief_sugerido_a, chief_sugerido_b, gancho_direto, gancho_exploratorio FROM intel_src.mql_candidates;
INSERT INTO intelligence.novo_funil_pipedrive (deal_id, title, status, pipeline_id, pipeline_name, stage_id, stage_name, value, weighted_value, currency, probability, owner_id, owner_name, org_id, org_name, person_name, person_email, person_phone, label_ids, source_name, lost_reason, activities_count, notes_count, files_count, expected_close_date, last_activity_date, next_activity_date, close_time, added_at, updated_at_remote, notes, files, synced_at, deleted_at, origem_oportunidade, utm_source, deal_snapshot, enriquecimento_snapshot, stage_novo, zona, tipo_origem, resultado, base_inferencia, dados_consolidados, dados_pendentes, analisado_em)
SELECT deal_id, title, status, pipeline_id, pipeline_name, stage_id, stage_name, value, weighted_value, currency, probability, owner_id, owner_name, org_id, org_name, person_name, person_email, person_phone, label_ids, source_name, lost_reason, activities_count, notes_count, files_count, expected_close_date, last_activity_date, next_activity_date, close_time, added_at, updated_at_remote, notes, files, synced_at, deleted_at, origem_oportunidade, utm_source, deal_snapshot, enriquecimento_snapshot, stage_novo, zona, tipo_origem, resultado, base_inferencia, dados_consolidados, dados_pendentes, analisado_em FROM intel_src.novo_funil_pipedrive;
INSERT INTO intelligence.pipedrive_write_log (id, deal_id, action, from_stage_id, to_stage_id, from_stage_name, to_stage_name, signal, note_preview, actor, status, created_at, undone_at, undone_by, payload)
SELECT id, deal_id, action, from_stage_id, to_stage_id, from_stage_name, to_stage_name, signal, note_preview, actor, status, created_at, undone_at, undone_by, payload FROM intel_src.pipedrive_write_log;
INSERT INTO intelligence.pipeline_runs (id, run_id, job_id, phase, version, status, input_data, output_data, model_version, token_count_input, token_count_output, execution_time_ms, triggered_by, created_at)
SELECT id, run_id, job_id, phase, version, status, input_data, output_data, model_version, token_count_input, token_count_output, execution_time_ms, triggered_by, created_at FROM intel_src.pipeline_runs;
INSERT INTO intelligence.platform_sync_state (key, last_sync_at, last_full_sync_at)
SELECT key, last_sync_at, last_full_sync_at FROM intel_src.platform_sync_state;
INSERT INTO intelligence.system_prompts (id, prompt_key, prompt_text, version, is_active, description, created_at, module_group, sort_order, input_type)
SELECT id, prompt_key, prompt_text, version, is_active, description, created_at, module_group, sort_order, input_type FROM intel_src.system_prompts;
INSERT INTO intelligence.ui_access_grant (email, display_name, role, is_active, added_by, added_at, updated_at)
SELECT email, display_name, role, is_active, added_by, added_at, updated_at FROM intel_src.ui_access_grant;
INSERT INTO intelligence.uploaded_files (id, filename, content_type, file_data, file_size, extracted_text, uploaded_at)
SELECT id, filename, content_type, file_data, file_size, extracted_text, uploaded_at FROM intel_src.uploaded_files;
INSERT INTO intelligence.user_activity_log (id, user_id, session_id, event_type, event_data, ip_address, user_agent, created_at)
SELECT id, user_id, session_id, event_type, event_data, ip_address, user_agent, created_at FROM intel_src.user_activity_log;
INSERT INTO intelligence.user_favorites (id, username, jd_id, created_at)
SELECT id, username, jd_id, created_at FROM intel_src.user_favorites;
INSERT INTO intelligence.users (id, username, hashed_password, scope, is_active, created_at)
SELECT id, username, hashed_password, scope, is_active, created_at FROM intel_src.users;
INSERT INTO intelligence.chief_embeddings (id, chief_id, field_name, embedding, model_version, content_hash, created_at, updated_at, chunk_index)
SELECT id, chief_id, field_name, embedding, model_version, content_hash, created_at, updated_at, chunk_index FROM intel_src.chief_embeddings;
INSERT INTO intelligence.chief_field_history (id, chief_id, field_name, old_value, new_value, source, source_file, changed_at, run_id)
SELECT id, chief_id, field_name, old_value, new_value, source, source_file, changed_at, run_id FROM intel_src.chief_field_history;
INSERT INTO intelligence.job_descriptions (id, title, jd_status, description, challenge, chief_profile, contract_conditions, requirements, responsibilities, benefits, culture, company_id, empresa_nome, raw_briefing, cargo_extraido, remuneracao_extraida, work_model_extraido, pipeline_status, pipeline_run_id, pipeline_error, pipeline_run_count, pipeline_started_at, pipeline_completed_at, consultor_responsavel, ingested_at, is_deleted, deleted_at, created_at, uploaded_file_id, is_favorited, raw_briefing_edited_by, raw_briefing_edited_at, raw_briefing_ai, jd_source, escopo_extraido, vaga_review_text, vaga_review_video_url, rails_vaga_id, rails_synced_hash, rails_synced_at, rails_viewer_company_ids, jd_variants, created_by)
SELECT id, title, jd_status, description, challenge, chief_profile, contract_conditions, requirements, responsibilities, benefits, culture, company_id, empresa_nome, raw_briefing, cargo_extraido, remuneracao_extraida, work_model_extraido, pipeline_status, pipeline_run_id, pipeline_error, pipeline_run_count, pipeline_started_at, pipeline_completed_at, consultor_responsavel, ingested_at, is_deleted, deleted_at, created_at, uploaded_file_id, is_favorited, raw_briefing_edited_by, raw_briefing_edited_at, raw_briefing_ai, jd_source, escopo_extraido, vaga_review_text, vaga_review_video_url, rails_vaga_id, rails_synced_hash, rails_synced_at, rails_viewer_company_ids, jd_variants, created_by FROM intel_src.job_descriptions;
INSERT INTO intelligence.job_embeddings (id, job_id, field_name, embedding, model_version, content_hash, created_at, updated_at)
SELECT id, job_id, field_name, embedding, model_version, content_hash, created_at, updated_at FROM intel_src.job_embeddings;
INSERT INTO intelligence.jd_briefing_embeddings (id, jd_id, field_name, embedding, model_version, content_hash, created_at, updated_at)
SELECT id, jd_id, field_name, embedding, model_version, content_hash, created_at, updated_at FROM intel_src.jd_briefing_embeddings;
INSERT INTO intelligence.jd_extracted_metadata (id, jd_id, cargo, senioridade, remuneracao, work_model, escopo, prazo, autonomia, modelo_contrato, empresa_nome, porte_empresa, momento_empresa, faturamento_empresa, localizacao_estado, localizacao_cidade, industrias_alvo, setores_alvo, hard_skills_requeridas, idiomas_requeridos, desafios_chave, experiencia_minima_anos, extraction_meta, extraction_status, prompt_version_used, model_version, extracted_at, edited_at, created_at, field_confidence)
SELECT id, jd_id, cargo, senioridade, remuneracao, work_model, escopo, prazo, autonomia, modelo_contrato, empresa_nome, porte_empresa, momento_empresa, faturamento_empresa, localizacao_estado, localizacao_cidade, industrias_alvo, setores_alvo, hard_skills_requeridas, idiomas_requeridos, desafios_chave, experiencia_minima_anos, extraction_meta, extraction_status, prompt_version_used, model_version, extracted_at, edited_at, created_at, field_confidence FROM intel_src.jd_extracted_metadata;
INSERT INTO intelligence.jd_results (id, job_description_id, pipeline_run_id, chief_id, chief_name, iqt_score, aderencia, outreach_subject, outreach_body, outreach_word_count, rank_position, search_origin, scored_at, is_deleted, deleted_at, t2_detail, t3_detail, scoring_method, manual_add_reason, manual_add_reason_note, shadow_rank, shadow_score, shadow_method)
SELECT id, job_description_id, pipeline_run_id, chief_id, chief_name, iqt_score, aderencia, outreach_subject, outreach_body, outreach_word_count, rank_position, search_origin, scored_at, is_deleted, deleted_at, t2_detail, t3_detail, scoring_method, manual_add_reason, manual_add_reason_note, shadow_rank, shadow_score, shadow_method FROM intel_src.jd_results;
-- reposiciona sequences (obrigatório após carga com ids explícitos)
SELECT setval('intelligence.allocation_history_shortlist_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.allocation_history_shortlist), 0) + 1, false);
SELECT setval('intelligence.attractiveness_snapshots_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.attractiveness_snapshots), 0) + 1, false);
SELECT setval('intelligence.backtest_jobs_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.backtest_jobs), 0) + 1, false);
SELECT setval('intelligence.benchmark_market_cache_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.benchmark_market_cache), 0) + 1, false);
SELECT setval('intelligence.benchmark_qa_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.benchmark_qa), 0) + 1, false);
SELECT setval('intelligence.chief_career_history_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_career_history), 0) + 1, false);
SELECT setval('intelligence.chief_contextual_qa_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_contextual_qa), 0) + 1, false);
SELECT setval('intelligence.chief_embeddings_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_embeddings), 0) + 1, false);
SELECT setval('intelligence.chief_enrichment_history_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_enrichment_history), 0) + 1, false);
SELECT setval('intelligence.chief_field_history_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_field_history), 0) + 1, false);
SELECT setval('intelligence.chief_improvement_event_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_improvement_event), 0) + 1, false);
SELECT setval('intelligence.chief_laudo_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_laudo), 0) + 1, false);
SELECT setval('intelligence.chief_platform_history_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_platform_history), 0) + 1, false);
SELECT setval('intelligence.chief_rerank_cache_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_rerank_cache), 0) + 1, false);
SELECT setval('intelligence.chief_reverse_matches_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_reverse_matches), 0) + 1, false);
SELECT setval('intelligence.chief_reverse_profile_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_reverse_profile), 0) + 1, false);
SELECT setval('intelligence.chief_snapshot_before_op_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_snapshot_before_op), 0) + 1, false);
SELECT setval('intelligence.chief_stimulus_event_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.chief_stimulus_event), 0) + 1, false);
SELECT setval('intelligence.deal_enrichment_jobs_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.deal_enrichment_jobs), 0) + 1, false);
SELECT setval('intelligence.deal_enrichments_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.deal_enrichments), 0) + 1, false);
SELECT setval('intelligence.deal_sales_ops_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.deal_sales_ops), 0) + 1, false);
SELECT setval('intelligence.governance_conflicts_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.governance_conflicts), 0) + 1, false);
SELECT setval('intelligence.ingestion_logs_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.ingestion_logs), 0) + 1, false);
SELECT setval('intelligence.iqp_snapshots_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.iqp_snapshots), 0) + 1, false);
SELECT setval('intelligence.jd_briefing_embeddings_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_briefing_embeddings), 0) + 1, false);
SELECT setval('intelligence.jd_chief_alerts_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_chief_alerts), 0) + 1, false);
SELECT setval('intelligence.jd_chief_match_comments_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_chief_match_comments), 0) + 1, false);
SELECT setval('intelligence.jd_chief_stages_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_chief_stages), 0) + 1, false);
SELECT setval('intelligence.jd_extracted_metadata_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_extracted_metadata), 0) + 1, false);
SELECT setval('intelligence.jd_list_quality_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_list_quality), 0) + 1, false);
SELECT setval('intelligence.jd_results_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.jd_results), 0) + 1, false);
SELECT setval('intelligence.job_descriptions_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.job_descriptions), 0) + 1, false);
SELECT setval('intelligence.job_embeddings_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.job_embeddings), 0) + 1, false);
SELECT setval('intelligence.mcp_query_log_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.mcp_query_log), 0) + 1, false);
SELECT setval('intelligence.mql_candidates_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.mql_candidates), 0) + 1, false);
SELECT setval('intelligence.pipedrive_write_log_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.pipedrive_write_log), 0) + 1, false);
SELECT setval('intelligence.pipeline_runs_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.pipeline_runs), 0) + 1, false);
SELECT setval('intelligence.system_prompts_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.system_prompts), 0) + 1, false);
SELECT setval('intelligence.uploaded_files_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.uploaded_files), 0) + 1, false);
SELECT setval('intelligence.user_activity_log_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.user_activity_log), 0) + 1, false);
SELECT setval('intelligence.user_favorites_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.user_favorites), 0) + 1, false);
SELECT setval('intelligence.users_id_seq', COALESCE((SELECT MAX(id) FROM intelligence.users), 0) + 1, false);
COMMIT;
