-- P2/P3 · CENÁRIO A (NÃO aplicar sem pedido): n8n_contexto_cliente grava em mql_candidates
--
-- Em 06/10 o Duda escolheu o CENÁRIO B: o nó "Persist MQL Candidate" do Prospect
-- Enrichment (que não está no repositório da Chiefs e nunca gravou — 797 linhas,
-- todas source='driva', última em 22/07) é desativado em PROD antes do dia D, e
-- mql_candidates fica FORA do grant (ddl/p2-roles-n8n.sql v3).
-- Este arquivo é o pedido de grant próprio, para depois do cutover, se a Chiefs
-- quiser religar o nó. SQL do nó:
--   INSERT INTO mql_candidates (cnpj, org_name, person_name, person_email, cargo, area,
--     nivel, decisor_comercial, setor, dor_setor, origem, stage_novo, tipo_origem, status,
--     source, version, is_active) VALUES (...)
--   ON CONFLICT (cnpj, person_name) DO UPDATE SET person_email=EXCLUDED.person_email, cargo=…,
--     area=…, nivel=…, decisor_comercial=…, setor=…, dor_setor=…, origem=…,
--     version=mql_candidates.version+1, is_active=TRUE, updated_at=NOW()
--
-- O que o Postgres exige para esse comando (resposta ao Duda, 06/10):
--   - INSERT na tabela (cobre as 17 colunas);
--   - UPDATE nas 11 colunas do SET;
--   - SELECT nas colunas lidas: version (SET), cnpj e person_name (alvo do ON CONFLICT)
--     e as referenciadas via EXCLUDED/tabela → SELECT na tabela, por simplicidade;
--   - USAGE em mql_candidates_id_seq (o INSERT não informa id);
--   - UNIQUE/PK exatamente em (cnpj, person_name): existe, uq_mql_candidates_cnpj_person
--     (origem e destino).
--
-- Executar como a credencial DEFAULT, depois de ddl/p2-roles-n8n.sql (que REVOGA
-- tudo em mql_candidates — portanto este arquivo tem de rodar DEPOIS dele e ser
-- re-executado a cada re-run daquele). Teste: MQL_CANDIDATES=A bash scripts/testa-permissoes-n8n.sh
-- ⚠ Re-executar o ddl/p2-roles-n8n.sql DESFAZ este arquivo (a seção 1 dele revoga
--    tudo em intelligence e volta ao cenário B). Validado em Docker 06/10: v3 → B
--    (45/45), + este → A (45/45), v3 de novo → B.
--
-- Idempotente.

\set ON_ERROR_STOP on

BEGIN;

GRANT SELECT, INSERT ON intelligence.mql_candidates TO n8n_contexto_cliente;
GRANT UPDATE (person_email, cargo, area, nivel, decisor_comercial, setor, dor_setor, origem,
              version, is_active, updated_at)
  ON intelligence.mql_candidates TO n8n_contexto_cliente;
GRANT USAGE ON SEQUENCE intelligence.mql_candidates_id_seq TO n8n_contexto_cliente;

DO $$
DECLARE falhas text; n int;
BEGIN
  SELECT string_agg(format('UPDATE mql_candidates.%s: esperado %s', t.col, t.esperado), '; ')
    INTO falhas
    FROM (VALUES
      ('person_email', true), ('cargo', true), ('area', true), ('nivel', true),
      ('decisor_comercial', true), ('setor', true), ('dor_setor', true), ('origem', true),
      ('version', true), ('is_active', true), ('updated_at', true),
      ('cnpj', false), ('person_name', false), ('source', false), ('org_name', false)
    ) t(col, esperado)
   WHERE has_column_privilege('n8n_contexto_cliente', 'intelligence.mql_candidates', t.col, 'UPDATE') IS DISTINCT FROM t.esperado;
  IF falhas IS NOT NULL THEN RAISE EXCEPTION 'cenário A divergente: %', falhas; END IF;

  IF NOT has_table_privilege('n8n_contexto_cliente', 'intelligence.mql_candidates', 'SELECT')
     OR NOT has_table_privilege('n8n_contexto_cliente', 'intelligence.mql_candidates', 'INSERT')
     OR has_table_privilege('n8n_contexto_cliente', 'intelligence.mql_candidates', 'DELETE')
     OR has_table_privilege('n8n_fila_salesops',    'intelligence.mql_candidates', 'SELECT')
     OR NOT has_sequence_privilege('n8n_contexto_cliente', 'intelligence.mql_candidates_id_seq', 'USAGE') THEN
    RAISE EXCEPTION 'cenário A divergente (tabela/sequence)';
  END IF;

  -- ON CONFLICT (cnpj, person_name) exige UNIQUE/PK exatamente nessas colunas
  SELECT count(*) INTO n
    FROM pg_constraint c
   WHERE c.conrelid = 'intelligence.mql_candidates'::regclass
     AND c.contype IN ('u', 'p')
     AND (SELECT array_agg(a.attname::text ORDER BY a.attname)
            FROM unnest(c.conkey) k JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k)
         = ARRAY['cnpj', 'person_name'];
  IF n = 0 THEN
    RAISE EXCEPTION 'mql_candidates sem UNIQUE (cnpj, person_name): o ON CONFLICT do n8n falharia';
  END IF;
END $$;

COMMIT;

SELECT grantee, privilege_type FROM information_schema.table_privileges
 WHERE grantee = 'n8n_contexto_cliente' AND table_schema = 'intelligence' AND table_name = 'mql_candidates' ORDER BY 2;
