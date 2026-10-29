# Incidente Railway QH8L8B3E (21/10/2026 23:57 UTC) — credenciais de banco expostas

Fonte: aviso da Chiefs em 22/10 + https://status.railway.com/incident/QH8L8B3E.
Variáveis de ambiente dos projetos Railway foram acessadas e parte decriptada.
**Tudo que estava em variável do Railway é tratado como comprometido.**

## 1 · O que estava exposto (inventário do que vive no Railway)

| Segredo | Onde | Alcance se usado por terceiro | Ação |
|---|---|---|---|
| `intelligence_user` do **PINK** (10 services + 3 MCPs) | `DATABASE_URL` | leitura de todo `intelligence.*` (PII: currículos, e-mails, laudos), allowlist de `app` (28 relações), UPDATE em 53 colunas de `app.chiefs`, **escrita total em `intelligence.*`** (inclusive `users`, `ui_access_grant`, `system_prompts`), CREATE em `intelligence`/`lab`, DDL por ownership | **rotacionar** (seção 3) |
| `intelligence_user` do **fluffy** | `DATABASE_URL_FLUFFY` nos services de PROD (!) e nos de HML | idem na homolog (dado real copiado) | rotacionar; **remover a var de PROD** |
| **`rubi`** (role pessoal do TL) | `DATABASE_URL_PROD_RO` em todos os services e `DATABASE_URL` do n8n | tudo de `tl`: SELECT allowlist + `intelligence` + `analytical`, INSERT/UPDATE em 7 tabelas, **SET ROLE tl → CREATE em `analytical`/`knowledge`**, funções de monitoramento | rotacionar já; substituir por `intelligence_ro` (serviço, só leitura) |
| `n8n_contexto_cliente`, `n8n_fila_salesops` | cofre do n8n (Postgres `railway`), cifrado com `N8N_ENCRYPTION_KEY` — **a chave é variável do Railway** | INSERT/UPDATE em `deal_enrichments` / `deal_sales_ops`; leitura de `pipedrive_deals`, `chiefs_ativos` | rotacionar; **todo o cofre do n8n** (Pipedrive, Slack, LLM…) e a própria `N8N_ENCRYPTION_KEY` são da Chiefs |
| Postgres **`chiefs_intelligence` do Railway** (origem, "para consulta") | variáveis do próprio serviço (`PGPASSWORD`/`DATABASE_URL`) | cópia completa da intelligence pré-cutover, com PII | **parar o serviço agora** (ninguém usa) ou trocar a senha do `postgres`; a decisão de 09/10 de manter "para consulta" perde o sentido com a senha exposta |
| `DATABASE_URL_RAILWAY` / `DATABASE_URL_MCP_RAILWAY` (reservas antigas) | 13 slots | idem acima | remover (já era o gate c do §6) |
| `knowledge_app` | **ainda não** está em variável do Railway | — | criar a var só depois da rotação geral; se já tiver sido colocada, rotacionar |
| Chaves de LLM | services | — | já rotacionadas pela Chiefs |

Não exposto por este incidente: `app_user` (só no Heroku), credencial default dos dois
addons (nunca em variável de app), agentes exceto rubi (URLs buscadas no Heroku), `tl`/`worker`
(nunca entregues), `looker_reader`.

## 2 · O que a leitura mostrou (homolog, 22/10 ~14:30 UTC; PROD = Amelia rodar o mesmo)

- Conexões de `intelligence_user` na HML: **152.55.181.195 = bloco próprio do Railway
  (152.55.176.0/20, RC-1550)**. Logo, Railway sai com IPs próprios, não com IPs do Google.
- **34.85.206.6 = Google Cloud (34.64.0.0/10, googleusercontent)**, não é Railway, não é
  Heroku (AWS 52.x/54.x) e não é a Amelia. Até alguém da Chiefs reconhecer (Cloud Run,
  VM de dev, job no GCP), tratar como **acesso não autorizado**: rotacionar antes de
  investigar.
