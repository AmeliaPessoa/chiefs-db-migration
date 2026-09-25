--
-- P2/P3 · DDL — schema `intelligence` no Postgres principal (49 tabelas + alembic_version)
-- Vereditos de 13/08 (Renan, doc "Feedback do Inventário & Janela P1",
-- recebido 18/08): espelho NÃO migra — só migra o que nasce no Intelligence.
--
-- FORA deste DDL (22 das 70 tabelas do dump):
--   · 11 ca_* e 3 ac_*  — re-syncáveis das APIs Conta Azul / ActiveCampaign
--   · accounts, companies, chiefs_platform — espelhos do main
--   · pipedrive_deals, chiefs_ativos, chiefs_todos — híbridas: as colunas
--     extras entram no MAIN via ALTER + UPDATE (DDL: ddl-main-enrichment.sql;
--     o UPDATE de merge é do ETL)
--   · mcp_refresh_tokens — tokens efêmeros; a tabela se auto-cria no startup da app
--   · chief_embeddings_bak_20260803 — backup operacional, descartado
--
-- A view deal_quality_scores é RECRIADA no fim do arquivo, repontada para
-- app.pipedrive_deals (id exposto = id do Pipedrive, como na intel;
-- notes_count derivado do jsonb `notes` adicionado pelo enrichment).
--
-- Gerado do dump-chiefs_intelligence-202608111618.sql (schema-only);
-- cortado para os vereditos em 18/08.
-- Inclui: 50 tabelas (49 + alembic_version), 44 sequences, defaults, constraints, índices (3 HNSW) e a view.
-- Nota (19/08): linhas "OWNER TO postgres" do pg_dump removidas — no Heroku
-- não há role postgres; o owner é quem executa o DDL (credencial default).
-- Nota (08/09): re-diff contra a origem viva (alembic 106_job_descriptions_outcome):
--   +tabela chief_perfil_perguntas (nasce no Intelligence → migra, 49ª);
--   +5 colunas em job_descriptions (is_test, outcome, outcome_chief_id,
--   outcome_note, outcome_at) e 2 índices parciais. O backup
--   chiefs_reenrich_backup_20260831 da origem é descartado (mesma regra do
--   chief_embeddings_bak). Owner final dos objetos: intelligence_user
--   (etl/05-owner-intelligence.sql / passo final do etl.py) — as migrations
--   Alembic do Intelligence fazem ALTER TABLE e exigem ownership.
-- Nota (25/09): re-diff contra a origem viva (alembic 114_ac_compat_views_shared_db,
--   feedback do Renan 24/09, item 6): +tabela jd_external_candidates (mig 112,
--   sem FK; PII de candidato: nome, e-mail, LinkedIn — migra, decisão Amelia
--   25/09) e +coluna job_descriptions.dados_base_extraidos jsonb (mig 111).
--   As views/funções de compatibilidade (chiefs_todos/chiefs_ativos,
--   pipedrive_deals, chiefs_platform, companies, accounts, ca_*, ac_*,
--   compat_csv_split/compat_strip_html) NÃO estão aqui de propósito: são
--   criadas pelas migrations 107–114 do Intelligence, que rodam no deploy
--   porque o etl.py semeia alembic_version em 106 (ALEMBIC_SEED_VERSION).
--   Nenhum desses nomes pode existir como TABELA antes do alembic upgrade
--   (a 107 pula a criação da view e a 108 renomeia para _legacy).
-- Pré-requisitos: extensão pgvector (vector 1536 + vector_cosine_ops);
-- a view exige app.pipedrive_deals já com as colunas de ddl-main-enrichment.sql.
--

CREATE SCHEMA IF NOT EXISTS intelligence;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE intelligence.alembic_version (
    version_num character varying(255) NOT NULL
);


CREATE TABLE intelligence.allocation_history (
    startup_ad_id bigint NOT NULL,
    title text NOT NULL,
    ad_status character varying(30),
    chief_id bigint,
    chief_selected_at timestamp with time zone,
    outcome_at timestamp with time zone,
    outcome_source character varying(20),
    startup_id bigint,
    company_id bigint,
    ad_created_at timestamp with time zone NOT NULL,
    jd_chars integer NOT NULL,
    jd_degenerate boolean DEFAULT false NOT NULL,
    excluded boolean DEFAULT false NOT NULL,
    excluded_reason character varying(30),
    snapshot_at timestamp with time zone NOT NULL,
    raw jsonb
);


CREATE TABLE intelligence.allocation_history_shortlist (
    id bigint NOT NULL,
    startup_ad_id bigint NOT NULL,
    chief_id bigint NOT NULL,
    stage character varying(30) NOT NULL,
    escolhido boolean DEFAULT false NOT NULL,
    chief_registered_at timestamp with time zone
);


CREATE SEQUENCE intelligence.allocation_history_shortlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.allocation_history_shortlist_id_seq OWNED BY intelligence.allocation_history_shortlist.id;

