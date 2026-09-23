#!/bin/sh
# Roda como entrypoint do container.
# - PKI e usuario inicial: gerados so na primeira execucao (volume "openvpn-data"
#   vazio). Redeploy/restart nunca regenera certificado nem apaga usuarios.
# - Ajustes do openvpn.conf, auth.sh e client.ovpn: reaplicados A CADA START.
#   Assim um "Pull and redeploy" (com o nome do config versionado no compose)
#   corrige volumes ja existentes sem nenhum passo manual.
set -e

OVPN_DATA=/etc/openvpn
OVPN_SERVER_HOST="${OVPN_SERVER_HOST:?OVPN_SERVER_HOST nao definido}"
OVPN_USER="${OVPN_USER:?OVPN_USER nao definido}"
OVPN_PASSWORD="$(cat /run/secrets/openvpn_password)"
MARK='# --- gerenciado por openvpn-init.sh (reescrito a cada start) ---'

cd "$OVPN_DATA"

# ---------------------------------------------------------------- 1a execucao
if [ ! -f pki/ca.crt ]; then
  echo "[openvpn-init] Primeira execucao: gerando config e PKI..."
  # -d: nao empurra a rota padrao via genconfig (o push "redirect-gateway" vem
  # do bloco gerenciado). -N: NAT para os clientes alcancarem a rede do servidor.
  # O tls-auth (pki/ta.key) continua ativo e vai embutido no client.ovpn.
  ovpn_genconfig -u "udp://${OVPN_SERVER_HOST}" -d -N
  EASYRSA_BATCH=1 ovpn_initpki nopass
fi

if [ ! -f users.txt ]; then
  printf '%s:%s\n' "$OVPN_USER" "$OVPN_PASSWORD" > users.txt
fi

# ------------------------------------------------------------ a cada start
# via-file: o OpenVPN passa o caminho do arquivo temporario (usuario na 1a
# linha, senha na 2a) como $1.
cat > auth.sh <<'EOF'
#!/bin/sh
username=$(head -n 1 "$1")
password=$(tail -n 1 "$1")
grep -qxF "${username}:${password}" /etc/openvpn/users.txt && exit 0 || exit 1
EOF
chmod +x auth.sh

# Remove o bloco gerenciado anterior (e as linhas que versoes antigas do script
# acrescentavam sem marcador) antes de reescrever.
sed -i "/^${MARK}\$/,\$d" openvpn.conf
sed -i '/^auth-user-pass-verify /d; /^script-security /d; /^verify-client-cert /d; /^username-as-common-name$/d; /^push "redirect-gateway /d; /^push "dhcp-option DNS /d' openvpn.conf
# Sem compressao: o OpenVPN Connect (nivel Preferred/DCO) recusa o push de
# comp-lzo ("server pushed compression settings that are not allowed").
sed -i '/comp-lzo/d; /^compress/d; /^push "compress/d' openvpn.conf

cat >> openvpn.conf <<EOF
${MARK}
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
# Sem certificado de cliente: evita o aviso "Missing external certificate" do OpenVPN Connect
setenv CLIENT_CERT 0
# So AEAD: o DCO do OpenVPN Connect/2.6 recusa o perfil se CBC aparecer, mesmo
# como fallback. Sem "cipher" o Connect assume BF-CBC; por isso GCM nos dois.
data-ciphers AES-256-GCM:AES-128-GCM
cipher AES-256-GCM
key-direction 1
verb 3
<ca>
$(cat pki/ca.crt)
</ca>
<tls-auth>
$(cat pki/ta.key)
</tls-auth>
EOF

# NAT dos clientes para a internet. O ovpn_run so mascara saindo por eth0, mas
# no Swarm eth0 e a overlay da stack e a saida real e o docker_gwbridge (eth1):
# sem esta regra o cliente conecta e fica sem internet (envia, nada volta).
OVPN_NET=$(sed -n 's/^declare -x OVPN_SERVER=//p' ovpn_env.sh 2>/dev/null | tr -d '"')
OVPN_NET="${OVPN_NET:-192.168.255.0/24}"
iptables -t nat -C POSTROUTING -s "$OVPN_NET" -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -s "$OVPN_NET" -j MASQUERADE
echo "[openvpn-init] NAT ${OVPN_NET} em todas as interfaces; ip_forward=$(cat /proc/sys/net/ipv4/ip_forward); rota padrao: $(ip route show default)"

echo "[openvpn-init] Pronto. client.ovpn atualizado em ${OVPN_DATA}/client.ovpn (docker cp pra fora do container)."

exec ovpn_run
