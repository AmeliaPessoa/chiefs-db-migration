-- P2 ETL · 04 — Testes de integridade além das contagens (critério de aceite:
-- "testes de integridade OK"). Rodar no DESTINO após a carga (credencial
-- default ou qualquer uma com SELECT em intelligence + app).
--
-- Duas classes de verificação:
--   · DUROS (ERRO = reprovado): sequence atrás do MAX(id) — quebraria o
--     primeiro INSERT pós-cutover; PK duplicada é impossível (constraints).
--   · AUDITORIA (INFO): órfãos das FKs LÓGICAS (o banco não declara: ~90
--     relações para 27 FKs físicas) — chief_id → app.chiefs, deal_id →
--     app.pipedrive_deals(pipedrive_id), jd_id/job_description_id →
--     intelligence.job_descriptions, rails_vaga_id → app.startup_ads.
--     Órfãos aqui refletem a ORIGEM (a carga é espelho fiel); servem para a
--     auditoria do P2, não reprovam o ETL.
--
-- Uso: psql "<url-destino>" -v app_schema=app -f 04-integridade.sql
\set ON_ERROR_STOP on

CREATE TEMP TABLE r(classe text, item text, valor text, ok text);

-- ============ 1 · DUROS: sequences não podem estar atrás do MAX ============
DO $$
DECLARE t record; seq text; behind int := 0; total int := 0; mx bigint; lv bigint;
BEGIN
  FOR t IN
    SELECT c.table_name, c.column_name,
           pg_get_serial_sequence(quote_ident(c.table_schema)||'.'||quote_ident(c.table_name), c.column_name) AS seqname
    FROM information_schema.columns c
    WHERE c.table_schema = 'intelligence'
      AND pg_get_serial_sequence(quote_ident(c.table_schema)||'.'||quote_ident(c.table_name), c.column_name) IS NOT NULL
  LOOP
    total := total + 1;
    EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM intelligence.%I', t.column_name, t.table_name) INTO mx;
    EXECUTE format('SELECT last_value FROM %s', t.seqname) INTO lv;
    IF lv < mx THEN
      behind := behind + 1;
      INSERT INTO r VALUES ('DURO', 'sequence atrás do MAX: '||t.table_name,
                            'last_value='||lv||' < max='||mx, 'ERRO');
    END IF;
  END LOOP;
  INSERT INTO r VALUES ('DURO', 'sequences verificadas', total||' sequences, '||behind||' atrás do MAX',
                        CASE WHEN behind = 0 THEN 'OK' ELSE 'ERRO' END);
END $$;

-- ============ 2 · INFO: tabelas sem PK (não deveria haver) ============
INSERT INTO r
SELECT 'INFO', 'tabelas sem PK em intelligence',
       COALESCE(string_agg(t.tablename, ', '), 'nenhuma'),
       CASE WHEN count(*) = 0 THEN 'OK' ELSE 'ATENCAO' END
FROM pg_tables t
WHERE t.schemaname = 'intelligence'
  AND NOT EXISTS (SELECT 1 FROM pg_constraint c
                  WHERE c.conrelid = (quote_ident(t.schemaname)||'.'||quote_ident(t.tablename))::regclass
                    AND c.contype = 'p');

-- ============ 3 · AUDITORIA: órfãos das FKs lógicas (descoberta dinâmica) ==
-- (variáveis psql não interpolam dentro de DO $$; passa via set_config)
SELECT set_config('etl.app_schema', :'app_schema', false);
DO $$
DECLARE
  c record; expr text; orfaos bigint; tot bigint; alvo text; alvo_col text;
BEGIN
  FOR c IN
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'intelligence'
      AND column_name IN ('chief_id','deal_id','jd_id','job_description_id','rails_vaga_id')
      AND table_name NOT IN ('job_descriptions')  -- é o alvo de jd_id
    ORDER BY table_name, column_name
  LOOP
    -- alvo da relação lógica
    IF c.column_name = 'chief_id' THEN
      alvo := current_setting('etl.app_schema') || '.chiefs'; alvo_col := 'id';
    ELSIF c.column_name = 'deal_id' THEN
      alvo := current_setting('etl.app_schema') || '.pipedrive_deals'; alvo_col := 'pipedrive_id';
    ELSIF c.column_name = 'rails_vaga_id' THEN
      alvo := current_setting('etl.app_schema') || '.startup_ads'; alvo_col := 'id';
    ELSE
      alvo := 'intelligence.job_descriptions'; alvo_col := 'id';
    END IF;
    -- cast seguro para colunas texto (ids varchar na intel)
    IF c.data_type IN ('character varying','text') THEN
      expr := format('CASE WHEN t.%I ~ ''^[0-9]+$'' THEN t.%I::bigint END', c.column_name, c.column_name);
    ELSE
      expr := format('t.%I::bigint', c.column_name);
    END IF;
    EXECUTE format(
      'SELECT count(*) FILTER (WHERE t.%I IS NOT NULL), '
      || 'count(*) FILTER (WHERE t.%I IS NOT NULL AND NOT EXISTS '
      || '(SELECT 1 FROM %s a WHERE a.%I = %s)) FROM intelligence.%I t',
      c.column_name, c.column_name, alvo, alvo_col, expr, c.table_name)
      INTO tot, orfaos;
    IF tot > 0 THEN
      INSERT INTO r VALUES ('AUDITORIA',
        c.table_name || '.' || c.column_name || ' → ' || alvo,
        orfaos || ' órfãos de ' || tot || ' (' || round(100.0*orfaos/GREATEST(tot,1),1) || '%)',
        CASE WHEN orfaos = 0 THEN 'OK' ELSE 'INFO' END);
    END IF;
  END LOOP;
END $$;

-- ============ 4 · resultado ============
SELECT * FROM r ORDER BY (classe='DURO') DESC, (ok='ERRO') DESC, item;
SELECT CASE WHEN EXISTS (SELECT 1 FROM r WHERE ok = 'ERRO')
       THEN 'INTEGRIDADE: REPROVADO (checks duros com ERRO)'
       ELSE 'INTEGRIDADE: OK — checks duros aprovados; órfãos lógicos são auditoria (refletem a origem)' END;