CREATE TABLE intelligence.attractiveness_snapshots (
    id bigint NOT NULL,
    snapshot_name character varying(100) NOT NULL,
    table_name character varying(50) NOT NULL,
    chief_id character varying NOT NULL,
    attractiveness_score double precision,
    attractiveness_classification character varying(20),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.attractiveness_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.attractiveness_snapshots_id_seq OWNED BY intelligence.attractiveness_snapshots.id;

CREATE TABLE intelligence.backtest_jobs (
    id bigint NOT NULL,
    job_id uuid NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    created_by text,
    input_data jsonb NOT NULL,
    result_data jsonb,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.backtest_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.backtest_jobs_id_seq OWNED BY intelligence.backtest_jobs.id;

CREATE TABLE intelligence.benchmark_market_cache (
    id bigint NOT NULL,
    job_title_normalized character varying(200) NOT NULL,
    sectors_key character varying(500) NOT NULL,
    result_json jsonb NOT NULL,
    cached_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone
);


CREATE SEQUENCE intelligence.benchmark_market_cache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.benchmark_market_cache_id_seq OWNED BY intelligence.benchmark_market_cache.id;

CREATE TABLE intelligence.benchmark_qa (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    reviewed_by character varying(100) NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL,
    quality_score character varying(20) NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT benchmark_qa_quality_score_check CHECK (((quality_score)::text = ANY ((ARRAY['approved'::character varying, 'needs_review'::character varying, 'rejected'::character varying])::text[])))
);


CREATE SEQUENCE intelligence.benchmark_qa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.benchmark_qa_id_seq OWNED BY intelligence.benchmark_qa.id;

CREATE TABLE intelligence.chief_career_history (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    company character varying NOT NULL,
    role character varying NOT NULL,
    start_date date,
    end_date date,
    is_current boolean DEFAULT false NOT NULL,
    duration_months integer,
    source character varying(50) DEFAULT 'linkedin'::character varying NOT NULL,
    raw_data jsonb,
    ingested_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.chief_career_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_career_history_id_seq OWNED BY intelligence.chief_career_history.id;

CREATE TABLE intelligence.chief_contextual_qa (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    jd_id bigint NOT NULL,
    pergunta text NOT NULL,
    resposta text,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    respondido_por character varying(100),
    asked_at timestamp with time zone DEFAULT now() NOT NULL,
    answered_at timestamp with time zone,
    generation_batch_id character varying(36),
    gaps_abordados character varying[],
    re_enriched boolean DEFAULT false NOT NULL
);


CREATE SEQUENCE intelligence.chief_contextual_qa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_contextual_qa_id_seq OWNED BY intelligence.chief_contextual_qa.id;

CREATE TABLE intelligence.chief_embeddings (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    field_name character varying(100) NOT NULL,
    embedding public.vector(1536) NOT NULL,
    model_version character varying(100) NOT NULL,
    content_hash character varying(32),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    chunk_index integer DEFAULT 0 NOT NULL
);


CREATE SEQUENCE intelligence.chief_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_embeddings_id_seq OWNED BY intelligence.chief_embeddings.id;

CREATE TABLE intelligence.chief_enrichment_history (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    table_name character varying(50) NOT NULL,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    old_source character varying(50),
    new_source character varying(50) NOT NULL,
    actor character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_enrichment_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_enrichment_history_id_seq OWNED BY intelligence.chief_enrichment_history.id;

CREATE TABLE intelligence.chief_field_history (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    field_name character varying(100) NOT NULL,
    old_value text,
    new_value text,
    source character varying(20) NOT NULL,
    source_file character varying(500),
    changed_at timestamp with time zone DEFAULT now(),
    run_id character varying(36) NOT NULL
);


CREATE SEQUENCE intelligence.chief_field_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_field_history_id_seq OWNED BY intelligence.chief_field_history.id;

CREATE TABLE intelligence.chief_improvement_event (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    source character varying(20) NOT NULL,
    source_ref character varying NOT NULL,
    occurred_at timestamp with time zone,
    changed_fields text[],
    chief_age_days integer,
    payload jsonb,
    synced_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_improvement_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_improvement_event_id_seq OWNED BY intelligence.chief_improvement_event.id;

CREATE TABLE intelligence.chief_laudo (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    curriculo_id character varying NOT NULL,
    status character varying(20) DEFAULT 'processing'::character varying NOT NULL,
    laudo_json jsonb,
    score_geral numeric(3,1),
    scores_internos jsonb,
    classificacao character varying,
    prompt_version character varying,
    error text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    cv_text text,
    cv_blob_url text,
    enriched_at timestamp with time zone,
    answers jsonb,
    answers_at timestamp with time zone,
    devolutiva text,
    answers_enriched_at timestamp with time zone,
    CONSTRAINT chief_laudo_status_check CHECK (((status)::text = ANY ((ARRAY['processing'::character varying, 'ready'::character varying, 'failed'::character varying])::text[])))
);


CREATE SEQUENCE intelligence.chief_laudo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_laudo_id_seq OWNED BY intelligence.chief_laudo.id;

CREATE TABLE intelligence.chief_laudo_modal_state (
    chief_id character varying NOT NULL,
    first_shown_at timestamp with time zone,
    last_shown_at timestamp with time zone,
    responded_at timestamp with time zone,
    dismissed_at timestamp with time zone,
    dismiss_count integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE TABLE intelligence.chief_perfil_perguntas (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    perguntas jsonb NOT NULL,
    answers jsonb,
    answers_at timestamp with time zone,
    answers_enriched_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_perfil_perguntas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_perfil_perguntas_id_seq OWNED BY intelligence.chief_perfil_perguntas.id;


CREATE TABLE intelligence.chief_platform_history (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    event_type character varying(40) NOT NULL,
    source_event_id bigint NOT NULL,
    occurred_at timestamp with time zone,
    startup_ad_id bigint,
    startup_ad_match_id bigint,
    vaga character varying,
    stage character varying(50),
    status character varying(50),
    result character varying(30),
    content text,
    author character varying,
    visible_to_chief boolean,
    payload jsonb,
    synced_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_platform_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_platform_history_id_seq OWNED BY intelligence.chief_platform_history.id;

CREATE TABLE intelligence.chief_rerank_cache (
    id integer NOT NULL,
    chief_id character varying NOT NULL,
    fact_key character varying(100) NOT NULL,
    fact_value text NOT NULL,
    confidence double precision DEFAULT '0.8'::double precision NOT NULL,
    source_jd_ids integer[] DEFAULT '{}'::integer[],
    extracted_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.chief_rerank_cache_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_rerank_cache_id_seq OWNED BY intelligence.chief_rerank_cache.id;

CREATE TABLE intelligence.chief_reverse_matches (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    jd_id bigint NOT NULL,
    similarity double precision NOT NULL,
    aderencia_atingida boolean NOT NULL,
    batch_run_id character varying(36) NOT NULL,
    calculated_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_reverse_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_reverse_matches_id_seq OWNED BY intelligence.chief_reverse_matches.id;

CREATE TABLE intelligence.chief_reverse_profile (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    setor_ideal character varying[],
    porte_empresa_ideal text,
    modelo_trabalho_ideal text,
    faixa_remuneracao character varying,
    tipo_desafio_ideal character varying,
    momento_empresa_ideal text,
    natureza_atuacao_ideal text,
    icp_narrative text,
    plano_interno_bp text,
    plano_externo_chief text,
    gaps_snapshot jsonb,
    model_version character varying(50),
    prompt_version integer,
    generated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


CREATE SEQUENCE intelligence.chief_reverse_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_reverse_profile_id_seq OWNED BY intelligence.chief_reverse_profile.id;

CREATE TABLE intelligence.chief_snapshot_before_op (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    operation character varying(50) NOT NULL,
    snapshot jsonb NOT NULL,
    actor character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_snapshot_before_op_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_snapshot_before_op_id_seq OWNED BY intelligence.chief_snapshot_before_op.id;

CREATE TABLE intelligence.chief_stimulus_event (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    stimulus_type character varying(20) NOT NULL,
    stimulus_ref character varying NOT NULL,
    channel character varying(20),
    sent_at timestamp with time zone NOT NULL,
    payload jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.chief_stimulus_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.chief_stimulus_event_id_seq OWNED BY intelligence.chief_stimulus_event.id;

CREATE TABLE intelligence.deal_enrichment_jobs (
    id bigint NOT NULL,
    job_id uuid NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    created_by text,
    input_data jsonb NOT NULL,
    result_data jsonb,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.deal_enrichment_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.deal_enrichment_jobs_id_seq OWNED BY intelligence.deal_enrichment_jobs.id;

CREATE TABLE intelligence.deal_enrichments (
    id integer NOT NULL,
    deal_id bigint NOT NULL,
    prospect_name text NOT NULL,
    company text NOT NULL,
    cargo text,
    email text,
    email_type character varying(20),
    perplexity_raw jsonb,
    chiefs_matches jsonb,
    briefing_json jsonb,
    briefing_text text,
    score_total integer DEFAULT 0,
    score_chief integer DEFAULT 0,
    score_seniority integer DEFAULT 0,
    score_multithread integer DEFAULT 0,
    score_email_quality integer DEFAULT 0,
    score_event_lead integer DEFAULT 0,
    score_engagement integer DEFAULT 0,
    score_company_size integer DEFAULT 0,
    tier character varying(1),
    enrichment_source character varying(50) DEFAULT 'n8n_pipeline'::character varying,
    enrichment_version integer DEFAULT 1,
    slack_message_ts text,
    slack_channel_id text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    grade_score integer,
    grade_band text,
    has_whatsapp boolean,
    has_chief_bridge boolean,
    chief_bridge_names text[],
    contact_is_decisor boolean,
    contact_count integer
);


CREATE SEQUENCE intelligence.deal_enrichments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.deal_enrichments_id_seq OWNED BY intelligence.deal_enrichments.id;

CREATE TABLE intelligence.deal_sales_ops (
    id integer NOT NULL,
    deal_id bigint NOT NULL,
    contact_name text,
    contact_email text,
    cargo text,
    area character varying(40),
    nivel character varying(30),
    decisor_comercial character varying(10),
    cargo_confianca character varying(15),
    cargo_fonte text,
    estagio text,
    dias_sem_mov integer,
    atividades_count integer,
    notas_count integer,
    sub_segmento text,
    bizdev_responsavel text,
    chief_a_id bigint,
    chief_a_nome text,
    chief_a_motivo text,
    chief_b_id bigint,
    chief_b_nome text,
    gancho text,
    assunto text,
    nba_text text,
    source character varying(50) DEFAULT 'n8n_pipeline'::character varying,
    version integer DEFAULT 1,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    conta text,
    flag_observacao text,
    origem text,
    utm_source text,
    setor text,
    dor_setor text,
    contexto_desafio_cliente text,
    chief_b_motivo text,
    chief_a_sim double precision,
    chief_b_sim double precision,
    dor_nota_anonimizada text
);


CREATE SEQUENCE intelligence.deal_sales_ops_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.deal_sales_ops_id_seq OWNED BY intelligence.deal_sales_ops.id;

CREATE TABLE intelligence.governance_conflicts (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    table_name character varying(50) DEFAULT 'chiefs_ativos'::character varying NOT NULL,
    field_name character varying(100),
    current_value text,
    current_source character varying(50),
    incoming_value text,
    incoming_source character varying(50),
    conflict_type character varying(50) NOT NULL,
    actor character varying(100) NOT NULL,
    detected_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.governance_conflicts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.governance_conflicts_id_seq OWNED BY intelligence.governance_conflicts.id;

CREATE TABLE intelligence.ingestion_logs (
    id bigint NOT NULL,
    run_id character varying(36) NOT NULL,
    source_file character varying(500) NOT NULL,
    source_type character varying(20) NOT NULL,
    started_at timestamp with time zone NOT NULL,
    finished_at timestamp with time zone,
    records_processed bigint DEFAULT '0'::bigint,
    records_imported bigint DEFAULT '0'::bigint,
    records_updated bigint DEFAULT '0'::bigint,
    records_rejected bigint DEFAULT '0'::bigint,
    error_detail jsonb,
    status character varying(20) DEFAULT 'running'::character varying
);


CREATE SEQUENCE intelligence.ingestion_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.ingestion_logs_id_seq OWNED BY intelligence.ingestion_logs.id;

CREATE TABLE intelligence.iqp_snapshots (
    id bigint NOT NULL,
    snapshot_name character varying(100) NOT NULL,
    table_name character varying(50) NOT NULL,
    chief_id character varying NOT NULL,
    iqp_score numeric(5,2),
    iqp_classification character varying(20),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.iqp_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.iqp_snapshots_id_seq OWNED BY intelligence.iqp_snapshots.id;

CREATE TABLE intelligence.jd_briefing_embeddings (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    field_name character varying(50) DEFAULT 'raw_briefing'::character varying NOT NULL,
    embedding public.vector(1536) NOT NULL,
    model_version character varying(100) NOT NULL,
    content_hash character varying(32),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


CREATE SEQUENCE intelligence.jd_briefing_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_briefing_embeddings_id_seq OWNED BY intelligence.jd_briefing_embeddings.id;

CREATE TABLE intelligence.jd_chief_alerts (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    chief_id character varying NOT NULL,
    chief_name character varying,
    estimated_iqt double precision,
    threshold_iqt double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by character varying(100),
    resolution_run_id character varying(36)
);


CREATE SEQUENCE intelligence.jd_chief_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_chief_alerts_id_seq OWNED BY intelligence.jd_chief_alerts.id;

CREATE TABLE intelligence.jd_chief_match_comments (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    run_id character varying(36) NOT NULL,
    chief_id character varying NOT NULL,
    rails_comment_id bigint NOT NULL,
    author_chief_id bigint,
    author_name character varying,
    content text NOT NULL,
    visible_to_chief boolean DEFAULT false NOT NULL,
    commented_at timestamp with time zone,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.jd_chief_match_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_chief_match_comments_id_seq OWNED BY intelligence.jd_chief_match_comments.id;

CREATE TABLE intelligence.jd_chief_stages (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    run_id character varying(36) NOT NULL,
    chief_id character varying NOT NULL,
    chief_name character varying,
    stage character varying(50) NOT NULL,
    source character varying(20) DEFAULT '''pipeline'''::character varying NOT NULL,
    moved_at timestamp with time zone DEFAULT now() NOT NULL,
    moved_by character varying(100),
    triagem_notes text,
    transcription_text text,
    transcription_filename character varying(255),
    elsa_output text,
    matching_report text,
    feedback_notes text,
    chief_review_text text,
    chief_review_video_url text,
    client_decision text,
    client_feedback text,
    client_rating integer,
    client_stage text,
    client_verdict_at timestamp with time zone,
    is_chosen boolean DEFAULT false NOT NULL,
    manual_add_reason character varying(30),
    manual_add_reason_note text,
    delivery_position integer,
    is_deprioritized boolean DEFAULT false NOT NULL,
    is_deprioritized_reason text,
    manual_add_by character varying(100),
    manual_add_at timestamp with time zone
);


CREATE SEQUENCE intelligence.jd_chief_stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_chief_stages_id_seq OWNED BY intelligence.jd_chief_stages.id;

CREATE TABLE intelligence.jd_external_candidates (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    candidate_name text NOT NULL,
    candidate_email text NOT NULL,
    candidate_linkedin text,
    added_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    removed_by text,
    removal_reason text
);


CREATE SEQUENCE intelligence.jd_external_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_external_candidates_id_seq OWNED BY intelligence.jd_external_candidates.id;

CREATE TABLE intelligence.jd_extracted_metadata (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    cargo character varying,
    senioridade character varying(50),
    remuneracao character varying,
    work_model character varying(50),
    escopo text,
    prazo character varying(100),
    autonomia character varying(100),
    modelo_contrato character varying(50),
    empresa_nome character varying,
    porte_empresa character varying(50),
    momento_empresa character varying(50),
    faturamento_empresa character varying,
    localizacao_estado character varying(10),
    localizacao_cidade character varying,
    industrias_alvo character varying[],
    setores_alvo character varying[],
    hard_skills_requeridas character varying[],
    idiomas_requeridos character varying[],
    desafios_chave character varying[],
    experiencia_minima_anos integer,
    extraction_meta jsonb,
    extraction_status character varying(20) DEFAULT 'pending'::character varying,
    prompt_version_used integer,
    model_version character varying(50),
    extracted_at timestamp with time zone,
    edited_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    field_confidence jsonb DEFAULT '{}'::jsonb NOT NULL
);


CREATE SEQUENCE intelligence.jd_extracted_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_extracted_metadata_id_seq OWNED BY intelligence.jd_extracted_metadata.id;

CREATE TABLE intelligence.jd_list_quality (
    id bigint NOT NULL,
    job_description_id bigint NOT NULL,
    pipeline_run_id character varying(36) NOT NULL,
    consultor_responsavel text,
    n_chiefs integer DEFAULT 0 NOT NULL,
    iqt_mean double precision,
    iqt_median double precision,
    iqt_p25 double precision,
    pct_apto double precision DEFAULT 0 NOT NULL,
    pct_parcial double precision DEFAULT 0 NOT NULL,
    delivery_top_n integer DEFAULT 20 NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.jd_list_quality_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_list_quality_id_seq OWNED BY intelligence.jd_list_quality.id;

CREATE TABLE intelligence.jd_results (
    id bigint NOT NULL,
    job_description_id bigint NOT NULL,
    pipeline_run_id character varying(36) NOT NULL,
    chief_id character varying NOT NULL,
    chief_name character varying,
    iqt_score double precision,
    aderencia character varying(20),
    outreach_subject text,
    outreach_body text,
    outreach_word_count integer,
    rank_position integer NOT NULL,
    search_origin character varying(20),
    scored_at timestamp with time zone DEFAULT now(),
    is_deleted boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    t2_detail jsonb,
    t3_detail jsonb,
    scoring_method character varying(30),
    manual_add_reason character varying(30),
    manual_add_reason_note text,
    shadow_rank integer,
    shadow_score double precision,
    shadow_method character varying(20),
    rerank_detail jsonb  -- adicionada 18/08 na origem (PR #842); incorporada 20/08 (Achado #1)
);


CREATE SEQUENCE intelligence.jd_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.jd_results_id_seq OWNED BY intelligence.jd_results.id;

CREATE TABLE intelligence.job_descriptions (
    id bigint NOT NULL,
    title character varying,
    jd_status character varying(50),
    description text,
    challenge text,
    chief_profile text,
    contract_conditions text,
    requirements text,
    responsibilities text,
    benefits text,
    culture text,
    company_id bigint,
    empresa_nome character varying,
    raw_briefing text,
    cargo_extraido character varying,
    remuneracao_extraida character varying,
    work_model_extraido character varying,
    pipeline_status character varying(20) DEFAULT 'pending'::character varying,
    pipeline_run_id character varying(36),
    pipeline_error text,
    pipeline_run_count integer DEFAULT 0,
    pipeline_started_at timestamp with time zone,
    pipeline_completed_at timestamp with time zone,
    consultor_responsavel character varying,
    ingested_at timestamp with time zone DEFAULT now(),
    is_deleted boolean DEFAULT false,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone,
    uploaded_file_id bigint,
    is_favorited boolean DEFAULT false NOT NULL,
    raw_briefing_edited_by text,
    raw_briefing_edited_at timestamp with time zone,
    raw_briefing_ai text,
    jd_source character varying(20) DEFAULT 'manual'::character varying,
    escopo_extraido text,
    vaga_review_text text,
    vaga_review_video_url text,
    rails_vaga_id bigint,
    rails_synced_hash text,
    rails_synced_at timestamp with time zone,
    rails_viewer_company_ids integer[] DEFAULT '{}'::integer[],
    jd_variants jsonb,
    created_by character varying,
    is_test boolean DEFAULT false NOT NULL,
    outcome character varying(30),
    outcome_chief_id bigint,
    outcome_note text,
    outcome_at timestamp with time zone,
    dados_base_extraidos jsonb
);


CREATE SEQUENCE intelligence.job_descriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.job_descriptions_id_seq OWNED BY intelligence.job_descriptions.id;

CREATE TABLE intelligence.job_embeddings (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    field_name character varying(50) DEFAULT 'composite'::character varying NOT NULL,
    embedding public.vector(1536) NOT NULL,
    model_version character varying(100) NOT NULL,
    content_hash character varying(32),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


CREATE SEQUENCE intelligence.job_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.job_embeddings_id_seq OWNED BY intelligence.job_embeddings.id;

CREATE TABLE intelligence.mcp_query_log (
    id bigint NOT NULL,
    service_name character varying(32),
    tool_name character varying(64) NOT NULL,
    user_email character varying(255),
    access_level character varying(32),
    input_summary text,
    result_count integer,
    execution_ms integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.mcp_query_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.mcp_query_log_id_seq OWNED BY intelligence.mcp_query_log.id;

CREATE TABLE intelligence.mql_candidates (
    id integer NOT NULL,
    cnpj text NOT NULL,
    org_name text NOT NULL,
    person_name text NOT NULL,
    person_email text,
    person_phone text,
    title text,
    stage_novo character varying(20),
    zona character varying(20),
    tipo_origem character varying(30),
    status character varying(20),
    origem text,
    email_status text,
    cargo text,
    area text,
    nivel text,
    decisor_comercial text,
    decisor_motivo text,
    setor text,
    setor_confianca text,
    dor_setor text,
    custo_lead numeric,
    custo_fonte text,
    setor_driva text,
    subsetor_driva text,
    setor_fonte text,
    cnae_secao text,
    cnae_divisao text,
    cnae_subclasse text,
    faturamento text,
    funcionarios text,
    natureza_juridica text,
    capital_social text,
    uf text,
    municipio text,
    linkedin_empresa text,
    person_linkedin text,
    contato_rank integer,
    contato_primario text,
    is_mql_completo boolean DEFAULT false,
    dados_pendentes text[],
    driva_snapshot jsonb,
    source text DEFAULT 'driva'::text,
    version integer DEFAULT 1,
    is_active boolean DEFAULT true,
    deal_id bigint,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    chief_sugerido_a text,
    chief_sugerido_b text,
    gancho_direto text,
    gancho_exploratorio text
);


CREATE SEQUENCE intelligence.mql_candidates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.mql_candidates_id_seq OWNED BY intelligence.mql_candidates.id;

CREATE TABLE intelligence.novo_funil_pipedrive (
    deal_id bigint NOT NULL,
    title text,
    status character varying(20),
    pipeline_id integer,
    pipeline_name text,
    stage_id integer,
    stage_name text,
    value numeric,
    weighted_value numeric,
    currency character varying(10),
    probability integer,
    owner_id integer,
    owner_name text,
    org_id integer,
    org_name text,
    person_name text,
    person_email text,
    person_phone text,
    label_ids jsonb,
    source_name text,
    lost_reason text,
    activities_count integer,
    notes_count integer,
    files_count integer,
    expected_close_date date,
    last_activity_date timestamp with time zone,
    next_activity_date timestamp with time zone,
    close_time timestamp with time zone,
    added_at timestamp with time zone,
    updated_at_remote timestamp with time zone,
    notes jsonb,
    files jsonb,
    synced_at timestamp with time zone,
    deleted_at timestamp with time zone,
    origem_oportunidade jsonb,
    utm_source text,
    deal_snapshot jsonb NOT NULL,
    enriquecimento_snapshot jsonb,
    stage_novo character varying(20),
    zona character varying(20),
    tipo_origem character varying(20),
    resultado character varying(15),
    base_inferencia text,
    dados_consolidados text,
    dados_pendentes text[],
    analisado_em timestamp with time zone DEFAULT now()
);


CREATE TABLE intelligence.pipedrive_write_log (
    id bigint NOT NULL,
    deal_id bigint NOT NULL,
    action character varying(32) NOT NULL,
    from_stage_id integer,
    to_stage_id integer,
    from_stage_name character varying(128),
    to_stage_name character varying(128),
    signal character varying(64),
    note_preview text,
    actor character varying(255),
    status character varying(16) DEFAULT 'applied'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    undone_at timestamp with time zone,
    undone_by character varying(255),
    payload jsonb
);


CREATE SEQUENCE intelligence.pipedrive_write_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.pipedrive_write_log_id_seq OWNED BY intelligence.pipedrive_write_log.id;

CREATE TABLE intelligence.pipeline_runs (
    id bigint NOT NULL,
    run_id character varying(36) NOT NULL,
    job_id character varying(36),
    phase character varying(10) NOT NULL,
    version bigint DEFAULT '1'::bigint NOT NULL,
    status character varying(20) NOT NULL,
    input_data jsonb NOT NULL,
    output_data jsonb NOT NULL,
    model_version character varying(50),
    token_count_input bigint,
    token_count_output bigint,
    execution_time_ms bigint,
    triggered_by character varying(100),
    created_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.pipeline_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.pipeline_runs_id_seq OWNED BY intelligence.pipeline_runs.id;

CREATE TABLE intelligence.platform_sync_state (
    key character varying(64) NOT NULL,
    last_sync_at timestamp with time zone,
    last_full_sync_at timestamp with time zone
);


CREATE TABLE intelligence.system_prompts (
    id bigint NOT NULL,
    prompt_key character varying(100) NOT NULL,
    prompt_text text NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    module_group character varying(50),
    sort_order integer DEFAULT 999,
    input_type character varying(10) DEFAULT 'chief'::character varying
);


CREATE SEQUENCE intelligence.system_prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.system_prompts_id_seq OWNED BY intelligence.system_prompts.id;

CREATE TABLE intelligence.ui_access_grant (
    email text NOT NULL,
    display_name text DEFAULT ''::text NOT NULL,
    role text DEFAULT 'operator'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    added_by text DEFAULT ''::text NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ui_access_grant_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'ops'::text, 'operator'::text])))
);


CREATE TABLE intelligence.uploaded_files (
    id bigint NOT NULL,
    filename character varying(255) NOT NULL,
    content_type character varying(100) NOT NULL,
    file_data bytea NOT NULL,
    file_size integer NOT NULL,
    extracted_text text,
    uploaded_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.uploaded_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.uploaded_files_id_seq OWNED BY intelligence.uploaded_files.id;

CREATE TABLE intelligence.user_activity_log (
    id bigint NOT NULL,
    user_id character varying(200) NOT NULL,
    session_id character varying(100) DEFAULT ''::character varying NOT NULL,
    event_type character varying(50) NOT NULL,
    event_data jsonb,
    ip_address character varying(45),
    user_agent character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


CREATE SEQUENCE intelligence.user_activity_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.user_activity_log_id_seq OWNED BY intelligence.user_activity_log.id;

CREATE TABLE intelligence.user_favorites (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    jd_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.user_favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.user_favorites_id_seq OWNED BY intelligence.user_favorites.id;

CREATE TABLE intelligence.users (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    hashed_password character varying(200) NOT NULL,
    scope character varying(20) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


CREATE SEQUENCE intelligence.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE intelligence.users_id_seq OWNED BY intelligence.users.id;

ALTER TABLE ONLY intelligence.allocation_history_shortlist ALTER COLUMN id SET DEFAULT nextval('intelligence.allocation_history_shortlist_id_seq'::regclass);

ALTER TABLE ONLY intelligence.attractiveness_snapshots ALTER COLUMN id SET DEFAULT nextval('intelligence.attractiveness_snapshots_id_seq'::regclass);

ALTER TABLE ONLY intelligence.backtest_jobs ALTER COLUMN id SET DEFAULT nextval('intelligence.backtest_jobs_id_seq'::regclass);

ALTER TABLE ONLY intelligence.benchmark_market_cache ALTER COLUMN id SET DEFAULT nextval('intelligence.benchmark_market_cache_id_seq'::regclass);

ALTER TABLE ONLY intelligence.benchmark_qa ALTER COLUMN id SET DEFAULT nextval('intelligence.benchmark_qa_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_career_history ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_career_history_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_contextual_qa ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_contextual_qa_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_embeddings ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_embeddings_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_enrichment_history ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_enrichment_history_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_field_history ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_field_history_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_improvement_event ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_improvement_event_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_laudo ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_laudo_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_perfil_perguntas ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_perfil_perguntas_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_platform_history ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_platform_history_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_rerank_cache ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_rerank_cache_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_reverse_matches ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_reverse_matches_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_reverse_profile ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_reverse_profile_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_snapshot_before_op ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_snapshot_before_op_id_seq'::regclass);

ALTER TABLE ONLY intelligence.chief_stimulus_event ALTER COLUMN id SET DEFAULT nextval('intelligence.chief_stimulus_event_id_seq'::regclass);

ALTER TABLE ONLY intelligence.deal_enrichment_jobs ALTER COLUMN id SET DEFAULT nextval('intelligence.deal_enrichment_jobs_id_seq'::regclass);

ALTER TABLE ONLY intelligence.deal_enrichments ALTER COLUMN id SET DEFAULT nextval('intelligence.deal_enrichments_id_seq'::regclass);

ALTER TABLE ONLY intelligence.deal_sales_ops ALTER COLUMN id SET DEFAULT nextval('intelligence.deal_sales_ops_id_seq'::regclass);

ALTER TABLE ONLY intelligence.governance_conflicts ALTER COLUMN id SET DEFAULT nextval('intelligence.governance_conflicts_id_seq'::regclass);

ALTER TABLE ONLY intelligence.ingestion_logs ALTER COLUMN id SET DEFAULT nextval('intelligence.ingestion_logs_id_seq'::regclass);

ALTER TABLE ONLY intelligence.iqp_snapshots ALTER COLUMN id SET DEFAULT nextval('intelligence.iqp_snapshots_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_briefing_embeddings ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_briefing_embeddings_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_chief_alerts ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_chief_alerts_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_chief_match_comments ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_chief_match_comments_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_chief_stages ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_chief_stages_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_external_candidates ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_external_candidates_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_extracted_metadata ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_extracted_metadata_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_list_quality ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_list_quality_id_seq'::regclass);

ALTER TABLE ONLY intelligence.jd_results ALTER COLUMN id SET DEFAULT nextval('intelligence.jd_results_id_seq'::regclass);

ALTER TABLE ONLY intelligence.job_descriptions ALTER COLUMN id SET DEFAULT nextval('intelligence.job_descriptions_id_seq'::regclass);

ALTER TABLE ONLY intelligence.job_embeddings ALTER COLUMN id SET DEFAULT nextval('intelligence.job_embeddings_id_seq'::regclass);

ALTER TABLE ONLY intelligence.mcp_query_log ALTER COLUMN id SET DEFAULT nextval('intelligence.mcp_query_log_id_seq'::regclass);

ALTER TABLE ONLY intelligence.mql_candidates ALTER COLUMN id SET DEFAULT nextval('intelligence.mql_candidates_id_seq'::regclass);

ALTER TABLE ONLY intelligence.pipedrive_write_log ALTER COLUMN id SET DEFAULT nextval('intelligence.pipedrive_write_log_id_seq'::regclass);

ALTER TABLE ONLY intelligence.pipeline_runs ALTER COLUMN id SET DEFAULT nextval('intelligence.pipeline_runs_id_seq'::regclass);

ALTER TABLE ONLY intelligence.system_prompts ALTER COLUMN id SET DEFAULT nextval('intelligence.system_prompts_id_seq'::regclass);

ALTER TABLE ONLY intelligence.uploaded_files ALTER COLUMN id SET DEFAULT nextval('intelligence.uploaded_files_id_seq'::regclass);

ALTER TABLE ONLY intelligence.user_activity_log ALTER COLUMN id SET DEFAULT nextval('intelligence.user_activity_log_id_seq'::regclass);

ALTER TABLE ONLY intelligence.user_favorites ALTER COLUMN id SET DEFAULT nextval('intelligence.user_favorites_id_seq'::regclass);

ALTER TABLE ONLY intelligence.users ALTER COLUMN id SET DEFAULT nextval('intelligence.users_id_seq'::regclass);

ALTER TABLE ONLY intelligence.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);

ALTER TABLE ONLY intelligence.allocation_history
    ADD CONSTRAINT allocation_history_pkey PRIMARY KEY (startup_ad_id);

ALTER TABLE ONLY intelligence.allocation_history_shortlist
    ADD CONSTRAINT allocation_history_shortlist_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.attractiveness_snapshots
    ADD CONSTRAINT attractiveness_snapshots_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.backtest_jobs
    ADD CONSTRAINT backtest_jobs_job_id_key UNIQUE (job_id);

ALTER TABLE ONLY intelligence.backtest_jobs
    ADD CONSTRAINT backtest_jobs_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.benchmark_market_cache
    ADD CONSTRAINT benchmark_market_cache_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.benchmark_qa
    ADD CONSTRAINT benchmark_qa_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_career_history
    ADD CONSTRAINT chief_career_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_contextual_qa
    ADD CONSTRAINT chief_contextual_qa_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_embeddings
    ADD CONSTRAINT chief_embeddings_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_enrichment_history
    ADD CONSTRAINT chief_enrichment_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_field_history
    ADD CONSTRAINT chief_field_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_improvement_event
    ADD CONSTRAINT chief_improvement_event_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_laudo_modal_state
    ADD CONSTRAINT chief_laudo_modal_state_pkey PRIMARY KEY (chief_id);

ALTER TABLE ONLY intelligence.chief_laudo
    ADD CONSTRAINT chief_laudo_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_perfil_perguntas
    ADD CONSTRAINT chief_perfil_perguntas_chief_id_key UNIQUE (chief_id);

ALTER TABLE ONLY intelligence.chief_perfil_perguntas
    ADD CONSTRAINT chief_perfil_perguntas_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_platform_history
    ADD CONSTRAINT chief_platform_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_rerank_cache
    ADD CONSTRAINT chief_rerank_cache_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_reverse_matches
    ADD CONSTRAINT chief_reverse_matches_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_reverse_profile
    ADD CONSTRAINT chief_reverse_profile_chief_id_key UNIQUE (chief_id);

ALTER TABLE ONLY intelligence.chief_reverse_profile
    ADD CONSTRAINT chief_reverse_profile_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_snapshot_before_op
    ADD CONSTRAINT chief_snapshot_before_op_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.chief_stimulus_event
    ADD CONSTRAINT chief_stimulus_event_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.deal_enrichment_jobs
    ADD CONSTRAINT deal_enrichment_jobs_job_id_key UNIQUE (job_id);

ALTER TABLE ONLY intelligence.deal_enrichment_jobs
    ADD CONSTRAINT deal_enrichment_jobs_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.deal_enrichments
    ADD CONSTRAINT deal_enrichments_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.deal_sales_ops
    ADD CONSTRAINT deal_sales_ops_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.governance_conflicts
    ADD CONSTRAINT governance_conflicts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.ingestion_logs
    ADD CONSTRAINT ingestion_logs_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.ingestion_logs
    ADD CONSTRAINT ingestion_logs_run_id_key UNIQUE (run_id);

ALTER TABLE ONLY intelligence.iqp_snapshots
    ADD CONSTRAINT iqp_snapshots_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_briefing_embeddings
    ADD CONSTRAINT jd_briefing_embeddings_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_chief_alerts
    ADD CONSTRAINT jd_chief_alerts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_chief_match_comments
    ADD CONSTRAINT jd_chief_match_comments_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_chief_stages
    ADD CONSTRAINT jd_chief_stages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_external_candidates
    ADD CONSTRAINT jd_external_candidates_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_jd_id_key UNIQUE (jd_id);

ALTER TABLE ONLY intelligence.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_list_quality
    ADD CONSTRAINT jd_list_quality_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.jd_results
    ADD CONSTRAINT jd_results_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.job_descriptions
    ADD CONSTRAINT job_descriptions_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.job_embeddings
    ADD CONSTRAINT job_embeddings_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.mcp_query_log
    ADD CONSTRAINT mcp_query_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.mql_candidates
    ADD CONSTRAINT mql_candidates_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.novo_funil_pipedrive
    ADD CONSTRAINT novo_funil_pipedrive_pkey PRIMARY KEY (deal_id);

ALTER TABLE ONLY intelligence.pipedrive_write_log
    ADD CONSTRAINT pipedrive_write_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.pipeline_runs
    ADD CONSTRAINT pipeline_runs_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.platform_sync_state
    ADD CONSTRAINT platform_sync_state_pkey PRIMARY KEY (key);

ALTER TABLE ONLY intelligence.system_prompts
    ADD CONSTRAINT system_prompts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.ui_access_grant
    ADD CONSTRAINT ui_access_grant_pkey PRIMARY KEY (email);

ALTER TABLE ONLY intelligence.uploaded_files
    ADD CONSTRAINT uploaded_files_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.allocation_history_shortlist
    ADD CONSTRAINT uq_allocation_history_shortlist_ad_chief UNIQUE (startup_ad_id, chief_id);

ALTER TABLE ONLY intelligence.chief_career_history
    ADD CONSTRAINT uq_career_chief_company_role_start UNIQUE (chief_id, company, role, start_date);

ALTER TABLE ONLY intelligence.chief_embeddings
    ADD CONSTRAINT uq_chief_embeddings_chief_field_model_chunk UNIQUE (chief_id, field_name, model_version, chunk_index);

ALTER TABLE ONLY intelligence.chief_laudo
    ADD CONSTRAINT uq_chief_laudo_chief_curriculo UNIQUE (chief_id, curriculo_id);

ALTER TABLE ONLY intelligence.chief_rerank_cache
    ADD CONSTRAINT uq_chief_rerank_fact UNIQUE (chief_id, fact_key);

ALTER TABLE ONLY intelligence.chief_improvement_event
    ADD CONSTRAINT uq_improvement_event UNIQUE (source, source_ref);

ALTER TABLE ONLY intelligence.jd_briefing_embeddings
    ADD CONSTRAINT uq_jd_briefing_embeddings_jd_field_model UNIQUE (jd_id, field_name, model_version);

ALTER TABLE ONLY intelligence.jd_chief_alerts
    ADD CONSTRAINT uq_jd_chief_alerts_jd_chief UNIQUE (jd_id, chief_id);

ALTER TABLE ONLY intelligence.job_embeddings
    ADD CONSTRAINT uq_job_embeddings_job_field_model UNIQUE (job_id, field_name, model_version);

ALTER TABLE ONLY intelligence.mql_candidates
    ADD CONSTRAINT uq_mql_candidates_cnpj_person UNIQUE (cnpj, person_name);

ALTER TABLE ONLY intelligence.chief_platform_history
    ADD CONSTRAINT uq_platform_history_event UNIQUE (chief_id, event_type, source_event_id);

ALTER TABLE ONLY intelligence.chief_stimulus_event
    ADD CONSTRAINT uq_stimulus_event UNIQUE (stimulus_type, stimulus_ref, chief_id);

ALTER TABLE ONLY intelligence.system_prompts
    ADD CONSTRAINT uq_system_prompts_key_version UNIQUE (prompt_key, version);

ALTER TABLE ONLY intelligence.user_favorites
    ADD CONSTRAINT uq_user_favorites_user_jd UNIQUE (username, jd_id);

ALTER TABLE ONLY intelligence.user_activity_log
    ADD CONSTRAINT user_activity_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.user_favorites
    ADD CONSTRAINT user_favorites_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY intelligence.users
    ADD CONSTRAINT users_username_key UNIQUE (username);

CREATE INDEX idx_deal_enrichments_active ON intelligence.deal_enrichments USING btree (is_active) WHERE (is_active = true);

CREATE INDEX idx_deal_enrichments_company ON intelligence.deal_enrichments USING btree (company);

CREATE INDEX idx_deal_enrichments_deal_id ON intelligence.deal_enrichments USING btree (deal_id);

CREATE INDEX idx_deal_enrichments_latest ON intelligence.deal_enrichments USING btree (deal_id, enrichment_version DESC);

CREATE INDEX idx_deal_enrichments_score ON intelligence.deal_enrichments USING btree (score_total DESC);

CREATE INDEX idx_deal_enrichments_tier ON intelligence.deal_enrichments USING btree (tier);

CREATE INDEX idx_deal_sales_ops_active ON intelligence.deal_sales_ops USING btree (is_active) WHERE (is_active = true);

CREATE INDEX idx_deal_sales_ops_area ON intelligence.deal_sales_ops USING btree (area);

CREATE INDEX idx_deal_sales_ops_conta ON intelligence.deal_sales_ops USING btree (conta);

CREATE INDEX idx_deal_sales_ops_deal_id ON intelligence.deal_sales_ops USING btree (deal_id);

CREATE INDEX idx_deal_sales_ops_decisor ON intelligence.deal_sales_ops USING btree (decisor_comercial);

CREATE INDEX idx_deal_sales_ops_estagio ON intelligence.deal_sales_ops USING btree (estagio);

CREATE INDEX idx_deal_sales_ops_latest ON intelligence.deal_sales_ops USING btree (deal_id, version DESC);

CREATE INDEX idx_deal_sales_ops_origem ON intelligence.deal_sales_ops USING btree (origem);

CREATE INDEX idx_deal_sales_ops_setor ON intelligence.deal_sales_ops USING btree (setor);

CREATE INDEX idx_jd_list_quality_consultor ON intelligence.jd_list_quality USING btree (consultor_responsavel);

CREATE INDEX idx_jd_list_quality_jd ON intelligence.jd_list_quality USING btree (job_description_id);

CREATE INDEX idx_nfp_owner ON intelligence.novo_funil_pipedrive USING btree (owner_name);

CREATE INDEX idx_nfp_pendentes ON intelligence.novo_funil_pipedrive USING gin (dados_pendentes);

CREATE INDEX idx_nfp_resultado ON intelligence.novo_funil_pipedrive USING btree (resultado);

CREATE INDEX idx_nfp_stage_novo ON intelligence.novo_funil_pipedrive USING btree (stage_novo);

CREATE INDEX idx_nfp_status ON intelligence.novo_funil_pipedrive USING btree (status);

CREATE INDEX idx_nfp_zona ON intelligence.novo_funil_pipedrive USING btree (zona);

CREATE INDEX ix_activity_created_at ON intelligence.user_activity_log USING btree (created_at);

CREATE INDEX ix_activity_event_type ON intelligence.user_activity_log USING btree (event_type);

CREATE INDEX ix_activity_user_id ON intelligence.user_activity_log USING btree (user_id);

CREATE INDEX ix_allocation_history_chief_id ON intelligence.allocation_history USING btree (chief_id);

CREATE INDEX ix_allocation_history_excluded ON intelligence.allocation_history USING btree (excluded);

CREATE INDEX ix_allocation_history_shortlist_chief_id ON intelligence.allocation_history_shortlist USING btree (chief_id);

CREATE INDEX ix_allocation_history_shortlist_startup_ad_id ON intelligence.allocation_history_shortlist USING btree (startup_ad_id);

CREATE INDEX ix_att_snapshots_chief_id ON intelligence.attractiveness_snapshots USING btree (chief_id);

CREATE INDEX ix_att_snapshots_snapshot_name ON intelligence.attractiveness_snapshots USING btree (snapshot_name);

CREATE INDEX ix_backtest_jobs_job_id ON intelligence.backtest_jobs USING btree (job_id);

CREATE INDEX ix_backtest_jobs_status_created ON intelligence.backtest_jobs USING btree (status, created_at DESC);

CREATE INDEX ix_benchmark_market_cache_expires ON intelligence.benchmark_market_cache USING btree (expires_at);

CREATE INDEX ix_benchmark_qa_approved ON intelligence.benchmark_qa USING btree (chief_id) WHERE ((quality_score)::text = 'approved'::text);

CREATE INDEX ix_career_history_chief_id ON intelligence.chief_career_history USING btree (chief_id);

CREATE INDEX ix_chief_embeddings_chief_id ON intelligence.chief_embeddings USING btree (chief_id);

CREATE INDEX ix_chief_embeddings_field_name ON intelligence.chief_embeddings USING btree (field_name);

CREATE INDEX ix_chief_embeddings_hnsw_cosine ON intelligence.chief_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');

CREATE INDEX ix_chief_enrichment_history_chief_id ON intelligence.chief_enrichment_history USING btree (chief_id);

CREATE INDEX ix_chief_enrichment_history_created ON intelligence.chief_enrichment_history USING btree (created_at);

CREATE INDEX ix_chief_field_history_chief_id ON intelligence.chief_field_history USING btree (chief_id);

CREATE INDEX ix_chief_laudo_chief ON intelligence.chief_laudo USING btree (chief_id);

CREATE INDEX ix_chief_rerank_cache_chief_fact ON intelligence.chief_rerank_cache USING btree (chief_id, fact_key);

CREATE INDEX ix_chief_rerank_cache_chief_id ON intelligence.chief_rerank_cache USING btree (chief_id);

CREATE INDEX ix_chief_snapshot_chief_id ON intelligence.chief_snapshot_before_op USING btree (chief_id);

CREATE INDEX ix_chief_snapshot_operation ON intelligence.chief_snapshot_before_op USING btree (operation);

CREATE INDEX ix_contextual_qa_chief_jd ON intelligence.chief_contextual_qa USING btree (chief_id, jd_id);

CREATE INDEX ix_contextual_qa_pending ON intelligence.chief_contextual_qa USING btree (chief_id, status) WHERE ((status)::text = 'pending'::text);

CREATE INDEX ix_deal_enrichment_jobs_job_id ON intelligence.deal_enrichment_jobs USING btree (job_id);

CREATE INDEX ix_deal_enrichment_jobs_status_created ON intelligence.deal_enrichment_jobs USING btree (status, created_at DESC);

CREATE INDEX ix_deal_enrichments_grade_band ON intelligence.deal_enrichments USING btree (grade_band) WHERE (grade_band IS NOT NULL);

CREATE INDEX ix_governance_conflicts_chief_id ON intelligence.governance_conflicts USING btree (chief_id);

CREATE INDEX ix_governance_conflicts_detected_at ON intelligence.governance_conflicts USING btree (detected_at);

CREATE INDEX ix_governance_conflicts_type ON intelligence.governance_conflicts USING btree (conflict_type);

CREATE INDEX ix_improvement_event_chief_id ON intelligence.chief_improvement_event USING btree (chief_id);

CREATE INDEX ix_improvement_event_occurred ON intelligence.chief_improvement_event USING btree (occurred_at);

CREATE INDEX ix_improvement_event_source ON intelligence.chief_improvement_event USING btree (source);

CREATE INDEX ix_iqp_snapshots_name_table ON intelligence.iqp_snapshots USING btree (snapshot_name, table_name);

CREATE INDEX ix_jd_briefing_embeddings_hnsw_cosine ON intelligence.jd_briefing_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');

CREATE INDEX ix_jd_briefing_embeddings_jd_id ON intelligence.jd_briefing_embeddings USING btree (jd_id);

CREATE INDEX ix_jd_chief_alerts_active ON intelligence.jd_chief_alerts USING btree (jd_id) WHERE (resolved_at IS NULL);

CREATE INDEX ix_jd_chief_alerts_chief_id ON intelligence.jd_chief_alerts USING btree (chief_id);

CREATE INDEX ix_jd_chief_match_comments_chief ON intelligence.jd_chief_match_comments USING btree (jd_id, run_id, chief_id);

CREATE UNIQUE INDEX ix_jd_chief_match_comments_rails_id ON intelligence.jd_chief_match_comments USING btree (rails_comment_id);

CREATE INDEX ix_jd_chief_stages_jd_run ON intelligence.jd_chief_stages USING btree (jd_id, run_id);

CREATE UNIQUE INDEX ix_jd_chief_stages_one_chosen ON intelligence.jd_chief_stages USING btree (jd_id, run_id) WHERE is_chosen;

CREATE INDEX ix_jd_chief_stages_stage ON intelligence.jd_chief_stages USING btree (stage);

CREATE INDEX ix_jd_meta_hard_skills_gin ON intelligence.jd_extracted_metadata USING gin (hard_skills_requeridas);

CREATE INDEX ix_jd_meta_industrias_alvo_gin ON intelligence.jd_extracted_metadata USING gin (industrias_alvo);

CREATE INDEX ix_jd_meta_setores_alvo_gin ON intelligence.jd_extracted_metadata USING gin (setores_alvo);

CREATE INDEX ix_jd_results_active ON intelligence.jd_results USING btree (job_description_id, pipeline_run_id) WHERE (is_deleted = false);

CREATE INDEX ix_jd_results_chief_id ON intelligence.jd_results USING btree (chief_id);

CREATE INDEX ix_jd_results_job_description_id ON intelligence.jd_results USING btree (job_description_id);

CREATE INDEX ix_jd_results_pipeline_run_id ON intelligence.jd_results USING btree (pipeline_run_id);

CREATE INDEX ix_jd_external_candidates_active ON intelligence.jd_external_candidates USING btree (jd_id) WHERE (is_deleted = false);

CREATE INDEX ix_chief_perfil_perguntas_pending ON intelligence.chief_perfil_perguntas USING btree (answers_at) WHERE ((answers IS NOT NULL) AND (answers_enriched_at IS NULL));

CREATE INDEX ix_job_descriptions_created_at ON intelligence.job_descriptions USING btree (created_at);

CREATE INDEX ix_job_descriptions_is_test ON intelligence.job_descriptions USING btree (is_test) WHERE (is_test = true);

CREATE INDEX ix_job_descriptions_outcome ON intelligence.job_descriptions USING btree (outcome) WHERE (outcome IS NOT NULL);

CREATE INDEX ix_job_descriptions_jd_status ON intelligence.job_descriptions USING btree (jd_status);

CREATE INDEX ix_job_descriptions_pipeline_status ON intelligence.job_descriptions USING btree (pipeline_status);

CREATE INDEX ix_job_embeddings_hnsw_cosine ON intelligence.job_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');

CREATE INDEX ix_job_embeddings_job_id ON intelligence.job_embeddings USING btree (job_id);

CREATE INDEX ix_mql_candidates_decisor ON intelligence.mql_candidates USING btree (decisor_comercial);

CREATE INDEX ix_mql_candidates_origem ON intelligence.mql_candidates USING btree (origem);

CREATE INDEX ix_mql_candidates_pendencias ON intelligence.mql_candidates USING gin (dados_pendentes);

CREATE INDEX ix_mql_candidates_setor ON intelligence.mql_candidates USING btree (setor);

CREATE INDEX ix_pipeline_runs_job_id ON intelligence.pipeline_runs USING btree (job_id);

CREATE INDEX ix_pipeline_runs_run_id_phase ON intelligence.pipeline_runs USING btree (run_id, phase);

CREATE INDEX ix_platform_history_chief_id ON intelligence.chief_platform_history USING btree (chief_id);

CREATE INDEX ix_platform_history_occurred ON intelligence.chief_platform_history USING btree (occurred_at);

CREATE INDEX ix_reverse_matches_calculated_at ON intelligence.chief_reverse_matches USING btree (calculated_at);

CREATE INDEX ix_reverse_matches_chief_id ON intelligence.chief_reverse_matches USING btree (chief_id);

CREATE INDEX ix_stimulus_event_chief_id ON intelligence.chief_stimulus_event USING btree (chief_id);

CREATE INDEX ix_stimulus_event_sent_at ON intelligence.chief_stimulus_event USING btree (sent_at);

CREATE INDEX ix_stimulus_event_type ON intelligence.chief_stimulus_event USING btree (stimulus_type);

CREATE INDEX ix_ui_access_grant_active ON intelligence.ui_access_grant USING btree (is_active) WHERE (is_active = true);

CREATE INDEX ix_user_favorites_username ON intelligence.user_favorites USING btree (username);

CREATE INDEX ix_users_username ON intelligence.users USING btree (username);

CREATE INDEX mcp_query_log_created_at_idx ON intelligence.mcp_query_log USING btree (created_at DESC);

CREATE INDEX mcp_query_log_service_name_tool_name_idx ON intelligence.mcp_query_log USING btree (service_name, tool_name);

CREATE INDEX mcp_query_log_user_email_tool_name_idx ON intelligence.mcp_query_log USING btree (user_email, tool_name);

CREATE INDEX pipedrive_write_log_created_at_idx ON intelligence.pipedrive_write_log USING btree (created_at DESC);

CREATE INDEX pipedrive_write_log_deal_id_created_at_idx ON intelligence.pipedrive_write_log USING btree (deal_id, created_at DESC);

CREATE INDEX pipedrive_write_log_status_idx ON intelligence.pipedrive_write_log USING btree (status);

CREATE UNIQUE INDEX uq_benchmark_market_cache_key ON intelligence.benchmark_market_cache USING btree (job_title_normalized, sectors_key);

CREATE UNIQUE INDEX uq_benchmark_qa_chief_id ON intelligence.benchmark_qa USING btree (chief_id);

CREATE UNIQUE INDEX uq_jd_chief_stages_jd_chief_run ON intelligence.jd_chief_stages USING btree (jd_id, chief_id, run_id);

CREATE UNIQUE INDEX uq_jd_list_quality_run ON intelligence.jd_list_quality USING btree (pipeline_run_id);

CREATE UNIQUE INDEX uq_reverse_matches_chief_jd ON intelligence.chief_reverse_matches USING btree (chief_id, jd_id);

ALTER TABLE ONLY intelligence.allocation_history_shortlist
    ADD CONSTRAINT allocation_history_shortlist_startup_ad_id_fkey FOREIGN KEY (startup_ad_id) REFERENCES intelligence.allocation_history(startup_ad_id);

ALTER TABLE ONLY intelligence.jd_briefing_embeddings
    ADD CONSTRAINT jd_briefing_embeddings_jd_id_fkey FOREIGN KEY (jd_id) REFERENCES intelligence.job_descriptions(id);

ALTER TABLE ONLY intelligence.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_jd_id_fkey FOREIGN KEY (jd_id) REFERENCES intelligence.job_descriptions(id);

ALTER TABLE ONLY intelligence.jd_results
    ADD CONSTRAINT jd_results_job_description_id_fkey FOREIGN KEY (job_description_id) REFERENCES intelligence.job_descriptions(id);

ALTER TABLE ONLY intelligence.job_descriptions
    ADD CONSTRAINT job_descriptions_uploaded_file_id_fkey FOREIGN KEY (uploaded_file_id) REFERENCES intelligence.uploaded_files(id);

ALTER TABLE ONLY intelligence.job_embeddings
    ADD CONSTRAINT job_embeddings_job_id_fkey FOREIGN KEY (job_id) REFERENCES intelligence.job_descriptions(id);

-- View da intelligence — RECRIADA (veredito 13/08): a intel.pipedrive_deals
-- não migra; a view passa a ler app.pipedrive_deals do main.
-- Adaptações: id exposto = pipedrive_id (equivale ao id da antiga tabela da
-- intel); notes_count = jsonb_array_length(notes) (coluna notes_count não é
-- preservada no main — só notes/files/origem_oportunidade/utm_source).
-- Lógica de pontuação (LQS) inalterada.
CREATE VIEW intelligence.deal_quality_scores AS
 WITH deals AS (
         SELECT pd.pipedrive_id AS id,
            pd.title,
            pd.org_name,
            pd.person_name,
            pd.person_email,
            pd.person_phone,
            pd.status,
            pd.stage_name,
            pd.activities_count,
            COALESCE(jsonb_array_length(pd.notes), 0) AS notes_count
           FROM app.pipedrive_deals pd
        ), email_class AS (
         SELECT deals.id,
            deals.person_email,
                CASE
                    WHEN ((deals.person_email IS NULL) OR ((deals.person_email)::text = ''::text)) THEN 'none'::text
                    WHEN (lower((deals.person_email)::text) ~ '@(gmail|googlemail|hotmail|yahoo|outlook|live|icloud|msn|aol|protonmail|uol|bol|terra|ig|r7|globo|zipmail|oi\.com|superig|ibest)\.'::text) THEN 'personal'::text
                    ELSE 'corporate'::text
                END AS email_type
           FROM deals
        ), phone_class AS (
         SELECT deals.id,
            deals.person_phone,
                CASE
                    WHEN ((deals.person_phone IS NULL) OR ((deals.person_phone)::text = ''::text)) THEN false
                    WHEN ((length(regexp_replace(regexp_replace((deals.person_phone)::text, '^\+?55'::text, ''::text), '[^0-9]'::text, ''::text, 'g'::text)) >= 10) AND (length(regexp_replace(regexp_replace((deals.person_phone)::text, '^\+?55'::text, ''::text), '[^0-9]'::text, ''::text, 'g'::text)) <= 11)) THEN true
                    ELSE false
                END AS phone_valid
           FROM deals
        )
 SELECT d.id,
    d.title,
    d.org_name,
    d.person_name,
    d.person_email,
    d.person_phone,
    d.status,
    d.stage_name,
    d.activities_count,
    d.notes_count,
        CASE
            WHEN ((d.org_name IS NOT NULL) AND ((d.org_name)::text <> ''::text)) THEN 15
            ELSE 0
        END AS pts_empresa,
        CASE
            WHEN ((d.person_name IS NOT NULL) AND ((d.person_name)::text <> ''::text)) THEN 15
            ELSE 0
        END AS pts_contato,
        CASE e.email_type
            WHEN 'corporate'::text THEN 40
            WHEN 'personal'::text THEN 20
            WHEN 'none'::text THEN
            CASE
                WHEN p.phone_valid THEN 15
                ELSE 0
            END
            ELSE 0
        END AS pts_email,
        CASE
            WHEN p.phone_valid THEN 10
            ELSE 0
        END AS pts_telefone,
        CASE
            WHEN ((COALESCE(d.activities_count, 0) > 0) OR (COALESCE(d.notes_count, 0) > 0)) THEN 10
            ELSE 0
        END AS pts_atividade,
        CASE
            WHEN ((d.title IS NOT NULL) AND ((d.title)::text !~~* '%negócio%'::text) AND ((d.title)::text !~~* '%negocio%'::text) AND ((d.title)::text !~~* '%lead%'::text)) THEN 10
            ELSE 0
        END AS pts_titulo,
    (((((
        CASE
            WHEN ((d.org_name IS NOT NULL) AND ((d.org_name)::text <> ''::text)) THEN 15
            ELSE 0
        END +
        CASE
            WHEN ((d.person_name IS NOT NULL) AND ((d.person_name)::text <> ''::text)) THEN 15
            ELSE 0
        END) +
        CASE e.email_type
            WHEN 'corporate'::text THEN 40
            WHEN 'personal'::text THEN 20
            WHEN 'none'::text THEN
            CASE
                WHEN p.phone_valid THEN 15
                ELSE 0
            END
            ELSE 0
        END) +
        CASE
            WHEN p.phone_valid THEN 10
            ELSE 0
        END) +
        CASE
            WHEN ((COALESCE(d.activities_count, 0) > 0) OR (COALESCE(d.notes_count, 0) > 0)) THEN 10
            ELSE 0
        END) +
        CASE
            WHEN ((d.title IS NOT NULL) AND ((d.title)::text !~~* '%negócio%'::text) AND ((d.title)::text !~~* '%negocio%'::text) AND ((d.title)::text !~~* '%lead%'::text)) THEN 10
            ELSE 0
        END) AS lqs,
    e.email_type,
    p.phone_valid
   FROM ((deals d
     JOIN email_class e ON ((e.id = d.id)))
     JOIN phone_class p ON ((p.id = d.id)));
