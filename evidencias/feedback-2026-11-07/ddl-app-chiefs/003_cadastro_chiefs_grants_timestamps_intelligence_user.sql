-- ddl/app/003 ? timestamps do Rails no INSERT do chief_writer (#1141)
-- Motivo: app.chiefs.created_at/updated_at são NOT NULL sem default (o Rails preenche no ActiveRecord).
--   O INSERT do cadastro novo (src/cadastro/chief_writer.py::_insert) passa a mandar now(), now();
--   sem este grant o callback LinkedIn dá 500 (InsufficientPrivilege) ? visto no HML em 04/11/2026.
-- Alvo: HML (fluffy, chiefsgroup-homolog) primeiro. PROD (PINK) só via #1152, com OK do Renan.
-- Aplicar a partir da credencial default do addon (`heroku pg:psql <addon> -a <app> -f`) com `SET ROLE app_user` ? owner de `app.*`.
-- `tl` NÃO tem GRANT OPTION; nunca aplicar como intelligence_user. Reportar na thread da DBA (fora do script de inventário dela).
SET ROLE app_user;
GRANT INSERT (created_at, updated_at) ON app.chiefs TO intelligence_user;
GRANT UPDATE (updated_at) ON app.chiefs TO intelligence_user;
RESET ROLE;
