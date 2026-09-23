# FlussonicExporter

Exporter Prometheus para a API v3 do Flussonic Media Server (`170.80.69.5`, versão 23.01).
O 23.01 não gera formato Prometheus (`?format=openmetrics` é ignorado) e pagina os streams,
então `flussonic_exporter.py` lê o JSON de `/streamer/api/v3/streams` e converte em métricas.
Só usa a biblioteca padrão: roda em `python:3.12-alpine`, com o script montado como Docker Config.

Lista de canais e origens (foto da config em 2026-09-23): [CANAIS.md](CANAIS.md).

## Deploy

1. Secret com a senha da API (Portainer → Secrets, ou via SSH):
   `printf '<senha>' | docker secret create flussonic_api_password -`
2. Portainer → Stacks → Add stack → **Repository** → Compose path `FlussonicExporter/docker-compose.yml`.
3. Em "Environment variables" da stack: `FLUSSONIC_USER=<usuário da API>`.
4. Deploy. O Prometheus coleta por `flussonic-exporter:9105` (job `flussonic`).

Ao alterar `flussonic_exporter.py`, incrementar `name: flussonic_exporter_script_vN` no compose.

## Métricas

| Métrica | Labels | O que é |
|---|---|---|
| `flussonic_up` | — | 1 se a API respondeu |
| `flussonic_streams` | — | streams habilitados |
| `flussonic_stream_alive` | `stream`, `title`, `static`, `primary`, `source` | `stats.alive` |
| `flussonic_stream_input_bitrate_kbps` | idem | bitrate de entrada |
| `flussonic_stream_clients` | idem | espectadores |
| `flussonic_stream_on_backup` | idem | 1 se a origem ativa (`source`) não é a primeira configurada (`primary`) |
| `flussonic_input_up` | `stream`, `static`, `position`, `host`, `url` | 1 se a entrada recebeu quadro nos últimos 60s |
| `flussonic_input_last_frame_age_seconds` | idem | idade do último quadro da entrada |

`static="true"` são os canais sempre ligados; os sob demanda (`false`) param sem espectador e
ficam fora dos alertas. Alertas no grupo `flussonic` de `Prometheus/rules/alerts.yml`.

Teste manual de dentro do Swarm:
`docker exec $(docker ps -qf name=flussonic) wget -qO- 'localhost:9105/probe?target=170.80.69.5' | head -30`
