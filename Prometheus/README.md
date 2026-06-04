<h1 align="center">Prometheus com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-prometheus-blueviolet"/>
  <img src="https://img.shields.io/badge/Prometheus-latest-E6522C?logo=prometheus&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Prometheus em Docker via Portainer, com configuração de scrape via Docker Config e retenção de dados configurável.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Prometheus** — plataforma de coleta e armazenamento de métricas

## Sobre o Projeto

Este repositório documenta a implementação do **Prometheus** utilizando Docker via Portainer, com Stack (Docker Compose), configuração de scrape via Docker Config externo e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Coleta de métricas de aplicações e serviços
- Retenção configurável de dados (padrão: 30 dias)
- Integração com Grafana para visualização de dashboards
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Prometheus
├── prometheus.yml       # Configuração de scrape (jobs e targets)
└── README.md
```

## Configuração do Prometheus

O arquivo `prometheus.yml` define os jobs de scrape. Para adicionar uma nova aplicação, copie o bloco de exemplo e ajuste `job_name` e `targets`:

```yaml
scrape_configs:
  - job_name: 'minha-app'
    scheme: https
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['minha-app.dominio.com.br']
        labels:
          app: 'minha-app'
          env: 'production'
```

## Deploy via Portainer

### Primeiro deploy

Antes de subir a stack, o Docker Config precisa existir — a stack referencia `prometheus_config` pelo nome e falhará se ele não estiver criado.

Acesse o servidor via SSH, crie o diretório, edite o `prometheus.yml` e registre o config:

```bash
sudo mkdir -p /opt/docker/prometheus
vim /opt/docker/prometheus/prometheus.yml
docker config create prometheus_config /opt/docker/prometheus/prometheus.yml
```

Em seguida, acesse o Portainer, vá em **Stacks → Add stack**, cole o conteúdo do `docker-compose.yml` e clique em **Deploy the stack**.

O Prometheus estará disponível em: `http://<IP-do-host>:9090`

### Atualizar a configuração

Docker Configs são imutáveis — para alterar o `prometheus.yml` de uma stack já em execução:

```bash
vim /opt/docker/prometheus/prometheus.yml
docker config rm prometheus_config
docker config create prometheus_config /opt/docker/prometheus/prometheus.yml
```

Em seguida, faça o redeploy da stack no Portainer para que o serviço monte o config atualizado.

## Persistência de Dados

Os dados do Prometheus são persistidos no volume Docker `prometheus_data`, gerenciado automaticamente pelo Docker.

## Rede

A stack utiliza a rede externa `network_swarm_public`. Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Segurança

A porta `9090` não possui autenticação nativa — restrinja o acesso via firewall às redes confiáveis:

```bash
ufw allow from 168.90.16.0/22 to any port 9090
ufw allow from 45.187.224.0/22 to any port 9090
ufw deny 9090
```

> A flag `--web.enable-lifecycle` permite recarregar a configuração via API (`POST /-/reload`) — restrinja o acesso a essa rota pelo mesmo motivo.

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
