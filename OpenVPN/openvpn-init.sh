#!/bin/sh
# Roda como entrypoint do container. Na primeira execucao (volume "openvpn-data"
# vazio, sem openvpn.conf) gera a PKI e a config completas; nas execucoes
# seguintes pula a inicializacao e apenas sobe o servidor. Idempotente: pode
# reiniciar/redeploy a stack sem regenerar certificados nem apagar usuarios.
set -e

OVPN_DATA=/etc/openvpn
OVPN_SERVER_HOST="${OVPN_SERVER_HOST:?OVPN_SERVER_HOST nao definido}"
OVPN_USER="${OVPN_USER:?OVPN_USER nao definido}"
OVPN_PASSWORD="$(cat /run/secrets/openvpn_password)"

if [ ! -f "$OVPN_DATA/openvpn.conf" ]; then
  echo "[openvpn-init] Primeira execucao: gerando config e PKI..."
  cd "$OVPN_DATA"

  # -d: nao empurra a rota padrao via genconfig (o push "redirect-gateway" e
  # adicionado abaixo). -N: NAT para os clientes alcancarem a rede do servidor.
  # O tls-auth (pki/ta.key) continua ativo e vai embutido no client.ovpn.
  ovpn_genconfig -u "udp://${OVPN_SERVER_HOST}" -d -N
  EASYRSA_BATCH=1 ovpn_initpki nopass

  printf '%s:%s\n' "$OVPN_USER" "$OVPN_PASSWORD" > users.txt

  # via-file: o OpenVPN passa o caminho do arquivo temporario (usuario na 1a
  # linha, senha na 2a) como $1.
  cat > auth.sh <<'EOF'
#!/bin/sh
username=$(head -n 1 "$1")
password=$(tail -n 1 "$1")
grep -qxF "${username}:${password}" /etc/openvpn/users.txt && exit 0 || exit 1
EOF
  chmod +x auth.sh

  cat >> openvpn.conf <<'EOF'
auth-user-pass-verify /etc/openvpn/auth.sh via-file
script-security 2
verify-client-cert none
username-as-common-name
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
EOF

  cat > client.ovpn <<EOF
client
dev tun
proto udp
remote ${OVPN_SERVER_HOST} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
# GCM primeiro: o DCO do OpenVPN Connect/2.6 so aceita AEAD; CBC fica de fallback
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
data-ciphers-fallback AES-256-CBC
key-direction 1
verb 3
<ca>
EOF
  cat pki/ca.crt >> client.ovpn
  echo '</ca>' >> client.ovpn
  echo '<tls-auth>' >> client.ovpn
  cat pki/ta.key >> client.ovpn
  echo '</tls-auth>' >> client.ovpn

  echo "[openvpn-init] Concluido. client.ovpn disponivel em ${OVPN_DATA}/client.ovpn (docker cp pra fora do container)."
else
  echo "[openvpn-init] Config ja existe, pulando inicializacao."
fi

exec ovpn_run
