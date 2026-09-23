# Padrão de Observabilidade — Backends Spring Boot

Documento normativo. Toda aplicação backend que envia métricas, logs ou traces
para esta infra (`45.187.224.251` — Prometheus / Loki / Tempo) **deve** seguir
este padrão. O objetivo é ter **um único nome canônico por aplicação**, usado de
forma idêntica em métricas, logs, traces e na config de scrape — eliminando a
divergência de labels entre datasources (o que hoje quebra silenciosamente
painéis do dashboard `aplicacao-spring-boot.json`).

---

## 1. Nome canônico da aplicação

Fonte única da verdade: **`spring.application.name`**.

- Formato: `kebab-case`, com sufixo `-backend` para APIs. Ex.: `talkchat-backend`,
  `voipmanager-backend`, `lognet-crm`.
- Esse valor **nunca** é digitado à mão em outro lugar — todos os outros pontos
  derivam dele.

| Onde aparece | Como amarrar ao `spring.application.name` |
|---|---|
| Tag Micrometer `application` (métricas Prometheus) | `management.metrics.tags.application=${spring.application.name}` |
| Label Loki `app` (logback) | `<springProperty name="APP_NAME" source="spring.application.name" defaultValue="<slug>-backend"/>` |
| `resource.attributes` do OTLP / `service.name` (traces Tempo) | derivado automaticamente de `spring.application.name` pelo Micrometer Tracing |
| `job_name` no `Prometheus/prometheus_config.yml` (infra) | digitado **igual** ao `spring.application.name` |
| Label estático `app:` no bloco do job (infra) | **igual** ao `spring.application.name` |

Resultado esperado: para uma app `X`, todas estas consultas resolvem para a
mesma série —
`up{job="X"}`, `http_server_requests_seconds_count{application="X"}`,
`{app="X"}` (Loki), `service.name="X"` (Tempo).

> **Atenção — `app` ≠ `application`:** métricas expõem o label `application`;
> logs no Loki expõem o label `app`. Os **nomes** dos labels são diferentes por
> histórico das ferramentas, mas o **valor** tem que ser idêntico. O dashboard
> já usa `application=` nas queries Prometheus e `app=` nas queries Loki.

> **Pegadinha do `up`:** o metric `up` do Prometheus só carrega os labels do
> `scrape_configs` (`job`, `instance`, labels estáticos) — **nunca** o label
> `application` da app. Por isso `job_name` **tem** que ser igual ao
> `spring.application.name`: é o que faz o painel "App UP" do dashboard casar.

---

## 2. Label de ambiente — uma env só, um nome de label só

**Nome do label:** `environment` em todos os lugares (métricas, logs, traces e
labels estáticos do `prometheus_config.yml`). **Não** usar `env` — é o que o
Micrometer já emite como tag, então padroniza-se por ele. (O `talkchat-backend`
usava `env` no logback e o `voipmanager-backend` usava `environment` — unificar
em `environment`.)

**Fonte do valor:** `SPRING_PROFILES_ACTIVE` / `spring.profiles.active`
(mecanismo nativo do Spring), com default `production`:

- Métricas: `management.metrics.tags.environment=${SPRING_PROFILES_ACTIVE:production}`
- Logs (logback): `<springProperty name="APP_ENV" source="spring.profiles.active" defaultValue="production"/>`
  e no destino Loki o label é `environment=${APP_ENV}` (chave `environment`, não `env`).
- Traces (se usar `management.observations.key-values`):
  `management.observations.key-values.environment=${SPRING_PROFILES_ACTIVE:production}`

**Proibido** usar uma env própria (`APP_ENVIRONMENT`, `ENV`, `info.app.environment`
como fonte, etc.) — foi o que gerou o risco de os labels virarem `local`
silenciosamente no `voipmanager-backend` se a env faltasse no Coolify.

---

## 3. Actuator — endpoint de métricas

- `management.endpoints.web.base-path=/actuator` — **na raiz**, sem
  `server.servlet.context-path` e sem porta de management separada.
