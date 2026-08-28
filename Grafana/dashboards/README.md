# Dashboards Grafana — Stack de Observabilidade

Dashboards prontos para importar, cobrindo aplicação, host, containers e logs de rede.

| Arquivo | Fonte de dados | O que mostra |
|---|---|---|
| `spring-application-dashboard.json` | Prometheus + Loki | Aplicação Spring Boot: JVM, HTTP, latência, erros, logs, conexões de DB |
| `host-linux-dashboard.json` | Prometheus (node-exporter) | Host Linux: CPU, memória, disco, rede, load |
| `docker-containers-dashboard.json` | Prometheus (cAdvisor) | Por container Docker: CPU, memória, rede, I/O |
| `syslog-switches.json` | Loki (syslog-ng) | Syslog dos switches Huawei: logs filtrados por switch, severidade e tempo |

---

## Pré-requisitos

O dashboard de aplicação usa plugins de painel customizado. Instale antes de importar:

```bash
# No container/servidor do Grafana
grafana-cli plugins install marcusolsson-dynamictext-panel
grafana-cli plugins install gapit-htmlgraphics-panel
grafana-cli plugins install grafana-clock-panel  # opcional

# Reinicie o Grafana após instalar
systemctl restart grafana-server
# ou no Docker:
docker restart grafana
```

Os dashboards de host e containers usam apenas painéis nativos (Time Series, Bar Gauge, Stat) — não exigem plugins.

---

## Como importar

1. Acesse `http://45.187.224.251:3000`
2. **Dashboards → New → Import**
3. Clique em **Upload JSON file** e selecione o `.json` desejado
4. Na tela de configuração, mapeie os datasources:
   - **Prometheus** → selecione `Prometheus`
   - **Loki** → selecione `Loki` (apenas para o dashboard de aplicação)
5. Clique em **Import**

---

## Dashboard de Aplicação (Spring Boot)

