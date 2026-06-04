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
├── exemplo.env          # Exemplo de variáveis de ambiente
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

### 1. Criar o Docker Config

Antes de subir a stack, registre o `prometheus.yml` como um Config no Docker:

```bash
docker config create prometheus_config prometheus.yml
```

> Para atualizar a configuração posteriormente, remova e recrie o config:
> ```bash
> docker config rm prometheus_config
> docker config create prometheus_config prometheus.yml
> ```

### 2. Criar a Stack

1. Acesse o Portainer e vá em **Stacks → Add stack**
2. Cole o conteúdo do `docker-compose.yml`
3. Clique em **Deploy the stack**

O Prometheus estará disponível em: `http://<IP-do-host>:9090`

## Persistência de Dados

Os dados do Prometheus são persistidos no volume Docker `prometheus_data`, gerenciado automaticamente pelo Docker.

## Rede

A stack utiliza a rede externa `network_swarm_public`. Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Segurança

- O endpoint `:9090` deve ser restrito por IP no firewall ou protegido via proxy reverso
- A flag `--web.enable-lifecycle` permite recarregar a configuração via API (`POST /-/reload`) — restrinja o acesso a essa rota

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
