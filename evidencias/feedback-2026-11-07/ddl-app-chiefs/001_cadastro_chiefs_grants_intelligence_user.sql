-- ddl/app/001 ? grants pro fluxo de cadastro do chief pelo Intelligence (#1140/#1141, ADR-026).
-- Alvo: HML (fluffy) primeiro; PROD (PINK) só no card 15 (#1152) com OK do Renan.
-- Aplicar a partir da credencial default do addon (`heroku pg:psql <addon> -a <app> -f`) com `SET ROLE app_user` ? owner de `app.*`.
-- `tl` NÃO tem GRANT OPTION em app.chiefs/app.chiefs_id_seq (aprendido 04/11/2026: 42501 em todos os GRANTs sob SET ROLE tl). Nunca como intelligence_user.
-- Inventário da DBA: grant fora do script dela morre no próximo re-run ? reportar na thread na mesma volta.
-- Pré-requisito: plataforma #416 mergeado + db:migrate (colunas entry_source, vinculo, horas_semana_livres, a_partir_de).
SET ROLE app_user;

-- leitura das colunas que o chief_writer consulta e que hoje NÃO estão na allowlist por coluna
GRANT SELECT (contact_email, provider, uid, linkedin_token, linkedin_expires, picture_url,
              entry_source, vinculo, horas_semana_livres, a_partir_de)
  ON app.chiefs TO intelligence_user;

-- escrita: só as colunas do INSERT/UPDATE do src/cadastro/chief_writer.py (sem DELETE, nunca)
GRANT INSERT (name, email, contact_email, slug, status, role, provider, uid,
              linkedin_token, linkedin_expires, picture_url, entry_source)
  ON app.chiefs TO intelligence_user;
GRANT UPDATE (provider, uid, linkedin_token, linkedin_expires, picture_url, status,
              entry_source, vinculo, horas_semana_livres, a_partir_de)
  ON app.chiefs TO intelligence_user;

-- id do chief vem da sequence do Rails (chief_id imutável, ADR-003: Intelligence não gera id por fora)
GRANT USAGE ON SEQUENCE app.chiefs_id_seq TO intelligence_user;

RESET ROLE;
-- Validação (como intelligence_user, read-only):
--   select has_column_privilege('app.chiefs','uid','INSERT'), has_sequence_privilege('app.chiefs_id_seq','USAGE');