### Estrutura

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER BANNER — Business Text                              │
│  Aplicação · Observabilidade · Indicador Ao Vivo           │
├──────────┬──────────┬──────────┬──────────────────────────┤
│ Req/min  │ Erro %   │ P95 (ms) │ Heap JVM %              │
│ HTML Grp │ HTML Grp │ HTML Grp │ HTML Grp + barra         │
├────────────────────────────────┬────────────────────────────┤
│  MAPA DE TOPOLOGIA             │  LOGS RECENTES             │
│  HTML Graphics (SVG animado)   │  Business Text             │
│  Client→Nginx→App→MySQL/Prom   │  Erros & Avisos do Loki    │
├────────────────────────┬───────┴────────────────────────────┤
│  HTTP req/s por Status  │  GAUGE Taxa de Erro               │
│  Time Series (nativo)   │  HTML Graphics (SVG arc animado)  │
├────────────────────────┴───────────────────────────────────┤
│  TABELA — Top Endpoints por Volume                         │
│  Business Text — método, URI, status, req/min, latência    │
└────────────────────────────────────────────────────────────┘
```

### Painéis — Detalhes

| Título | Plugin | Query |
|--------|--------|-------|
| Header Banner | **Business Text** | estático |
| Requisições / min | **HTML Graphics** | `rate(http_server_requests_seconds_count[5m]) * 60` |
| Taxa de Erro | **HTML Graphics** | erros 5xx / total × 100 |
| Latência P95 | **HTML Graphics** | `histogram_quantile(0.95, ...)` × 1000 ms |
| Heap JVM | **HTML Graphics** | `jvm_memory_used_bytes / jvm_memory_max_bytes` |
| Mapa de Topologia | **HTML Graphics** | `up{application="$app_name"}` |
| Logs Recentes | **Loki (Logs)** | `{app="$app_name"} \| pattern ...` |
| HTTP req/s por Status | Time Series | `rate(...) by (status)` |
| Gauge Taxa de Erro | **HTML Graphics** | idem painel de Taxa de Erro |
| Top Endpoints | **Bar Gauge** | `sum(increase(http_server_requests_seconds_count[$__range])) by (uri)` |

### Thresholds de Cor

| Métrica | Verde | Amarelo | Vermelho |
|---------|-------|---------|----------|
| Taxa de Erro | < 0,5% | 0,5–2% | ≥ 2% |
| Latência P95 | < 500ms | 500–1000ms | ≥ 1000ms |
| Heap JVM | < 70% | 70–85% | ≥ 85% |
| Req/min | < 1000 | 1000–5000 | ≥ 5000 |

### Variável de Template

O dashboard expõe a variável `$app_name`, populada via `label_values(http_server_requests_seconds_count, application)` e filtrada pelo regex `lognet.*`. Use o seletor **Aplicação** no topo para escolher o serviço — os painéis Prometheus **e** o painel de logs Loki (`{app="$app_name"}`) acompanham a seleção.

> Isso pressupõe que o label `app` no Loki use o mesmo valor que o label `application` no Prometheus (convenção do `logback-spring.xml`). Para listar outras aplicações no seletor, ajuste o regex da variável `app_name` (atualmente `lognet.*`).

### Personalização

**Trocar a fonte de logs:** edite a query Loki do painel de logs para incluir outros labels:
```logql
{app="$app_name", namespace="producao"} | pattern `...`
```

**Campo `correlationId` nos logs:** o painel de logs extrai `correlationId`, `traceId` e `spanId` via `pattern` do LogQL. O backend deve injetar esses campos via MDC.

**Ajustar thresholds do gauge:** no `onRender` do painel, edite as constantes:
```javascript
var color = pct >= 2 ? '#EF4444' : pct >= 0.5 ? '#F59E0B' : '#10B981';
```

---

## Dashboards de Host e Containers

- **`host-linux-dashboard.json`** — métricas do node-exporter. O seletor **Host** no topo lista a instância automaticamente.
- **`docker-containers-dashboard.json`** — métricas do cAdvisor, agrupadas por container.

Ambos dependem das stacks `../../NodeExporter/` e `../../Cadvisor/` e dos jobs `node-exporter` / `cadvisor` no `prometheus_config.yml`. Ver `NodeExporter/README.md` e `Cadvisor/README.md` para o deploy dos exporters.

---

## Dashboard de Syslog (Switches Huawei)

- **`syslog-switches.json`** — logs de syslog dos switches Huawei, coletados pelo
  syslog-ng e enviados ao Loki (ver `../../Syslog/README.md`). Header banner
  (Business Text) no padrão LOGNET, cartões de stat, Time Series, Bar Gauge e Logs.

### Layout

```
┌──────────────────────────────────────────────────────────────┐
│  HEADER BANNER — Syslog · Switches Huawei · LOGNET · Ao vivo  │
├──────────────┬──────────────┬──────────────┬─────────────────┤
│ Total de     │ Switches     │ Avisos       │ Críticos (err+) │
│ logs         │ ativos       │ (warning)    │                 │
├──────────────┴──────────────┴──────┬───────┴─────────────────┤
│  VOLUME DE LOGS POR SWITCH         │  TOTAL POR SEVERIDADE    │
│  Time Series (barras empilhadas)   │  Bar Gauge (cor/nível)   │
├────────────────────────────────────┴─────────────────────────┤
│  LOGS DOS SWITCHES — Tabela (Hora · Switch · Evento · Msg)   │
└──────────────────────────────────────────────────────────────┘
```

Cartões de stat: **Avisos** fica laranja com ≥1 warning; **Críticos** fica
vermelho com ≥1 evento `err`/`crit`/`alert`/`emerg` (ambos ignoram o filtro
`$severity` de propósito, para sempre sinalizar). No Bar Gauge, cada severidade
tem cor própria (vermelho = err/crit, laranja = warning, azul = notice, verde = info).

A **tabela de logs** desmembra o formato proprietário Huawei
(`%%01MÓDULO/nível/EVENTO(flag)[seq]:descrição`) em colunas, via um parser
`| regexp` no LogQL, deixando a leitura limpa em vez de uma linha gigante:

| Coluna | Origem |
|---|---|
| Hora | timestamp do log no Loki |
| Switch | hostname (sysname) extraído da linha |
| Evento | mnemônico Huawei (ex.: `PKT_OUTQUEDROP_ABNL`, `CPCAR_DROP_MPU`) |
| Mensagem | descrição do evento |

Colunas são filtráveis (ícone de filtro no cabeçalho) e mensagens longas ficam
inspecionáveis na célula. Para ver a linha bruta completa, use o **Explore** do
Grafana com `{job="huawei-switches"}`.

### Pré-requisitos

- Datasource **Loki** configurado no Grafana (`http://loki:3100`). Ao importar,
  mapeie a variável **Datasource Loki** para o datasource Loki existente.
- Plugin **`marcusolsson-dynamictext-panel`** (Business Text) para o header banner
  — já incluído no `GF_INSTALL_PLUGINS` do `Grafana/docker-compose.yml`.
- Plugin **`gapit-htmlgraphics-panel`** (HTML Graphics) para os 4 cartões de KPI
  (mesmo plugin do dashboard de aplicação Spring — ver "Pré-requisitos" no topo).

### Variáveis de template

| Variável | Origem | Uso |
|---|---|---|
| `$datasource` | tipo `datasource` / `loki` | Torna o dashboard portátil entre instâncias. |
| `$switch` | `label_values({job="huawei-switches"}, host)` | Seletor **Switch**, multi-select + "All". |
| `$severity` | `label_values({job="huawei-switches"}, severity)` | Seletor **Severidade**, multi-select + "All". |

### Painéis

| Título | Painel | Query (LogQL) |
|---|---|---|
| Volume de logs por switch | Time Series (barras empilhadas) | `sum by (host) (count_over_time({job="huawei-switches", host=~"$switch", severity=~"$severity"}[$__interval]))` |
| Total por severidade | Bar Gauge | `sum by (severity) (count_over_time({job="huawei-switches", host=~"$switch", severity=~"$severity"}[$__range]))` |
| Logs dos switches | Logs | `{job="huawei-switches", host=~"$switch", severity=~"$severity"}` |

O filtro **por intervalo de tempo** usa o time picker nativo do Grafana (default `now-6h`).
