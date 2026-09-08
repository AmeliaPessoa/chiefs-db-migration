#!/usr/bin/env python3
"""P2 · ETL intelligence → schema `intelligence` do destino + merge no main.

Vereditos de 13/08 (Renan): espelho NÃO migra. Este ETL faz:

  1. Carga integral (full load) das tabelas que nascem no Intelligence
     (49 no schema: 48 recarregadas + alembic_version preservada), espelho
     1:1 no schema `intelligence`: SELECT na origem e INSERT no destino por
     streaming COPY→COPY, direto de conexão a conexão — nenhum dado toca
     disco, repositório ou arquivo intermediário (§5.1).
  2. (--merge) Merge das híbridas no main (schema APP_SCHEMA, default `app`):
     `chiefs` +53 colunas de enriquecimento (ativos ∪ todos; em conflito
     vale chiefs_ativos) e `pipedrive_deals` +4 colunas, casando
     main.pipedrive_id = intel.id. O UPDATE só escreve as colunas NOVAS
     (nunca sobrescreve o main); ids sem match são descartados (decisão
     18/08) e apenas contabilizados.

Idempotente: TRUNCATE ... RESTART IDENTITY (SEM CASCADE) antes da carga, e a
execução inteira (truncate + 48 tabelas + merge + setval + owner) roda em UMA
transação no destino — ou entra tudo, ou nada; re-executar nunca duplica.

Garantias da re-execução (feedback Chiefs 08/09, item 4 — o Intelligence
passa a criar objetos no schema `intelligence` via Alembic):
  · só as tabelas de TABLES são esvaziadas/recarregadas; tabelas, views,
    funções e colunas criadas pelas migrations do Intelligence NÃO são
    tocadas (não há DROP/CREATE; o DDL é passo separado, só na 1ª vez);
  · TRUNCATE sem CASCADE: tabela nova do cliente com FK para uma das 48
    faz a carga FALHAR (alto) em vez de ser esvaziada em silêncio;
  · intelligence.alembic_version NUNCA é sobrescrita — só semeada da origem
    se estiver vazia (1ª carga); depois pertence ao Alembic do Intelligence;
  · coluna que existe só no DESTINO (migration à frente da origem) é
    tolerada com WARN e fica com o DEFAULT; coluna só na ORIGEM continua
    sendo DRIFT (erro — Achado #1, perderia dado);
  · tabela nova na ORIGEM fora de TABLES e fora da lista de excluídas
    (vereditos 13/08) é erro: precisa de veredito (carregar ou excluir);
  · grants e default privileges não mudam (nada é dropado/recriado);
  · passo final: owner dos objetos de `intelligence` → DST_OBJECT_OWNER
    (default intelligence_user; vazio desliga) — as migrations Alembic
    exigem ownership para ALTER TABLE (item 5 do feedback).

Uso: trocar apenas as variáveis de conexão (env vars ou o bloco CONFIG
abaixo) e rodar:

    SRC_HOST=... SRC_PASSWORD=... DST_HOST=... DST_PASSWORD=... python3 etl.py

Flags:
    --merge           inclui o merge das híbridas no main (exige DST_USER
                      com UPDATE em app.chiefs/app.pipedrive_deals — o
                      intelligence_user NÃO tem; usar credencial admin)
    --merge-only      só o merge (sem tocar o schema intelligence)
    --validate-only   só compara contagens origem × destino (não escreve)

Pré-requisitos no destino: schema `intelligence` criado
(../ddl-intelligence-schema.sql), extensão pgvector e — para o merge —
../ddl-main-enrichment.sql aplicado.
"""

import argparse
import os
import re
import sys
import threading
import time

try:
    import psycopg2
    from psycopg2.extensions import quote_ident
except ImportError:
    sys.exit("psycopg2 ausente — instale com: pip3 install psycopg2-binary")

