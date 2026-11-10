-- ddl/app/005 ? leitura de app.legal_pages p/ o modal de Termos/Privacidade do cadastro (#1287)
-- Motivo: src/cadastro/legal.py::get_legal lê slug/title/content/updated_at; sem o grant dá 42501 e a tela cai no fallback (links do Rails).
-- Alvo: HML (fluffy, chiefsgroup-homolog) ? JÁ APLICADO pelo rubi. PROD (PINK) só via #1152, com OK do Renan.
-- Aplicar a partir da credencial default do addon (`heroku pg:psql <addon> -a <app> -f`) com `SET ROLE app_user` ? owner de `app.*`.
-- `tl` NÃO tem GRANT OPTION; nunca aplicar como intelligence_user.
SET ROLE app_user;
GRANT SELECT (slug, title, content, updated_at) ON app.legal_pages TO intelligence_user;
RESET ROLE;
