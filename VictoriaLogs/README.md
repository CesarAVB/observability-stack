# VictoriaLogs - CGNAT MikroTik

Stack dedicada para armazenar registros de CGNAT enviados diretamente por um
MikroTik via syslog UDP. A ideia e manter esses logs separados do Loki usado
pelas aplicacoes e pelos switches, com retencao propria e consulta pela API/UI
do VictoriaLogs.

```
MikroTik
   |  syslog UDP 5514
   v
VictoriaLogs
   |  porta HTTP interna 9428 / Traefik
   v
logs.redelognet.com.br
```

## Arquivos

| Arquivo | Funcao |
|---|---|
| `docker-compose.yml` | Stack do VictoriaLogs. Publica `5514/udp` em `mode: host`, persiste dados em volume Docker e expoe a API HTTP `9428` via Traefik. |

## Configuracao da stack

Principais flags usadas:

| Flag | Funcao |
|---|---|
| `-storageDataPath=/victoria-logs-data` | Diretorio interno onde os logs ficam persistidos. |
| `-retentionPeriod=13M` | Retem os logs por 13 meses. O sufixo `M` deixa explicito que sao meses. |
| `-syslog.listenAddr.udp=:5514` | Recebe syslog UDP na porta `5514`. |
| `-syslog.useLocalTimestamp.udp=true` | Usa o horario de recebimento do servidor como `_time`, evitando problemas de timezone/ano do emissor. |
| `-syslog.useRemoteIP.udp=true` | Salva o IP remoto visto pelo servidor no campo `remote_ip`. |
| `-syslog.extraFields.udp={...}` | Adiciona campos fixos `job=mikrotik-cgnat` e `source=mikrotik`. |

## Porta em `mode: host`

A porta `5514/udp` usa sintaxe longa com `mode: host`:

```yaml
ports:
  - target: 5514
    published: 5514
    protocol: udp
    mode: host
```

Isso evita o routing mesh do Swarm para essa entrada UDP e preserva melhor o IP
de origem do MikroTik. Como efeito colateral, a porta escuta apenas no node onde
a tarefa do container esta rodando. Por isso a stack esta fixa no manager:

```yaml
deploy:
  placement:
    constraints:
      - node.role == manager
```

Se o MikroTik envia para `45.187.224.251`, garanta que a task do VictoriaLogs
rode nesse servidor.

## Firewall

A porta `5514/udp` deve ficar liberada apenas para a origem do MikroTik.
No script `../Firewall/firewall-setup-lognet.sh`, ajuste:

```bash
ALLOWED_NETWORKS_CGNAT="$ALLOWED_NETWORKS IP_PUBLICO_DO_MIKROTIK/32"
```

Se o MikroTik ja estiver dentro de `168.90.16.0/22` ou `45.187.224.0/22`, o valor
padrao ja cobre a origem:

```bash
ALLOWED_NETWORKS_CGNAT="$ALLOWED_NETWORKS"
```

Depois de alterar, aplique no servidor:

```bash
cd /caminho/do/repositorio/Firewall
chmod +x firewall-setup-lognet.sh
sudo ./firewall-setup-lognet.sh
```

## Deploy via Portainer

A stack nao usa Docker Config. O deploy pode ser feito pelo Portainer com:

- **Build method:** Repository
- **Compose path:** `VictoriaLogs/docker-compose.yml`
- **Rede externa:** `network_swarm_public`

Primeiro deploy:

1. Portainer -> Stacks -> Add stack.
2. Selecione **Repository**.
3. Aponte para o remoto Git deste repositorio.
4. Use o compose path `VictoriaLogs/docker-compose.yml`.
5. Clique em **Deploy the stack**.

Atualizacoes futuras: push no repo e **Pull and redeploy** no Portainer.

## Configuracao no MikroTik

Exemplo base para enviar logs ao VictoriaLogs:

```routeros
/system logging action add name=victorialogs target=remote remote=45.187.224.251 remote-port=5514
/system logging add action=victorialogs topics=firewall,info
```

Para gerar registros de CGNAT, use regras de firewall/NAT com `log=yes` e um
prefixo identificavel. Ajuste com cuidado para nao registrar trafego demais sem
necessidade:

```routeros
/ip firewall nat set [find comment="CGNAT"] log=yes log-prefix="CGNAT "
```

Em ambientes de alto volume, prefira validar primeiro em uma regra ou faixa
limitada e acompanhar uso de CPU, disco e volume diario no VictoriaLogs.

## Consulta

Via Traefik:

```text
https://logs.redelognet.com.br
```

Campos esperados nos logs recebidos:

| Campo | Origem |
|---|---|
| `_time` | Horario de recebimento no servidor VictoriaLogs. |
| `_msg` | Mensagem syslog enviada pelo MikroTik. |
| `remote_ip` | IP remoto visto pelo VictoriaLogs. |
| `job` | Campo fixo `mikrotik-cgnat`. |
| `source` | Campo fixo `mikrotik`. |

Exemplos de filtros no VictoriaLogs:

```text
job:mikrotik-cgnat
```

```text
job:mikrotik-cgnat AND _msg:"CGNAT"
```

```text
remote_ip:"IP_PUBLICO_DO_MIKROTIK"
```

## Grafana

O dashboard importavel fica em:

```text
../Grafana/dashboards/cgnat-victorialogs.json
```

Ele requer o plugin `victoriametrics-logs-datasource` no Grafana e um datasource
VictoriaLogs apontando para a URL interna:

```text
http://victorialogs:9428
```

Evite usar a URL publica no datasource:

```text
https://logs.redelognet.com.br
```

Essa URL passa pelo Traefik e pode retornar `403 Forbidden`, porque o middleware
de IP allowlist ve a origem da requisicao como o IP interno do container/rede
Docker, nao como o IP do operador no navegador.

O dashboard extrai da mensagem do MikroTik os campos `client_ip`, `src_mac`,
`dst_ip`, `dst_port`, `proto`, `client_port` e `nat_rule`.

## Verificacao

1. No Portainer, confirme que a task do VictoriaLogs esta no servidor que recebe
   o trafego do MikroTik.
2. No servidor, confira se a porta UDP esta escutando:
   ```bash
   sudo ss -lunp | grep 5514
   ```
3. Gere um evento de teste no MikroTik e consulte no VictoriaLogs por:
   ```text
   job:mikrotik-cgnat
   ```
4. Confirme se o campo `remote_ip` mostra o IP esperado da origem.

## Observacoes

- A porta HTTP interna do VictoriaLogs e `9428`; o acesso externo passa pelo
  Traefik em `logs.redelognet.com.br`.
- O volume `victorialogs_data` e gerenciado pelo Docker, seguindo o padrao das
  stacks Prometheus/Loki/Tempo.
- A retencao de 13 meses deve ser revisada junto com capacidade de disco e
  volume diario de logs de CGNAT.
