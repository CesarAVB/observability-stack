#!/bin/bash
set -e

# Portas internas de observabilidade (TCP) — acesso restrito às redes confiáveis.
ALLOWED_NETWORKS="168.90.16.0/22 45.187.224.0/22"
PROTECTED_PORTS="9090 3100 3200 4317 4318"

# Syslog dos switches Huawei (UDP/TCP 514). A origem que chega ao servidor é o IP
# pós-NAT do gateway de gerência (10.129.190.0/24) — os switches têm IP de gerência
# em 10.129.180.x, mas atravessam um NAT antes de alcançar o servidor.
ALLOWED_NETWORKS_SYSLOG="168.90.16.0/22 45.187.224.0/22 10.129.190.0/24"
SYSLOG_PORTS="514"

UFW_AFTER_RULES="/etc/ufw/after.rules"
MARKER="# BEGIN observability-docker-rules"

# detecta a interface de rede padrão (primeira rota default)
IFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)

if [ -z "$IFACE" ]; then
  echo "Erro: não foi possível detectar a interface de rede." >&2
  exit 1
fi

echo "Interface detectada: $IFACE"
echo "Aplicando regras iptables na chain DOCKER-USER..."

# Aplica as regras imediatamente (ativas até o próximo reboot). Para cada porta:
# insere o DROP e, acima dele, os RETURN das redes permitidas (-I 1 empilha no topo).
apply_now() {
  local proto="$1" ports="$2" nets="$3"
  for PORT in $ports; do
    iptables -I DOCKER-USER 1 -i "$IFACE" -p "$proto" --dport "$PORT" -j DROP
    for NET in $nets; do
      iptables -I DOCKER-USER 1 -i "$IFACE" -s "$NET" -p "$proto" --dport "$PORT" -j RETURN
    done
  done
}

apply_now tcp "$PROTECTED_PORTS" "$ALLOWED_NETWORKS"
apply_now tcp "$SYSLOG_PORTS"    "$ALLOWED_NETWORKS_SYSLOG"
apply_now udp "$SYSLOG_PORTS"    "$ALLOWED_NETWORKS_SYSLOG"

echo "Regras aplicadas com sucesso."

# persiste no after.rules (remove bloco anterior se existir)
if grep -q "$MARKER" "$UFW_AFTER_RULES" 2>/dev/null; then
  echo "Removendo bloco anterior em $UFW_AFTER_RULES..."
  sed -i "/$MARKER/,/# END observability-docker-rules/d" "$UFW_AFTER_RULES"
fi

echo "Persistindo regras em $UFW_AFTER_RULES..."

cat >> "$UFW_AFTER_RULES" <<EOF

$MARKER
*filter
:DOCKER-USER - [0:0]
EOF

# No arquivo as regras são lidas em ordem: os RETURN (permitidos) precisam vir
# antes dos DROP, então escrevemos todos os RETURN e depois todos os DROP.
persist_return() {
  local proto="$1" ports="$2" nets="$3"
  for NET in $nets; do
    for PORT in $ports; do
      echo "-A DOCKER-USER -i $IFACE -s $NET -p $proto --dport $PORT -j RETURN" >> "$UFW_AFTER_RULES"
    done
  done
}

persist_drop() {
  local proto="$1" ports="$2"
  for PORT in $ports; do
    echo "-A DOCKER-USER -i $IFACE -p $proto --dport $PORT -j DROP" >> "$UFW_AFTER_RULES"
  done
}

persist_return tcp "$PROTECTED_PORTS" "$ALLOWED_NETWORKS"
persist_return tcp "$SYSLOG_PORTS"    "$ALLOWED_NETWORKS_SYSLOG"
persist_return udp "$SYSLOG_PORTS"    "$ALLOWED_NETWORKS_SYSLOG"

persist_drop tcp "$PROTECTED_PORTS"
persist_drop tcp "$SYSLOG_PORTS"
persist_drop udp "$SYSLOG_PORTS"

cat >> "$UFW_AFTER_RULES" <<EOF
COMMIT
# END observability-docker-rules
EOF

echo "Recarregando UFW..."
ufw reload

echo ""
echo "Concluído."
echo "Portas TCP (observabilidade): $PROTECTED_PORTS  ->  $ALLOWED_NETWORKS"
echo "Syslog 514 (TCP/UDP):         $SYSLOG_PORTS  ->  $ALLOWED_NETWORKS_SYSLOG"
