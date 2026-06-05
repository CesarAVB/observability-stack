#!/bin/bash
set -e

# Firewall para o servidor 45.187.224.248 (exporters standalone).
# Protege as portas dos exporters: só os blocos confiáveis (que incluem o
# Prometheus em 45.187.224.251) conseguem fazer scrape. Como o Docker publica
# as portas ignorando o UFW, as regras vão na chain DOCKER-USER do iptables.

ALLOWED_NETWORKS="168.90.16.0/22 45.187.224.0/22"
PROTECTED_PORTS="9100 8081"
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

# aplica as regras imediatamente (ativas até o próximo reboot)
for PORT in $PROTECTED_PORTS; do
  iptables -I DOCKER-USER 1 -i "$IFACE" -p tcp --dport "$PORT" -j DROP
  for NET in $ALLOWED_NETWORKS; do
    iptables -I DOCKER-USER 1 -i "$IFACE" -s "$NET" -p tcp --dport "$PORT" -j RETURN
  done
done

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

for NET in $ALLOWED_NETWORKS; do
  for PORT in $PROTECTED_PORTS; do
    echo "-A DOCKER-USER -i $IFACE -s $NET -p tcp --dport $PORT -j RETURN" >> "$UFW_AFTER_RULES"
  done
done

for PORT in $PROTECTED_PORTS; do
  echo "-A DOCKER-USER -i $IFACE -p tcp --dport $PORT -j DROP" >> "$UFW_AFTER_RULES"
done

cat >> "$UFW_AFTER_RULES" <<EOF
COMMIT
# END observability-docker-rules
EOF

echo "Recarregando UFW..."
ufw reload

echo ""
echo "Concluído. Portas protegidas: $PROTECTED_PORTS"
echo "Redes permitidas: $ALLOWED_NETWORKS"
