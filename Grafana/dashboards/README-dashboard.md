# LogNet CRM — Dashboard Grafana

## Pré-requisitos

Instale os dois plugins no Grafana antes de importar:

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

---

## Como importar

1. Acesse `http://45.187.224.251:3000`
2. **Dashboards → New → Import**
3. Clique em **Upload JSON file** e selecione `lognet-crm-dashboard.json`
4. Na tela de configuração, mapeie os datasources:
   - **Prometheus** → selecione `Prometheus`
   - **Loki** → selecione `Loki`
5. Clique em **Import**

---

## Estrutura do Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│  HEADER BANNER — Business Text                              │
│  LogNet CRM · Observabilidade · Indicador Ao Vivo          │
├──────────┬──────────┬──────────┬──────────────────────────┤
│ Req/min  │ Erro %   │ P95 (ms) │ Heap JVM %              │
│ HTML Grp │ HTML Grp │ HTML Grp │ HTML Grp + barra         │
├────────────────────────────────┬────────────────────────────┤
│  MAPA DE TOPOLOGIA             │  LOGS RECENTES             │
│  HTML Graphics (SVG animado)   │  Business Text             │
│  Client→Nginx→CRM→MySQL/Prom   │  Erros & Avisos do Loki    │
├────────────────────────┬───────┴────────────────────────────┤
│  HTTP req/s por Status  │  GAUGE Taxa de Erro               │
│  Time Series (nativo)   │  HTML Graphics (SVG arc animado)  │
├────────────────────────┴───────────────────────────────────┤
│  TABELA — Top Endpoints por Volume                         │
│  Business Text — método, URI, status, req/min, latência    │
└────────────────────────────────────────────────────────────┘
```

---

## Painéis — Detalhes

| # | Título | Plugin | Query |
|---|--------|--------|-------|
| 1 | Header Banner | **Business Text** | estático |
| 2 | Requisições / min | **HTML Graphics** | `rate(http_server_requests_seconds_count[5m]) * 60` |
| 3 | Taxa de Erro | **HTML Graphics** | erros 5xx / total × 100 |
| 4 | Latência P95 | **HTML Graphics** | `histogram_quantile(0.95, ...)` × 1000 ms |
| 5 | Heap JVM | **HTML Graphics** | `jvm_memory_used_bytes / jvm_memory_max_bytes` |
| 6 | Mapa de Topologia | **HTML Graphics** | `up{job=~"$job"}` |
| 7 | Logs Recentes | **Business Text** | Loki: `{job=~"$job"} \| json \| level=~"ERROR\|WARN"` |
| 8 | HTTP req/s por Status | Time Series | `rate(...) by (status)` |
| 9 | Gauge Taxa de Erro | **HTML Graphics** | idem painel 3 |
| 10 | Top Endpoints | **Business Text** | `topk(10, sum(rate(...)) by (uri, method, status))` |

---

## Thresholds de Cor

| Métrica | Verde | Amarelo | Vermelho |
|---------|-------|---------|----------|
| Taxa de Erro | < 0,5% | 0,5–2% | ≥ 2% |
| Latência P95 | < 500ms | 500–1000ms | ≥ 1000ms |
| Heap JVM | < 70% | 70–85% | ≥ 85% |
| Req/min | < 1000 | 1000–5000 | ≥ 5000 |

---

## Variável de Template

O dashboard expõe a variável `$job` (populada via `label_values(up, job)` no Prometheus, filtrado por `lognet.*`). Use o seletor no topo para filtrar por instância/serviço.

---

## Personalização

### Trocar a fonte de logs no painel 7

Edite a query Loki para incluir outros labels:
```logql
{job=~"$job", namespace="producao"} | json | level=~"ERROR|WARN"
```

### Adicionar o label `correlationId` nos logs

O painel 7 exibe o campo `correlationId` automaticamente se estiver presente no JSON do log. O backend já injeta esse campo via MDC (ver `CLAUDE.md`).

### Ajustar thresholds do gauge (painel 9)

No `onRender` do painel 9, edite as constantes:
```javascript
var color = pct >= 2 ? '#EF4444' : pct >= 0.5 ? '#F59E0B' : '#10B981';
```
