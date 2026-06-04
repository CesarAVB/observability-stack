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

Este repositório documenta a implementação do **Grafana Loki** utilizando Docker via Portainer, com Stack (Docker Compose), configuração via Docker Config externo e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Agregação centralizada de logs de aplicações e serviços
- Retenção configurável de logs (padrão: 30 dias)
- Integração com Grafana para visualização e consultas via LogQL
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Loki
├── loki-config.yml      # Configuração do Loki (schema, storage, retenção)
├── exemplo.env          # Exemplo de variáveis de ambiente
└── README.md
```

## Configuração do Loki

O arquivo `loki-config.yml` define o comportamento do Loki. Principais parâmetros:

```yaml
limits_config:
  retention_period: 30d   # Altere para ajustar o período de retenção
```

## Deploy via Portainer

### Primeiro deploy

Antes de subir a stack, o Docker Config precisa existir — a stack referencia `loki_config` pelo nome e falhará se ele não estiver criado.

Acesse o servidor via SSH, crie o diretório, edite o `loki-config.yml` e registre o config:

```bash
sudo mkdir -p /opt/docker/loki
vim /opt/docker/loki/loki-config.yml
docker config create loki_config /opt/docker/loki/loki-config.yml
```

Em seguida, acesse o Portainer, vá em **Stacks → Add stack**, cole o conteúdo do `docker-compose.yml` e clique em **Deploy the stack**.

O Loki estará disponível na porta `3100` via rede `network_swarm_public`.

### Atualizar a configuração

Docker Configs são imutáveis — para alterar o `loki-config.yml` de uma stack já em execução:

```bash
vim /opt/docker/loki/loki-config.yml
docker config rm loki_config
docker config create loki_config /opt/docker/loki/loki-config.yml
```

Em seguida, faça o redeploy da stack no Portainer para que o serviço monte o config atualizado.

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

- O endpoint `:3100` deve ser restrito por IP no firewall ou acessado apenas via rede interna
- `auth_enabled: false` desativa autenticação — adequado para ambientes internos isolados

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