# ---------------------------------------------------------------------------
# CONFIG · conexões — TROCAR AQUI (ou via variáveis de ambiente de mesmo nome)
# ---------------------------------------------------------------------------
CONFIG = {
    # origem (Railway · chiefs_intelligence) — acessada SOMENTE para leitura
    "SRC_HOST": "localhost",
    "SRC_PORT": "5432",
    "SRC_DB": "chiefs_intelligence",
    "SRC_USER": "postgres",
    "SRC_PASSWORD": "",
    "SRC_SSLMODE": "prefer",          # na base real: require/verify-full
    "SRC_SCHEMA": "public",
    # destino (Heroku PG · schema intelligence)
    "DST_HOST": "localhost",
    "DST_PORT": "5432",
    "DST_DB": "postgres",
    "DST_USER": "postgres",
    "DST_PASSWORD": "",
    "DST_SSLMODE": "prefer",          # na base real: require/verify-full
    "DST_SCHEMA": "intelligence",
    "APP_SCHEMA": "app",          # schema do monolito no destino (merge); local: public
    "DST_OBJECT_OWNER": "intelligence_user",  # owner final de intelligence.* ("" = não alterar)
}


def cfg(key: str) -> str:
    return os.environ.get(key, CONFIG[key])


# As tabelas que migram (vereditos 13/08 + chief_perfil_perguntas, 08/09), em
# ordem de FK (mesma ordem do 01-load-intelligence.sql): pais primeiro,
# filhas depois. alembic_version fica FORA desta lista: é semeada uma vez e
# depois pertence ao Alembic do Intelligence (ver seed_alembic_version).
ALEMBIC_TABLE = "alembic_version"
TABLES = [
    "allocation_history", "allocation_history_shortlist",
    "attractiveness_snapshots", "backtest_jobs", "benchmark_market_cache",
    "benchmark_qa", "chief_career_history", "chief_contextual_qa",
    "chief_enrichment_history", "chief_improvement_event", "chief_laudo",
    "chief_laudo_modal_state", "chief_perfil_perguntas",
    "chief_platform_history",
    "chief_rerank_cache", "chief_reverse_matches", "chief_reverse_profile",
    "chief_snapshot_before_op", "chief_stimulus_event",
    "deal_enrichment_jobs", "deal_enrichments", "deal_sales_ops",
    "governance_conflicts", "ingestion_logs", "iqp_snapshots",
    "jd_chief_alerts", "jd_chief_match_comments", "jd_chief_stages",
    "jd_list_quality", "mcp_query_log", "mql_candidates",
    "novo_funil_pipedrive", "pipedrive_write_log", "pipeline_runs",
    "platform_sync_state", "system_prompts", "ui_access_grant",
    "uploaded_files", "user_activity_log", "user_favorites", "users",
    "chief_embeddings", "chief_field_history", "job_descriptions",
    "job_embeddings", "jd_briefing_embeddings", "jd_extracted_metadata",
    "jd_results",
]

# Tabelas da origem que NÃO migram (vereditos 13/08): espelhos re-syncáveis,
# híbridas (entram via merge), tokens e backups. Qualquer outra tabela nova
# na origem fora de TABLES precisa de veredito → erro (check_origin_tables).
ORIGIN_EXCLUDED = {
    "accounts", "companies", "chiefs_platform",            # espelhos do main
    "pipedrive_deals", "chiefs_ativos", "chiefs_todos",    # híbridas (merge)
    "mcp_refresh_tokens",                                  # tokens efêmeros
}
ORIGIN_EXCLUDED_PREFIXES = ("ca_", "ac_")                  # Conta Azul / ActiveCampaign
BACKUP_TABLE_RE = re.compile(r"(_bak|_backup)_\d{8}$")   # ex.: chief_embeddings_bak_20260803

# Merge das híbridas (vereditos 13/08) — colunas NOVAS escritas no main.
# Fonte: ddl-main-enrichment.sql (gerado do diff chiefs_ativos × chiefs).
MERGE_CHIEFS_COLS = [
    "years_experience", "enrichment_status", "vectorization_status",
    "is_deleted", "deleted_at", "executive_competency", "state_inferred",
    "state_inferred_confidence", "english_level_inferred",
    "is_potential_apt_tier1", "work_model_inferred",
    "profile_completeness_score", "regiao_influencia_secundaria",
    "BP_verification_notes", "enrichment_meta", "enrichment_error",
    "enrichment_claimed_at", "natureza_atuacao", "prazo_disponivel",
    "perfil_atuacao", "stakeholder_mgmt", "porte_empresa_ideal",
    "momento_empresa_ideal", "ferramentas_dominadas",
    "tolerancia_ambiguidade", "perfil_cultural", "capacidade_mentoria",
    "iqp_score", "iqp_classification", "years_career_inferred",
    "years_executive_inferred", "sector_experience_detail",
    "job_title_normalized", "resume_combined",
    "resume_experience_synthetic", "avatar_blob_key", "avatar_url",
    "needs_re_enrichment", "field_confidence", "total_career_months",
    "exec_level_months", "unique_companies_count", "current_roles_count",
    "longest_tenure_months", "avg_tenure_months", "career_start_date",
    "linkedin_enriched_at", "all_job_titles", "deletion_reason",
    "attractiveness_score", "attractiveness_classification",
    "chair_inferred", "registered_at",
]
MERGE_CHIEFS_ONLY_ATIVOS = {"attractiveness_score", "attractiveness_classification"}
MERGE_PD_COLS = ["notes", "files", "origem_oportunidade", "utm_source"]


