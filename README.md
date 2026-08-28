<h1 align="center">Infraestrutura de Observabilidade</h1>

<p align="center">
  <img src="https://img.shields.io/badge/repo-observabilidade-blueviolet"/>
  <img src="https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white"/>
  <img src="https://img.shields.io/badge/Loki-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Tempo-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white"/>
  <img src="https://img.shields.io/badge/Zabbix-red?logo=zabbix&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Portainer-13BEF9?logo=portainer&logoColor=white"/>
  <img src="https://img.shields.io/badge/License-MIT-green"/>
</p>

<p align="center">
Stack completa de observabilidade em Docker via Portainer: métricas, logs, traces e dashboards centralizados para aplicações Spring Boot em produção.
</p>

---

## Índice

- [Visão Geral](#visão-geral)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Firewall](#firewall)
- [Infraestrutura](#infraestrutura)
- [Onboarding - Novo Projeto Spring Boot](#onboarding--novo-projeto-spring-boot)
  - [1. Dependências (pom.xml)](#1-dependências-pomxml)
  - [2. Configuração de Logging (logback-spring.xml)](#2-configuração-de-logging-logback-springxml)
  - [3. Propriedades (application.properties)](#3-propriedades-applicationproperties)
  - [4. Filtro de Correlation ID](#4-filtro-de-correlation-id)
  - [5. Variáveis de Ambiente (Coolify)](#5-variáveis-de-ambiente-coolify)
  - [6. Registrar no Prometheus (Portainer)](#6-registrar-no-prometheus-portainer)
  - [7. Grafana - nenhuma ação necessária](#7-grafana--nenhuma-ação-necessária)
- [Checklist de Verificação](#checklist-de-verificação)
- [Contato](#contato)

---

## Visão Geral

Este repositório centraliza toda a infraestrutura de observabilidade, organizada em subpastas por ferramenta. Cada subpasta contém o `docker-compose.yml`, arquivos de configuração e o README próprio com instruções de deploy.

A stack cobre os três pilares da observabilidade:

| Pilar | Ferramenta | Função |
|---|---|---|
| Métricas | **Prometheus** | Coleta e armazena métricas via scrape |
| Logs | **Loki** | Agrega e indexa logs das aplicações |
| Traces | **Tempo** | Armazena e correlaciona traces distribuídos |
| Visualização | **Grafana** | Dashboards, Explore e correlação entre pilares |
| Métricas de infra (host) | **node-exporter** | Exporter de métricas do host (CPU, RAM, disco, rede, load) |
| Métricas de infra (containers) | **cAdvisor** | Exporter de métricas por container Docker |
| Monitoramento de infra | **Zabbix** | Monitoramento de hosts, serviços e rede |
| Logs de rede | **syslog-ng (AxoSyslog)** | Recebe syslog dos switches Huawei e encaminha ao Loki |
| Probe HTTP externo | **blackbox_exporter** | Sonda HTTP endpoints sem exporter próprio (ex.: reverse proxy de apps) |

---

## Estrutura do Repositório

```
.
├── Grafana/                  # Stack do Grafana (dashboards e datasources)
│   ├── dashboards/           # Templates de dashboard (JSON) + guia de import
│   ├── docker-compose.yml
│   ├── exemplo.env
│   └── README.md
├── NodeExporter/             # Stack do node-exporter (métricas do host)
│   ├── docker-compose.yml
│   └── README.md
├── Cadvisor/                 # Stack do cAdvisor (métricas por container)
│   ├── docker-compose.yml
│   └── README.md
├── Loki/                     # Stack do Grafana Loki (agregação de logs)
│   ├── docker-compose.yml
│   ├── loki_config.yml
│   ├── exemplo.env
│   └── README.md
├── Prometheus/               # Stack do Prometheus (coleta de métricas)
│   ├── docker-compose.yml
│   ├── prometheus_config.yml
│   ├── exemplo.env
│   └── README.md
├── Tempo/                    # Stack do Grafana Tempo (rastreamento distribuído)
│   ├── docker-compose.yml
│   ├── tempo_config.yml
│   ├── exemplo.env
│   └── README.md
├── Zabbix/                   # Stack do Zabbix Server (monitoramento de infra)
│   ├── docker-compose.yml
│   ├── exemplo.env
│   └── README.md
├── Syslog/                    # Stack do syslog-ng (switches Huawei → Loki)
│   ├── docker-compose.yml
│   ├── syslog-ng.conf
│   └── README.md
├── Blackbox/                  # Stack do blackbox_exporter (probe HTTP externo)
│   ├── docker-compose.yml
│   └── blackbox_config.yml
├── Firewall/                  # Scripts de firewall (DOCKER-USER/iptables)
│   ├── firewall-setup-251.sh              # Servidor principal (45.187.224.251)
│   └── README.md
└── README.md                 # Este arquivo
```

### Links para os READMEs das subpastas

| Ferramenta | README |
|---|---|
| Grafana | [Grafana/README.md](Grafana/README.md) |
| Dashboards (templates) | [Grafana/dashboards/README.md](Grafana/dashboards/README.md) |
| NodeExporter | [NodeExporter/README.md](NodeExporter/README.md) |
| Cadvisor | [Cadvisor/README.md](Cadvisor/README.md) |
| Firewall | [Firewall/README.md](Firewall/README.md) |
| Loki | [Loki/README.md](Loki/README.md) |
| Prometheus | [Prometheus/README.md](Prometheus/README.md) |
| Tempo | [Tempo/README.md](Tempo/README.md) |
| Zabbix | [Zabbix/README.md](Zabbix/README.md) |
| Syslog (switches Huawei) | [Syslog/README.md](Syslog/README.md) |

---

## Firewall

> **Importante:** o Docker ignora o UFW — ele insere regras diretamente no `iptables`, antes das regras do UFW. Para restringir portas publicadas pelo Docker, as regras precisam ser aplicadas na chain `DOCKER-USER`.

Os scripts vivem em `Firewall/` (ver [Firewall/README.md](Firewall/README.md) para o detalhamento) — cada um automatiza a configuração: detecta a interface de rede, aplica as regras imediatamente e persiste no `/etc/ufw/after.rules` para sobreviver a reboots.

**Servidor principal (`45.187.224.251`)** — `Firewall/firewall-setup-251.sh`:
**Portas internas** (`9090` Prometheus, `3100` Loki, `3200` / `4317` / `4318` Tempo, `10051` Zabbix Server) → liberadas para `168.90.16.0/22` e `45.187.224.0/22`.
**Syslog `514` (UDP/TCP)** → liberado também para `10.129.190.0/24` (IP pós-NAT do gateway de gerência dos switches), sem abrir as portas internas para essa faixa.

```bash
# no servidor .251 via SSH
chmod +x Firewall/firewall-setup-251.sh
sudo Firewall/firewall-setup-251.sh
```

Para reaplicar após um reboot sem rodar os scripts novamente, o UFW já carrega as regras do `after.rules` automaticamente ao iniciar.

---

## Infraestrutura

Os serviços rodam via Docker Swarm gerenciado pelo Portainer. `node-exporter` e `cAdvisor` usam `mode: global`, então sobem em cada nó do Swarm e são coletados pelo Prometheus via DNS interno `tasks.*`.

**Servidor principal:** `45.187.224.251`
**Nó adicional:** `45.187.224.248`

| Serviço | Porta | Acesso |
|---|---|---|
| Grafana | `3000` | Interface web de dashboards |
| Prometheus | `9090` | Interface web e API de métricas |
| Loki | `3100` | API de ingestão e consulta de logs |
| Tempo (query) | `3200` | API de consulta de traces |
| Tempo (OTLP gRPC) | `4317` | Recebimento de traces via gRPC |
| Tempo (OTLP HTTP) | `4318` | Recebimento de traces via HTTP |
| Zabbix Web | `8080` | Interface web do Zabbix |
| Zabbix Server | `10051` | Comunicação com agentes e proxies |
| Syslog (syslog-ng) | `514` UDP/TCP | Recebimento de syslog dos switches Huawei |

**Rede Docker:** `network_swarm_public` — compartilhada por todos os serviços.

---

## Onboarding — Novo Projeto Spring Boot

Guia completo para integrar uma nova aplicação Spring Boot à stack de observabilidade. Para a versão em arquivo separado, veja [observability-onboarding.md](observability-onboarding.md).

### 1. Dependências (`pom.xml`)

Adicione as três dependências abaixo. As versões de `micrometer-tracing-bridge-otel` e `opentelemetry-exporter-otlp` são gerenciadas automaticamente pelo BOM do Spring Boot 3.x — não declare versão explícita.

```xml
<!-- Distributed Tracing: Micrometer → OpenTelemetry → Tempo -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>

<!-- Push de logs para Loki -->
<dependency>
    <groupId>com.github.loki4j</groupId>
    <artifactId>loki-logback-appender</artifactId>
    <version>1.5.2</version>
</dependency>
```

O Actuator e Micrometer Prometheus já devem existir no projeto:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

---

### 2. Configuração de Logging (`logback-spring.xml`)

Crie o arquivo `src/main/resources/logback-spring.xml`. Ele substitui o `logging.pattern.console` do `application.properties`.

> Substitua `meu-projeto` pelo nome real da aplicação em `APP_NAME` e ajuste o logger do pacote na última linha.

```xml
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>

    <springProperty name="APP_NAME" source="spring.application.name" defaultValue="meu-projeto"/>
    <springProperty name="APP_ENV"  source="spring.profiles.active"  defaultValue="production"/>
    <springProperty name="LOKI_URL" source="loki.url"                defaultValue="http://45.187.224.251:3100"/>

    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] [corr=%X{correlationId:-none}] [trace=%X{traceId:-none} span=%X{spanId:-none}] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
        <http>
            <url>${LOKI_URL}/loki/api/v1/push</url>
            <connectionTimeoutMs>5000</connectionTimeoutMs>
            <requestTimeoutMs>5000</requestTimeoutMs>
        </http>
        <format>
            <label>
                <pattern>app=${APP_NAME},env=${APP_ENV},level=%level,host=${HOSTNAME}</pattern>
                <readMarkers>true</readMarkers>
            </label>
            <message>
                <pattern>[%d{yyyy-MM-dd HH:mm:ss.SSS}] [%thread] correlationId=%X{correlationId:-none} traceId=%X{traceId:-none} spanId=%X{spanId:-none} %-5level %logger{36} - %msg%n</pattern>
            </message>
            <sortByTime>true</sortByTime>
        </format>
    </appender>

    <root level="${LOG_LEVEL_ROOT:-INFO}">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="LOKI"/>
    </root>

    <!-- Ajuste o pacote para o do projeto -->
    <logger name="com.exemplo.meuprojeto" level="${LOG_LEVEL_APP:-DEBUG}"/>
    <logger name="org.springframework.web" level="${LOG_LEVEL_WEB:-WARN}"/>
</configuration>
```

---

### 3. Propriedades (`application.properties`)

Adicione o bloco abaixo. **Remova** `logging.pattern.console` se existir — o padrão passa a ser controlado pelo `logback-spring.xml`.

```properties
# ============================================
# Actuator + Prometheus
# ============================================
management.endpoints.web.base-path=/actuator
management.endpoints.web.exposure.include=${MANAGEMENT_ENDPOINTS_EXPOSURE:health,info,metrics,prometheus,loggers}
management.endpoint.health.show-details=${MANAGEMENT_HEALTH_SHOW_DETAILS:always}
management.endpoint.prometheus.enabled=true
management.metrics.tags.application=${spring.application.name}
management.metrics.tags.environment=${SPRING_PROFILES_ACTIVE:production}

# ============================================
# Distributed Tracing (Micrometer → Tempo via OTLP)
# ============================================
management.tracing.sampling.probability=${TRACING_SAMPLING_PROBABILITY:1.0}
management.otlp.tracing.endpoint=${TEMPO_OTLP_ENDPOINT:http://45.187.224.251:4318/v1/traces}

# ============================================
# Loki (URL lida pelo logback-spring.xml)
# ============================================
loki.url=${LOKI_URL:http://45.187.224.251:3100}
```

---

### 4. Filtro de Correlation ID

Crie em `src/main/java/<pacote>/filter/CorrelationIdFilter.java`. Gera ou propaga o `correlationId` no MDC para toda requisição HTTP.

```java
package com.exemplo.meuprojeto.filter;  // ajuste o pacote

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class CorrelationIdFilter extends OncePerRequestFilter {

    private static final String HEADER  = "X-Correlation-ID";
    private static final String MDC_KEY = "correlationId";

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String cid = req.getHeader(HEADER);
        if (cid == null || cid.isBlank()) {
            cid = UUID.randomUUID().toString();
        }
        MDC.put(MDC_KEY, cid);
        res.setHeader(HEADER, cid);
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.remove(MDC_KEY);
        }
    }
}
```

---

### 5. Variáveis de Ambiente (Coolify)

No painel do Coolify, adicione nas variáveis de ambiente do serviço:

| Variável | Valor |
|---|---|
| `LOKI_URL` | `http://45.187.224.251:3100` |
| `TEMPO_OTLP_ENDPOINT` | `http://45.187.224.251:4318/v1/traces` |
| `TRACING_SAMPLING_PROBABILITY` | `1.0` |

Para desenvolvimento local com arquivo `.env`:

```properties
LOKI_URL=http://45.187.224.251:3100
TEMPO_OTLP_ENDPOINT=http://45.187.224.251:4318/v1/traces
TRACING_SAMPLING_PROBABILITY=1.0
```

---

### 6. Registrar no Prometheus (Portainer)

O `Prometheus/docker-compose.yml` referencia `Prometheus/prometheus_config.yml` via `file: ./prometheus_config.yml` — não é `external`. Edite o arquivo neste repo e adicione um novo bloco em `scrape_configs` para a nova aplicação:

```yaml
  - job_name: 'nome-do-novo-projeto'
    scheme: https
    metrics_path: '/api/v1/actuator/prometheus'
    tls_config:
      insecure_skip_verify: false
    static_configs:
      - targets: ['url-publica-do-projeto.com.br']
        labels:
          app: 'nome-do-novo-projeto'
          env: 'production'
```

Dê push pro remoto Git e, no Portainer, rode **Pull and redeploy** na stack do Prometheus (a stack precisa ter sido criada com Build method **Repository**, não "Web editor"/"Upload" — só assim o `file:` enxerga o arquivo atualizado). O Portainer recria o Docker Config automaticamente, sem precisar de SSH.

---

### 7. Grafana — nenhuma ação necessária

Os datasources Prometheus, Loki e Tempo já estão configurados. Use o **Explore** do Grafana para filtrar pelos labels da nova aplicação:

| Datasource | Query de exemplo |
|---|---|
| Loki | `{app="nome-do-novo-projeto"}` |
| Prometheus | `up{app="nome-do-novo-projeto"}` |
| Tempo | Colar um `traceId` capturado nos logs do Loki |

---

## Checklist de Verificação

Use este checklist ao integrar um novo projeto:

- [ ] Dependências adicionadas no `pom.xml`
- [ ] `logback-spring.xml` criado com o nome correto da aplicação
- [ ] `logging.pattern.console` removido do `application.properties`
- [ ] Bloco de tracing/Loki adicionado ao `application.properties`
- [ ] `CorrelationIdFilter.java` criado no pacote correto
- [ ] Variáveis de ambiente configuradas no Coolify
- [ ] Aplicação deployada e respondendo em `https://url-do-projeto/api/v1/actuator/prometheus`
- [ ] `prometheus_config` atualizado no Portainer com o novo scrape target
- [ ] No Grafana → Loki Explore: logs aparecendo com `traceId`
- [ ] No Grafana → Tempo Explore: traces visíveis ao colar um `traceId`
- [ ] Header `X-Correlation-ID` presente na resposta HTTP

---

## Contato

**Autor:** César Augusto  
**E-mail:** cesar.augusto.rj1@gmail.com  
**LinkedIn:** https://www.linkedin.com/in/cesaravbezerra/  
**Portfólio:** https://portfolio.cesaraugusto.dev.br/

---

<h5 align="center">© 2026 César Augusto - Backend Developer Java & Infraestrutura de Redes</h5>
