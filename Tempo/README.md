<h1 align="center">Tempo com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-tempo-blueviolet"/>
  <img src="https://img.shields.io/badge/Tempo-2.6.0-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Grafana Tempo 2.6.0 em Docker via Portainer, com recebimento de traces via OTLP (gRPC e HTTP), configuração via Docker Config e retenção de 48 horas.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Grafana Tempo 2.6.0** — backend de rastreamento distribuído (distributed tracing)

## Sobre o Projeto

Este repositório documenta a implementação do **Grafana Tempo** utilizando Docker via Portainer, com Stack (Docker Compose), configuração via Docker Config referenciado por arquivo (deploy via Portainer "Repository") e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Recebimento e armazenamento de traces distribuídos via protocolo OTLP
- Integração com Grafana para visualização de traces e correlação com logs (Loki) e métricas (Prometheus)
- Retenção configurável de traces (padrão: 48 horas)
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Tempo
├── tempo_config.yml            # Configuração do Tempo (receivers, storage, retenção)
└── README.md
```

## Configuração do Tempo

O arquivo `tempo_config.yml` define o comportamento do Tempo. Principais parâmetros:

```yaml
compactor:
  compaction:
    block_retention: 48h   # Altere para ajustar o período de retenção

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317   # OTLP gRPC
        http:
          endpoint: 0.0.0.0:4318   # OTLP HTTP
```

## Deploy via Portainer

O `docker-compose.yml` referencia o config via `file: ./tempo_config.yml` — não é `external`. Pra isso resolver no servidor, a stack precisa ser criada com **Build method → Repository**, apontando pro remoto Git deste repositório, com **Compose path** `Tempo/docker-compose.yml`.

### Primeiro deploy

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `Tempo/docker-compose.yml` → **Deploy the stack**.

### Atualizar a configuração

Edite `tempo_config.yml` neste repo, dê push pro remoto e, no Portainer, rode **Pull and redeploy** na stack. O Portainer recria o Docker Config automaticamente — sem SSH, sem `docker config create/rm` manual.

## Portas

| Porta | Protocolo | Função |
|---|---|---|
| `3200` | HTTP | Query API / Interface |
| `4317` | gRPC | Recebimento de traces OTLP |
| `4318` | HTTP | Recebimento de traces OTLP |

## Persistência de Dados

Os dados do Tempo são persistidos no volume Docker `tempo_data`, gerenciado automaticamente pelo Docker. Os diretórios internos utilizados são:

```
/var/tempo/blocks   # Blocos de traces compactados
/var/tempo/wal      # Write-Ahead Log
```

## Integração com Grafana

No Grafana, adicione o Tempo como datasource:

- **URL:** `http://tempo:3200`
- **Tipo:** Tempo

Para correlação de traces com logs, configure o link para o datasource do Loki nas configurações do Tempo no Grafana.

## Rede

A stack utiliza a rede externa `network_swarm_public`. Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Segurança

As portas `3200` (query), `4317` (OTLP gRPC) e `4318` (OTLP HTTP) não possuem autenticação — restrinja o acesso via firewall às redes confiáveis:

```bash
ufw allow from 168.90.16.0/22 to any port 3200
ufw allow from 45.187.224.0/22 to any port 3200
ufw allow from 168.90.16.0/22 to any port 4317
ufw allow from 45.187.224.0/22 to any port 4317
ufw allow from 168.90.16.0/22 to any port 4318
ufw allow from 45.187.224.0/22 to any port 4318
ufw deny 3200
ufw deny 4317
ufw deny 4318
```

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
