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
├── docker-compose.swarm-asb.yml        # Stack Swarm no ASB/.248, com porta publicada
└── README.md
```

## Pré-requisito: rede overlay do Prometheus

O node-exporter precisa estar na **mesma rede overlay** do Prometheus para o DNS do Swarm resolvê-lo. No ambiente atual essa rede é **`network_swarm_public`** — já configurada no `docker-compose.yml` em `networks.monitoring.name`.

## Deploy via Portainer (mesmo cluster Swarm)

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `NodeExporter/docker-compose.yml` → **Deploy the stack**.

> ⚠️ O Swarm cria automaticamente o alias de rede curto **`node-exporter`** (igual ao nome do serviço no compose), além do nome com prefixo da stack. É o alias curto que vai no `prometheus_config.yml`.

Verifique:

```bash
docker service ls | grep node-exporter   # deve ficar 1/1 (ou N/N por nó, em mode: global)
```

## Deploy no Swarm do servidor 45.187.224.248

O `.248` está em outro Swarm/Portainer. Por isso o Prometheus do `.251` não enxerga o DNS interno desse Swarm e precisa coletar via IP público.

Portainer do ASB/`.248` → **Stacks → Add stack** → Build method **Repository** → Compose path `NodeExporter/docker-compose.swarm-asb.yml` → **Deploy the stack**.

Esse compose publica `9100:9100` em `mode: host`. Depois rode o firewall do `.248`:

```bash
sudo chmod +x ../Firewall/firewall-setup-asb.sh && sudo ../Firewall/firewall-setup-asb.sh
```

## Testar o DNS a partir do Prometheus (cluster Swarm)

```bash
docker exec <id-prometheus> getent hosts node-exporter
docker exec <id-prometheus> wget -qO- http://node-exporter:9100/metrics | head
```

Retornou IP / métricas → DNS resolvendo.

## Scrape job no `prometheus_config.yml`

Já configurado em `Prometheus/prometheus_config.yml`, job `node-exporter`, com dois targets: `node-exporter:9100` para o Swarm do `.251` e `45.187.224.248:9100` para o Swarm separado do `.248`.

Confira em **Prometheus → Status → Targets**: `node-exporter` = `UP` para os dois targets.

## Importar o dashboard no Grafana

- `../Grafana/dashboards/host-linux-dashboard.json`

O seletor **Host** no topo lista a instância automaticamente.

## Notas

- **Dois Swarms:** DNS interno (`node-exporter`) só funciona dentro do Swarm do `.251`. Para o `.248`, o scrape é via IP público e porta publicada.

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