def connect(prefix: str):
    conn = psycopg2.connect(
        host=cfg(f"{prefix}_HOST"), port=cfg(f"{prefix}_PORT"),
        dbname=cfg(f"{prefix}_DB"), user=cfg(f"{prefix}_USER"),
        password=cfg(f"{prefix}_PASSWORD"), sslmode=cfg(f"{prefix}_SSLMODE"),
        application_name="p2-etl-intelligence",
    )
    conn.autocommit = False
    return conn


def columns_of(conn, schema: str, table: str) -> list[str]:
    with conn.cursor() as cur:
        cur.execute(
            """SELECT column_name FROM information_schema.columns
               WHERE table_schema = %s AND table_name = %s
               ORDER BY ordinal_position""",
            (schema, table),
        )
        return [r[0] for r in cur.fetchall()]


def stream_query(src, dst, src_select: str, dst_copy_target: str) -> None:
    """COPY (src_select) TO STDOUT (origem) → pipe em memória →
    COPY dst_copy_target FROM STDIN (destino)."""
    r_fd, w_fd = os.pipe()
    reader, writer = os.fdopen(r_fd, "rb"), os.fdopen(w_fd, "wb")
    src_error: list[Exception] = []

    def produce():
        try:
            with src.cursor() as cur:
                cur.copy_expert(f"COPY ({src_select}) TO STDOUT", writer)
        except Exception as exc:  # propaga para a thread principal
            src_error.append(exc)
        finally:
            writer.close()

    producer = threading.Thread(target=produce, daemon=True)
    producer.start()
    try:
        with dst.cursor() as cur:
            cur.copy_expert(f"COPY {dst_copy_target} FROM STDIN", reader)
    finally:
        reader.close()
        producer.join()
    if src_error:
        raise src_error[0]


def stream_table(src, dst, table: str, cols: list[str]) -> None:
    """Espelha uma tabela origem → destino (mesmas colunas)."""
    src_schema, dst_schema = cfg("SRC_SCHEMA"), cfg("DST_SCHEMA")
    col_list = ", ".join(quote_ident(c, dst) for c in cols)
    stream_query(
        src, dst,
        f"SELECT {col_list} FROM {quote_ident(src_schema, src)}.{quote_ident(table, src)}",
        f"{quote_ident(dst_schema, dst)}.{quote_ident(table, dst)} ({col_list})",
    )


