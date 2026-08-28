<h1 align="center">Loki com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-loki-blueviolet"/>
  <img src="https://img.shields.io/badge/Loki-3.0.0-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Grafana Loki em Docker via Portainer, com configuração via Docker Config, retenção de logs de 30 dias e schema TSDB v13.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Grafana Loki** — sistema de agregação e consulta de logs

## Sobre o Projeto

Este repositório documenta a implementação do **Grafana Loki** utilizando Docker via Portainer, com Stack (Docker Compose), configuração via Docker Config referenciado por arquivo (deploy via Portainer "Repository") e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Agregação centralizada de logs de aplicações e serviços
- Retenção configurável de logs (padrão: 30 dias)
- Integração com Grafana para visualização e consultas via LogQL
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Loki
├── loki_config.yml      # Configuração do Loki (schema, storage, retenção)
└── README.md
```

## Configuração do Loki

O arquivo `loki_config.yml` define o comportamento do Loki. Principais parâmetros:

```yaml
limits_config:
  retention_period: 30d   # Altere para ajustar o período de retenção
```

## Deploy via Portainer

O `docker-compose.yml` referencia o config via `file: ./loki_config.yml` — não é `external`. Pra isso resolver no servidor, a stack precisa ser criada com **Build method → Repository**, apontando pro remoto Git deste repositório, com **Compose path** `Loki/docker-compose.yml`.

### Primeiro deploy

Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `Loki/docker-compose.yml` → **Deploy the stack**.

O Loki estará disponível na porta `3100` via rede `network_swarm_public`.

### Atualizar a configuração

Edite `loki_config.yml` neste repo, dê push pro remoto e, no Portainer, rode **Pull and redeploy** na stack. O Portainer recria o Docker Config automaticamente — sem SSH, sem `docker config create/rm` manual.

## Persistência de Dados

Os dados do Loki são persistidos no volume Docker `loki_data`, gerenciado automaticamente pelo Docker. Os diretórios internos utilizados são:

```
/loki/chunks   # Blocos de log compactados
/loki/rules    # Regras de alertas
```

## Integração com Grafana

No Grafana, adicione o Loki como datasource:

- **URL:** `http://loki:3100`
- **Tipo:** Loki

## Rede

A stack utiliza a rede externa `network_swarm_public`. Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Segurança

A porta `3100` não possui autenticação (`auth_enabled: false`) — restrinja o acesso via firewall às redes confiáveis:

```bash
ufw allow from 168.90.16.0/22 to any port 3100
ufw allow from 45.187.224.0/22 to any port 3100
ufw deny 3100
```

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