- Qualquer prefixo de rota da API (`/api`, `/api/v1`) vive **só** nos
  `@RequestMapping` dos controllers, **não** afeta o Actuator.
- `metrics_path` no Prometheus é **sempre** `/actuator/prometheus`.
- Exceção legada: `lognet-crm` usa `/api/v1/actuator/prometheus` (context-path
  real). Não replicar em apps novas.

```properties
management.endpoints.web.base-path=/actuator
management.endpoints.web.exposure.include=${MANAGEMENT_ENDPOINTS_EXPOSURE:health,info,metrics,prometheus,loggers,scheduledtasks,threaddump}
management.endpoint.prometheus.enabled=true
management.endpoint.health.show-details=${MANAGEMENT_HEALTH_SHOW_DETAILS:when_authorized}
management.metrics.tags.application=${spring.application.name}
management.metrics.tags.environment=${SPRING_PROFILES_ACTIVE:production}
management.metrics.distribution.percentiles-histogram.http.server.requests=true
# opcional, deixa o histogram_quantile preciso e habilita painel "% dentro do SLO"
management.metrics.distribution.slo.http.server.requests=50ms,100ms,200ms,500ms,1s,2s
# expõe pool de threads do Tomcat (tomcat_threads_busy_threads etc.)
server.tomcat.mbeanregistry.enabled=true
```

---

## 3b. Métricas de aplicação obrigatórias

Além das que o Micrometer coleta sozinho (JVM, HikariCP, `http_server_requests`),
toda app **deve** expor:

### `http_client_requests_seconds` — chamadas de saída (integrações)

O ponto cego mais comum. Só é instrumentado se os clients HTTP forem criados a
partir dos **builders gerenciados pelo Spring**:

- `RestClient` → injetar `RestClient.Builder` (não `RestClient.create()`)
- `WebClient` → injetar `WebClient.Builder`
- `RestTemplate` → construir via `RestTemplateBuilder`

Dar um nome estável a cada cliente para virar a tag `client_name`:
```java
this.chatwootClient = restClientBuilder
        .baseUrl(props.getBaseUrl())
        .requestInterceptor(...)
        .build();
// e registrar um ObservationRegistry / usar .observationRegistry(...) se necessário
```
Resultado: `http_client_requests_seconds_count{client_name="chatwoot",status="200",...}`.
As regras `OutboundIntegrationErrors` / `OutboundIntegrationSlow` já consomem isso.

### `app_scheduled_seconds_*` — tarefas `@Scheduled`

O Micrometer **não** instrumenta `@Scheduled` automaticamente. Padronizar assim:

1. Registrar o aspecto uma vez:
   ```java
   @Bean
   TimedAspect timedAspect(MeterRegistry registry) { return new TimedAspect(registry); }
   ```
2. Anotar cada método `@Scheduled`:
   ```java
   @Timed(value = "app.scheduled", extraTags = {"job", "limpeza-sessoes"})
   @Scheduled(fixedDelayString = "...")
   void limpezaSessoes() { ... }
   ```

Gera `app_scheduled_seconds_count{job="limpeza-sessoes",exception="none|<classe>"}`.
A regra `ScheduledTaskFailing` alerta quando `exception != "none"`.

### `logback_events_total`

Vem de graça com Micrometer + Logback (autoconfig `LogbackMetricsAutoConfiguration`).
Só garantir que **não** foi desabilitada (`management.metrics.enable.logback=false`
ou exclusão do bean). A regra `HighLogErrorRate` usa `logback_events_total{level="error"}`.

---

## 4. Segurança do Actuator

- `SecurityConfig` libera **exatamente** `/actuator/health`, `/actuator/info` e
  `/actuator/prometheus` com `permitAll()`. **Nunca** `/actuator/**`
  (`/actuator/loggers`, `/actuator/threaddump`, `/actuator/env` seguem
  autenticados).
- `management.endpoint.health.show-details=when_authorized` (não `always`) —
  evita expor detalhes de saúde/infra publicamente.