def merge_main(src, dst) -> bool:
    """Merge das híbridas no main (schema APP_SCHEMA). Só escreve as colunas
    novas; ids sem match são descartados (decisão 18/08). Retorna True se a
    verificação de fidelidade fechar sem divergências."""
    app, src_schema = cfg("APP_SCHEMA"), cfg("SRC_SCHEMA")
    qd = lambda n: quote_ident(n, dst)
    qs = lambda n: quote_ident(n, src)
    ok = True

    # ---- chiefs: +53 colunas, fonte = ativos (prio 1) ∪ todos (prio 2) ----
    col_list = ", ".join(qd(c) for c in MERGE_CHIEFS_COLS)
    with dst.cursor() as cur:
        # id na intel é character varying (no main é bigint) — a fonte guarda
        # o id como texto; o cast seguro acontece no dedup (id_bigint).
        cur.execute(
            f"CREATE TEMP TABLE tmp_chiefs_fonte AS "
            f"SELECT 1::smallint AS prio, NULL::text AS id, {col_list} "
            f"FROM {qd(app)}.chiefs WHERE false"
        )
    for prio, table in ((1, "chiefs_ativos"), (2, "chiefs_todos")):
        sel = ", ".join(
            f"NULL AS {qs(c)}" if (prio == 2 and c in MERGE_CHIEFS_ONLY_ATIVOS)
            else qs(c)
            for c in MERGE_CHIEFS_COLS
        )
        stream_query(
            src, dst,
            f"SELECT {prio} AS prio, id, {sel} FROM {qs(src_schema)}.{qs(table)}",
            "tmp_chiefs_fonte",
        )
    with dst.cursor() as cur:
        cur.execute("CREATE TEMP TABLE tmp_chiefs_dedup AS "
                    "SELECT DISTINCT ON (id) *, "
                    "CASE WHEN id ~ '^[0-9]+$' THEN id::bigint END AS id_bigint "
                    "FROM tmp_chiefs_fonte ORDER BY id, prio")
        cur.execute("SELECT count(*) FROM tmp_chiefs_dedup")
        n_fonte = cur.fetchone()[0]
        set_list = ", ".join(f"{qd(c)} = f.{qd(c)}" for c in MERGE_CHIEFS_COLS)
        cur.execute(f"UPDATE {qd(app)}.chiefs c SET {set_list} "
                    f"FROM tmp_chiefs_dedup f WHERE c.id = f.id_bigint")
        n_upd = cur.rowcount
        row_c = ", ".join(f"c.{qd(c)}" for c in MERGE_CHIEFS_COLS)
        row_f = ", ".join(f"f.{qd(c)}" for c in MERGE_CHIEFS_COLS)
        cur.execute(f"SELECT count(*) FROM {qd(app)}.chiefs c "
                    f"JOIN tmp_chiefs_dedup f ON c.id = f.id_bigint "
                    f"WHERE ROW({row_c}) IS DISTINCT FROM ROW({row_f})")
        n_div = cur.fetchone()[0]
    ok = ok and n_div == 0
    print(f"  merge chiefs: fonte={n_fonte} atualizados={n_upd} "
          f"descartados(sem match)={n_fonte - n_upd} divergentes={n_div}")

    # ---- pipedrive_deals: +4 colunas, match main.pipedrive_id = intel.id ----
    pd_list = ", ".join(qd(c) for c in MERGE_PD_COLS)
    with dst.cursor() as cur:
        cur.execute(
            f"CREATE TEMP TABLE tmp_pd_fonte AS "
            f"SELECT pipedrive_id AS id, {pd_list} "
            f"FROM {qd(app)}.pipedrive_deals WHERE false"
        )
    stream_query(
        src, dst,
        f"SELECT id, {', '.join(qs(c) for c in MERGE_PD_COLS)} "
        f"FROM {qs(src_schema)}.pipedrive_deals",
        "tmp_pd_fonte",
    )
    with dst.cursor() as cur:
        cur.execute("SELECT count(*) FROM tmp_pd_fonte")
        n_fonte = cur.fetchone()[0]
        set_list = ", ".join(f"{qd(c)} = i.{qd(c)}" for c in MERGE_PD_COLS)
        cur.execute(f"UPDATE {qd(app)}.pipedrive_deals p SET {set_list} "
                    f"FROM tmp_pd_fonte i WHERE p.pipedrive_id = i.id")
        n_upd = cur.rowcount
        row_p = ", ".join(f"p.{qd(c)}" for c in MERGE_PD_COLS)
        row_i = ", ".join(f"i.{qd(c)}" for c in MERGE_PD_COLS)
        cur.execute(f"SELECT count(*) FROM {qd(app)}.pipedrive_deals p "
                    f"JOIN tmp_pd_fonte i ON p.pipedrive_id = i.id "
                    f"WHERE ROW({row_p}) IS DISTINCT FROM ROW({row_i})")
        n_div = cur.fetchone()[0]
    ok = ok and n_div == 0
    print(f"  merge pipedrive_deals: fonte={n_fonte} atualizados={n_upd} "
          f"descartados(sem match)={n_fonte - n_upd} divergentes={n_div}")
    with dst.cursor() as cur:
        cur.execute("DROP TABLE tmp_chiefs_fonte, tmp_chiefs_dedup, tmp_pd_fonte")
    return ok


