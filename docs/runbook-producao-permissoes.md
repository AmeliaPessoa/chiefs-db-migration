# Runbook — permissões em produção (#912 + usuários por agente)

Reproduz em produção, **na mesma ordem e com os mesmos arquivos**, o que foi
aplicado e validado na homolog (`chiefsgroup-homolog` / `postgresql-fluffy-10310`)
em 23/09/2026. Evidências da homolog: `evidencias/feedback-2026-09-22/`.

| Bloco | O que faz | Arquivo |
|---|---|---|
| A · #912 | SELECT do `intelligence_user` em `app.*` passa a ser por coluna (21 tabelas das views de compat) + as 3 `active_campaign_*` inteiras (24/09) + UPDATE nas 53 colunas de enriquecimento | `ddl/p2-grants-intelligence-user-minimo.sql` |
| B · Agentes | grupos `tl` / `worker` / `analytical_reader` + 8 usuários, `search_path` por usuário, teste permitido/negado | `ddl/p2-roles-agentes.sql`, `ddl/p2-search-path-agentes.sql`, `scripts/testa-permissoes-agentes.sh` |

Decisões por trás (registradas em `p2/0. p2-entregas.md`, 23/09): acesso
conforme os mapas do Renan (16/09) e do Bruno (21/09); `analytical_reader`
ampliado para SELECT em `app` + `intelligence`; **em produção o `worker` só lê**.
**24/09 (proposta do Renan, aceita pela Amelia em 25/09):** os três grupos
leem `app` pela **mesma allowlist do `intelligence_user`** (copiada na
execução do bloco B), não mais a `app` inteira: nada de `encrypted_password`,
`document`, `credit_cards`, `api_tokens`, `oauth_accounts`... Consequência:
`SELECT *` em `app.chiefs` dá `permission denied` para agente (colunas
explícitas ou as views `intelligence.chiefs_ativos`/`chiefs_todos`).

---

## Diferenças homolog × produção

| | Homolog (feito) | Produção |
|---|---|---|
| `APP` / `DB` | `chiefsgroup-homolog` / `postgresql-fluffy-10310` | `<app-prod>` / `<addon-prod>` — **preencher antes** |
| `p2-roles-agentes.sql` | `-v ambiente=homolog` | `-v ambiente=producao` |
| Escrita do `worker` | 10 tabelas INSERT/UPDATE + `pipeline_runs` INSERT | **nenhuma** (revogada explicitamente) |
| Escrita do `tl` | 7 tabelas INSERT/UPDATE | igual |
| Teste (`AMBIENTE=`) | `homolog` → **248 PASS, 0 FAIL** (152 antes de 25/09) | `producao` → **240 PASS, 0 FAIL** |
| Backup antes | não exigido | **obrigatório** (regra contratual) |

## Pré-requisitos (conferir antes da janela)

- [ ] Sonda de segurança do cliente passou **28/28** na homolog depois do #912,
      e o smoke do Intelligence/MCP não quebrou.
- [ ] #911 decidido (UPDATE em `app.chiefs.updated_at`: hoje fora — se entrar,
      descomentar a linha no fim do bloco de UPDATE do arquivo do #912).
- [ ] P1 aplicado em produção: schemas `app`/`intelligence`/`analytical`/`lab`,
      roles `app_user`/`intelligence_user`/`looker_reader`/`analytical_reader`.
- [ ] `ddl/p2-owner-app.sql` e `ddl/p2-grants-public-usage.sql` aplicados
      (owner de `app.*` = `app_user`; USAGE em `public`/`heroku_ext`).
- [ ] **Bloco B só depois da carga do P3**: `ddl-intelligence-schema.sql` +
      ETL + `etl/05-owner-intelligence.sql` — o `p2-roles-agentes.sql` dá
      grants em tabelas de `intelligence.*` e falha se elas não existirem.
- [ ] Bloco A depende das 21 tabelas de `app` (inclusive as `ca_*`) com as
      colunas da lista, e das 3 `app.active_campaign_*`. Se alguma faltar em produção, o arquivo falha **inteiro**
      (transação única — nada é aplicado). Nesse caso, parar e regerar a lista
      com o Renan.
- [ ] Aviso ao Renan com horário: consulta direta a tabela de `app` fora das
      views passa a dar `permission denied` depois do bloco A.

## Armadilhas já vistas na homolog

1. **zsh não aceita `# comentário` na linha colada** (`Unexpected arguments: #, …`).
   Rodar `setopt interactivecomments` no início, ou colar os comandos como estão
   abaixo (sem comentário na mesma linha).
2. **Não fazer `heroku addons:attach`** nas credenciais novas, apesar de o
   Heroku sugerir: ele cria config var com a URL no app e expõe a credencial
   de agente a todos os dynos. A URL sai de `pg:credentials:url`.
