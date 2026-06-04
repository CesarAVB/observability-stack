<h1 align="center">Tempo com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-tempo-blueviolet"/>
  <img src="https://img.shields.io/badge/Tempo-latest-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Grafana Tempo em Docker via Portainer, com recebimento de traces via OTLP (gRPC e HTTP), configuração via Docker Config e retenção de 48 horas.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Grafana Tempo** — backend de rastreamento distribuído (distributed tracing)

## Sobre o Projeto

Este repositório documenta a implementação do **Grafana Tempo** utilizando Docker via Portainer, com Stack (Docker Compose), configuração via Docker Config externo e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Recebimento e armazenamento de traces distribuídos via protocolo OTLP
- Integração com Grafana para visualização de traces e correlação com logs (Loki) e métricas (Prometheus)
- Retenção configurável de traces (padrão: 48 horas)
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Tempo
├── tempo.yml            # Configuração do Tempo (receivers, storage, retenção)
├── exemplo.env          # Exemplo de variáveis de ambiente
└── README.md
```

## Configuração do Tempo

O arquivo `tempo.yml` define o comportamento do Tempo. Principais parâmetros:

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

### 1. Criar o Docker Config

Antes de subir a stack, registre o `tempo.yml` como um Config no Docker:

```bash
docker config create tempo_config tempo.yml
```

> Para atualizar a configuração posteriormente, remova e recrie o config:
> ```bash
> docker config rm tempo_config
> docker config create tempo_config tempo.yml
> ```

### 2. Criar a Stack

1. Acesse o Portainer e vá em **Stacks → Add stack**
2. Cole o conteúdo do `docker-compose.yml`
3. Clique em **Deploy the stack**

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

- A porta `3200` deve ser restrita por IP no firewall ou acessada apenas via rede interna
- As portas `4317` e `4318` recebem traces das aplicações — restrinja o acesso conforme necessário

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
