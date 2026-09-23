<h1 align="center">Grafana com Docker via Portainer</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-grafana-blueviolet"/>
  <img src="https://img.shields.io/badge/Grafana-latest-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-✔-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-Stack-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/Linux-VPS-FCC624?logo=linux&logoColor=black"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Grafana em Docker via Portainer, com persistência de dados, plugins pré-instalados e pronto para produção.
</p>

---

## Tecnologias Utilizadas

- **Docker** — containerização do ambiente
- **Portainer (Stacks)** — deploy via Docker Compose
- **Linux** — sistema operacional do host
- **Visual Studio Code** — edição dos arquivos
- **Grafana** — plataforma de observabilidade e dashboards

## Sobre o Projeto

Este repositório demonstra como instalar o **Grafana** utilizando Docker via Portainer, com Stack (Docker Compose), variáveis de ambiente via `.env` e persistência de dados organizada em `/opt/docker`.

O objetivo é manter um ambiente limpo, organizado e próximo de produção.

## Estrutura do Projeto

```
.
├── docker-compose.yml   # Stack do Grafana
└── exemplo.env          # Exemplo de variáveis de ambiente
```

## Configuração das Variáveis de Ambiente

Copie o arquivo de exemplo e defina sua senha:

```bash
cp exemplo.env .env
```

Edite o `.env` com a senha desejada:

```env
GF_SECURITY_ADMIN_PASSWORD="sua_senha_forte_aqui"
```

## Persistência de Dados

Os dados do Grafana são persistidos em:

```
/opt/docker/grafana/data
```

Antes de subir a stack, crie o diretório e ajuste as permissões:

```bash
sudo mkdir -p /opt/docker/grafana/data
sudo chown -R 472:472 /opt/docker/grafana
```

> O Grafana roda internamente com o usuário `472`. Sem essa permissão, ocorrerá erro de acesso ao volume.

## Plugins Instalados

Os seguintes plugins são instalados automaticamente na inicialização do container:

| Plugin | Descrição |
|---|---|
| `alexanderzobnin-zabbix-app` | Integração com Zabbix |
| `agenty-flowcharting-panel` | Painel de fluxogramas |
| `grafana-clock-panel` | Painel de relógio |
| `grafana-piechart-panel` | Painel de gráfico de pizza |

## Deploy via Portainer

1. Acesse o Portainer e vá em **Stacks → Add stack**
2. Cole o conteúdo do `docker-compose.yml`
3. Em **Environment variables**, adicione `GF_SECURITY_ADMIN_PASSWORD` com sua senha
4. Clique em **Deploy the stack**

O Grafana estará disponível em: `http://<IP-do-host>:3000`

Login padrão: `admin` / `<senha definida no .env>`

## Rede

A stack utiliza a rede externa `network_swarm_public`. Certifique-se de que ela existe antes de fazer o deploy:

```bash
docker network create network_swarm_public
```

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

© 2026 César Augusto — Backend Developer Java & Infraestrutura de Redes
