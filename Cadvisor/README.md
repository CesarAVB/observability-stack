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
└── README.md
```

## Pré-requisito: rede overlay do Prometheus

O cAdvisor precisa estar na **mesma rede overlay** do Prometheus para o DNS do Swarm resolvê-lo. No ambiente atual essa rede é **`network_swarm_public`** — já configurada no `docker-compose.yml` em `networks.monitoring.name`.

## Deploy via Portainer (mesmo cluster Swarm)

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `Cadvisor/docker-compose.yml` → **Deploy the stack**.

> ⚠️ O Swarm cria automaticamente o alias de rede curto **`cadvisor`** (igual ao nome do serviço no compose), além do nome com prefixo da stack. É o alias curto que vai no `prometheus_config.yml`.

Verifique:

```bash
docker service ls | grep cadvisor   # deve ficar 1/1 (ou N/N por nó, em mode: global)
```

## Testar o DNS a partir do Prometheus (cluster Swarm)

```bash
docker exec <id-prometheus> getent hosts cadvisor
docker exec <id-prometheus> wget -qO- http://cadvisor:8080/metrics | head
```

Retornou IP / métricas → DNS resolvendo.

## Scrape job no `prometheus_config.yml`

Já configurado em `Prometheus/prometheus_config.yml`, job `cadvisor`, com descoberta DNS em `tasks.cadvisor:8080`. Como a stack roda em `mode: global`, o Prometheus coleta uma task por nó Swarm.

Confira em **Prometheus → Status → Targets**: `cadvisor` = `UP` para os dois targets.

## Importar o dashboard no Grafana

- `../Grafana/dashboards/docker-containers-dashboard.json`

## Notas

- **Multi-nó:** com `mode: global`, sobe 1 cAdvisor por nó. O Prometheus usa `dns_sd_configs` apontando para `tasks.cadvisor`, evitando o VIP do serviço e coletando todas as tasks.
- **`docker stack deploy` ignora `privileged:` e `devices:`** — por isso o `docker-compose.yml` não os usa. O cAdvisor funciona com os volumes montados; no máximo perde alguma métrica de baixo nível.

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
