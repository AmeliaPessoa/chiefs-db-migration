-- ddl/app/007 ? INSERT em app.chief_ads (oportunidades do chief)
-- Motivo: hoje intelligence_user só tem SELECT em app.chief_ads e na sequence; qualquer escrita pelo Intelligence cai em 42501.
-- Alvo: HML (fluffy) APLICADO em 05/11 16:42 pelo rubi (INSERT=t, USAGE=t). PROD (PINK) pendente ? aplicar só com OK do Renan, junto com o pacote do #1152.
-- Sequence confirmada em HML com pg_get_serial_sequence('app.chief_ads','id') = app.chief_ads_id_seq.
-- Aplicar a partir da credencial default do addon (`heroku pg:psql <addon> -a <app> -f`) com `SET ROLE app_user` ? owner de `app.*`.
-- `tl` NÃO tem GRANT OPTION; nunca aplicar como intelligence_user.
SET ROLE app_user;
GRANT INSERT ON app.chief_ads TO intelligence_user;
GRANT USAGE ON SEQUENCE app.chief_ads_id_seq TO intelligence_user;
RESET ROLE;