3. **A "foto antes" tem de ser tirada antes de tudo** e com `aclexplode`
   (não `information_schema`, que esconde linhas de roles de que a sessão
   não é membro). Na homolog a foto saiu depois do #912 e não serve de base
   de rollback.
4. As credenciais `tl` e `worker` são **só grupos** — nunca entregar a URL
   delas. Sem CREATEROLE não dá para torná-las NOLOGIN.

---

## Passo a passo

### 0 · Preparação

```bash
setopt interactivecomments
heroku login
cd ~/Documents/workspace/chiefs/chiefs-db-migration
APP=<app-prod>
DB=<addon-prod>
EV=evidencias/producao-permissoes-$(date +%Y-%m-%d)
mkdir -p $EV
DEFAULT_URL=$(heroku pg:credentials:url $DB --name default -a $APP | grep -oE 'postgres://[^ ]+' | head -1)
psql "$DEFAULT_URL" -Atc "select current_user, current_database(), version()" | tee $EV/00-conexao.txt
```

Conferir que **não** é `devpemtfal8rfl` (homolog). Se for, parar.

### 1 · Backup verificado

```bash
heroku pg:backups:capture $DB -a $APP
heroku pg:backups -a $APP | head -5 | tee $EV/01-backup.txt
```

O backup mais recente precisa estar `Completed`. Não seguir sem isso.

### 2 · Foto do estado antes (base do rollback)

```bash
psql "$DEFAULT_URL" -c "select c.relnamespace::regnamespace as schema, c.relname, a.grantee::regrole, a.privilege_type from pg_class c cross join lateral aclexplode(c.relacl) a where c.relnamespace in ('app'::regnamespace,'intelligence'::regnamespace) and a.grantee in (select oid from pg_roles where rolname in ('intelligence_user','tl','worker','analytical_reader')) order by 1,2,3,4" > $EV/02-antes-acl-tabelas.txt
psql "$DEFAULT_URL" -c "select pg_get_userbyid(defaclrole), defaclnamespace::regnamespace, defaclobjtype, defaclacl from pg_default_acl order by 1,2,3" > $EV/02-antes-default-acl.txt
psql "$DEFAULT_URL" -c "select count(*) as colunas_com_grant from information_schema.column_privileges where grantee='intelligence_user' and table_schema='app'" > $EV/02-antes-colunas.txt
wc -l $EV/02-antes-*.txt
```

Esperado no estado do P1: `intelligence_user` com SELECT em todas as tabelas
de `app` (≈ 97 linhas) e default ACL de `app` citando `intelligence_user`.

### 3 · Bloco A — #912

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -f ddl/p2-grants-intelligence-user-minimo.sql 2>&1 | tee $EV/03-grants-intelligence-user-minimo.txt
```

Esperado (idêntico à homolog, `feedback-2026-09-22/02`):

| Verificação | Esperado |
|---|---|
| 1 · SELECT table-level em `app` | 3 linhas (`active_campaign_campaigns`, `_contact_messages`, `_contacts`) |
| 2 · default ACL de `app` com `intelligence_user` | 0 linhas |
| 3 · SELECT por coluna (`information_schema`) | **24** tabelas (21 por coluna + 3 inteiras) |
| 4 · UPDATE em `app.chiefs` | **53** |
| 5 · `schema_migrations`, `ar_internal_metadata`, `encrypted_password` (chiefs, startups), `chief_accounts`, `credit_cards` | tudo `f` |

Avisar o Renan: sonda (28/28) + smoke do Intelligence/MCP em produção.

### 4 · Criar as 10 credenciais

```bash
for r in tl worker rubi jade safira ametista roma tokyo bogota oslo; do heroku pg:credentials:create $DB --name $r -a $APP; done
heroku pg:credentials $DB -a $APP
```

Repetir o segundo comando até as 10 aparecerem `active`. **Não** rodar o
`addons:attach` sugerido.

### 5 · A default consegue dar membership?

```bash
psql "$DEFAULT_URL" -c "select r.rolname as grupo, m.admin_option from pg_auth_members m join pg_roles r on r.oid=m.roleid where m.member=(select oid from pg_roles where rolname=current_user) and r.rolname in ('tl','worker','analytical_reader')" | tee $EV/05-admin-option-grupos.txt
```

Esperado: 3 linhas, `admin_option = t` (como na homolog). Se não, parar —
plano B é dar os grants direto a cada usuário (preparar SQL à parte).

### 6 · Bloco B — grupos e membership

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -v ambiente=producao -f ddl/p2-roles-agentes.sql 2>&1 | tee $EV/06-roles-agentes-producao.txt
```

Esperado:

