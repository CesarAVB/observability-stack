<h1 align="center">node-exporter com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-node--exporter-blueviolet"/>
  <img src="https://img.shields.io/badge/node--exporter-v1.8.2-E6522C?logo=prometheus&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Stack do <strong>node-exporter</strong> em Docker via Portainer para coletar métricas do host Linux, lidas pelo Prometheus já existente. Não duplica Prometheus nem Grafana.
</p>

---

## Tecnologias Utilizadas

- **Docker (Swarm)** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **node-exporter** — métricas do host (CPU, RAM, disco, rede, load)

## Sobre o Projeto

Esta stack sobe apenas o **node-exporter**. Ele expõe métricas que o **Prometheus** já em execução coleta via scrape e o **Grafana** exibe no dashboard `host-linux-dashboard.json`. Em **Docker Swarm**, roda em `mode: global` (uma instância por nó do cluster).

| Serviço | Camada | Porta | Alimenta o dashboard |
|---|---|---|---|
| `node-exporter` | Host (máquina/VM): CPU, RAM, disco, rede, load | `9100` | `../Grafana/dashboards/host-linux-dashboard.json` |

## Estrutura do Projeto

```
.
├── docker-compose.yml            # Stack Swarm (mesmo cluster do Prometheus)
├── docker-compose.standalone.yml # Docker Compose puro (host fora do Swarm, ex.: 45.187.224.248)
└── README.md
```

> O script de firewall do host standalone (45.187.224.248) fica centralizado em `../Firewall/firewall-setup-248-node-exporter.sh` — ver `../Firewall/README.md`.

## Pré-requisito: rede overlay do Prometheus

O node-exporter precisa estar na **mesma rede overlay** do Prometheus para o DNS do Swarm resolvê-lo. No ambiente atual essa rede é **`network_swarm_public`** — já configurada no `docker-compose.yml` em `networks.monitoring.name`.

## Deploy via Portainer (mesmo cluster Swarm)

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `NodeExporter/docker-compose.yml` → **Deploy the stack**.

> ⚠️ O Swarm cria automaticamente o alias de rede curto **`node-exporter`** (igual ao nome do serviço no compose), além do nome com prefixo da stack. É o alias curto que vai no `prometheus_config.yml`.

Verifique:

```bash
docker service ls | grep node-exporter   # deve ficar 1/1 (ou N/N por nó, em mode: global)
```

## Deploy standalone (servidor fora do Swarm, ex.: 45.187.224.248)

```bash
docker compose -f docker-compose.standalone.yml up -d
sudo chmod +x ../Firewall/firewall-setup-248-node-exporter.sh && sudo ../Firewall/firewall-setup-248-node-exporter.sh
```

O Prometheus coleta via **IP público** do host na porta `9100` — protegida pelo firewall pra só aceitar as redes confiáveis (que incluem o Prometheus em `45.187.224.251`).

## Testar o DNS a partir do Prometheus (cluster Swarm)

```bash
docker exec <id-prometheus> getent hosts node-exporter
docker exec <id-prometheus> wget -qO- http://node-exporter:9100/metrics | head
```

Retornou IP / métricas → DNS resolvendo.

## Scrape job no `prometheus_config.yml`

Já configurado em `Prometheus/prometheus_config.yml`, job `node-exporter`, com dois targets: `node-exporter:9100` (srv-251, via DNS do Swarm) e `45.187.224.248:9100` (srv-248, standalone via IP público).

Confira em **Prometheus → Status → Targets**: `node-exporter` = `UP` para os dois targets.

## Importar o dashboard no Grafana

- `../Grafana/dashboards/host-linux-dashboard.json`

O seletor **Host** no topo lista a instância automaticamente.

## Notas

- **Multi-nó:** com `mode: global`, sobe 1 exporter por nó. Para o Prometheus coletar **todos** os nós (e não só o VIP), troque o `static_configs` por `dns_sd_configs` apontando para `tasks.node-exporter` (porta no campo `port`). Para 1 nó só, o static basta.

### Consulta útil

```promql
node_load1                    # load average de 1 minuto por host
```

## Contato

**Autor:** César Augusto
**E-mail:** cesar.augusto.rj1@gmail.com
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
