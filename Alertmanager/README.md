# Alertmanager

Recebe os alertas do Prometheus e notifica no **Telegram**.

```
Prometheus  ──(alertas firing)──▶  Alertmanager  ──▶  Telegram (bot)
 rule_files: alerts.yml             agrupa / deduplica
 alerting: alertmanager:9093        silencia / inibe / repete
```

O Prometheus **detecta**; o Alertmanager **notifica**. Sem esta stack, alertas
só aparecem na aba *Alerts* da UI do Prometheus e ninguém é avisado.

| | |
|---|---|
| Porta | `9093` (UI web + API) |
| Config | `alertmanager.yml` (Docker Config `file:`) |
| Token do bot | Docker **secret** `telegram_bot_token` (não vai pro git) |
| Persistência | volume `alertmanager_data` (silences sobrevivem a restart) |
| Rede | `network_swarm_public` — Prometheus alcança por `alertmanager:9093` |

## Grupos do Telegram e som

São **2 grupos** no Telegram, os dois com o mesmo bot (`@lognet_alertas_bot`):

| Grupo | chat_id | Recebe |
|---|---|---|
| **Lognet - Observabilidade** | `-1004347506618` | apps Java, APIs, certificados, infra da observabilidade |
| **Lognet - Alertas TV** | `-1004439481378` | tudo com `servico="flussonic"`: canais, origens, ping dos IPs do Flussonic |

Dentro de cada grupo, a **severidade** decide se o celular toca:

- `critical` → a mensagem chega e **toca/vibra** normalmente.
- `warning` → a mensagem **chega igual no grupo**, mas **sem som** (`disable_notifications: true`).

Como cada combinação de grupo e som precisa de um receiver, o `alertmanager.yml` tem **4 receivers**
para os **2 grupos**:

| Configuração interna | Grupo | Toca? |
|---|---|---|
| `telegram` | Observabilidade | 🔔 sim |
| `telegram-silencioso` | Observabilidade | 🔕 não |
| `telegram-tv` | Alertas TV | 🔔 sim |
| `telegram-tv-silencioso` | Alertas TV | 🔕 não |

Os 4 usam a mesma mensagem e o mesmo token: `telegram` define a âncora `&telegram_base` e os outros
fazem `<<: *telegram_base`, trocando só `chat_id` e `disable_notifications`. Para conferir para qual
receiver um alerta vai:

```bash
amtool config routes test --config.file=alertmanager.yml servico=flussonic severity=warning
# telegram-tv-silencioso
```

> **Supergrupo muda o id.** Se um grupo comum virar supergrupo (tornar público, histórico visível
> para novos membros, mais de 200 membros), o `chat_id` muda para `-100…` e o envio falha **em
> silêncio** (`group chat was upgraded to a supergroup chat (400)` no log). O id novo vem no
> `migrate_to_chat_id` da resposta de erro de um `sendMessage` para o id antigo. Os dois grupos
> acima já são supergrupos.

## Primeiro deploy

### 1. Criar o bot do Telegram
1. Fale com o [@BotFather](https://t.me/BotFather) → `/newbot` → guarde o token.
2. Adicione o bot ao grupo/canal que vai receber os alertas.
3. Pegue o `chat_id`:
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
   Mande uma mensagem qualquer no grupo e procure `"chat":{"id":-100...}` na resposta.
   Grupo/canal = número **negativo**.

### 2. Criar o secret no servidor (via SSH, uma vez)
```bash
printf '123456789:ABCdef_your_token_here' | docker secret create telegram_bot_token -
```

### 3. Ajustar o `chat_id`
Editar `chat_id` nos receivers de `Alertmanager/alertmanager.yml` com o número do passo 1, e dar push.

### 4. Adicionar a stack no Portainer
Stacks → Add stack → Build method **Repository** → URL deste repo →
Compose path `Alertmanager/docker-compose.yml` → Deploy.

### 5. Redeploy do Prometheus
A stack Prometheus já foi alterada (`rule_files` + `alerting` + config novo de
regras). Portainer → stack Prometheus → **Pull and redeploy**.

### 6. Validar
- `http://45.187.224.251:9090/rules` → regras carregadas, sem erro de sintaxe.
- `http://45.187.224.251:9090/alerts` → alertas em estado `inactive`/`pending`/`firing`.
- `http://45.187.224.251:9093` → UI do Alertmanager.
- Teste ponta a ponta: pare um alvo de propósito (ou use `amtool`) e veja a
  mensagem chegar no Telegram após ~2min + `group_wait`.

## Atualizar regras ou config

- **Regras de alerta:** editar `Prometheus/rules/alerts.yml` → push → *Pull and
  redeploy* da stack **Prometheus**.
- **Roteamento / receivers:** editar `Alertmanager/alertmanager.yml` → incrementar
  `name: alertmanager_config_vN` no `docker-compose.yml` → push → *Pull and redeploy*
  da stack **Alertmanager**. Sem trocar o nome, o Swarm pode manter o config antigo.

## Silenciar durante manutenção

UI do Alertmanager (`:9093`) → **Silences** → New Silence → matcher
(ex.: `application="talkchat-backend"`) → duração. Ou via `amtool`.

## Firewall

A `9093` está no grupo "portas internas/publicadas" — liberar só para as redes
confiáveis em `Firewall/firewall-setup-lognet.sh` (`ALLOWED_NETWORKS`), como as
demais portas internas. A UI não tem autenticação própria.
