-- ddl/app/004 ? grants de UPDATE dos obrigatórios do Rails no cadastro do chief (card G wdp7exb9xx, 04/11/2026).
-- Alvo: HML (fluffy) primeiro; PROD (PINK) só com OK do Renan. APLICADO no fluffy em 05/11/2026 pelo rubi (11/11 validadas); PINK pendente (#1152).
-- Aplicar DEPOIS do 001/002, a partir da credencial default do addon com `SET ROLE app_user` (owner de `app.*`); `tl` não tem GRANT OPTION em app.* (04/11/2026). Nunca como intelligence_user.
-- Inventário da DBA: grant fora do script dela morre no próximo re-run ? reportar na thread na mesma volta.
-- Fonte das colunas: src/cadastro/telas.py::to_columns (telas quem_e_voce e como_atua) e chief_writer.STATED_GRANTED_COLUMNS.
-- SELECT já existe nestas colunas no HML (conferido via has_column_privilege em 04/11/2026); só falta UPDATE.
-- Sem este grant o UPDATE em lote falha, é engolido (warning) e o dado fica só no rascunho (cadastro_draft).
SET ROLE app_user;
GRANT UPDATE (job_title, company, chair, c_level_experience, state, city, linkedin,
              industries_experience, sectors_experience, business_model, main_companies)
  ON app.chiefs TO intelligence_user;
RESET ROLE;
-- Validação (read-only, como qualquer role):
--   select c, has_column_privilege('intelligence_user','app.chiefs',c,'UPDATE')
--   from unnest(array['job_title','company','chair','c_level_experience','state','city','linkedin',
--                     'industries_experience','sectors_experience','business_model','main_companies']) c;
