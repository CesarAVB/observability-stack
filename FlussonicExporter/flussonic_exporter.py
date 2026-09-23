#!/usr/bin/env python3
"""Exporter Prometheus para a API v3 do Flussonic Media Server.

O Flussonic 23.01 não gera formato Prometheus (ignora ?format=openmetrics) e a
API pagina os streams, então este script busca o JSON, segue a paginação e
converte os campos de interesse em métricas. Só usa a biblioteca padrão.

Multi-target, no mesmo padrão do blackbox_exporter:
    GET /probe?target=170.80.69.5         (http:// e porta 80 por padrão)
    GET /probe?target=https://host:8443

Credenciais: usuário em FLUSSONIC_USER e senha no Docker secret
flussonic_api_password (/run/secrets/flussonic_api_password).
"""
import base64
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USER = os.environ["FLUSSONIC_USER"]
with open(os.environ.get("FLUSSONIC_PASSWORD_FILE", "/run/secrets/flussonic_api_password")) as f:
    PASSWORD = f.read().strip()
AUTH = "Basic " + base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()
TIMEOUT = float(os.environ.get("FLUSSONIC_TIMEOUT", "15"))
# Entrada sem quadro novo há mais que isso é considerada sem sinal.
STALE_SECONDS = float(os.environ.get("INPUT_STALE_SECONDS", "60"))
PORT = int(os.environ.get("PORT", "9105"))

HELP = {
    "flussonic_up": "1 se a API do Flussonic respondeu",
    "flussonic_scrape_duration_seconds": "Tempo para ler todos os streams da API",
    "flussonic_streams": "Quantidade de streams habilitados",
    "flussonic_stream_alive": "1 se o stream está vivo (stats.alive)",
    "flussonic_stream_input_bitrate_kbps": "Bitrate de entrada do stream em kbps",
    "flussonic_stream_clients": "Clientes assistindo o stream",
    "flussonic_stream_retry_count": "Tentativas de reconexão da entrada",
    "flussonic_stream_on_backup": "1 se o stream está puxando de uma origem que não é a primeira configurada",
    "flussonic_input_up": "1 se a entrada recebeu quadro nos últimos INPUT_STALE_SECONDS",
    "flussonic_input_last_frame_age_seconds": "Segundos desde o último quadro recebido na entrada",
}


def base_url(target):
    if "://" not in target:
        target = "http://" + target
    return target.rstrip("/")


def host_of(url):
    try:
        return urllib.parse.urlsplit(url or "").hostname or ""
    except ValueError:
        return ""


def fetch_streams(base):
    streams, cursor = [], None
    for _ in range(50):
        query = {"limit": "1000"}
        if cursor:
            query["cursor"] = cursor
        req = urllib.request.Request(
            f"{base}/streamer/api/v3/streams?{urllib.parse.urlencode(query)}",
            headers={"Authorization": AUTH},
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            page = json.load(resp)
        batch = page.get("streams") or []
        streams += batch
        cursor = page.get("next")
        if not cursor or not batch or len(streams) >= page.get("estimated_count", 0):
            break
    return streams


def esc(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def num(value):
    if isinstance(value, bool):
        return 1 if value else 0
    return value if isinstance(value, (int, float)) else 0


def collect(target):
    samples = {name: [] for name in HELP}

    def add(name, labels, value):
        text = ",".join(f'{k}="{esc(v)}"' for k, v in labels.items())
        samples[name].append(f"{name}{{{text}}} {value}" if text else f"{name} {value}")

    started = time.time()
    try:
        streams = fetch_streams(base_url(target))
        up = 1
    except Exception as exc:  # API fora, senha errada, timeout: vira flussonic_up 0
        print(f"erro lendo {target}: {exc}", file=sys.stderr, flush=True)
        streams, up = [], 0
    now_ms = time.time() * 1000
    add("flussonic_up", {}, up)
    add("flussonic_scrape_duration_seconds", {}, round(time.time() - started, 3))

    enabled = [s for s in streams if not s.get("disabled")]
    add("flussonic_streams", {}, len(enabled))

    for stream in enabled:
        stats = stream.get("stats") or {}
        configured = (stream.get("config_on_disk") or {}).get("inputs") or stream.get("inputs") or []
        primary = host_of(configured[0].get("url")) if configured else ""
        source = stats.get("source_hostname") or host_of(stats.get("url"))
        labels = {
            "stream": stream.get("name", ""),
            "title": ((stats.get("media_info") or {}).get("title") or ""),
            # static=false: stream sob demanda, só roda com espectador (não alertar)
            "static": str(bool(stream.get("static"))).lower(),
            "primary": primary,
            "source": source,
        }
        add("flussonic_stream_alive", labels, num(stats.get("alive")))
        add("flussonic_stream_input_bitrate_kbps", labels, num(stats.get("input_bitrate")))
        add("flussonic_stream_clients", labels, num(stats.get("client_count")))
        add("flussonic_stream_retry_count", labels, num(stats.get("retry_count")))
        on_backup = 1 if len(configured) > 1 and source and primary and source != primary else 0
        add("flussonic_stream_on_backup", labels, on_backup)

        for position, inp in enumerate(stream.get("inputs") or []):
            last = (inp.get("stats") or {}).get("last_dts_at")
            age = (now_ms - last) / 1000 if isinstance(last, (int, float)) else -1
            in_labels = {
                "stream": labels["stream"],
                "static": labels["static"],
                "position": str(position),
                "host": host_of(inp.get("url")),
                "url": inp.get("url", ""),
            }
            add("flussonic_input_up", in_labels, 1 if 0 <= age < STALE_SECONDS else 0)
            add("flussonic_input_last_frame_age_seconds", in_labels, round(age, 1))

    lines = []
    for name, rows in samples.items():
        lines += [f"# HELP {name} {HELP[name]}", f"# TYPE {name} gauge", *rows]
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        if url.path == "/probe":
            target = urllib.parse.parse_qs(url.query).get("target", [""])[0]
            if not target:
                return self.reply(400, "parâmetro target obrigatório\n")
            return self.reply(200, collect(target), "text/plain; version=0.0.4; charset=utf-8")
        if url.path in ("/", "/health"):
            return self.reply(200, "ok\n")
        self.reply(404, "not found\n")

    def reply(self, code, body, ctype="text/plain; charset=utf-8"):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"flussonic-exporter ouvindo em :{PORT}", flush=True)
    ThreadingHTTPServer(("", PORT), Handler).serve_forever()
