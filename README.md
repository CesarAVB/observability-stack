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
- [Infraestrutura](#infraestrutura)
- [Onboarding - Novo Projeto Spring Boot](#onboarding--novo-projeto-spring-boot)
  - [1. Dependências (pom.xml)](#1-dependências-pomxml)
  - [2. Configuração de Logging (logback-spring.xml)](#2-configuração-de-logging-logback-springxml)
  - [3. Propriedades (application.properties)](#3-propriedades-applicationproperties)
  - [4. Filtro de Correlation ID](#4-filtro-de-correlation-id)
  - [5. Variáveis de Ambiente (Coolify)](#5-variáveis-de-ambiente-coolify)
  - [6. Registrar no Prometheus (host via SSH)](#6-registrar-no-prometheus-host-via-ssh)
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
| Monitoramento de infra | **Zabbix** | Monitoramento de hosts, serviços e rede |

---

## Estrutura do Repositório

```
.
├── Grafana/                  # Stack do Grafana (dashboards e datasources)
│   ├── docker-compose.yml
│   ├── exemplo.env
│   └── README.md
├── Loki/                     # Stack do Grafana Loki (agregação de logs)
│   ├── docker-compose.yml
│   ├── loki-config.yml
│   ├── exemplo.env
│   └── README.md
├── Prometheus/               # Stack do Prometheus (coleta de métricas)
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   ├── exemplo.env
│   └── README.md
├── Tempo/                    # Stack do Grafana Tempo (rastreamento distribuído)
│   ├── docker-compose.yml
│   ├── tempo.yml
│   ├── exemplo.env
│   └── README.md
├── Zabbix/                   # Stack do Zabbix Server (monitoramento de infra)
│   ├── docker-compose.yml
│   ├── exemplo.env
│   └── README.md
├── observability-onboarding.md   # Guia de integração para projetos Spring Boot
└── README.md                 # Este arquivo
```

### Links para os READMEs das subpastas

| Ferramenta | README |
|---|---|
| Grafana | [Grafana/README.md](Grafana/README.md) |
| Loki | [Loki/README.md](Loki/README.md) |
| Prometheus | [Prometheus/README.md](Prometheus/README.md) |
| Tempo | [Tempo/README.md](Tempo/README.md) |
| Zabbix | [Zabbix/README.md](Zabbix/README.md) |

---

## Infraestrutura

Todos os serviços rodam no mesmo servidor VPS via Docker Swarm gerenciado pelo Portainer.

**Servidor:** `45.187.224.251`

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

### 6. Registrar no Prometheus (host via SSH)

Acesse o servidor via SSH e edite diretamente o `prometheus.yml`:

```bash
ssh usuario@45.187.224.251
sudo mkdir -p /opt/docker/prometheus
vim /opt/docker/prometheus/prometheus.yml
```

Adicione um novo bloco em `scrape_configs` para a nova aplicação:

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

Após salvar o arquivo, remova o config antigo, recrie-o e force o reload do Prometheus:

```bash
docker config rm prometheus_config
docker config create prometheus_config /opt/docker/prometheus/prometheus.yml
curl -X POST http://45.187.224.251:9090/-/reload
```

> O reload aplica a nova configuração sem reiniciar o container nem perder dados.

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