- No edge (Traefik/Coolify): restringir `/actuator/**` ao IP do servidor de
  observabilidade `45.187.224.251/32` (mais a rede interna, se houver
  coleta interna). Se aplicar `ipAllowList`, **incluir esse IP** ou o scrape
  para de funcionar.

---

## 5. Envs obrigatórias no Coolify (checklist de deploy)

```env
SPRING_PROFILES_ACTIVE=production
LOKI_URL=http://45.187.224.251:3100
TEMPO_OTLP_ENDPOINT=http://45.187.224.251:4318/v1/traces
MANAGEMENT_ENDPOINTS_EXPOSURE=health,info,metrics,prometheus,loggers,scheduledtasks,threaddump
```

- **Sem `LOKI_URL`:** o appender cai em `http://localhost:3100` e **nenhum log
  chega ao Loki** (falha silenciosa).
- **Sem `SPRING_PROFILES_ACTIVE`:** tudo cai em `production` por default e fica
  consistente — mas se for setado só de um lado (só logback ou só Micrometer),
  o label de ambiente diverge. Setar sempre.

---

## 6. Bloco de scrape correspondente (feito no repo de observabilidade)

Para cada app nova, adicionar em `Prometheus/prometheus_config.yml` um bloco
assim, com `job_name` == `spring.application.name`:

```yaml
  - job_name: '<spring.application.name>'
    scheme: https
    metrics_path: '/actuator/prometheus'
    tls_config:
      insecure_skip_verify: false
    static_configs:
      - targets: ['<host-publico-da-api>']
        labels:
          app: '<spring.application.name>'
          environment: 'production'
```

Depois: `git push` → Portainer → stack Prometheus → **Pull and redeploy** →
conferir `up{job="<nome>"}` em `http://45.187.224.251:9090/targets`.

---
---

# PROMPT PARA ENVIAR A CADA APLICAÇÃO BACKEND

> Copie o bloco abaixo e mande para o agente/dev de cada repositório backend.
> Ele é auto-contido.

---

Preciso alinhar este backend Spring Boot ao **padrão de observabilidade** da
nossa infra (Prometheus / Loki / Tempo em `45.187.224.251`). O princípio é:
**um único nome canônico para a aplicação**, vindo de `spring.application.name`,
usado de forma idêntica em métricas, logs, traces e na config de scrape.

Faça uma auditoria do repositório e me devolva, item por item, o que **já está
conforme** e o que **precisa mudar** (com o diff proposto). Não altere nada
ainda — primeiro me mostre o levantamento.

### 1. Nome canônico
- Qual o valor de `spring.application.name`? Deve ser `kebab-case` com sufixo
  `-backend` (ex.: `meuservico-backend`). Se não for, proponha o ajuste.
- `management.metrics.tags.application` deve ser **exatamente**
  `${spring.application.name}` (não string literal, não outra env).
- No `logback-spring.xml`: o label enviado ao Loki deve se chamar `app` e seu
  valor deve vir de `<springProperty ... source="spring.application.name"/>`.
  Me diga o nome do `springProperty`, o `source` e como ele é usado no
  destino Loki (`app=${...}`).
- Confirme que os três valores resolvem para a **mesma string** em produção.

### 2. Ambiente
- O **nome do label** de ambiente deve ser `environment` em métricas E logs
  (não `env`). Se o logback envia ao Loki como `env=...`, renomear para
  `environment=...`.
- O valor do label das **métricas** deve vir de
  `management.metrics.tags.environment=${SPRING_PROFILES_ACTIVE:production}`.
- O valor do label dos **logs** (logback) deve vir de
  `source="spring.profiles.active"` com `defaultValue="production"`.
- Se hoje usa uma env própria (`APP_ENVIRONMENT`, `ENV`, `info.app.environment`
  como fonte, etc.) para isso, proponha a migração para `SPRING_PROFILES_ACTIVE`
  e a remoção da env legada do Coolify após o deploy.

