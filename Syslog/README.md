# Syslog — Switches Huawei → Loki

Stack que recebe **syslog** dos switches Huawei da LOGNET e encaminha os logs
**direto para o Loki**, usando o **syslog-ng** (distribuição [AxoSyslog](https://axoflow.com/docs/axosyslog-core/),
que traz o destino `loki()` nativo).

```
Switches Huawei (45.187.224.0/22)
   │  syslog UDP/TCP 514 (RFC3164, formato Huawei %%...)
   ▼
syslog-ng (AxoSyslog)
   │  parse PRI → facility/severity · extrai host (sysname) + source_ip
   │  destination loki()  →  gRPC interno loki:9095 (rede network_swarm_public)
   ▼
Loki 3.0.0  →  Grafana (dashboard "Syslog Switches LOGNET")
```

## Arquivos

| Arquivo | Função |
|---|---|
| `docker-compose.yml` | Stack do syslog-ng. Publica `514/udp` e `514/tcp`, monta o config via `file: ./syslog-ng.conf` e o volume `syslog_buffer` (disk-buffer). |
| `syslog-ng.conf` | **Fonte de verdade** do config. Recebe RFC3164 em UDP/TCP 514, normaliza e empurra pro Loki com os labels `job`, `host`, `source_ip`, `severity`, `facility`. |

## Labels no Loki

| Label | Origem | Exemplo |
|---|---|---|
| `job` | fixo | `huawei-switches` |
| `host` | sysname **de dentro da mensagem** (requer `keep-hostname(yes)`) | `SW04-POP-MAG-RJ` |
| `source_ip` | IP de origem visto pelo servidor (pós-NAT do gateway, **não** o IP de gerência do switch). Requer `mode: host` na porta — senão o routing mesh do Swarm mascara para `10.0.0.x` | `10.129.190.42` |
| `severity` | derivado do PRI (RFC3164) | `warning` |
| `facility` | derivado do PRI (RFC3164) | `local7` |

> Baixa cardinalidade de propósito. O miolo proprietário Huawei
> (`%%01IFNET/4/IF_STATE...`) fica na **linha do log**, pesquisável via LogQL —
> não vira label.

## Deploy

Segue o padrão de **Docker Config referenciado por arquivo** do repositório (ver `CLAUDE.md`): o `docker-compose.yml` referencia `file: ./syslog-ng.conf` — não `external`. Pra isso resolver no servidor, a stack precisa ser criada no Portainer com **Build method → Repository**, apontando pro remoto Git deste repositório, com **Compose path** `Syslog/docker-compose.yml`.

**Primeiro deploy:** Portainer → **Stacks → Add stack** → Build method **Repository** → cole a URL do repositório → Compose path `Syslog/docker-compose.yml` → **Deploy the stack**.

**Atualizar a configuração:** edite `syslog-ng.conf` neste repo, dê push pro remoto e, no Portainer, rode **Pull and redeploy** na stack — sem SSH, sem `docker config create/rm` manual.

A rede `network_swarm_public` precisa existir (compartilhada com o Loki).

> **`mode: host` na porta 514:** preserva o IP real de origem, mas faz a porta
> escutar **apenas no nó onde a tarefa roda**. Como os switches enviam para o IP
> do servidor (`45.187.224.251`), a tarefa precisa estar nesse nó. Em cluster
> multi-nó, fixe com `deploy.placement.constraints` (ex.: `- node.role == manager`)
> ou hostname do nó. Em nó único, não é necessário.

## Firewall

A porta `514` (UDP e TCP) é liberada pelo `Firewall/firewall-setup-251.sh`, via
`ALLOWED_NETWORKS_SYSLOG` — que inclui `10.129.190.0/24`, o IP **pós-NAT** do
gateway de gerência dos switches (os switches têm IP `10.129.180.x`, mas
atravessam um NAT antes de chegar ao servidor, então a origem vista na 514 é
`10.129.190.x`). Essa faixa libera só o syslog, sem abrir as portas internas.
Rode no servidor após o deploy:

```bash
sudo ../Firewall/firewall-setup-251.sh
```

## Configuração nos switches Huawei (VRP)

Em cada switch, apontar o loghost para o servidor (`45.187.224.251`, porta 514 UDP):

```
info-center enable
info-center loghost 45.187.224.251
info-center source default channel loghost log level informational
```

## Verificação

1. Contêiner subiu sem erro de config: logs do serviço `syslog-ng` limpos.
2. DNS do Loki na Swarm: o `url()` do `syslog-ng.conf` usa o nome curto `loki`,
   que resolve via alias do Swarm (o serviço também responde como `loki_loki`).
   Para conferir a resolução de dentro do contêiner:
   ```bash
   docker exec <container_id_syslog-ng> getent hosts loki
   ```
3. Log sintético de um host na rede permitida:
   ```bash
   logger -n 45.187.224.251 -P 514 -d "teste syslog huawei"
   ```
   No Grafana → Explore (Loki): `{job="huawei-switches"}` deve retornar a entrada.
4. Switch real: gerar um evento (ex.: shut/no shut de interface de teste) e ver
   aparecer com `host="SW##-POP-..."` e `source_ip` correto.

## Dashboard

`../Grafana/dashboards/syslog-switches.json` — filtros por switch (`$switch`),
severidade (`$severity`) e intervalo de tempo. **Pré-requisito:** datasource
**Loki** existente no Grafana (`http://loki:3100`).
