-- P3 · Marcos de status do Chief a partir do PaperTrail (app.versions), SEM PII
-- (pedido do Renan 15/10 — rotina "engajamento-refresh" do Intelligence, KR O3KR2)
--
-- Por que uma view e não GRANT na tabela: app.versions.object_changes é o diff
-- YAML completo da linha versionada; quando item_type = 'Chief' ele carrega
-- email, phone, birth_at, salary etc. (§5.1 do briefing). A view expõe só o
-- que a rotina pediu — item_type, item_id, event, created_at, whodunnit — e o
-- status extraído do diff (de → para), nada mais.
--
-- Formato do object_changes (PaperTrail, YAML texto; conferido na homolog 17/10):
--   ---
--   status:
--   - pending
--   - waiting_approval
--   updated_at:
--   - ...
-- Linhas com transição de status: object_changes ~ '\nstatus:\n'. Valor nulo
-- aparece como "-" sem espaço (destroy: "- active\n-\n"; create: "-\n- pending")
-- → a regex tolera "-" com ou sem valor e o lado vazio vira NULL.
-- Conferido na homolog (17/10, só leitura): 438 linhas; update
-- waiting_approval→active 120, pending→waiting_approval 116, create pending→active 63,
-- active→pending 53, destroy pending→NULL 51 e active→NULL 6, ...
--
-- Owner da view = app_user (regra (A) 10/09: objeto em app pertence à role de
-- migration do Rails). Criada pela default e transferida; a Chiefs pode
-- absorvê-la depois numa migration do Rails (CREATE OR REPLACE idêntico) sem
-- quebrar nada.
--
-- Executar como a credencial DEFAULT, em HML e depois em PROD:
--   psql "<url-default>" -v ON_ERROR_STOP=1 -f ddl/p3-view-chief-status-versions.sql
-- O GRANT ao intelligence_user está em ddl/p2-grants-intelligence-user-minimo.sql
-- (seção 26) — rodar depois deste arquivo; este arquivo também concede, para o
-- caso de ser aplicado sozinho (idempotente).

\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW app.chief_status_versions AS
SELECT v.id,
       v.item_type,
       v.item_id,
       v.event,
       v.created_at,
       v.whodunnit,
       NULLIF(btrim((regexp_match(v.object_changes, E'\\nstatus:\\n-(?: ([^\\n]*))?\\n-(?: ([^\\n]*))?'))[1]), '') AS status_de,
       NULLIF(btrim((regexp_match(v.object_changes, E'\\nstatus:\\n-(?: ([^\\n]*))?\\n-(?: ([^\\n]*))?'))[2]), '') AS status_para
  FROM app.versions v
 WHERE v.item_type = 'Chief'
   AND v.object_changes ~ E'\\nstatus:\\n';

COMMENT ON VIEW app.chief_status_versions IS
  'Marcos de status do Chief (PaperTrail) sem PII: só item/event/created_at/whodunnit e status de→para extraídos de object_changes. Pedido Renan 15/10; §5.1.';

ALTER VIEW app.chief_status_versions OWNER TO app_user;
GRANT SELECT ON app.chief_status_versions TO intelligence_user;

-- Guarda: a view não pode expor nenhuma coluna de PII nem o diff bruto
DO $$
DECLARE cols text;
BEGIN
  SELECT string_agg(column_name, ',' ORDER BY ordinal_position) INTO cols
    FROM information_schema.columns
   WHERE table_schema = 'app' AND table_name = 'chief_status_versions';
  IF cols <> 'id,item_type,item_id,event,created_at,whodunnit,status_de,status_para' THEN
    RAISE EXCEPTION 'view chief_status_versions com colunas inesperadas: %', cols;
  END IF;
  IF has_table_privilege('intelligence_user', 'app.versions', 'SELECT') THEN
    RAISE EXCEPTION 'intelligence_user com SELECT direto em app.versions — o desenho é só pela view';
  END IF;
END $$;

COMMIT;

-- Amostra (sem PII) e contagem
SELECT status_de, status_para, count(*) FROM app.chief_status_versions GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 12;
