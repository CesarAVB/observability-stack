<h1 align="center">Zabbix Server com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-zabbix--server-blueviolet"/>
  <img src="https://img.shields.io/badge/Zabbix-7.4-red?logo=zabbix&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Zabbix Server 7.4 em Docker via Portainer, com MySQL 8.0, interface web Nginx e agente local.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux (VPS)** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Zabbix 7.4** — plataforma de monitoramento e observabilidade
- **MySQL 8.0** — banco de dados do Zabbix

## Sobre o Projeto

Este repositório documenta a implementação de um **Zabbix Server distribuído** utilizando Docker via Portainer, com Stack (Docker Compose) e infraestrutura reproduzível.

O objetivo é manter um ambiente limpo, organizado e próximo de produção, com foco em:

- Observabilidade centralizada
- Integração com proxies remotos
- Comunicação segura via TLS nativo do Zabbix (PSK)
- Infraestrutura reproduzível com Docker

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Zabbix (server, web, agent, mysql)
├── exemplo.env          # Exemplo de variáveis de ambiente
└── README.md
```

## Configuração das Variáveis de Ambiente

Copie o arquivo de exemplo e defina suas credenciais:

```bash
cp exemplo.env .env
```

Edite o `.env` com os valores desejados:

```env
MYSQL_DATABASE=zabbix
MYSQL_USER=zabbix
MYSQL_PASSWORD=sua_senha_forte
MYSQL_ROOT_PASSWORD=sua_senha_root
ZBX_SERVER_NAME=Aragorn Zabbix
TZ=America/Sao_Paulo
```

## Serviços da Stack

| Container | Imagem | Função |
|---|---|---|
| `zabbix-mysql` | `mysql:8.0` | Banco de dados |
| `zabbix-server` | `zabbix-server-mysql:alpine-7.4` | Servidor Zabbix |
| `zabbix-web` | `zabbix-web-nginx-mysql:alpine-7.4` | Interface Web |
| `zabbix-agent` | `zabbix-agent:alpine-7.4` | Agente local |

## Persistência de Dados

Os dados do MySQL são persistidos em:

```
/opt/docker/zabbix/mysql/data
```

Antes de subir a stack, crie o diretório e ajuste as permissões:

```bash
sudo mkdir -p /opt/docker/zabbix/mysql/data
sudo chown -R 999:999 /opt/docker/zabbix/mysql/data
```

## Deploy via Portainer

1. Acesse o Portainer e vá em **Stacks → Add stack**
2. Cole o conteúdo do `docker-compose.yml`
3. Clique em **Deploy the stack**

A interface Web do Zabbix estará disponível internamente na porta `8080` via rede `network_swarm_public`.

Login padrão: `Admin` / `zabbix`

## Rede

A stack utiliza a mesma rede externa do Grafana (`network_swarm_public`). Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Segurança

- TLS nativo do Zabbix (PSK) para comunicação com proxies
- Porta `10051` deve ser restrita por IP no firewall
- Variáveis sensíveis (senhas) devem ser movidas para um arquivo `.env` fora do Git

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/  

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
