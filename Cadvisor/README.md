<h1 align="center">cAdvisor com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-cadvisor-blueviolet"/>
  <img src="https://img.shields.io/badge/cAdvisor-v0.49.1-2496ED?logo=google&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Stack do <strong>cAdvisor</strong> em Docker via Portainer para coletar métricas por container, lidas pelo Prometheus já existente. Não duplica Prometheus nem Grafana.
</p>

---

## Tecnologias Utilizadas

- **Docker (Swarm)** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **cAdvisor** — métricas por container (CPU, RAM, rede, I/O)

## Sobre o Projeto

Esta stack sobe apenas o **cAdvisor**. Ele expõe métricas que o **Prometheus** já em execução coleta via scrape e o **Grafana** exibe no dashboard `docker-containers-dashboard.json`. Em **Docker Swarm**, roda em `mode: global` (uma instância por nó do cluster).

| Serviço | Camada | Porta | Alimenta o dashboard |
|---|---|---|---|
| `cadvisor` | Por container Docker: CPU, RAM, rede, I/O | `8080` | `../Grafana/dashboards/docker-containers-dashboard.json` |

## Estrutura do Projeto

```
.
├── docker-compose.yml            # Stack Swarm (mesmo cluster do Prometheus)
├── docker-compose.standalone.yml # Docker Compose puro (host fora do Swarm, ex.: 45.187.224.248)
└── README.md
```

> O script de firewall do host standalone (45.187.224.248) fica centralizado em `../Firewall/firewall-setup-248-cadvisor.sh` — ver `../Firewall/README.md`.

## Pré-requisito: rede overlay do Prometheus

O cAdvisor precisa estar na **mesma rede overlay** do Prometheus para o DNS do Swarm resolvê-lo. No ambiente atual essa rede é **`network_swarm_public`** — já configurada no `docker-compose.yml` em `networks.monitoring.name`.

## Deploy via Portainer (mesmo cluster Swarm)

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `Cadvisor/docker-compose.yml` → **Deploy the stack**.

> ⚠️ O Swarm cria automaticamente o alias de rede curto **`cadvisor`** (igual ao nome do serviço no compose), além do nome com prefixo da stack. É o alias curto que vai no `prometheus_config.yml`.

Verifique:

```bash
docker service ls | grep cadvisor   # deve ficar 1/1 (ou N/N por nó, em mode: global)
```

## Deploy standalone (servidor fora do Swarm, ex.: 45.187.224.248)

```bash
docker compose -f docker-compose.standalone.yml up -d
sudo chmod +x ../Firewall/firewall-setup-248-cadvisor.sh && sudo ../Firewall/firewall-setup-248-cadvisor.sh
```

> **OBS:** no standalone o cAdvisor é publicado na porta **8081** do host (a 8080 já está em uso nesse servidor). Dentro do container ele continua escutando na 8080 — é por isso que o target no Prometheus usa `:8080`, mas o firewall protege a `8081`.

O Prometheus coleta via **IP público** do host na porta `8081` (mapeada para a `8080` do container) — protegida pelo firewall pra só aceitar as redes confiáveis (que incluem o Prometheus em `45.187.224.251`).

## Testar o DNS a partir do Prometheus (cluster Swarm)

```bash
docker exec <id-prometheus> getent hosts cadvisor
docker exec <id-prometheus> wget -qO- http://cadvisor:8080/metrics | head
```

Retornou IP / métricas → DNS resolvendo.

## Scrape job no `prometheus_config.yml`

Já configurado em `Prometheus/prometheus_config.yml`, job `cadvisor`, com dois targets: `cadvisor:8080` (srv-251, via DNS do Swarm) e `45.187.224.248:8080` (srv-248, standalone via IP público mapeado da 8081).

Confira em **Prometheus → Status → Targets**: `cadvisor` = `UP` para os dois targets.

## Importar o dashboard no Grafana

- `../Grafana/dashboards/docker-containers-dashboard.json`

## Notas

- **Multi-nó:** com `mode: global`, sobe 1 cAdvisor por nó. Para o Prometheus coletar **todos** os nós (e não só o VIP), troque o `static_configs` por `dns_sd_configs` apontando para `tasks.cadvisor` (porta no campo `port`). Para 1 nó só, o static basta.
- **`docker stack deploy` ignora `privileged:` e `devices:`** — por isso o `docker-compose.yml` (modo Swarm) não os usa. O cAdvisor funciona com os volumes montados; no máximo perde alguma métrica de baixo nível. Já o `docker-compose.standalone.yml` (Compose puro) usa `privileged: true` normalmente.

### Consultas úteis

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
