-- ddl/app/008 ? grant de UPDATE de hard_skills no cadastro do chief (#1376, 06/11/2026).
-- Alvo: HML (fluffy) APLICADO 06/11/2026 (rubi, grant HML). PROD (PINK) PENDENTE ? DBA aplica junto com a chief_curation_decisions (card wdp7exbfqz).
-- Aplicar a partir da credencial default do addon com `SET ROLE app_user` (owner de `app.*`). Nunca como intelligence_user.
-- Inventário da DBA: grant fora do script dela morre no próximo re-run ? reportar na thread na mesma volta.
-- Fonte: src/cadastro/telas.py::to_columns (como_atua) e chief_writer.STATED_GRANTED_COLUMNS.
-- app.chiefs.hard_skills é text (CSV); o stated vai pra ela, o inferido continua no overlay chief_inferred (mig 117).
-- Sem este grant a coluna é pulada (has_column_privilege) e as demais gravam normalmente; skills ficam só no rascunho.
SET ROLE app_user;
GRANT UPDATE (hard_skills) ON app.chiefs TO intelligence_user;
RESET ROLE;
-- Validação (read-only, como qualquer role):
--   select has_column_privilege('intelligence_user','app.chiefs','hard_skills','UPDATE');
