# OpenVPN (LOGNET - 45.187.224.251)

Stack baseada na imagem `kylemanna/openvpn`. A inicialização (gerar PKI, config
e primeiro usuário) roda **automaticamente** no entrypoint (`openvpn-init.sh`),
montado via Docker Config igual ao restante do repositório (`file: ./openvpn-init.sh`).

## Autenticação

Usa **usuário/senha** (`auth-user-pass-verify` via `users.txt` + `auth.sh`), não
certificado por cliente. `verify-client-cert none` desativa a exigência de
certificado individual e `username-as-common-name` usa o usuário autenticado
como CN. O `tls-auth` (`pki/ta.key`) continua ativo e vai embutido no
`client.ovpn` junto com a CA.

## Como funciona a automação

`openvpn-init.sh` roda como entrypoint a cada start do container:

- Se `/etc/openvpn/openvpn.conf` **não existe** (volume `openvpn-data` vazio,
  primeiro deploy): gera PKI, `openvpn.conf`, `users.txt` (com o usuário inicial
  vindo de `OVPN_USER`/secret `openvpn_password`), `auth.sh` e `client.ovpn`.
- Se já existe (redeploy, restart, update da stack): pula tudo isso e só sobe
  o servidor (`exec ovpn_run`). Não regenera certificado nem apaga usuários
  adicionados manualmente depois.

> Mudanças no `openvpn-init.sh` só valem para um volume **novo**. Para regerar
> tudo: remover a stack, `docker volume rm openvpn_openvpn-data` e fazer deploy de novo.

Variáveis/segredo usados pela automação (`docker-compose.yml`):

| Nome | Tipo | Uso |
|---|---|---|
| `OVPN_SERVER_HOST` | env da stack (Portainer) | Host/IP público usado no `ovpn_genconfig` e no `client.ovpn` gerado (ex.: `45.187.224.251`). Não fica no repositório; sem ela o container aborta com `OVPN_SERVER_HOST nao definido`. |
| `OVPN_USER` | env da stack (Portainer) | Usuário inicial gravado em `users.txt` na primeira execução. Não fica no repositório; sem ela o container aborta com `OVPN_USER nao definido`. |
| `openvpn_password` | secret externo | Senha do usuário inicial. Não fica no repositório. |

## Deploy pela primeira vez

No servidor, conferir que a porta está livre e o módulo `tun` disponível:

```bash
ss -ulpn | grep 1194        # não deve retornar nada
modprobe tun && ls -l /dev/net/tun
```

Criar o secret `openvpn_password` (não vai pro git): pelo Portainer em
**Secrets → Add secret** (com "Encode secret" ligado), ou via SSH — o espaço
inicial evita que a senha fique no histórico do shell:

```bash
 printf '%s' '<senha>' | docker secret create openvpn_password -
```

Depois seguir o padrão do repositório: Portainer → Stacks → Add stack →
nome `openvpn` → Build method **Repository** → Compose path
`OpenVPN/docker-compose.yml` → em **Environment variables** adicionar
`OVPN_SERVER_HOST` = `<ip ou host público>` e `OVPN_USER` = `<usuário>` → Deploy the stack.

Acompanhar a inicialização (a geração do DH/PKI leva alguns minutos):

```bash
docker service logs -f openvpn_openvpn
```

## Obter o `client.ovpn`

O perfil é gerado uma única vez, dentro do volume, em `/etc/openvpn/client.ovpn`
(só existe depois de aparecer `[openvpn-init] Concluido` no log). É o mesmo
arquivo para todos os usuários — a identificação é por usuário/senha.

**1. No servidor (SSH)** — copiar do container para o `/root`:

```bash
docker cp $(docker ps -qf name=openvpn_openvpn):/etc/openvpn/client.ovpn /root/client.ovpn
```

**2. No Windows (PowerShell)** — baixar (ou usar WinSCP/FileZilla em SFTP, porta 2224):

```powershell
scp -P 2224 root@45.187.224.251:/root/client.ovpn $HOME\Downloads\client.ovpn
```

**3. No servidor** — apagar a cópia (o arquivo carrega a chave `tls-auth`):

```bash
rm /root/client.ovpn
```

**4. No OpenVPN Connect** — **+** → aba **Upload File** (não **URL**: essa aba
é para OpenVPN Access Server e falha com "Incorrect response from server") →
arrastar o arquivo → informar usuário/senha → Connect.

### Perfil gerado por versão antiga do script

Redeploy/"Pull and redeploy" **não** regera o `client.ovpn` — o script pula a
inicialização quando o volume já tem config. Se o perfil foi gerado antes dos
ajustes para o OpenVPN Connect, os sintomas são:

| Sintoma no OpenVPN Connect | Causa / correção |
|---|---|
| "Missing external certificate" | Falta `setenv CLIENT_CERT 0` no perfil |
| "TAP adapter is disabled" | DCO desligado no cliente: **☰ → Settings → Advanced Settings** (rolar até o fim) → ligar **Data Channel Offload (DCO)** |
| "non-preferred data channel algorithms are not compatible with dco" | Perfil aceita CBC (`cipher AES-256-CBC`, ou CBC em `data-ciphers`/`data-ciphers-fallback`). Deve ter só `data-ciphers AES-256-GCM:AES-128-GCM` |

Corrigir o arquivo no volume, sem regerar a PKI (os comandos são idempotentes), e
repetir os passos 1 a 4:

```bash
C=$(docker ps -qf name=openvpn_openvpn)
docker exec $C sh -c '
  f=/etc/openvpn/client.ovpn
  grep -q "^setenv CLIENT_CERT 0" $f || sed -i "/^auth-user-pass$/a setenv CLIENT_CERT 0" $f
  sed -i -e "/^data-ciphers-fallback /d" -e "s/^cipher AES-256-CBC$/data-ciphers AES-256-GCM:AES-128-GCM/" -e "s/^data-ciphers .*/data-ciphers AES-256-GCM:AES-128-GCM/" $f
  grep -E "^(setenv|data-ciphers|cipher)" $f'
```

No OpenVPN Connect, depois de trocar o arquivo, **apagar o perfil antigo e
importar de novo** — ele guarda uma cópia própria e não relê o original.

Para regerar tudo do zero (novos certificados — perfis antigos deixam de
funcionar): remover a stack, `docker volume rm openvpn_openvpn-data` e fazer o
deploy de novo, recadastrando as variáveis da stack.

## Adicionar novo usuário

Editar `users.txt` diretamente no volume (`docker exec -it <container> vi /etc/openvpn/users.txt`
ou `docker cp`), adicionando uma linha `usuario:senha`. Não precisa gerar
certificado nem reiniciar o container — `auth.sh` lê o arquivo a cada tentativa
de conexão.

## Trocar a senha do usuário inicial

Trocar a senha depois do primeiro deploy só via `users.txt` (o secret
`openvpn_password` só é lido na inicialização do volume vazio, não em
redeploys seguintes).

## Firewall

A porta `1194/udp` é pública por desenho do ambiente (ver `VPS/Firewall/README.md`, que fica fora do git) —
não há restrição de origem no `firewall-setup-lognet.sh`.