def reset_sequences(dst) -> int:
    """setval(MAX(col)+1) para toda coluna serial/identity das tabelas
    CARREGADAS (só TABLES — sequences de tabelas criadas pelo Intelligence
    não são tocadas)."""
    dst_schema = cfg("DST_SCHEMA")
    with dst.cursor() as cur:
        cur.execute(
            """SELECT table_name, column_name,
                      pg_get_serial_sequence(quote_ident(table_schema) || '.' ||
                                             quote_ident(table_name), column_name)
               FROM information_schema.columns
               WHERE table_schema = %s
                 AND table_name = ANY(%s)
                 AND pg_get_serial_sequence(quote_ident(table_schema) || '.' ||
                                            quote_ident(table_name), column_name)
                     IS NOT NULL""",
            (dst_schema, TABLES),
        )
        seqs = cur.fetchall()
        for table, col, seq in seqs:
            cur.execute(
                f"SELECT setval(%s, COALESCE((SELECT MAX({quote_ident(col, dst)}) "
                f"FROM {quote_ident(dst_schema, dst)}.{quote_ident(table, dst)}), 0) + 1, false)",
                (seq,),
            )
    return len(seqs)


def check_origin_tables(src) -> None:
    """Tabela nova na ORIGEM que não está em TABLES nem na lista de excluídas
    precisa de veredito (carregar ou excluir) — senão o cutover perderia
    dado que nasce no Intelligence. Backups (_bak_/_backup_YYYYMMDD) são
    descartados por regra (13/08) e só geram aviso."""
    src_schema = cfg("SRC_SCHEMA")
    with src.cursor() as cur:
        cur.execute("SELECT tablename FROM pg_tables WHERE schemaname = %s", (src_schema,))
        origin = {r[0] for r in cur.fetchall()}
    known = set(TABLES) | {ALEMBIC_TABLE} | ORIGIN_EXCLUDED
    unknown = sorted(
        t for t in origin - known if not t.startswith(ORIGIN_EXCLUDED_PREFIXES)
    )
    backups = [t for t in unknown if BACKUP_TABLE_RE.search(t)]
    for t in backups:
        print(f"  !! WARN backup operacional na origem, descartado por regra: {t}")
    unknown = [t for t in unknown if t not in backups]
    if unknown:
        msg = (f"tabelas NOVAS na origem sem veredito (carregar em TABLES ou "
               f"excluir em ORIGIN_EXCLUDED): {unknown}")
        if os.environ.get("ETL_ALLOW_SCHEMA_DRIFT") == "1":
            print(f"  !! WARN drift tolerado: {msg}")
        else:
            raise RuntimeError(msg)
    missing_in_origin = sorted(set(TABLES) - origin)
    if missing_in_origin:
        raise RuntimeError(f"tabelas de TABLES ausentes na origem: {missing_in_origin}")


def check_truncate_privilege(dst) -> None:
    """Falha cedo, com mensagem clara, se a credencial não puder TRUNCATE
    (após o owner virar intelligence_user, a default opera por ser MEMBRO
    da role — se a membership faltar, é aqui que aparece)."""
    dst_schema = cfg("DST_SCHEMA")
    with dst.cursor() as cur:
        cur.execute(
            """SELECT t FROM unnest(%s::text[]) AS t
               WHERE to_regclass(quote_ident(%s) || '.' || quote_ident(t)) IS NOT NULL
                 AND NOT has_table_privilege(quote_ident(%s) || '.' || quote_ident(t), 'TRUNCATE')""",
            (TABLES, dst_schema, dst_schema),
        )
        denied = [r[0] for r in cur.fetchall()]
    if denied:
        raise RuntimeError(
            f"credencial {cfg('DST_USER')} sem TRUNCATE em {dst_schema}.{denied[:3]}... — "
            f"usar a credencial default (owner ou membro de {cfg('DST_OBJECT_OWNER') or 'owner'})")


def seed_alembic_version(src, dst) -> str:
    """intelligence.alembic_version: semeia da origem SÓ se o destino estiver
    vazio (1ª carga). Nunca sobrescreve — depois da 1ª carga a tabela é do
    Alembic do Intelligence (item 4 do feedback de 08/09)."""
    src_schema, dst_schema = cfg("SRC_SCHEMA"), cfg("DST_SCHEMA")
    qd = lambda n: quote_ident(n, dst)
    with dst.cursor() as cur:
        cur.execute(f"SELECT count(*) FROM {qd(dst_schema)}.{qd(ALEMBIC_TABLE)}")
        if cur.fetchone()[0] > 0:
            return "preservada (destino já versionado pelo Alembic)"
    stream_table(src, dst, ALEMBIC_TABLE, columns_of(dst, dst_schema, ALEMBIC_TABLE))
    return "semeada da origem (1ª carga)"