- `pg_stat_statements` (desde 19/08): nenhum padrão de extração em massa por
  `intelligence_user` (COPY/pg_dump só da default = ETL); nenhum acesso a
  `credit_cards`/`chief_accounts`/`encrypted_password` por outra role.
- Roles: só as esperadas (24, incl. `postgres` e `internal_utility_*` do Heroku).
  Funções: 3 `compat_*` + 4 `lab.mon_*`. Nenhum objeto estranho.
- Tabelas de autenticação do Intelligence (`users`, `ui_access_grant`,
  `system_prompts`, `mcp_refresh_tokens`, `user_activity_log`) desde 21/10: ver
  `inc3` (abaixo) — **a Chiefs precisa auditar o conteúdo**: um usuário/grant novo ou
  um prompt alterado é o backdoor mais barato com essa credencial.
- Limite: Heroku não expõe log de conexões do Postgres; só falhas de autenticação
  chegam ao log do app (`heroku logs -p postgres`). Não há como provar ausência de
  leitura; por isso a resposta é rotação, não investigação.

## 2b · O que a leitura do PINK mostrou (22/10 14:31 UTC, `evidencias/incidente-2026-10-22/`)

1. **34.85.206.6 (Google Cloud): 5 conexões idle como `intelligence_user`, abertas desde
   19/10 16:30 UTC (13:30 BRT), último comando ROLLBACK, sem application_name.** Padrão
   de pool de aplicação (5 conexões), vivo há 3 dias. Começou ANTES da publicação do
   incidente (21/10 23:57 UTC) e num horário de trabalho da Chiefs em que houve deploys
   (19/10). Hipóteses: (a) um service do Railway/GCP sem Static Outbound IP (o egress
   padrão do Railway é GCP; os 152.55.x são os services com IP estático) ou um job no
   GCP da Chiefs (Cloud Run/VM) deployado em 19/10 ~13:30 BRT; (b) terceiro. **A Chiefs
   consegue decidir isso pelos logs de deploy de 19/10.** Se não reconhecerem em 1h:
   `pg_terminate_backend` nas 5 sessões (a default pode, é membro de intelligence_user)
   e `rotate --force` da intelligence_user, aceitando a indisponibilidade.
   As demais conexões: Railway próprio (152.55.180.24, .181.178, .181.192), Rails na
   AWS (3.83/3.85), Heroku automation, Amelia.
2. **Exportação integral de PII pela `intelligence_user`:** `COPY (select * from
   chiefs_ativos) TO STDOUT csv header` (2.121 linhas) e `COPY (select * from
   chiefs_todos) TO STDOUT csv header` (5.446 linhas) — forma típica do `\copy` do
   psql, 1 chamada cada. Nome, e-mail, telefone, currículo de todos os chiefs.
   Datação pelas contagens: 2.121 = contagem de `chiefs_ativos` em 08/10 (20/10 já era
   2.129); 5.446 ≈ `chiefs_todos` logo após o cutover (5.444 em 08/10) → **entre 08 e
   ~12/10**, antes da janela conhecida do incidente. Pode ser conferência interna da
   Chiefs com a credencial de serviço; **precisa ser reconhecido por quem fez**. Se
   ninguém reconhecer, é exfiltração de PII de 5.446 pessoas (LGPD) e o incidente muda
   de categoria.
3. `INSERT INTO ui_access_grant` — 1 chamada, 1 linha, pela `intelligence_user`
   (19 grants no PINK contra 18 na HML; nenhum alterado desde 21/10). Confirmar quem
   e quando (a tabela tem `added_by`).
4. `user_activity_log`: 19 eventos desde 21/10 (uso da UI) — conferir IPs.
5. Tabelas de autenticação: nenhum `users`; `system_prompts` sem linha nova desde 21/10.
6. MCP (`_mcp_q`) lendo `ui_access_grant` e `system_prompts`: esperado (chiefs-adm).

