-- ddl/app/002 ? grants v2 do cadastro do chief pelo Intelligence (#1143 telas, #1146 envio, #1149 paridade, #1151 CPF).
-- Alvo: HML (fluffy) primeiro; PROD (PINK) só no card 15 (#1152) com OK do Renan.
-- Aplicar DEPOIS do 001, a partir da credencial default do addon com `SET ROLE app_user` (owner de `app.*`); `tl` não tem GRANT OPTION em app.* (04/11/2026). Nunca como intelligence_user.
-- Inventário da DBA: grant fora do script dela morre no próximo re-run ? reportar na thread na mesma volta.
-- Fonte das colunas: src/cadastro/chief_writer.py (submit_for_review), src/cadastro/telas.py::to_columns (#1143),
-- issue #1149 (profile_percentage) e #1151/ADR-028 (document = CPF; UI sempre mascarada 123.***.***-45).
-- app.chief_ads NÃO entra: nenhum código em src/cadastro/ escreve nele hoje (grep 2026-11-04).
SET ROLE app_user;
-- S8/S9 (#1146/#1149): envio pra aprovação + leitura do que o próprio fluxo gravou
GRANT SELECT (terms_accepted, terms_accepted_at, email_optin, document)
  ON app.chiefs TO intelligence_user;
GRANT UPDATE (terms_accepted, terms_accepted_at, birth_at, gender, email_optin, profile_percentage)
  ON app.chiefs TO intelligence_user;
-- #1143 ? telas remuneracao_contato / como_atua / problema_cases viram stated ("Pendências de grant" do PR)
GRANT UPDATE (salary, phone, contact_email, work_model, availability_status, company_profiles,
              business_moment, biggest_team_responsibility, biggest_problems, relevant_problems,
              important_cases_connecting_customers)
  ON app.chiefs TO intelligence_user;
-- #1151 ? CPF: grava em app.chiefs.document (SELECT acima cobre a checagem de duplicidade do #1149)
GRANT UPDATE (document) ON app.chiefs TO intelligence_user;
RESET ROLE;
-- Validação (read-only, como qualquer role):
--   select has_column_privilege('intelligence_user','app.chiefs','document','UPDATE'),
--          has_column_privilege('intelligence_user','app.chiefs','terms_accepted','UPDATE');