def ensure_owner(dst) -> int:
    """Passo final: owner de tabelas/sequences/views de DST_SCHEMA →
    DST_OBJECT_OWNER (as migrations Alembic exigem ownership para ALTER
    TABLE — item 5 do feedback de 08/09). Idempotente; exige que a
    credencial atual seja owner E membro da role destino."""
    owner = cfg("DST_OBJECT_OWNER")
    if not owner:
        return 0
    dst_schema = cfg("DST_SCHEMA")
    with dst.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (owner,))
        if cur.fetchone() is None:
            print(f"  !! WARN role {owner} não existe neste banco — owner não alterado")
            return 0
        cur.execute(
            """SELECT c.relname FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = %s AND c.relkind IN ('r','p','S','v','m')
                 AND c.relowner <> (SELECT oid FROM pg_roles WHERE rolname = %s)""",
            (dst_schema, owner),
        )
        rels = [r[0] for r in cur.fetchall()]
        for rel in rels:
            cur.execute(f"ALTER TABLE {quote_ident(dst_schema, dst)}.{quote_ident(rel, dst)} "
                        f"OWNER TO {quote_ident(owner, dst)}")
    return len(rels)


def validate(src, dst) -> bool:
    src_schema, dst_schema = cfg("SRC_SCHEMA"), cfg("DST_SCHEMA")
    print(f"\n{'tabela':<32}{'origem':>12}{'destino':>12}  status")
    print("-" * 66)
    ok = True
    total_src = total_dst = 0
    drift_report, ahead_report = [], []
    for table in TABLES:
        s_cols = set(columns_of(src, src_schema, table))
        d_cols = set(columns_of(dst, dst_schema, table))
        if s_cols - d_cols:
            drift_report.append(f"{table}: origem tem a mais {sorted(s_cols - d_cols)}")
        if d_cols - s_cols:
            ahead_report.append(f"{table}: destino tem a mais {sorted(d_cols - s_cols)}")
        with src.cursor() as cur:
            cur.execute(f"SELECT count(*) FROM {quote_ident(src_schema, src)}.{quote_ident(table, src)}")
            n_src = cur.fetchone()[0]
        with dst.cursor() as cur:
            cur.execute(f"SELECT count(*) FROM {quote_ident(dst_schema, dst)}.{quote_ident(table, dst)}")
            n_dst = cur.fetchone()[0]
        total_src += n_src
        total_dst += n_dst
        status = "OK" if n_src == n_dst else "DIVERGE"
        ok = ok and n_src == n_dst
        print(f"{table:<32}{n_src:>12}{n_dst:>12}  {status}")
    print("-" * 66)
    print(f"{'TOTAL':<32}{total_src:>12}{total_dst:>12}")
    with src.cursor() as cur:
        cur.execute(f"SELECT string_agg(version_num, ',') FROM "
                    f"{quote_ident(src_schema, src)}.{quote_ident(ALEMBIC_TABLE, src)}")
        v_src = cur.fetchone()[0]
    with dst.cursor() as cur:
        cur.execute(f"SELECT string_agg(version_num, ',') FROM "
                    f"{quote_ident(dst_schema, dst)}.{quote_ident(ALEMBIC_TABLE, dst)}")
        v_dst = cur.fetchone()[0]
    print(f"{ALEMBIC_TABLE}: origem={v_src} destino={v_dst}"
          + ("" if v_src == v_dst else "  (INFO: destino gerido pelo Alembic do Intelligence)"))
    if ahead_report:
        print("\n!! INFO destino à frente da origem (migration do Intelligence; coluna fica com DEFAULT):")
        for line in ahead_report:
            print(f"   {line}")
    if drift_report:
        ok = False
        print("\n!! DRIFT DE SCHEMA (Achado #1 — coluna na ORIGEM ausente no destino):")
        for line in drift_report:
            print(f"   {line}")
    print("\n== ZERO DIVERGÊNCIAS ==" if ok else "\n== HÁ DIVERGÊNCIAS ==")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate-only", action="store_true",
                        help="só compara contagens; não escreve no destino")
    parser.add_argument("--merge", action="store_true",
                        help="inclui o merge das híbridas no main (APP_SCHEMA)")
    parser.add_argument("--merge-only", action="store_true",
                        help="só o merge das híbridas (não toca o schema intelligence)")
    args = parser.parse_args()

    src = connect("SRC")
    dst = connect("DST")
    # trava de segurança: origem read-only (§5.1) + REPEATABLE READ, para
    # que as 70 leituras enxerguem UM único snapshot consistente mesmo com
    # gravadores ativos na origem durante a carga
    with src.cursor() as cur:
        cur.execute("SET SESSION CHARACTERISTICS AS TRANSACTION "
                    "ISOLATION LEVEL REPEATABLE READ READ ONLY")
    # ⚠ o SET acima só vale para transações FUTURAS — e o psycopg2 já abriu
    # uma transação (READ COMMITTED) para executá-lo. Fechar essa transação
    # garante que TODA a leitura (carga + merge + validação) aconteça em UMA
    # transação REPEATABLE READ = um único snapshot, mesmo com gravadores
    # ativos na origem (bug constatado em 19/08 na homolog: mcp_query_log
    # ganhou 2 linhas durante a execução e a validação divergiu).
    src.commit()

    try:
        merge_ok = True
        if args.merge_only:
            print(f"Merge das híbridas em {cfg('DST_HOST')}/{cfg('DST_DB')}.{cfg('APP_SCHEMA')}")
            merge_ok = merge_main(src, dst)
            dst.commit()
            print("Commit OK." if merge_ok else "Commit OK — MAS HÁ DIVERGÊNCIAS no merge.")
            return 0 if merge_ok else 1
        if not args.validate_only:
            dst_schema = cfg("DST_SCHEMA")
            print(f"Carga: {cfg('SRC_HOST')}/{cfg('SRC_DB')} → "
                  f"{cfg('DST_HOST')}/{cfg('DST_DB')}.{dst_schema} "
                  f"({len(TABLES)} tabelas, transação única)")
            check_origin_tables(src)
            check_truncate_privilege(dst)
            all_tables = ", ".join(
                f"{quote_ident(dst_schema, dst)}.{quote_ident(t, dst)}" for t in TABLES
            )
            with dst.cursor() as cur:
                # SEM CASCADE: tabela do cliente com FK para uma das 48 faz
                # falhar aqui, em vez de ser esvaziada em silêncio (item 4).
                cur.execute(f"TRUNCATE {all_tables} RESTART IDENTITY")
            for i, table in enumerate(TABLES, 1):
                cols = columns_of(dst, dst_schema, table)
                if not cols:
                    raise RuntimeError(f"tabela {dst_schema}.{table} não existe no destino — rodar o DDL antes")
                src_cols = set(columns_of(src, cfg("SRC_SCHEMA"), table))
                ahead = set(cols) - src_cols
                if ahead:
                    # destino à frente (migration do Intelligence já aplicada
                    # aqui e ainda não na origem): carrega a interseção; a
                    # coluna nova fica com o DEFAULT. Não é perda de dado.
                    print(f"  !! INFO {table}: coluna só no destino (fica com DEFAULT): {sorted(ahead)}")
                    cols = [c for c in cols if c in src_cols]
                # Achado #1 (feedback Chiefs 20/08): check SIMÉTRICO — coluna
                # nova na ORIGEM ausente no destino é drift de schema e
                # perderia dado silenciosamente (a contagem fecharia mesmo
                # assim). Erro por padrão; ETL_ALLOW_SCHEMA_DRIFT=1 rebaixa
                # para WARN (uso emergencial e consciente).
                drift = src_cols - set(cols)
                if drift:
                    msg = (f"{table}: colunas na ORIGEM ausentes no destino "
                           f"(DRIFT DE SCHEMA — regenerar DDL/ALTER antes da "
                           f"carga): {sorted(drift)}")
                    if os.environ.get("ETL_ALLOW_SCHEMA_DRIFT") == "1":
                        print(f"  !! WARN drift tolerado: {msg}")
                    else:
                        raise RuntimeError(msg)
                t0 = time.monotonic()
                stream_table(src, dst, table, cols)
                print(f"  [{i:2}/{len(TABLES)}] {table} ({time.monotonic() - t0:.1f}s)")
            print(f"  {ALEMBIC_TABLE}: {seed_alembic_version(src, dst)}")
            if args.merge:
                merge_ok = merge_main(src, dst)
            n_seq = reset_sequences(dst)
            n_own = ensure_owner(dst)
            dst.commit()
            print(f"Commit OK — {n_seq} sequences reposicionadas; "
                  f"owner → {cfg('DST_OBJECT_OWNER') or '(inalterado)'}: {n_own} objeto(s) alterado(s).")
        return 0 if (validate(src, dst) and merge_ok) else 1
    except Exception:
        dst.rollback()
        raise
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    sys.exit(main())