## 3 · Como rotacionar sem derrubar (e sem trocar o nome da role)

**Não criar uma `intelligence_user` nova.** A role é OWNER de `intelligence.*`, roda o
Alembic, tem 28 grants por coluna em `app`, default privileges e search_path na role;
trocar o nome é reconstruir tudo isso sob pressão. O nome fica; muda a senha.

`heroku pg:credentials:rotate <addon> --name <cred> -a <app>` gera senha nova e **mantém a
antiga válida até a rotação ser concluída**; `--force` conclui na hora e derruba as
conexões abertas. Isso dá a convivência que a Chiefs pediu, sem 24 h: a janela de
convivência é o tempo de redeploy, não um dia, porque a senha antiga está na mão de
terceiros.

Sequência por credencial (PINK; repetir no fluffy):

```bash
APP=chiefsgroup; DB=postgresql-trapezoidal-33655
heroku pg:credentials:rotate $DB --name intelligence_user -a $APP          # 1. senha nova; antiga ainda vale
heroku pg:credentials:url $DB --name intelligence_user -a $APP             # 2. URL nova → Chiefs grava nos 13 slots e redeploya
# 3. Chiefs confirma: /health 200 e pg_stat_activity só com conexões novas (ver abaixo)
heroku pg:credentials:rotate $DB --name intelligence_user -a $APP --force  # 4. invalida a antiga, derruba o que sobrou
```

Conferência entre 2 e 4 (default): `select usename, client_addr, backend_start from
pg_stat_activity where usename='intelligence_user'` — todas com `backend_start` posterior
ao redeploy e `client_addr` em 152.55.176.0/20.

Com os deploys do Railway **pausados**, o passo 2 não acontece → decisão da Chiefs:
(a) esperar o Railway liberar deploy e fazer 1–4 em sequência, aceitando a exposição
até lá; (b) `--force` agora, com indisponibilidade do Intelligence até o redeploy.
Recomendação: **(b) para `rubi` e para as duas do n8n imediatamente** (não derrubam o
produto); **(a) para `intelligence_user`**, com 1–2 feitos já (senha nova pronta) e 4
no minuto seguinte ao redeploy.

Ordem recomendada:

1. `rubi`: `rotate --force` nos dois addons agora. O TL busca a URL nova no Heroku. Os
   services/n8n que usavam `DATABASE_URL_PROD_RO` passam para `intelligence_ro`
   (seção 4) — nunca mais uma role pessoal em variável de serviço.
2. `n8n_contexto_cliente` e `n8n_fila_salesops`: `rotate --force` nos dois addons; o
   Duda recadastra no n8n (os workflows são sob demanda/cron, sem queda perceptível).
   Chiefs: rotacionar `N8N_ENCRYPTION_KEY` e todas as credenciais do cofre do n8n.
3. Postgres `chiefs_intelligence` do Railway: parar o serviço (Renan).
4. `intelligence_user` PINK e fluffy: passos 1–2 agora; 3–4 assim que o Railway
   liberar deploy. Remover `DATABASE_URL_FLUFFY` dos services de PROD no mesmo deploy.
5. Variáveis mortas (`*_RAILWAY`, outras sem consumidor): remover no mesmo deploy.
6. Depois: auditoria das tabelas de autenticação (Chiefs), `heroku logs -p postgres`
   dos dois apps desde 21/10 (Amelia), e o alerta de falhas de auth no Papertrail
   (item 19 do P1, pendente) sai do backlog.

## 4 · `intelligence_ro` (substitui rubi nas variáveis de serviço)

`ddl/p3-intelligence-ro.sql`: credencial de serviço membro de `analytical_reader`
(INHERIT, sem SET) — SELECT na allowlist de `app`, em `intelligence.*` e `analytical.*`;
nada de escrita, CREATE ou monitoramento. Mesma matriz testada dos agentes reader.

