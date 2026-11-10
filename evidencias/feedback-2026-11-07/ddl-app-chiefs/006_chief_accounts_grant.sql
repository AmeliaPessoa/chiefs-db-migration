-- ddl/app/006 ? escrita em app.chief_accounts p/ o cadastro novo (pré-requisito do #1317)
-- Motivo: o cadastro novo grava a conta do chief em app.chief_accounts; intelligence_user não tinha privilégio nenhum na tabela.
-- Alvo: aplicado HML (fluffy, chiefsgroup-homolog) 05/11 12:54 pelo rubi via `heroku pg:psql` + `SET ROLE app_user`.
--       PROD (PINK): PENDENTE da decisão LGPD ? chief_accounts guarda dado bancário e estava na denylist da DBA.
-- Aplicar a partir da credencial default do addon (`heroku pg:psql <addon> -a <app> -f`) com `SET ROLE app_user` ? owner de `app.*`.
-- `tl` NÃO tem GRANT OPTION; nunca aplicar como intelligence_user.
SET ROLE app_user;
GRANT SELECT, INSERT, UPDATE ON app.chief_accounts TO intelligence_user;
GRANT USAGE, SELECT ON SEQUENCE app.chief_accounts_id_seq TO intelligence_user;
RESET ROLE;
