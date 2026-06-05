<h1 align="center">Monitoramento de Infraestrutura (Exporters) com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-monitoring-blueviolet"/>
  <img src="https://img.shields.io/badge/node--exporter-v1.8.2-E6522C?logo=prometheus&logoColor=white"/>
  <img src="https://img.shields.io/badge/cAdvisor-v0.49.1-2496ED?logo=google&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Stack de <strong>exporters</strong> em Docker via Portainer para coletar métricas do host Linux e dos containers, lidas pelo Prometheus já existente. Não duplica Prometheus nem Grafana.
</p>

---

## Tecnologias Utilizadas

- **Docker (Swarm)** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **node-exporter** — métricas do host (CPU, RAM, disco, rede, load)
- **cAdvisor** — métricas por container (CPU, RAM, rede, I/O)

## Sobre o Projeto

Esta stack sobe apenas os **exporters** de infraestrutura. Eles expõem métricas que o **Prometheus** já em execução coleta via scrape e o **Grafana** exibe nos dashboards. Em **Docker Swarm**, ambos os exporters rodam em `mode: global` (uma instância por nó do cluster).

| Serviço | Camada | Porta | Alimenta o dashboard |
|---|---|---|---|
| `node-exporter` | Host (máquina/VM): CPU, RAM, disco, rede, load | `9100` | `../Grafana/dashboards/host-linux-dashboard.json` |
| `cadvisor` | Por container Docker: CPU, RAM, rede, I/O | `8080` | `../Grafana/dashboards/docker-containers-dashboard.json` |

## Estrutura do Projeto

```
.
├── docker-compose.yml       # Stack Swarm dos exporters (node-exporter + cadvisor)
└── README.md
```

## Pré-requisito: rede overlay do Prometheus

Os exporters precisam estar na **mesma rede overlay** do Prometheus para o DNS do Swarm resolvê-los. Descubra o nome:

```bash
# <id> = container do Prometheus (docker ps | grep prometheus)
docker inspect <id> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
```

No ambiente atual essa rede é **`network_swarm_public`** — já configurada no `docker-compose.yml` em `networks.monitoring.name`. Se mudar, ajuste lá.

## Deploy via Portainer

Via CLI:

```bash
docker stack deploy -c docker-compose.yml monitoring
```

Ou pelo **Portainer → Stacks → Add stack**, colando o conteúdo do `docker-compose.yml`.

> ⚠️ O **nome da stack vira prefixo** dos serviços no DNS do Swarm.
> Stack `monitoring` → serviços `monitoring_node-exporter` e `monitoring_cadvisor`.
> É esse nome com prefixo que vai no `prometheus_config.yml`.

Verifique:

```bash
docker stack services monitoring   # node-exporter e cadvisor devem ficar 1/1
```

## Testar o DNS a partir do Prometheus

```bash
docker exec <id-prometheus> getent hosts monitoring_node-exporter
docker exec <id-prometheus> wget -qO- http://monitoring_cadvisor:8080/metrics | head
```

Retornou IP / métricas → DNS resolvendo.

## Scrape jobs no `prometheus_config.yml`

Use os nomes **com o prefixo da stack** (`monitoring_`). São HTTP puro — sem `scheme`/`tls_config`:

```yaml
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['monitoring_node-exporter:9100']
        labels:
          app: 'host-linux'
          env: 'production'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['monitoring_cadvisor:8080']
        labels:
          app: 'containers'
          env: 'production'
```

Recarregar o Prometheus:

```bash
docker exec <id-prometheus> kill -HUP 1
# ou, se o lifecycle estiver habilitado:
# curl -X POST http://localhost:9090/-/reload
```

Confira em **Prometheus → Status → Targets**: `node-exporter` e `cadvisor` = `UP`.

## Importar os dashboards no Grafana

- `../Grafana/dashboards/host-linux-dashboard.json`
- `../Grafana/dashboards/docker-containers-dashboard.json`

O seletor **Host** no topo lista a instância automaticamente.

## Notas

- **Multi-nó:** com `mode: global`, sobe 1 exporter por nó. Para o Prometheus coletar **todos** os nós (e não só o VIP), troque os `static_configs` por `dns_sd_configs` apontando para `tasks.monitoring_node-exporter` / `tasks.monitoring_cadvisor` (porta no campo `port`). Para 1 nó só, o static basta.
- **`docker stack deploy` ignora `privileged:` e `devices:`** — por isso o compose não os usa. O cAdvisor funciona com os volumes montados; no máximo perde alguma métrica de baixo nível.

### Consultas úteis do cAdvisor

```promql
container_memory_working_set_bytes{name!=""}                              # RAM por container
sum(rate(container_cpu_usage_seconds_total{name!=""}[5m])) by (name)      # CPU por container
```

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