```bash
heroku pg:credentials:create $DB --name intelligence_ro -a $APP        # sem addons:attach
psql "$(url default)" -v ON_ERROR_STOP=1 -f ddl/p3-intelligence-ro.sql
psql "$(url intelligence_ro)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql
```

Esperado: `le_intelligence t, le_allowlist t, le_senha f, escreve f, cria f`.

## 5 · Registro

Tudo que for rotacionado entra em `p3/0. p3-entregas.md` com data/hora e em
`docs/runbook-producao-permissoes.md` (inventário de credenciais). Nenhuma URL nos
e-mails nem nas evidências.

## 6 · Execução — passo 1 (liberado pelo Renan em 29/10): `rubi --force` + `intelligence_ro`, nos 2 addons

> **Executado em 29/10 ~15:15–15:25 BRT (Amelia)**, fluffy e PINK, tudo no esperado.
> Evidências `evidencias/incidente-2026-10-22/10-rubi-*-{hml,prod}.txt` e
> `11-intelligence-ro-*-{hml,prod}.txt`. Não usar loop `for … set -- $par` no zsh
> (não separa palavras sem `${=par}`): rodar um ambiente por vez.

```bash
cd ~/Documents/workspace/chiefs/chiefs-db-migration
EV=evidencias/incidente-2026-10-22; mkdir -p $EV
url() { heroku pg:credentials:url $DB --name $1 -a $APP | grep -oE 'postgres://[^ ]+' | head -1; }

# homolog:  APP=chiefsgroup-homolog; DB=postgresql-fluffy-10310;        AMB=hml   (db devpemtfal8rfl)
# produção: APP=chiefsgroup;         DB=postgresql-trapezoidal-33655;   AMB=prod  (db dfiit9c72iv839)
APP=chiefsgroup-homolog; DB=postgresql-fluffy-10310; AMB=hml
DB_URL=$(url default); psql "$DB_URL" -Atc "select current_database()"
heroku pg:credentials:rotate $DB --name rubi -a $APP --force --confirm $APP 2>&1 | tee $EV/10-rubi-rotate-$AMB.txt
heroku pg:credentials:create $DB --name intelligence_ro -a $APP 2>&1 | tee $EV/11-intelligence-ro-create-$AMB.txt
heroku pg:credentials $DB -a $APP        # esperar `active` em rubi e intelligence_ro
```

Depois (mesmas variáveis):

```bash
psql "$DB_URL" -v ON_ERROR_STOP=1 -f ddl/p3-intelligence-ro.sql 2>&1 | tee $EV/11-intelligence-ro-$AMB.txt
psql "$(url intelligence_ro)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql 2>&1 | tee $EV/11-intelligence-ro-search-path-$AMB.txt
psql "$(url intelligence_ro)" -c "select count(*) from intelligence.jd_results" -c "select 1 from app.credit_cards limit 1" -c "insert into intelligence.jd_results select * from intelligence.jd_results where false" 2>&1 | tee $EV/11-intelligence-ro-smoke-$AMB.txt
psql "$DB_URL" -c "select usename, client_addr, count(*) from pg_stat_activity where usename in ('rubi','intelligence_ro') group by 1,2" | tee $EV/10-rubi-sessoes-pos-$AMB.txt
```

Esperado (obtido nos 2 bancos em 29/10): `le_intelligence t, le_allowlist t, le_senha f,
escreve f, cria f`; search_path `intelligence, public, heroku_ext`; smoke com `count` ok
(19.356 hml / 18.152 prod), `permission denied` em `credit_cards` e no INSERT; 0 sessões
de `rubi` após o `--force`. A mensagem do Heroku sobre `addons:attach` é ignorada
(credencial de agente, fora do app). O TL busca a URL nova de `rubi` no Heroku; a Chiefs
põe a URL de `intelligence_ro` em `DATABASE_URL_PROD_RO`/n8n no deploy do passo 4.

