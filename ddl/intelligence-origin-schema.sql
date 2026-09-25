--
-- PostgreSQL database dump
--

-- Dumped from database version 17.8 (Debian 17.8-1.pgdg12+1)
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ac_campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ac_campaigns (
    id character varying(64) NOT NULL,
    name text,
    subject text,
    status text,
    sent_at timestamp with time zone,
    send_amount integer DEFAULT 0,
    unique_opens integer DEFAULT 0,
    unique_clicks integer DEFAULT 0,
    bounces integer DEFAULT 0,
    unsubscribes integer DEFAULT 0,
    message_id character varying(64),
    message_subject text,
    message_from_name text,
    message_from_email text,
    message_html text,
    message_text text,
    ac_updated_at timestamp with time zone,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ac_contact_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ac_contact_messages (
    id bigint NOT NULL,
    ac_contact_id character varying(64) NOT NULL,
    chief_id bigint,
    ac_campaign_id character varying(64),
    campaign_name text,
    subject text,
    sent_at timestamp with time zone,
    opens_count integer DEFAULT 0,
    clicks_count integer DEFAULT 0,
    last_open_at timestamp with time zone,
    last_click_at timestamp with time zone,
    bounce_type character varying(16),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ac_contact_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ac_contact_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ac_contact_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ac_contact_messages_id_seq OWNED BY public.ac_contact_messages.id;


--
-- Name: ac_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ac_contacts (
    id character varying(64) NOT NULL,
    email text,
    chief_id bigint,
    first_name text,
    last_name text,
    status text,
    score integer,
    derived_score integer,
    sent_count integer DEFAULT 0,
    open_count integer DEFAULT 0,
    click_count integer DEFAULT 0,
    last_open_at timestamp with time zone,
    last_click_at timestamp with time zone,
    bounced_hard_count integer DEFAULT 0,
    bounced_soft_count integer DEFAULT 0,
    bounced_at timestamp with time zone,
    tags jsonb DEFAULT '[]'::jsonb,
    ac_updated_at timestamp with time zone,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    name text,
    startup_ads_total integer,
    startup_ads_active integer,
    startup_ads jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at_remote timestamp with time zone,
    updated_at_remote timestamp with time zone,
    raw_payload jsonb,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(255) NOT NULL
);


--
-- Name: allocation_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_history (
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


--
-- Name: allocation_history_shortlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allocation_history_shortlist (
    id bigint NOT NULL,
    startup_ad_id bigint NOT NULL,
    chief_id bigint NOT NULL,
    stage character varying(30) NOT NULL,
    escolhido boolean DEFAULT false NOT NULL,
    chief_registered_at timestamp with time zone
);


--
-- Name: allocation_history_shortlist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.allocation_history_shortlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: allocation_history_shortlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.allocation_history_shortlist_id_seq OWNED BY public.allocation_history_shortlist.id;


--
-- Name: attractiveness_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attractiveness_snapshots (
    id bigint NOT NULL,
    snapshot_name character varying(100) NOT NULL,
    table_name character varying(50) NOT NULL,
    chief_id character varying NOT NULL,
    attractiveness_score double precision,
    attractiveness_classification character varying(20),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: attractiveness_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attractiveness_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attractiveness_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attractiveness_snapshots_id_seq OWNED BY public.attractiveness_snapshots.id;


--
-- Name: backtest_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backtest_jobs (
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


--
-- Name: backtest_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.backtest_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backtest_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.backtest_jobs_id_seq OWNED BY public.backtest_jobs.id;


--
-- Name: benchmark_market_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.benchmark_market_cache (
    id bigint NOT NULL,
    job_title_normalized character varying(200) NOT NULL,
    sectors_key character varying(500) NOT NULL,
    result_json jsonb NOT NULL,
    cached_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone
);


--
-- Name: benchmark_market_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.benchmark_market_cache_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: benchmark_market_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.benchmark_market_cache_id_seq OWNED BY public.benchmark_market_cache.id;


--
-- Name: benchmark_qa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.benchmark_qa (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    reviewed_by character varying(100) NOT NULL,
    reviewed_at timestamp with time zone DEFAULT now() NOT NULL,
    quality_score character varying(20) NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT benchmark_qa_quality_score_check CHECK (((quality_score)::text = ANY ((ARRAY['approved'::character varying, 'needs_review'::character varying, 'rejected'::character varying])::text[])))
);


--
-- Name: benchmark_qa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.benchmark_qa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: benchmark_qa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.benchmark_qa_id_seq OWNED BY public.benchmark_qa.id;


--
-- Name: ca_acquittances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_acquittances (
    id character varying(64) NOT NULL,
    parcela_uuid character varying(64),
    valor numeric(18,2),
    data_baixa date,
    conta_financeira_uuid character varying(64),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_categories (
    id character varying(64) NOT NULL,
    nome text,
    tipo character varying(16),
    categoria_pai character varying(64),
    entrada_dre character varying(64),
    considera_custo_dre boolean,
    versao integer,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_contracts (
    id character varying(64) NOT NULL,
    numero text,
    status text,
    periodicidade text,
    data_inicio date,
    data_fim date,
    valor_total numeric(18,2),
    valor_recorrente numeric(18,2),
    cliente_uuid character varying(64),
    cliente_nome text,
    vendedor_uuid character varying(64),
    vendedor_nome text,
    tipo_negociacao text,
    data_criacao timestamp with time zone,
    data_alteracao timestamp with time zone,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_cost_centers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_cost_centers (
    id character varying(64) NOT NULL,
    nome text,
    status text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_dre_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_dre_categories (
    id character varying(64) NOT NULL,
    parent_uuid character varying(64),
    descricao text,
    codigo text,
    posicao integer,
    indica_totalizador boolean,
    representa_soma_custo_medio boolean,
    categoria_uuids character varying(64)[] DEFAULT ARRAY[]::character varying[],
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_financial_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_financial_accounts (
    id character varying(64) NOT NULL,
    nome text,
    tipo text,
    banco text,
    status text,
    saldo_atual numeric(18,2),
    saldo_atualizado_em timestamp with time zone,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_financial_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_financial_events (
    id character varying(64) NOT NULL,
    tipo character varying(16),
    status text,
    valor numeric(18,2),
    data_competencia date,
    data_vencimento date,
    descricao text,
    pessoa_uuid character varying(64),
    categoria_uuid character varying(64),
    centro_custo_uuid character varying(64),
    conta_financeira_uuid character varying(64),
    installments jsonb DEFAULT '[]'::jsonb,
    apportionments jsonb DEFAULT '[]'::jsonb,
    synced_at timestamp with time zone DEFAULT now(),
    raw_payload jsonb DEFAULT '{}'::jsonb
);


--
-- Name: ca_people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_people (
    id character varying(64) NOT NULL,
    nome text,
    email text,
    documento text,
    telefone text,
    tipo_pessoa character varying(16),
    ativo boolean,
    perfis jsonb DEFAULT '[]'::jsonb,
    endereco jsonb,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_sales; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_sales (
    id character varying(64) NOT NULL,
    id_legado bigint,
    numero integer,
    data date,
    tipo_negociacao text,
    status text,
    situacao_nome text,
    situacao_descricao text,
    total numeric(18,2),
    valor_bruto numeric(18,2),
    desconto numeric(18,2),
    valor_liquido numeric(18,2),
    cliente_uuid character varying(64),
    cliente_nome text,
    vendedor_uuid character varying(64),
    vendedor_nome text,
    evento_financeiro_uuid character varying(64),
    contrato_uuid character varying(64),
    natureza_operacao_uuid character varying(64),
    natureza_operacao_label text,
    tipo_operacao text,
    template_operacao text,
    centro_custo_uuid character varying(64),
    categoria_uuid character varying(64),
    origem text,
    versao integer,
    data_criacao timestamp with time zone,
    data_alteracao timestamp with time zone,
    items jsonb DEFAULT '[]'::jsonb,
    synced_at timestamp with time zone DEFAULT now(),
    installments jsonb DEFAULT '[]'::jsonb,
    raw_payload jsonb DEFAULT '{}'::jsonb
);


--
-- Name: ca_sellers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_sellers (
    id character varying(64) NOT NULL,
    nome text,
    email text,
    documento text,
    status text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ca_service_invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_service_invoices (
    id character varying(64) NOT NULL,
    numero text,
    numero_rps text,
    chave_acesso text,
    status text,
    data_emissao date,
    data_competencia date,
    valor_total numeric(18,2),
    cliente_uuid character varying(64),
    cliente_nome text,
    venda_uuid character varying(64),
    contrato_uuid character varying(64),
    tipo_negociacao text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: chief_career_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_career_history (
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


--
-- Name: chief_career_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_career_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_career_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_career_history_id_seq OWNED BY public.chief_career_history.id;


--
-- Name: chief_contextual_qa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_contextual_qa (
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


--
-- Name: chief_contextual_qa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_contextual_qa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_contextual_qa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_contextual_qa_id_seq OWNED BY public.chief_contextual_qa.id;


--
-- Name: chief_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_embeddings (
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


--
-- Name: chief_embeddings_bak_20260803; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_embeddings_bak_20260803 (
    id bigint,
    chief_id character varying,
    field_name character varying(100),
    embedding public.vector(1536),
    model_version character varying(100),
    content_hash character varying(32),
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    chunk_index integer
);


--
-- Name: chief_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_embeddings_id_seq OWNED BY public.chief_embeddings.id;


--
-- Name: chief_enrichment_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_enrichment_history (
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


--
-- Name: chief_enrichment_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_enrichment_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_enrichment_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_enrichment_history_id_seq OWNED BY public.chief_enrichment_history.id;


--
-- Name: chief_field_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_field_history (
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


--
-- Name: chief_field_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_field_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_field_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_field_history_id_seq OWNED BY public.chief_field_history.id;


--
-- Name: chief_improvement_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_improvement_event (
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


--
-- Name: chief_improvement_event_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_improvement_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_improvement_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_improvement_event_id_seq OWNED BY public.chief_improvement_event.id;


--
-- Name: chief_laudo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_laudo (
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


--
-- Name: chief_laudo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_laudo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_laudo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_laudo_id_seq OWNED BY public.chief_laudo.id;


--
-- Name: chief_laudo_modal_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_laudo_modal_state (
    chief_id character varying NOT NULL,
    first_shown_at timestamp with time zone,
    last_shown_at timestamp with time zone,
    responded_at timestamp with time zone,
    dismissed_at timestamp with time zone,
    dismiss_count integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chief_perfil_perguntas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_perfil_perguntas (
    id bigint NOT NULL,
    chief_id bigint NOT NULL,
    perguntas jsonb NOT NULL,
    answers jsonb,
    answers_at timestamp with time zone,
    answers_enriched_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chief_perfil_perguntas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_perfil_perguntas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_perfil_perguntas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_perfil_perguntas_id_seq OWNED BY public.chief_perfil_perguntas.id;


--
-- Name: chief_platform_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_platform_history (
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


--
-- Name: chief_platform_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_platform_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_platform_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_platform_history_id_seq OWNED BY public.chief_platform_history.id;


--
-- Name: chief_rerank_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_rerank_cache (
    id integer NOT NULL,
    chief_id character varying NOT NULL,
    fact_key character varying(100) NOT NULL,
    fact_value text NOT NULL,
    confidence double precision DEFAULT '0.8'::double precision NOT NULL,
    source_jd_ids integer[] DEFAULT '{}'::integer[],
    extracted_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: chief_rerank_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_rerank_cache_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_rerank_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_rerank_cache_id_seq OWNED BY public.chief_rerank_cache.id;


--
-- Name: chief_reverse_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_reverse_matches (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    jd_id bigint NOT NULL,
    similarity double precision NOT NULL,
    aderencia_atingida boolean NOT NULL,
    batch_run_id character varying(36) NOT NULL,
    calculated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chief_reverse_matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_reverse_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_reverse_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_reverse_matches_id_seq OWNED BY public.chief_reverse_matches.id;


--
-- Name: chief_reverse_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_reverse_profile (
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


--
-- Name: chief_reverse_profile_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_reverse_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_reverse_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_reverse_profile_id_seq OWNED BY public.chief_reverse_profile.id;


--
-- Name: chief_snapshot_before_op; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_snapshot_before_op (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    operation character varying(50) NOT NULL,
    snapshot jsonb NOT NULL,
    actor character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chief_snapshot_before_op_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_snapshot_before_op_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_snapshot_before_op_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_snapshot_before_op_id_seq OWNED BY public.chief_snapshot_before_op.id;


--
-- Name: chief_stimulus_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chief_stimulus_event (
    id bigint NOT NULL,
    chief_id character varying NOT NULL,
    stimulus_type character varying(20) NOT NULL,
    stimulus_ref character varying NOT NULL,
    channel character varying(20),
    sent_at timestamp with time zone NOT NULL,
    payload jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chief_stimulus_event_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chief_stimulus_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chief_stimulus_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chief_stimulus_event_id_seq OWNED BY public.chief_stimulus_event.id;


--
-- Name: chiefs_ativos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_ativos (
    id character varying NOT NULL,
    name character varying,
    email character varying,
    job_title character varying,
    tier character varying(20),
    status character varying(50),
    city character varying,
    state character varying,
    linkedin character varying,
    phone character varying,
    c_level_experience character varying,
    years_experience character varying,
    profile_percentage numeric(5,2),
    resume_experience text,
    resume_project text,
    important_cases_connecting_customers text,
    biggest_problems text,
    relevant_problems text,
    info_extracted text,
    comment text,
    industries_experience character varying[],
    sectors_experience character varying[],
    work_model character varying[],
    business_model character varying[],
    business_moment character varying[],
    main_companies character varying[],
    hard_skills character varying[],
    others_language character varying[],
    enrichment_status character varying(20) DEFAULT 'pending'::character varying,
    vectorization_status character varying(20) DEFAULT 'pending'::character varying,
    is_deleted boolean DEFAULT false,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    executive_competency character varying(50),
    state_inferred character varying(10),
    state_inferred_confidence character varying(50),
    english_level_inferred character varying(30),
    is_potential_apt_tier1 boolean,
    work_model_inferred character varying[],
    profile_completeness_score numeric(5,2),
    regiao_influencia_secundaria character varying[],
    "BP_verification_notes" text,
    enrichment_meta jsonb,
    enrichment_error text,
    enrichment_claimed_at timestamp with time zone,
    natureza_atuacao character varying(50),
    prazo_disponivel character varying(50),
    perfil_atuacao character varying(50),
    stakeholder_mgmt character varying(50),
    porte_empresa_ideal character varying(50),
    momento_empresa_ideal character varying(50),
    ferramentas_dominadas character varying[],
    tolerancia_ambiguidade character varying(30),
    perfil_cultural character varying(50),
    capacidade_mentoria character varying(30),
    iqp_score numeric(5,2),
    iqp_classification character varying(20),
    years_career_inferred integer,
    years_executive_inferred integer,
    sector_experience_detail jsonb,
    job_title_normalized character varying,
    resume_combined text,
    resume_experience_synthetic text,
    english_level character varying(30),
    portuguese_level character varying(30),
    spanish_level character varying(30),
    availability character varying(10),
    availability_status character varying[],
    salary character varying,
    mentorship_fee character varying(20),
    company character varying,
    company_profiles character varying[],
    biggest_team_responsibility character varying,
    chair character varying(30),
    gender character varying(20),
    birth_at character varying,
    slug character varying,
    avatar_blob_key character varying,
    avatar_url text,
    needs_re_enrichment boolean DEFAULT false,
    field_confidence jsonb,
    total_career_months integer,
    exec_level_months integer,
    unique_companies_count integer,
    current_roles_count integer,
    longest_tenure_months integer,
    avg_tenure_months integer,
    career_start_date date,
    linkedin_enriched_at timestamp with time zone,
    all_job_titles text[] DEFAULT '{}'::text[],
    deletion_reason character varying(50),
    attractiveness_score double precision,
    attractiveness_classification character varying(20),
    chair_inferred character varying(30),
    registered_at timestamp with time zone
);


--
-- Name: chiefs_platform; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_platform (
    id integer NOT NULL,
    name text,
    email text,
    linkedin text,
    city text,
    state text,
    job_title text,
    company text,
    resume_experience text,
    tags text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: chiefs_platform_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chiefs_platform_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chiefs_platform_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chiefs_platform_id_seq OWNED BY public.chiefs_platform.id;


--
-- Name: chiefs_reenrich_backup_20260831; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_reenrich_backup_20260831 (
    id character varying,
    enrichment_status character varying(20),
    enrichment_claimed_at timestamp with time zone,
    needs_re_enrichment boolean,
    vectorization_status character varying(20)
);


--
-- Name: chiefs_todos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chiefs_todos (
    id character varying NOT NULL,
    name character varying,
    email character varying,
    job_title character varying,
    tier character varying(20),
    status character varying(50),
    city character varying,
    state character varying,
    linkedin character varying,
    phone character varying,
    c_level_experience character varying,
    years_experience character varying,
    profile_percentage numeric(5,2),
    resume_experience text,
    resume_project text,
    important_cases_connecting_customers text,
    biggest_problems text,
    relevant_problems text,
    info_extracted text,
    comment text,
    industries_experience character varying[],
    sectors_experience character varying[],
    work_model character varying[],
    business_model character varying[],
    business_moment character varying[],
    main_companies character varying[],
    hard_skills character varying[],
    others_language character varying[],
    enrichment_status character varying(20) DEFAULT 'pending'::character varying,
    vectorization_status character varying(20) DEFAULT 'pending'::character varying,
    is_deleted boolean DEFAULT false,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone,
    executive_competency character varying(50),
    state_inferred character varying(10),
    state_inferred_confidence character varying(50),
    english_level_inferred character varying(30),
    is_potential_apt_tier1 boolean,
    work_model_inferred character varying[],
    profile_completeness_score numeric(5,2),
    regiao_influencia_secundaria character varying[],
    "BP_verification_notes" text,
    enrichment_meta jsonb,
    enrichment_error text,
    enrichment_claimed_at timestamp with time zone,
    natureza_atuacao character varying(50),
    prazo_disponivel character varying(50),
    perfil_atuacao character varying(50),
    stakeholder_mgmt character varying(50),
    porte_empresa_ideal character varying(50),
    momento_empresa_ideal character varying(50),
    ferramentas_dominadas character varying[],
    tolerancia_ambiguidade character varying(30),
    perfil_cultural character varying(50),
    capacidade_mentoria character varying(30),
    iqp_score numeric(5,2),
    iqp_classification character varying(20),
    years_career_inferred integer,
    years_executive_inferred integer,
    sector_experience_detail jsonb,
    job_title_normalized character varying,
    resume_combined text,
    resume_experience_synthetic text,
    english_level character varying(30),
    portuguese_level character varying(30),
    spanish_level character varying(30),
    availability character varying(10),
    availability_status character varying[],
    salary character varying,
    mentorship_fee character varying(20),
    company character varying,
    company_profiles character varying[],
    biggest_team_responsibility character varying,
    chair character varying(30),
    gender character varying(20),
    birth_at character varying,
    slug character varying,
    avatar_blob_key character varying,
    avatar_url text,
    needs_re_enrichment boolean DEFAULT false,
    field_confidence jsonb,
    total_career_months integer,
    exec_level_months integer,
    unique_companies_count integer,
    current_roles_count integer,
    longest_tenure_months integer,
    avg_tenure_months integer,
    career_start_date date,
    linkedin_enriched_at timestamp with time zone,
    all_job_titles text[] DEFAULT '{}'::text[],
    deletion_reason character varying(50),
    chair_inferred character varying(30),
    registered_at timestamp with time zone
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    name text,
    slug text,
    status text,
    email text,
    cnpj text,
    site text,
    linkedin text,
    description text,
    sector text,
    market text,
    target text,
    company_stage text,
    fundation_year text,
    fulltime_team text,
    monetization text,
    customers text,
    investment_stage text,
    founders text,
    linkedin_founders text,
    revenue text,
    revenue_last_month text,
    service_type text,
    contact_name text,
    contact_email text,
    contact_phone text,
    contact_job_title text,
    contact_linkedin text,
    city text,
    accounts_total integer,
    startup_ads_total integer,
    startup_ads_active integer,
    created_at_remote timestamp with time zone,
    updated_at_remote timestamp with time zone,
    raw_payload jsonb,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: deal_enrichment_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_enrichment_jobs (
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


--
-- Name: deal_enrichment_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deal_enrichment_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deal_enrichment_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deal_enrichment_jobs_id_seq OWNED BY public.deal_enrichment_jobs.id;


--
-- Name: deal_enrichments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_enrichments (
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


--
-- Name: deal_enrichments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deal_enrichments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deal_enrichments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deal_enrichments_id_seq OWNED BY public.deal_enrichments.id;


--
-- Name: pipedrive_deals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_deals (
    id bigint NOT NULL,
    title text,
    status character varying(16),
    pipeline_id integer,
    pipeline_name text,
    stage_id integer,
    stage_name text,
    value numeric(18,2),
    weighted_value numeric(18,2),
    currency character varying(8),
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
    notes jsonb DEFAULT '[]'::jsonb,
    files jsonb DEFAULT '[]'::jsonb,
    synced_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    origem_oportunidade jsonb,
    utm_source text,
    raw_payload jsonb
);


--
-- Name: deal_quality_scores; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.deal_quality_scores AS
 WITH email_class AS (
         SELECT pipedrive_deals.id,
            pipedrive_deals.person_email,
                CASE
                    WHEN ((pipedrive_deals.person_email IS NULL) OR (pipedrive_deals.person_email = ''::text)) THEN 'none'::text
                    WHEN (lower(pipedrive_deals.person_email) ~ '@(gmail|googlemail|hotmail|yahoo|outlook|live|icloud|msn|aol|protonmail|uol|bol|terra|ig|r7|globo|zipmail|oi\.com|superig|ibest)\.'::text) THEN 'personal'::text
                    ELSE 'corporate'::text
                END AS email_type
           FROM public.pipedrive_deals
        ), phone_class AS (
         SELECT pipedrive_deals.id,
            pipedrive_deals.person_phone,
                CASE
                    WHEN ((pipedrive_deals.person_phone IS NULL) OR (pipedrive_deals.person_phone = ''::text)) THEN false
                    WHEN ((length(regexp_replace(regexp_replace(pipedrive_deals.person_phone, '^\+?55'::text, ''::text), '[^0-9]'::text, ''::text, 'g'::text)) >= 10) AND (length(regexp_replace(regexp_replace(pipedrive_deals.person_phone, '^\+?55'::text, ''::text), '[^0-9]'::text, ''::text, 'g'::text)) <= 11)) THEN true
                    ELSE false
                END AS phone_valid
           FROM public.pipedrive_deals
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
            WHEN ((d.org_name IS NOT NULL) AND (d.org_name <> ''::text)) THEN 15
            ELSE 0
        END AS pts_empresa,
        CASE
            WHEN ((d.person_name IS NOT NULL) AND (d.person_name <> ''::text)) THEN 15
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
            WHEN ((d.title IS NOT NULL) AND (d.title !~~* '%negócio%'::text) AND (d.title !~~* '%negocio%'::text) AND (d.title !~~* '%lead%'::text)) THEN 10
            ELSE 0
        END AS pts_titulo,
    (((((
        CASE
            WHEN ((d.org_name IS NOT NULL) AND (d.org_name <> ''::text)) THEN 15
            ELSE 0
        END +
        CASE
            WHEN ((d.person_name IS NOT NULL) AND (d.person_name <> ''::text)) THEN 15
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
            WHEN ((d.title IS NOT NULL) AND (d.title !~~* '%negócio%'::text) AND (d.title !~~* '%negocio%'::text) AND (d.title !~~* '%lead%'::text)) THEN 10
            ELSE 0
        END) AS lqs,
    e.email_type,
    p.phone_valid
   FROM ((public.pipedrive_deals d
     JOIN email_class e ON ((e.id = d.id)))
     JOIN phone_class p ON ((p.id = d.id)));


--
-- Name: deal_sales_ops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_sales_ops (
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


--
-- Name: deal_sales_ops_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deal_sales_ops_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deal_sales_ops_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deal_sales_ops_id_seq OWNED BY public.deal_sales_ops.id;


--
-- Name: governance_conflicts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.governance_conflicts (
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


--
-- Name: governance_conflicts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.governance_conflicts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: governance_conflicts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.governance_conflicts_id_seq OWNED BY public.governance_conflicts.id;


--
-- Name: ingestion_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_logs (
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


--
-- Name: ingestion_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ingestion_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ingestion_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ingestion_logs_id_seq OWNED BY public.ingestion_logs.id;


--
-- Name: iqp_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.iqp_snapshots (
    id bigint NOT NULL,
    snapshot_name character varying(100) NOT NULL,
    table_name character varying(50) NOT NULL,
    chief_id character varying NOT NULL,
    iqp_score numeric(5,2),
    iqp_classification character varying(20),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: iqp_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.iqp_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: iqp_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.iqp_snapshots_id_seq OWNED BY public.iqp_snapshots.id;


--
-- Name: jd_briefing_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_briefing_embeddings (
    id bigint NOT NULL,
    jd_id bigint NOT NULL,
    field_name character varying(50) DEFAULT 'raw_briefing'::character varying NOT NULL,
    embedding public.vector(1536) NOT NULL,
    model_version character varying(100) NOT NULL,
    content_hash character varying(32),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


--
-- Name: jd_briefing_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_briefing_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_briefing_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_briefing_embeddings_id_seq OWNED BY public.jd_briefing_embeddings.id;


--
-- Name: jd_chief_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_chief_alerts (
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


--
-- Name: jd_chief_alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_chief_alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_chief_alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_chief_alerts_id_seq OWNED BY public.jd_chief_alerts.id;


--
-- Name: jd_chief_match_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_chief_match_comments (
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


--
-- Name: jd_chief_match_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_chief_match_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_chief_match_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_chief_match_comments_id_seq OWNED BY public.jd_chief_match_comments.id;


--
-- Name: jd_chief_stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_chief_stages (
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


--
-- Name: jd_chief_stages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_chief_stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_chief_stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_chief_stages_id_seq OWNED BY public.jd_chief_stages.id;


--
-- Name: jd_external_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_external_candidates (
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


--
-- Name: jd_external_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_external_candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_external_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_external_candidates_id_seq OWNED BY public.jd_external_candidates.id;


--
-- Name: jd_extracted_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_extracted_metadata (
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


--
-- Name: jd_extracted_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_extracted_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_extracted_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_extracted_metadata_id_seq OWNED BY public.jd_extracted_metadata.id;


--
-- Name: jd_list_quality; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_list_quality (
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


--
-- Name: jd_list_quality_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_list_quality_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_list_quality_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_list_quality_id_seq OWNED BY public.jd_list_quality.id;


--
-- Name: jd_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jd_results (
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
    rerank_detail jsonb
);


--
-- Name: jd_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jd_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jd_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jd_results_id_seq OWNED BY public.jd_results.id;


--
-- Name: job_descriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_descriptions (
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


--
-- Name: job_descriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_descriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_descriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_descriptions_id_seq OWNED BY public.job_descriptions.id;


--
-- Name: job_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_embeddings (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    field_name character varying(50) DEFAULT 'composite'::character varying NOT NULL,
    embedding public.vector(1536) NOT NULL,
    model_version character varying(100) NOT NULL,
    content_hash character varying(32),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


--
-- Name: job_embeddings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_embeddings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_embeddings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_embeddings_id_seq OWNED BY public.job_embeddings.id;


--
-- Name: mcp_query_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mcp_query_log (
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


--
-- Name: mcp_query_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mcp_query_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mcp_query_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mcp_query_log_id_seq OWNED BY public.mcp_query_log.id;


--
-- Name: mcp_refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mcp_refresh_tokens (
    token_hash character varying(128) NOT NULL,
    email character varying(255) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mql_candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mql_candidates (
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


--
-- Name: mql_candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mql_candidates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mql_candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mql_candidates_id_seq OWNED BY public.mql_candidates.id;


--
-- Name: novo_funil_pipedrive; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.novo_funil_pipedrive (
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


--
-- Name: pipedrive_deals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_deals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_deals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_deals_id_seq OWNED BY public.pipedrive_deals.id;


--
-- Name: pipedrive_write_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipedrive_write_log (
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


--
-- Name: pipedrive_write_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipedrive_write_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipedrive_write_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipedrive_write_log_id_seq OWNED BY public.pipedrive_write_log.id;


--
-- Name: pipeline_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_runs (
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


--
-- Name: pipeline_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pipeline_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pipeline_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pipeline_runs_id_seq OWNED BY public.pipeline_runs.id;


--
-- Name: platform_sync_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_sync_state (
    key character varying(64) NOT NULL,
    last_sync_at timestamp with time zone,
    last_full_sync_at timestamp with time zone
);


--
-- Name: system_prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_prompts (
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


--
-- Name: system_prompts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_prompts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.system_prompts_id_seq OWNED BY public.system_prompts.id;


--
-- Name: ui_access_grant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ui_access_grant (
    email text NOT NULL,
    display_name text DEFAULT ''::text NOT NULL,
    role text DEFAULT 'operator'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    added_by text DEFAULT ''::text NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ui_access_grant_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'ops'::text, 'operator'::text])))
);


--
-- Name: uploaded_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploaded_files (
    id bigint NOT NULL,
    filename character varying(255) NOT NULL,
    content_type character varying(100) NOT NULL,
    file_data bytea NOT NULL,
    file_size integer NOT NULL,
    extracted_text text,
    uploaded_at timestamp with time zone DEFAULT now()
);


--
-- Name: uploaded_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uploaded_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploaded_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uploaded_files_id_seq OWNED BY public.uploaded_files.id;


--
-- Name: user_activity_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_activity_log (
    id bigint NOT NULL,
    user_id character varying(200) NOT NULL,
    session_id character varying(100) DEFAULT ''::character varying NOT NULL,
    event_type character varying(50) NOT NULL,
    event_data jsonb,
    ip_address character varying(45),
    user_agent character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_activity_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_activity_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_activity_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_activity_log_id_seq OWNED BY public.user_activity_log.id;


--
-- Name: user_favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_favorites (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    jd_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_favorites_id_seq OWNED BY public.user_favorites.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(50) NOT NULL,
    hashed_password character varying(200) NOT NULL,
    scope character varying(20) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: ac_contact_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ac_contact_messages ALTER COLUMN id SET DEFAULT nextval('public.ac_contact_messages_id_seq'::regclass);


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: allocation_history_shortlist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_history_shortlist ALTER COLUMN id SET DEFAULT nextval('public.allocation_history_shortlist_id_seq'::regclass);


--
-- Name: attractiveness_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attractiveness_snapshots ALTER COLUMN id SET DEFAULT nextval('public.attractiveness_snapshots_id_seq'::regclass);


--
-- Name: backtest_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backtest_jobs ALTER COLUMN id SET DEFAULT nextval('public.backtest_jobs_id_seq'::regclass);


--
-- Name: benchmark_market_cache id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benchmark_market_cache ALTER COLUMN id SET DEFAULT nextval('public.benchmark_market_cache_id_seq'::regclass);


--
-- Name: benchmark_qa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benchmark_qa ALTER COLUMN id SET DEFAULT nextval('public.benchmark_qa_id_seq'::regclass);


--
-- Name: chief_career_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_career_history ALTER COLUMN id SET DEFAULT nextval('public.chief_career_history_id_seq'::regclass);


--
-- Name: chief_contextual_qa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_contextual_qa ALTER COLUMN id SET DEFAULT nextval('public.chief_contextual_qa_id_seq'::regclass);


--
-- Name: chief_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_embeddings ALTER COLUMN id SET DEFAULT nextval('public.chief_embeddings_id_seq'::regclass);


--
-- Name: chief_enrichment_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_enrichment_history ALTER COLUMN id SET DEFAULT nextval('public.chief_enrichment_history_id_seq'::regclass);


--
-- Name: chief_field_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_field_history ALTER COLUMN id SET DEFAULT nextval('public.chief_field_history_id_seq'::regclass);


--
-- Name: chief_improvement_event id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_improvement_event ALTER COLUMN id SET DEFAULT nextval('public.chief_improvement_event_id_seq'::regclass);


--
-- Name: chief_laudo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_laudo ALTER COLUMN id SET DEFAULT nextval('public.chief_laudo_id_seq'::regclass);


--
-- Name: chief_perfil_perguntas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_perfil_perguntas ALTER COLUMN id SET DEFAULT nextval('public.chief_perfil_perguntas_id_seq'::regclass);


--
-- Name: chief_platform_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_platform_history ALTER COLUMN id SET DEFAULT nextval('public.chief_platform_history_id_seq'::regclass);


--
-- Name: chief_rerank_cache id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_rerank_cache ALTER COLUMN id SET DEFAULT nextval('public.chief_rerank_cache_id_seq'::regclass);


--
-- Name: chief_reverse_matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_reverse_matches ALTER COLUMN id SET DEFAULT nextval('public.chief_reverse_matches_id_seq'::regclass);


--
-- Name: chief_reverse_profile id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_reverse_profile ALTER COLUMN id SET DEFAULT nextval('public.chief_reverse_profile_id_seq'::regclass);


--
-- Name: chief_snapshot_before_op id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_snapshot_before_op ALTER COLUMN id SET DEFAULT nextval('public.chief_snapshot_before_op_id_seq'::regclass);


--
-- Name: chief_stimulus_event id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_stimulus_event ALTER COLUMN id SET DEFAULT nextval('public.chief_stimulus_event_id_seq'::regclass);


--
-- Name: chiefs_platform id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_platform ALTER COLUMN id SET DEFAULT nextval('public.chiefs_platform_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: deal_enrichment_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_enrichment_jobs ALTER COLUMN id SET DEFAULT nextval('public.deal_enrichment_jobs_id_seq'::regclass);


--
-- Name: deal_enrichments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_enrichments ALTER COLUMN id SET DEFAULT nextval('public.deal_enrichments_id_seq'::regclass);


--
-- Name: deal_sales_ops id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_sales_ops ALTER COLUMN id SET DEFAULT nextval('public.deal_sales_ops_id_seq'::regclass);


--
-- Name: governance_conflicts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governance_conflicts ALTER COLUMN id SET DEFAULT nextval('public.governance_conflicts_id_seq'::regclass);


--
-- Name: ingestion_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_logs ALTER COLUMN id SET DEFAULT nextval('public.ingestion_logs_id_seq'::regclass);


--
-- Name: iqp_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iqp_snapshots ALTER COLUMN id SET DEFAULT nextval('public.iqp_snapshots_id_seq'::regclass);


--
-- Name: jd_briefing_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_briefing_embeddings ALTER COLUMN id SET DEFAULT nextval('public.jd_briefing_embeddings_id_seq'::regclass);


--
-- Name: jd_chief_alerts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_alerts ALTER COLUMN id SET DEFAULT nextval('public.jd_chief_alerts_id_seq'::regclass);


--
-- Name: jd_chief_match_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_match_comments ALTER COLUMN id SET DEFAULT nextval('public.jd_chief_match_comments_id_seq'::regclass);


--
-- Name: jd_chief_stages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_stages ALTER COLUMN id SET DEFAULT nextval('public.jd_chief_stages_id_seq'::regclass);


--
-- Name: jd_external_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_external_candidates ALTER COLUMN id SET DEFAULT nextval('public.jd_external_candidates_id_seq'::regclass);


--
-- Name: jd_extracted_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_extracted_metadata ALTER COLUMN id SET DEFAULT nextval('public.jd_extracted_metadata_id_seq'::regclass);


--
-- Name: jd_list_quality id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_list_quality ALTER COLUMN id SET DEFAULT nextval('public.jd_list_quality_id_seq'::regclass);


--
-- Name: jd_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_results ALTER COLUMN id SET DEFAULT nextval('public.jd_results_id_seq'::regclass);


--
-- Name: job_descriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_descriptions ALTER COLUMN id SET DEFAULT nextval('public.job_descriptions_id_seq'::regclass);


--
-- Name: job_embeddings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_embeddings ALTER COLUMN id SET DEFAULT nextval('public.job_embeddings_id_seq'::regclass);


--
-- Name: mcp_query_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mcp_query_log ALTER COLUMN id SET DEFAULT nextval('public.mcp_query_log_id_seq'::regclass);


--
-- Name: mql_candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mql_candidates ALTER COLUMN id SET DEFAULT nextval('public.mql_candidates_id_seq'::regclass);


--
-- Name: pipedrive_deals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deals ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_deals_id_seq'::regclass);


--
-- Name: pipedrive_write_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_write_log ALTER COLUMN id SET DEFAULT nextval('public.pipedrive_write_log_id_seq'::regclass);


--
-- Name: pipeline_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs ALTER COLUMN id SET DEFAULT nextval('public.pipeline_runs_id_seq'::regclass);


--
-- Name: system_prompts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_prompts ALTER COLUMN id SET DEFAULT nextval('public.system_prompts_id_seq'::regclass);


--
-- Name: uploaded_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_files ALTER COLUMN id SET DEFAULT nextval('public.uploaded_files_id_seq'::regclass);


--
-- Name: user_activity_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity_log ALTER COLUMN id SET DEFAULT nextval('public.user_activity_log_id_seq'::regclass);


--
-- Name: user_favorites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorites ALTER COLUMN id SET DEFAULT nextval('public.user_favorites_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ac_campaigns ac_campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ac_campaigns
    ADD CONSTRAINT ac_campaigns_pkey PRIMARY KEY (id);


--
-- Name: ac_contact_messages ac_contact_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ac_contact_messages
    ADD CONSTRAINT ac_contact_messages_pkey PRIMARY KEY (id);


--
-- Name: ac_contacts ac_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ac_contacts
    ADD CONSTRAINT ac_contacts_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: allocation_history allocation_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_history
    ADD CONSTRAINT allocation_history_pkey PRIMARY KEY (startup_ad_id);


--
-- Name: allocation_history_shortlist allocation_history_shortlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_history_shortlist
    ADD CONSTRAINT allocation_history_shortlist_pkey PRIMARY KEY (id);


--
-- Name: attractiveness_snapshots attractiveness_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attractiveness_snapshots
    ADD CONSTRAINT attractiveness_snapshots_pkey PRIMARY KEY (id);


--
-- Name: backtest_jobs backtest_jobs_job_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backtest_jobs
    ADD CONSTRAINT backtest_jobs_job_id_key UNIQUE (job_id);


--
-- Name: backtest_jobs backtest_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backtest_jobs
    ADD CONSTRAINT backtest_jobs_pkey PRIMARY KEY (id);


--
-- Name: benchmark_market_cache benchmark_market_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benchmark_market_cache
    ADD CONSTRAINT benchmark_market_cache_pkey PRIMARY KEY (id);


--
-- Name: benchmark_qa benchmark_qa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.benchmark_qa
    ADD CONSTRAINT benchmark_qa_pkey PRIMARY KEY (id);


--
-- Name: ca_acquittances ca_acquittances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_acquittances
    ADD CONSTRAINT ca_acquittances_pkey PRIMARY KEY (id);


--
-- Name: ca_categories ca_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_categories
    ADD CONSTRAINT ca_categories_pkey PRIMARY KEY (id);


--
-- Name: ca_contracts ca_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_contracts
    ADD CONSTRAINT ca_contracts_pkey PRIMARY KEY (id);


--
-- Name: ca_cost_centers ca_cost_centers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_cost_centers
    ADD CONSTRAINT ca_cost_centers_pkey PRIMARY KEY (id);


--
-- Name: ca_dre_categories ca_dre_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_dre_categories
    ADD CONSTRAINT ca_dre_categories_pkey PRIMARY KEY (id);


--
-- Name: ca_financial_accounts ca_financial_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_accounts
    ADD CONSTRAINT ca_financial_accounts_pkey PRIMARY KEY (id);


--
-- Name: ca_financial_events ca_financial_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_financial_events
    ADD CONSTRAINT ca_financial_events_pkey PRIMARY KEY (id);


--
-- Name: ca_people ca_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_people
    ADD CONSTRAINT ca_people_pkey PRIMARY KEY (id);


--
-- Name: ca_sales ca_sales_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sales
    ADD CONSTRAINT ca_sales_pkey PRIMARY KEY (id);


--
-- Name: ca_sellers ca_sellers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_sellers
    ADD CONSTRAINT ca_sellers_pkey PRIMARY KEY (id);


--
-- Name: ca_service_invoices ca_service_invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_service_invoices
    ADD CONSTRAINT ca_service_invoices_pkey PRIMARY KEY (id);


--
-- Name: chief_career_history chief_career_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_career_history
    ADD CONSTRAINT chief_career_history_pkey PRIMARY KEY (id);


--
-- Name: chief_contextual_qa chief_contextual_qa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_contextual_qa
    ADD CONSTRAINT chief_contextual_qa_pkey PRIMARY KEY (id);


--
-- Name: chief_embeddings chief_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_embeddings
    ADD CONSTRAINT chief_embeddings_pkey PRIMARY KEY (id);


--
-- Name: chief_enrichment_history chief_enrichment_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_enrichment_history
    ADD CONSTRAINT chief_enrichment_history_pkey PRIMARY KEY (id);


--
-- Name: chief_field_history chief_field_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_field_history
    ADD CONSTRAINT chief_field_history_pkey PRIMARY KEY (id);


--
-- Name: chief_improvement_event chief_improvement_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_improvement_event
    ADD CONSTRAINT chief_improvement_event_pkey PRIMARY KEY (id);


--
-- Name: chief_laudo_modal_state chief_laudo_modal_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_laudo_modal_state
    ADD CONSTRAINT chief_laudo_modal_state_pkey PRIMARY KEY (chief_id);


--
-- Name: chief_laudo chief_laudo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_laudo
    ADD CONSTRAINT chief_laudo_pkey PRIMARY KEY (id);


--
-- Name: chief_perfil_perguntas chief_perfil_perguntas_chief_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_perfil_perguntas
    ADD CONSTRAINT chief_perfil_perguntas_chief_id_key UNIQUE (chief_id);


--
-- Name: chief_perfil_perguntas chief_perfil_perguntas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_perfil_perguntas
    ADD CONSTRAINT chief_perfil_perguntas_pkey PRIMARY KEY (id);


--
-- Name: chief_platform_history chief_platform_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_platform_history
    ADD CONSTRAINT chief_platform_history_pkey PRIMARY KEY (id);


--
-- Name: chief_rerank_cache chief_rerank_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_rerank_cache
    ADD CONSTRAINT chief_rerank_cache_pkey PRIMARY KEY (id);


--
-- Name: chief_reverse_matches chief_reverse_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_reverse_matches
    ADD CONSTRAINT chief_reverse_matches_pkey PRIMARY KEY (id);


--
-- Name: chief_reverse_profile chief_reverse_profile_chief_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_reverse_profile
    ADD CONSTRAINT chief_reverse_profile_chief_id_key UNIQUE (chief_id);


--
-- Name: chief_reverse_profile chief_reverse_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_reverse_profile
    ADD CONSTRAINT chief_reverse_profile_pkey PRIMARY KEY (id);


--
-- Name: chief_snapshot_before_op chief_snapshot_before_op_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_snapshot_before_op
    ADD CONSTRAINT chief_snapshot_before_op_pkey PRIMARY KEY (id);


--
-- Name: chief_stimulus_event chief_stimulus_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_stimulus_event
    ADD CONSTRAINT chief_stimulus_event_pkey PRIMARY KEY (id);


--
-- Name: chiefs_ativos chiefs_ativos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_ativos
    ADD CONSTRAINT chiefs_ativos_pkey PRIMARY KEY (id);


--
-- Name: chiefs_platform chiefs_platform_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_platform
    ADD CONSTRAINT chiefs_platform_pkey PRIMARY KEY (id);


--
-- Name: chiefs_todos chiefs_todos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chiefs_todos
    ADD CONSTRAINT chiefs_todos_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: deal_enrichment_jobs deal_enrichment_jobs_job_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_enrichment_jobs
    ADD CONSTRAINT deal_enrichment_jobs_job_id_key UNIQUE (job_id);


--
-- Name: deal_enrichment_jobs deal_enrichment_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_enrichment_jobs
    ADD CONSTRAINT deal_enrichment_jobs_pkey PRIMARY KEY (id);


--
-- Name: deal_enrichments deal_enrichments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_enrichments
    ADD CONSTRAINT deal_enrichments_pkey PRIMARY KEY (id);


--
-- Name: deal_sales_ops deal_sales_ops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_sales_ops
    ADD CONSTRAINT deal_sales_ops_pkey PRIMARY KEY (id);


--
-- Name: governance_conflicts governance_conflicts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.governance_conflicts
    ADD CONSTRAINT governance_conflicts_pkey PRIMARY KEY (id);


--
-- Name: ingestion_logs ingestion_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_logs
    ADD CONSTRAINT ingestion_logs_pkey PRIMARY KEY (id);


--
-- Name: ingestion_logs ingestion_logs_run_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_logs
    ADD CONSTRAINT ingestion_logs_run_id_key UNIQUE (run_id);


--
-- Name: iqp_snapshots iqp_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.iqp_snapshots
    ADD CONSTRAINT iqp_snapshots_pkey PRIMARY KEY (id);


--
-- Name: jd_briefing_embeddings jd_briefing_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_briefing_embeddings
    ADD CONSTRAINT jd_briefing_embeddings_pkey PRIMARY KEY (id);


--
-- Name: jd_chief_alerts jd_chief_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_alerts
    ADD CONSTRAINT jd_chief_alerts_pkey PRIMARY KEY (id);


--
-- Name: jd_chief_match_comments jd_chief_match_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_match_comments
    ADD CONSTRAINT jd_chief_match_comments_pkey PRIMARY KEY (id);


--
-- Name: jd_chief_stages jd_chief_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_stages
    ADD CONSTRAINT jd_chief_stages_pkey PRIMARY KEY (id);


--
-- Name: jd_external_candidates jd_external_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_external_candidates
    ADD CONSTRAINT jd_external_candidates_pkey PRIMARY KEY (id);


--
-- Name: jd_extracted_metadata jd_extracted_metadata_jd_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_jd_id_key UNIQUE (jd_id);


--
-- Name: jd_extracted_metadata jd_extracted_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_pkey PRIMARY KEY (id);


--
-- Name: jd_list_quality jd_list_quality_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_list_quality
    ADD CONSTRAINT jd_list_quality_pkey PRIMARY KEY (id);


--
-- Name: jd_results jd_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_results
    ADD CONSTRAINT jd_results_pkey PRIMARY KEY (id);


--
-- Name: job_descriptions job_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_descriptions
    ADD CONSTRAINT job_descriptions_pkey PRIMARY KEY (id);


--
-- Name: job_embeddings job_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_embeddings
    ADD CONSTRAINT job_embeddings_pkey PRIMARY KEY (id);


--
-- Name: mcp_query_log mcp_query_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mcp_query_log
    ADD CONSTRAINT mcp_query_log_pkey PRIMARY KEY (id);


--
-- Name: mcp_refresh_tokens mcp_refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mcp_refresh_tokens
    ADD CONSTRAINT mcp_refresh_tokens_pkey PRIMARY KEY (token_hash);


--
-- Name: mql_candidates mql_candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mql_candidates
    ADD CONSTRAINT mql_candidates_pkey PRIMARY KEY (id);


--
-- Name: novo_funil_pipedrive novo_funil_pipedrive_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.novo_funil_pipedrive
    ADD CONSTRAINT novo_funil_pipedrive_pkey PRIMARY KEY (deal_id);


--
-- Name: pipedrive_deals pipedrive_deals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_deals
    ADD CONSTRAINT pipedrive_deals_pkey PRIMARY KEY (id);


--
-- Name: pipedrive_write_log pipedrive_write_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipedrive_write_log
    ADD CONSTRAINT pipedrive_write_log_pkey PRIMARY KEY (id);


--
-- Name: pipeline_runs pipeline_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_runs
    ADD CONSTRAINT pipeline_runs_pkey PRIMARY KEY (id);


--
-- Name: platform_sync_state platform_sync_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_sync_state
    ADD CONSTRAINT platform_sync_state_pkey PRIMARY KEY (key);


--
-- Name: system_prompts system_prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_prompts
    ADD CONSTRAINT system_prompts_pkey PRIMARY KEY (id);


--
-- Name: ui_access_grant ui_access_grant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ui_access_grant
    ADD CONSTRAINT ui_access_grant_pkey PRIMARY KEY (email);


--
-- Name: uploaded_files uploaded_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploaded_files
    ADD CONSTRAINT uploaded_files_pkey PRIMARY KEY (id);


--
-- Name: ac_contact_messages uq_ac_contact_messages_contact_campaign_sent; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ac_contact_messages
    ADD CONSTRAINT uq_ac_contact_messages_contact_campaign_sent UNIQUE (ac_contact_id, ac_campaign_id, sent_at);


--
-- Name: allocation_history_shortlist uq_allocation_history_shortlist_ad_chief; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_history_shortlist
    ADD CONSTRAINT uq_allocation_history_shortlist_ad_chief UNIQUE (startup_ad_id, chief_id);


--
-- Name: chief_career_history uq_career_chief_company_role_start; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_career_history
    ADD CONSTRAINT uq_career_chief_company_role_start UNIQUE (chief_id, company, role, start_date);


--
-- Name: chief_embeddings uq_chief_embeddings_chief_field_model_chunk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_embeddings
    ADD CONSTRAINT uq_chief_embeddings_chief_field_model_chunk UNIQUE (chief_id, field_name, model_version, chunk_index);


--
-- Name: chief_laudo uq_chief_laudo_chief_curriculo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_laudo
    ADD CONSTRAINT uq_chief_laudo_chief_curriculo UNIQUE (chief_id, curriculo_id);


--
-- Name: chief_rerank_cache uq_chief_rerank_fact; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_rerank_cache
    ADD CONSTRAINT uq_chief_rerank_fact UNIQUE (chief_id, fact_key);


--
-- Name: chief_improvement_event uq_improvement_event; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_improvement_event
    ADD CONSTRAINT uq_improvement_event UNIQUE (source, source_ref);


--
-- Name: jd_briefing_embeddings uq_jd_briefing_embeddings_jd_field_model; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_briefing_embeddings
    ADD CONSTRAINT uq_jd_briefing_embeddings_jd_field_model UNIQUE (jd_id, field_name, model_version);


--
-- Name: jd_chief_alerts uq_jd_chief_alerts_jd_chief; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_chief_alerts
    ADD CONSTRAINT uq_jd_chief_alerts_jd_chief UNIQUE (jd_id, chief_id);


--
-- Name: job_embeddings uq_job_embeddings_job_field_model; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_embeddings
    ADD CONSTRAINT uq_job_embeddings_job_field_model UNIQUE (job_id, field_name, model_version);


--
-- Name: mql_candidates uq_mql_candidates_cnpj_person; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mql_candidates
    ADD CONSTRAINT uq_mql_candidates_cnpj_person UNIQUE (cnpj, person_name);


--
-- Name: chief_platform_history uq_platform_history_event; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_platform_history
    ADD CONSTRAINT uq_platform_history_event UNIQUE (chief_id, event_type, source_event_id);


--
-- Name: chief_stimulus_event uq_stimulus_event; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_stimulus_event
    ADD CONSTRAINT uq_stimulus_event UNIQUE (stimulus_type, stimulus_ref, chief_id);


--
-- Name: system_prompts uq_system_prompts_key_version; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_prompts
    ADD CONSTRAINT uq_system_prompts_key_version UNIQUE (prompt_key, version);


--
-- Name: user_favorites uq_user_favorites_user_jd; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorites
    ADD CONSTRAINT uq_user_favorites_user_jd UNIQUE (username, jd_id);


--
-- Name: user_activity_log user_activity_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_activity_log
    ADD CONSTRAINT user_activity_log_pkey PRIMARY KEY (id);


--
-- Name: user_favorites user_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_favorites
    ADD CONSTRAINT user_favorites_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_deal_enrichments_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_active ON public.deal_enrichments USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_deal_enrichments_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_company ON public.deal_enrichments USING btree (company);


--
-- Name: idx_deal_enrichments_deal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_deal_id ON public.deal_enrichments USING btree (deal_id);


--
-- Name: idx_deal_enrichments_latest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_latest ON public.deal_enrichments USING btree (deal_id, enrichment_version DESC);


--
-- Name: idx_deal_enrichments_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_score ON public.deal_enrichments USING btree (score_total DESC);


--
-- Name: idx_deal_enrichments_tier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_enrichments_tier ON public.deal_enrichments USING btree (tier);


--
-- Name: idx_deal_sales_ops_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_active ON public.deal_sales_ops USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_deal_sales_ops_area; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_area ON public.deal_sales_ops USING btree (area);


--
-- Name: idx_deal_sales_ops_conta; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_conta ON public.deal_sales_ops USING btree (conta);


--
-- Name: idx_deal_sales_ops_deal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_deal_id ON public.deal_sales_ops USING btree (deal_id);


--
-- Name: idx_deal_sales_ops_decisor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_decisor ON public.deal_sales_ops USING btree (decisor_comercial);


--
-- Name: idx_deal_sales_ops_estagio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_estagio ON public.deal_sales_ops USING btree (estagio);


--
-- Name: idx_deal_sales_ops_latest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_latest ON public.deal_sales_ops USING btree (deal_id, version DESC);


--
-- Name: idx_deal_sales_ops_origem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_origem ON public.deal_sales_ops USING btree (origem);


--
-- Name: idx_deal_sales_ops_setor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deal_sales_ops_setor ON public.deal_sales_ops USING btree (setor);


--
-- Name: idx_jd_list_quality_consultor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jd_list_quality_consultor ON public.jd_list_quality USING btree (consultor_responsavel);


--
-- Name: idx_jd_list_quality_jd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jd_list_quality_jd ON public.jd_list_quality USING btree (job_description_id);


--
-- Name: idx_nfp_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_owner ON public.novo_funil_pipedrive USING btree (owner_name);


--
-- Name: idx_nfp_pendentes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_pendentes ON public.novo_funil_pipedrive USING gin (dados_pendentes);


--
-- Name: idx_nfp_resultado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_resultado ON public.novo_funil_pipedrive USING btree (resultado);


--
-- Name: idx_nfp_stage_novo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_stage_novo ON public.novo_funil_pipedrive USING btree (stage_novo);


--
-- Name: idx_nfp_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_status ON public.novo_funil_pipedrive USING btree (status);


--
-- Name: idx_nfp_zona; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nfp_zona ON public.novo_funil_pipedrive USING btree (zona);


--
-- Name: ix_ac_campaigns_ac_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_campaigns_ac_updated_at ON public.ac_campaigns USING btree (ac_updated_at);


--
-- Name: ix_ac_campaigns_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_campaigns_sent_at ON public.ac_campaigns USING btree (sent_at);


--
-- Name: ix_ac_campaigns_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_campaigns_status ON public.ac_campaigns USING btree (status);


--
-- Name: ix_ac_contact_messages_ac_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contact_messages_ac_campaign_id ON public.ac_contact_messages USING btree (ac_campaign_id);


--
-- Name: ix_ac_contact_messages_ac_contact_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contact_messages_ac_contact_id ON public.ac_contact_messages USING btree (ac_contact_id);


--
-- Name: ix_ac_contact_messages_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contact_messages_chief_id ON public.ac_contact_messages USING btree (chief_id);


--
-- Name: ix_ac_contact_messages_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contact_messages_sent_at ON public.ac_contact_messages USING btree (sent_at);


--
-- Name: ix_ac_contacts_ac_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contacts_ac_updated_at ON public.ac_contacts USING btree (ac_updated_at);


--
-- Name: ix_ac_contacts_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contacts_chief_id ON public.ac_contacts USING btree (chief_id);


--
-- Name: ix_ac_contacts_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contacts_email_lower ON public.ac_contacts USING btree (lower(email));


--
-- Name: ix_ac_contacts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ac_contacts_status ON public.ac_contacts USING btree (status);


--
-- Name: ix_accounts_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_accounts_company_id ON public.accounts USING btree (company_id);


--
-- Name: ix_accounts_startup_ads_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_accounts_startup_ads_gin ON public.accounts USING gin (startup_ads);


--
-- Name: ix_activity_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_activity_created_at ON public.user_activity_log USING btree (created_at);


--
-- Name: ix_activity_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_activity_event_type ON public.user_activity_log USING btree (event_type);


--
-- Name: ix_activity_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_activity_user_id ON public.user_activity_log USING btree (user_id);


--
-- Name: ix_allocation_history_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_allocation_history_chief_id ON public.allocation_history USING btree (chief_id);


--
-- Name: ix_allocation_history_excluded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_allocation_history_excluded ON public.allocation_history USING btree (excluded);


--
-- Name: ix_allocation_history_shortlist_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_allocation_history_shortlist_chief_id ON public.allocation_history_shortlist USING btree (chief_id);


--
-- Name: ix_allocation_history_shortlist_startup_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_allocation_history_shortlist_startup_ad_id ON public.allocation_history_shortlist USING btree (startup_ad_id);


--
-- Name: ix_att_snapshots_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_att_snapshots_chief_id ON public.attractiveness_snapshots USING btree (chief_id);


--
-- Name: ix_att_snapshots_snapshot_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_att_snapshots_snapshot_name ON public.attractiveness_snapshots USING btree (snapshot_name);


--
-- Name: ix_backtest_jobs_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_backtest_jobs_job_id ON public.backtest_jobs USING btree (job_id);


--
-- Name: ix_backtest_jobs_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_backtest_jobs_status_created ON public.backtest_jobs USING btree (status, created_at DESC);


--
-- Name: ix_benchmark_market_cache_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_benchmark_market_cache_expires ON public.benchmark_market_cache USING btree (expires_at);


--
-- Name: ix_benchmark_qa_approved; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_benchmark_qa_approved ON public.benchmark_qa USING btree (chief_id) WHERE ((quality_score)::text = 'approved'::text);


--
-- Name: ix_ca_acquittances_conta_financeira_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_acquittances_conta_financeira_uuid ON public.ca_acquittances USING btree (conta_financeira_uuid);


--
-- Name: ix_ca_acquittances_data_baixa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_acquittances_data_baixa ON public.ca_acquittances USING btree (data_baixa);


--
-- Name: ix_ca_acquittances_parcela_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_acquittances_parcela_uuid ON public.ca_acquittances USING btree (parcela_uuid);


--
-- Name: ix_ca_categories_categoria_pai; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_categories_categoria_pai ON public.ca_categories USING btree (categoria_pai);


--
-- Name: ix_ca_categories_entrada_dre; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_categories_entrada_dre ON public.ca_categories USING btree (entrada_dre);


--
-- Name: ix_ca_categories_nome_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_categories_nome_lower ON public.ca_categories USING btree (lower(nome));


--
-- Name: ix_ca_categories_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_categories_tipo ON public.ca_categories USING btree (tipo);


--
-- Name: ix_ca_contracts_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_contracts_cliente_uuid ON public.ca_contracts USING btree (cliente_uuid);


--
-- Name: ix_ca_contracts_data_alteracao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_contracts_data_alteracao ON public.ca_contracts USING btree (data_alteracao);


--
-- Name: ix_ca_contracts_data_inicio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_contracts_data_inicio ON public.ca_contracts USING btree (data_inicio);


--
-- Name: ix_ca_contracts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_contracts_status ON public.ca_contracts USING btree (status);


--
-- Name: ix_ca_contracts_vendedor_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_contracts_vendedor_uuid ON public.ca_contracts USING btree (vendedor_uuid);


--
-- Name: ix_ca_cost_centers_nome_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_cost_centers_nome_lower ON public.ca_cost_centers USING btree (lower(nome));


--
-- Name: ix_ca_cost_centers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_cost_centers_status ON public.ca_cost_centers USING btree (status);


--
-- Name: ix_ca_dre_categories_categoria_uuids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_dre_categories_categoria_uuids ON public.ca_dre_categories USING gin (categoria_uuids);


--
-- Name: ix_ca_dre_categories_codigo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_dre_categories_codigo ON public.ca_dre_categories USING btree (codigo);


--
-- Name: ix_ca_dre_categories_parent_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_dre_categories_parent_uuid ON public.ca_dre_categories USING btree (parent_uuid);


--
-- Name: ix_ca_dre_categories_totalizador; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_dre_categories_totalizador ON public.ca_dre_categories USING btree (indica_totalizador);


--
-- Name: ix_ca_financial_accounts_nome_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_accounts_nome_lower ON public.ca_financial_accounts USING btree (lower(nome));


--
-- Name: ix_ca_financial_accounts_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_accounts_status ON public.ca_financial_accounts USING btree (status);


--
-- Name: ix_ca_financial_accounts_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_accounts_tipo ON public.ca_financial_accounts USING btree (tipo);


--
-- Name: ix_ca_financial_events_data_competencia; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_events_data_competencia ON public.ca_financial_events USING btree (data_competencia);


--
-- Name: ix_ca_financial_events_data_vencimento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_events_data_vencimento ON public.ca_financial_events USING btree (data_vencimento);


--
-- Name: ix_ca_financial_events_pessoa_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_events_pessoa_uuid ON public.ca_financial_events USING btree (pessoa_uuid);


--
-- Name: ix_ca_financial_events_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_events_status ON public.ca_financial_events USING btree (status);


--
-- Name: ix_ca_financial_events_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_financial_events_tipo ON public.ca_financial_events USING btree (tipo);


--
-- Name: ix_ca_people_ativo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_people_ativo ON public.ca_people USING btree (ativo);


--
-- Name: ix_ca_people_documento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_people_documento ON public.ca_people USING btree (documento);


--
-- Name: ix_ca_people_nome_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_people_nome_lower ON public.ca_people USING btree (lower(nome));


--
-- Name: ix_ca_people_tipo_pessoa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_people_tipo_pessoa ON public.ca_people USING btree (tipo_pessoa);


--
-- Name: ix_ca_sales_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_cliente_uuid ON public.ca_sales USING btree (cliente_uuid);


--
-- Name: ix_ca_sales_contrato_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_contrato_uuid ON public.ca_sales USING btree (contrato_uuid);


--
-- Name: ix_ca_sales_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_data ON public.ca_sales USING btree (data);


--
-- Name: ix_ca_sales_data_alteracao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_data_alteracao ON public.ca_sales USING btree (data_alteracao);


--
-- Name: ix_ca_sales_situacao_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_situacao_nome ON public.ca_sales USING btree (situacao_nome);


--
-- Name: ix_ca_sales_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_status ON public.ca_sales USING btree (status);


--
-- Name: ix_ca_sales_vendedor_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sales_vendedor_uuid ON public.ca_sales USING btree (vendedor_uuid);


--
-- Name: ix_ca_sellers_documento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sellers_documento ON public.ca_sellers USING btree (documento);


--
-- Name: ix_ca_sellers_nome_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sellers_nome_lower ON public.ca_sellers USING btree (lower(nome));


--
-- Name: ix_ca_sellers_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_sellers_status ON public.ca_sellers USING btree (status);


--
-- Name: ix_ca_service_invoices_cliente_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_service_invoices_cliente_uuid ON public.ca_service_invoices USING btree (cliente_uuid);


--
-- Name: ix_ca_service_invoices_contrato_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_service_invoices_contrato_uuid ON public.ca_service_invoices USING btree (contrato_uuid);


--
-- Name: ix_ca_service_invoices_data_emissao; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_service_invoices_data_emissao ON public.ca_service_invoices USING btree (data_emissao);


--
-- Name: ix_ca_service_invoices_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_service_invoices_status ON public.ca_service_invoices USING btree (status);


--
-- Name: ix_ca_service_invoices_venda_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ca_service_invoices_venda_uuid ON public.ca_service_invoices USING btree (venda_uuid);


--
-- Name: ix_career_history_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_career_history_chief_id ON public.chief_career_history USING btree (chief_id);


--
-- Name: ix_chief_embeddings_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_embeddings_chief_id ON public.chief_embeddings USING btree (chief_id);


--
-- Name: ix_chief_embeddings_field_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_embeddings_field_name ON public.chief_embeddings USING btree (field_name);


--
-- Name: ix_chief_embeddings_hnsw_cosine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_embeddings_hnsw_cosine ON public.chief_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');


--
-- Name: ix_chief_enrichment_history_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_enrichment_history_chief_id ON public.chief_enrichment_history USING btree (chief_id);


--
-- Name: ix_chief_enrichment_history_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_enrichment_history_created ON public.chief_enrichment_history USING btree (created_at);


--
-- Name: ix_chief_field_history_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_field_history_chief_id ON public.chief_field_history USING btree (chief_id);


--
-- Name: ix_chief_laudo_chief; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_laudo_chief ON public.chief_laudo USING btree (chief_id);


--
-- Name: ix_chief_perfil_perguntas_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_perfil_perguntas_pending ON public.chief_perfil_perguntas USING btree (answers_at) WHERE ((answers IS NOT NULL) AND (answers_enriched_at IS NULL));


--
-- Name: ix_chief_rerank_cache_chief_fact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_rerank_cache_chief_fact ON public.chief_rerank_cache USING btree (chief_id, fact_key);


--
-- Name: ix_chief_rerank_cache_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_rerank_cache_chief_id ON public.chief_rerank_cache USING btree (chief_id);


--
-- Name: ix_chief_snapshot_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_snapshot_chief_id ON public.chief_snapshot_before_op USING btree (chief_id);


--
-- Name: ix_chief_snapshot_operation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chief_snapshot_operation ON public.chief_snapshot_before_op USING btree (operation);


--
-- Name: ix_chiefs_ativos_all_job_titles_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_all_job_titles_gin ON public.chiefs_ativos USING gin (all_job_titles);


--
-- Name: ix_chiefs_ativos_availability_status_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_availability_status_gin ON public.chiefs_ativos USING gin (availability_status);


--
-- Name: ix_chiefs_ativos_business_model_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_business_model_gin ON public.chiefs_ativos USING gin (business_model);


--
-- Name: ix_chiefs_ativos_business_moment_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_business_moment_gin ON public.chiefs_ativos USING gin (business_moment);


--
-- Name: ix_chiefs_ativos_company_profiles_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_company_profiles_gin ON public.chiefs_ativos USING gin (company_profiles);


--
-- Name: ix_chiefs_ativos_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_fts ON public.chiefs_ativos USING gin (to_tsvector('portuguese'::regconfig, ((((COALESCE(resume_experience, ''::text) || ' '::text) || (COALESCE(job_title, ''::character varying))::text) || ' '::text) || COALESCE(important_cases_connecting_customers, ''::text))));


--
-- Name: ix_chiefs_ativos_hard_skills_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_hard_skills_gin ON public.chiefs_ativos USING gin (hard_skills);


--
-- Name: ix_chiefs_ativos_industries_experience_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_industries_experience_gin ON public.chiefs_ativos USING gin (industries_experience);


--
-- Name: ix_chiefs_ativos_main_companies_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_main_companies_gin ON public.chiefs_ativos USING gin (main_companies);


--
-- Name: ix_chiefs_ativos_others_language_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_others_language_gin ON public.chiefs_ativos USING gin (others_language);


--
-- Name: ix_chiefs_ativos_sector_exp_detail_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_sector_exp_detail_gin ON public.chiefs_ativos USING gin (sector_experience_detail);


--
-- Name: ix_chiefs_ativos_sectors_experience_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_sectors_experience_gin ON public.chiefs_ativos USING gin (sectors_experience);


--
-- Name: ix_chiefs_ativos_tier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_tier ON public.chiefs_ativos USING btree (tier);


--
-- Name: ix_chiefs_ativos_work_model_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_ativos_work_model_gin ON public.chiefs_ativos USING gin (work_model);


--
-- Name: ix_chiefs_platform_email_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_platform_email_norm ON public.chiefs_platform USING btree (lower(TRIM(BOTH FROM email)));


--
-- Name: ix_chiefs_todos_all_job_titles_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_all_job_titles_gin ON public.chiefs_todos USING gin (all_job_titles);


--
-- Name: ix_chiefs_todos_availability_status_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_availability_status_gin ON public.chiefs_todos USING gin (availability_status);


--
-- Name: ix_chiefs_todos_business_model_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_business_model_gin ON public.chiefs_todos USING gin (business_model);


--
-- Name: ix_chiefs_todos_business_moment_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_business_moment_gin ON public.chiefs_todos USING gin (business_moment);


--
-- Name: ix_chiefs_todos_company_profiles_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_company_profiles_gin ON public.chiefs_todos USING gin (company_profiles);


--
-- Name: ix_chiefs_todos_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_fts ON public.chiefs_todos USING gin (to_tsvector('portuguese'::regconfig, ((((COALESCE(resume_experience, ''::text) || ' '::text) || (COALESCE(job_title, ''::character varying))::text) || ' '::text) || COALESCE(important_cases_connecting_customers, ''::text))));


--
-- Name: ix_chiefs_todos_hard_skills_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_hard_skills_gin ON public.chiefs_todos USING gin (hard_skills);


--
-- Name: ix_chiefs_todos_industries_experience_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_industries_experience_gin ON public.chiefs_todos USING gin (industries_experience);


--
-- Name: ix_chiefs_todos_main_companies_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_main_companies_gin ON public.chiefs_todos USING gin (main_companies);


--
-- Name: ix_chiefs_todos_others_language_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_others_language_gin ON public.chiefs_todos USING gin (others_language);


--
-- Name: ix_chiefs_todos_sector_exp_detail_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_sector_exp_detail_gin ON public.chiefs_todos USING gin (sector_experience_detail);


--
-- Name: ix_chiefs_todos_sectors_experience_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_sectors_experience_gin ON public.chiefs_todos USING gin (sectors_experience);


--
-- Name: ix_chiefs_todos_work_model_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_chiefs_todos_work_model_gin ON public.chiefs_todos USING gin (work_model);


--
-- Name: ix_companies_name_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_companies_name_lower ON public.companies USING btree (lower(name));


--
-- Name: ix_companies_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_companies_slug ON public.companies USING btree (slug);


--
-- Name: ix_companies_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_companies_status ON public.companies USING btree (status);


--
-- Name: ix_companies_updated_at_remote; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_companies_updated_at_remote ON public.companies USING btree (updated_at_remote);


--
-- Name: ix_contextual_qa_chief_jd; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contextual_qa_chief_jd ON public.chief_contextual_qa USING btree (chief_id, jd_id);


--
-- Name: ix_contextual_qa_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contextual_qa_pending ON public.chief_contextual_qa USING btree (chief_id, status) WHERE ((status)::text = 'pending'::text);


--
-- Name: ix_deal_enrichment_jobs_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_deal_enrichment_jobs_job_id ON public.deal_enrichment_jobs USING btree (job_id);


--
-- Name: ix_deal_enrichment_jobs_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_deal_enrichment_jobs_status_created ON public.deal_enrichment_jobs USING btree (status, created_at DESC);


--
-- Name: ix_deal_enrichments_grade_band; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_deal_enrichments_grade_band ON public.deal_enrichments USING btree (grade_band) WHERE (grade_band IS NOT NULL);


--
-- Name: ix_governance_conflicts_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_governance_conflicts_chief_id ON public.governance_conflicts USING btree (chief_id);


--
-- Name: ix_governance_conflicts_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_governance_conflicts_detected_at ON public.governance_conflicts USING btree (detected_at);


--
-- Name: ix_governance_conflicts_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_governance_conflicts_type ON public.governance_conflicts USING btree (conflict_type);


--
-- Name: ix_improvement_event_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_improvement_event_chief_id ON public.chief_improvement_event USING btree (chief_id);


--
-- Name: ix_improvement_event_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_improvement_event_occurred ON public.chief_improvement_event USING btree (occurred_at);


--
-- Name: ix_improvement_event_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_improvement_event_source ON public.chief_improvement_event USING btree (source);


--
-- Name: ix_iqp_snapshots_name_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_iqp_snapshots_name_table ON public.iqp_snapshots USING btree (snapshot_name, table_name);


--
-- Name: ix_jd_briefing_embeddings_hnsw_cosine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_briefing_embeddings_hnsw_cosine ON public.jd_briefing_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');


--
-- Name: ix_jd_briefing_embeddings_jd_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_briefing_embeddings_jd_id ON public.jd_briefing_embeddings USING btree (jd_id);


--
-- Name: ix_jd_chief_alerts_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_chief_alerts_active ON public.jd_chief_alerts USING btree (jd_id) WHERE (resolved_at IS NULL);


--
-- Name: ix_jd_chief_alerts_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_chief_alerts_chief_id ON public.jd_chief_alerts USING btree (chief_id);


--
-- Name: ix_jd_chief_match_comments_chief; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_chief_match_comments_chief ON public.jd_chief_match_comments USING btree (jd_id, run_id, chief_id);


--
-- Name: ix_jd_chief_match_comments_rails_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_jd_chief_match_comments_rails_id ON public.jd_chief_match_comments USING btree (rails_comment_id);


--
-- Name: ix_jd_chief_stages_jd_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_chief_stages_jd_run ON public.jd_chief_stages USING btree (jd_id, run_id);


--
-- Name: ix_jd_chief_stages_one_chosen; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_jd_chief_stages_one_chosen ON public.jd_chief_stages USING btree (jd_id, run_id) WHERE is_chosen;


--
-- Name: ix_jd_chief_stages_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_chief_stages_stage ON public.jd_chief_stages USING btree (stage);


--
-- Name: ix_jd_external_candidates_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_external_candidates_active ON public.jd_external_candidates USING btree (jd_id) WHERE (is_deleted = false);


--
-- Name: ix_jd_meta_hard_skills_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_meta_hard_skills_gin ON public.jd_extracted_metadata USING gin (hard_skills_requeridas);


--
-- Name: ix_jd_meta_industrias_alvo_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_meta_industrias_alvo_gin ON public.jd_extracted_metadata USING gin (industrias_alvo);


--
-- Name: ix_jd_meta_setores_alvo_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_meta_setores_alvo_gin ON public.jd_extracted_metadata USING gin (setores_alvo);


--
-- Name: ix_jd_results_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_results_active ON public.jd_results USING btree (job_description_id, pipeline_run_id) WHERE (is_deleted = false);


--
-- Name: ix_jd_results_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_results_chief_id ON public.jd_results USING btree (chief_id);


--
-- Name: ix_jd_results_job_description_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_results_job_description_id ON public.jd_results USING btree (job_description_id);


--
-- Name: ix_jd_results_pipeline_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_jd_results_pipeline_run_id ON public.jd_results USING btree (pipeline_run_id);


--
-- Name: ix_job_descriptions_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_descriptions_created_at ON public.job_descriptions USING btree (created_at);


--
-- Name: ix_job_descriptions_is_test; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_descriptions_is_test ON public.job_descriptions USING btree (is_test) WHERE (is_test = true);


--
-- Name: ix_job_descriptions_jd_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_descriptions_jd_status ON public.job_descriptions USING btree (jd_status);


--
-- Name: ix_job_descriptions_outcome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_descriptions_outcome ON public.job_descriptions USING btree (outcome) WHERE (outcome IS NOT NULL);


--
-- Name: ix_job_descriptions_pipeline_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_descriptions_pipeline_status ON public.job_descriptions USING btree (pipeline_status);


--
-- Name: ix_job_embeddings_hnsw_cosine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_embeddings_hnsw_cosine ON public.job_embeddings USING hnsw (embedding public.vector_cosine_ops) WITH (m='16', ef_construction='128');


--
-- Name: ix_job_embeddings_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_job_embeddings_job_id ON public.job_embeddings USING btree (job_id);


--
-- Name: ix_mql_candidates_decisor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mql_candidates_decisor ON public.mql_candidates USING btree (decisor_comercial);


--
-- Name: ix_mql_candidates_origem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mql_candidates_origem ON public.mql_candidates USING btree (origem);


--
-- Name: ix_mql_candidates_pendencias; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mql_candidates_pendencias ON public.mql_candidates USING gin (dados_pendentes);


--
-- Name: ix_mql_candidates_setor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_mql_candidates_setor ON public.mql_candidates USING btree (setor);


--
-- Name: ix_pipedrive_deals_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipedrive_deals_deleted_at ON public.pipedrive_deals USING btree (deleted_at);


--
-- Name: ix_pipedrive_deals_person_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipedrive_deals_person_email ON public.pipedrive_deals USING btree (person_email);


--
-- Name: ix_pipedrive_deals_person_email_norm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipedrive_deals_person_email_norm ON public.pipedrive_deals USING btree (lower(TRIM(BOTH FROM person_email)));


--
-- Name: ix_pipedrive_deals_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipedrive_deals_status ON public.pipedrive_deals USING btree (status);


--
-- Name: ix_pipedrive_deals_updated_at_remote; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipedrive_deals_updated_at_remote ON public.pipedrive_deals USING btree (updated_at_remote);


--
-- Name: ix_pipeline_runs_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipeline_runs_job_id ON public.pipeline_runs USING btree (job_id);


--
-- Name: ix_pipeline_runs_run_id_phase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pipeline_runs_run_id_phase ON public.pipeline_runs USING btree (run_id, phase);


--
-- Name: ix_platform_history_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_platform_history_chief_id ON public.chief_platform_history USING btree (chief_id);


--
-- Name: ix_platform_history_occurred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_platform_history_occurred ON public.chief_platform_history USING btree (occurred_at);


--
-- Name: ix_reverse_matches_calculated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_reverse_matches_calculated_at ON public.chief_reverse_matches USING btree (calculated_at);


--
-- Name: ix_reverse_matches_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_reverse_matches_chief_id ON public.chief_reverse_matches USING btree (chief_id);


--
-- Name: ix_stimulus_event_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_stimulus_event_chief_id ON public.chief_stimulus_event USING btree (chief_id);


--
-- Name: ix_stimulus_event_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_stimulus_event_sent_at ON public.chief_stimulus_event USING btree (sent_at);


--
-- Name: ix_stimulus_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_stimulus_event_type ON public.chief_stimulus_event USING btree (stimulus_type);


--
-- Name: ix_ui_access_grant_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ui_access_grant_active ON public.ui_access_grant USING btree (is_active) WHERE (is_active = true);


--
-- Name: ix_user_favorites_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_user_favorites_username ON public.user_favorites USING btree (username);


--
-- Name: ix_users_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_users_username ON public.users USING btree (username);


--
-- Name: mcp_query_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mcp_query_log_created_at_idx ON public.mcp_query_log USING btree (created_at DESC);


--
-- Name: mcp_query_log_service_name_tool_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mcp_query_log_service_name_tool_name_idx ON public.mcp_query_log USING btree (service_name, tool_name);


--
-- Name: mcp_query_log_user_email_tool_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mcp_query_log_user_email_tool_name_idx ON public.mcp_query_log USING btree (user_email, tool_name);


--
-- Name: pipedrive_write_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipedrive_write_log_created_at_idx ON public.pipedrive_write_log USING btree (created_at DESC);


--
-- Name: pipedrive_write_log_deal_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipedrive_write_log_deal_id_created_at_idx ON public.pipedrive_write_log USING btree (deal_id, created_at DESC);


--
-- Name: pipedrive_write_log_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pipedrive_write_log_status_idx ON public.pipedrive_write_log USING btree (status);


--
-- Name: uq_benchmark_market_cache_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_benchmark_market_cache_key ON public.benchmark_market_cache USING btree (job_title_normalized, sectors_key);


--
-- Name: uq_benchmark_qa_chief_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_benchmark_qa_chief_id ON public.benchmark_qa USING btree (chief_id);


--
-- Name: uq_jd_chief_stages_jd_chief_run; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_jd_chief_stages_jd_chief_run ON public.jd_chief_stages USING btree (jd_id, chief_id, run_id);


--
-- Name: uq_jd_list_quality_run; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_jd_list_quality_run ON public.jd_list_quality USING btree (pipeline_run_id);


--
-- Name: uq_reverse_matches_chief_jd; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_reverse_matches_chief_jd ON public.chief_reverse_matches USING btree (chief_id, jd_id);


--
-- Name: accounts accounts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: allocation_history_shortlist allocation_history_shortlist_startup_ad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allocation_history_shortlist
    ADD CONSTRAINT allocation_history_shortlist_startup_ad_id_fkey FOREIGN KEY (startup_ad_id) REFERENCES public.allocation_history(startup_ad_id);


--
-- Name: chief_embeddings chief_embeddings_chief_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_embeddings
    ADD CONSTRAINT chief_embeddings_chief_id_fkey FOREIGN KEY (chief_id) REFERENCES public.chiefs_todos(id);


--
-- Name: chief_field_history chief_field_history_chief_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chief_field_history
    ADD CONSTRAINT chief_field_history_chief_id_fkey FOREIGN KEY (chief_id) REFERENCES public.chiefs_todos(id);


--
-- Name: jd_briefing_embeddings jd_briefing_embeddings_jd_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_briefing_embeddings
    ADD CONSTRAINT jd_briefing_embeddings_jd_id_fkey FOREIGN KEY (jd_id) REFERENCES public.job_descriptions(id);


--
-- Name: jd_extracted_metadata jd_extracted_metadata_jd_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_extracted_metadata
    ADD CONSTRAINT jd_extracted_metadata_jd_id_fkey FOREIGN KEY (jd_id) REFERENCES public.job_descriptions(id);


--
-- Name: jd_results jd_results_job_description_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jd_results
    ADD CONSTRAINT jd_results_job_description_id_fkey FOREIGN KEY (job_description_id) REFERENCES public.job_descriptions(id);


--
-- Name: job_descriptions job_descriptions_uploaded_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_descriptions
    ADD CONSTRAINT job_descriptions_uploaded_file_id_fkey FOREIGN KEY (uploaded_file_id) REFERENCES public.uploaded_files(id);


--
-- Name: job_embeddings job_embeddings_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_embeddings
    ADD CONSTRAINT job_embeddings_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.job_descriptions(id);


--
-- PostgreSQL database dump complete
--