### 3. Actuator
- Deve existir `management.endpoints.web.base-path=/actuator` e **não** deve
  existir `server.servlet.context-path` nem porta de management separada.
- Teste e me diga qual URL responde as métricas (corpo `# HELP jvm_...`):
  `https://<host>/actuator/prometheus` ou `https://<host>/api/.../actuator/prometheus`.
  O padrão exige que seja `/actuator/prometheus` na raiz.
- `management.endpoints.web.exposure.include` (ou a env
  `MANAGEMENT_ENDPOINTS_EXPOSURE`) deve conter `prometheus`, `health`, `info`,
  `metrics`, `loggers`, `scheduledtasks`, `threaddump`.
- `management.endpoint.prometheus.enabled=true`.
- `management.endpoint.health.show-details` deve ser `when_authorized`
  (não `always`).

### 4. Segurança
- No `SecurityConfig`: `permitAll()` deve cobrir **apenas**
  `/actuator/health`, `/actuator/info`, `/actuator/prometheus` — **nunca**
  `/actuator/**`. Me mostre o trecho atual.
- Existe algum filtro de auth (JWT etc.) que possa barrar `/actuator/prometheus`
  com 401? Confirme que passa sem token.

### 5. Tracing
- `management.otlp.tracing.endpoint` deve apontar para
  `${TEMPO_OTLP_ENDPOINT:http://45.187.224.251:4318/v1/traces}`.
- `management.tracing.sampling.probability` definido (via env, default `1.0` em
  homologação / valor menor em produção conforme volume).

### 5b. Métricas de aplicação (obrigatórias)
- **`http_client_requests_seconds`** (chamadas de saída / integrações): liste
  cada cliente HTTP do projeto (Chatwoot, LLM, Hubsoft, Evolution, dialer, etc.)
  e diga se é criado a partir de builder gerenciado pelo Spring
  (`RestClient.Builder` / `WebClient.Builder` / `RestTemplateBuilder`). Se algum
  usa `HttpClient` cru / `RestClient.create()` / `new RestTemplate()`, proponha
  a migração para o builder e um `client_name` estável por cliente. Confirme no
  `/actuator/prometheus` em produção se `http_client_requests_seconds_count`
  aparece hoje.
- **`@Scheduled`**: liste todos os métodos `@Scheduled` do projeto. Proponha
  registrar `@Bean TimedAspect` e anotar cada um com
  `@Timed(value="app.scheduled", extraTags={"job","<nome-curto>"})`. Confirme se
  `app_scheduled_seconds_count` aparece no `/actuator/prometheus`.
- **`logback_events_total`**: confirme que aparece no `/actuator/prometheus` e
  que não há `management.metrics.enable.logback=false`.

### 6. Envs de deploy (Coolify)
Liste quais destas estão definidas no ambiente de produção e quais faltam:
```
SPRING_PROFILES_ACTIVE=production
LOKI_URL=http://45.187.224.251:3100
TEMPO_OTLP_ENDPOINT=http://45.187.224.251:4318/v1/traces
MANAGEMENT_ENDPOINTS_EXPOSURE=health,info,metrics,prometheus,loggers,scheduledtasks,threaddump
```
- **Crítico:** sem `LOKI_URL`, o logback cai em `localhost:3100` e nenhum log
  chega ao Loki (falha silenciosa). Confirme que está setada.

### 7. Proxy / edge
- O `/actuator/prometheus` precisa ser acessível pelo IP `45.187.224.251`
  (servidor de observabilidade). Se houver `ipAllowList` no Traefik/edge para
  `/actuator/**`, esse IP `45.187.224.251/32` precisa estar liberado.

### Entrega esperada
1. Tabela "item / conforme? / ação".
2. Diffs propostos para `application.properties`, `logback-spring.xml` e
   `SecurityConfig` (se necessário).
3. Lista de envs a adicionar/renomear no Coolify.
4. O valor final de `spring.application.name` — vou usar exatamente esse string
   como `job_name` no `prometheus_config.yml` da infra.