- 8 memberships, todas `inherit_option = t`, `set_option = f`;
- escrita: **7 linhas, todas do `tl`** (`INSERT, UPDATE` em `chief_laudo`,
  `chief_laudo_modal_state`, `jd_chief_stages`, `jd_results`,
  `platform_sync_state`, `system_prompts`, `ui_access_grant`); **nenhuma
  linha do `worker`** (na homolog eram 11);
- SELECT table-level em `app`: **9 linhas** (3 grupos × 3 `active_campaign_*`);
- SELECT por coluna em `app`: **21 tabelas / 340 colunas** por grupo;
- default privileges de `app` citando os grupos: 0 linhas;
- PII (`encrypted_password`, `document`, `reset_password_token`, `credit_cards`,
  `conta_azul_oauth_tokens`, `api_tokens`, `oauth_accounts`): tudo `f`;
- CREATE: 0 linhas.

O bloco B **tem de rodar depois do bloco A**: a seção 2a copia a allowlist do
`intelligence_user` e aborta se não achar as 21 tabelas.

### 7 · `search_path` de cada usuário

```bash
for u in rubi jade safira ametista roma tokyo bogota oslo; do psql "$(heroku pg:credentials:url $DB --name $u -a $APP | grep -oE 'postgres://[^ ]+' | head -1)" -v ON_ERROR_STOP=1 -f ddl/p2-search-path-agentes.sql; done 2>&1 | tee $EV/07-search-path-agentes.txt
```

Esperado: 8 blocos com `{"search_path=intelligence, public, heroku_ext"}`.

### 8 · Teste permitido/negado

```bash
APP=$APP DB=$DB AMBIENTE=producao bash scripts/testa-permissoes-agentes.sh | tee $EV/08-permissoes-agentes-producao.txt
```

Esperado: **`240 PASS, 0 FAIL`** (208 comuns aos 8 usuários — 26 cada,
inclusive as 8 negações de PII em `app` de 25/09 — + 10 do `tl` + 16 do
`worker`, que em produção testa só negações + 6 do reader). Tudo roda
em `BEGIN … ROLLBACK` — nada é gravado.

### 9 · Fechamento

1. Entregar as URLs por canal seguro (`heroku pg:credentials:url $DB --name <usuario> -a $APP`):
   rubi, jade, safira, ametista → Renan; roma, tokyo, bogota, oslo → Bruno.
   `tl` e `worker`: ninguém.
2. Registrar a aplicação com data em `p2/0. p2-entregas.md` e `p3/0. p3-entregas.md`.
3. Resultado da sonda (28/28) do Renan anexado às evidências.

---

## Rollback

**Bloco A (#912)** — volta o `intelligence_user` a ler todas as tabelas de
`app`, como no P1 (conferir contra `02-antes-*.txt`):

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -c "GRANT SELECT ON ALL TABLES IN SCHEMA app TO intelligence_user; ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT ON TABLES TO intelligence_user; ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA app GRANT SELECT ON TABLES TO intelligence_user;"
```

**Bloco B (agentes)** — tirar o acesso de um usuário sem mexer nos outros:

```bash
psql "$DEFAULT_URL" -v ON_ERROR_STOP=1 -c "REVOKE tl FROM rubi;"
```

Remover tudo (as credenciais somem; o Heroku pede confirmação digitando o nome do app):

```bash
for r in rubi jade safira ametista roma tokyo bogota oslo tl worker; do heroku pg:credentials:destroy $DB --name $r -a $APP; done
```

O `analytical_reader` não é destruído (é role do P1); para voltar ao escopo
antigo, revogar dele o SELECT em `app` e `intelligence` e os dois
`ALTER DEFAULT PRIVILEGES … TO … analytical_reader` do `p2-roles-agentes.sql`.

## Incrementos depois (mesma receita)

- **Duda** (terminais + 3 cargas do n8n): `pg:credentials:create` + membership
  no grupo certo ou grants por carga; entra no `p2-roles-agentes.sql` e no
  script de teste, re-rodar os passos 6–8.
- **Tabela nova que precise de escrita** de `tl`/`worker`: default privileges
  só dão SELECT — incluir no `p2-roles-agentes.sql` e re-rodar (idempotente).
- **Coluna nova usada pelas views de compat**: grant por coluna não é coberto
  por default privileges — incluir no `p2-grants-intelligence-user-minimo.sql`
  e re-rodar **os dois** (A e depois B: os agentes copiam a allowlist).
- **Tabela/coluna nova de `app` para os agentes**: não fica legível sozinha
  (sem default privileges em `app` desde 24/09). Entra pela allowlist do
  bloco A, se o Intelligence também precisar, ou por GRANT à parte no
  `p2-roles-agentes.sql` (depois da seção 2a).
