# OpenVPN (LOGNET - 45.187.224.251)

Stack baseada na imagem `kylemanna/openvpn`. Toda a configuração é feita
**automaticamente** pelo entrypoint (`openvpn-init.sh`), montado via Docker
Config igual ao restante do repositório (`file: ./openvpn-init.sh`). Nenhum
arquivo precisa ser editado à mão, nem no servidor nem no cliente.

## Autenticação

Usa **usuário/senha** (`auth-user-pass-verify` via `users.txt` + `auth.sh`), não
certificado por cliente. `verify-client-cert none` desativa a exigência de
certificado individual e `username-as-common-name` usa o usuário autenticado
como CN. O `tls-auth` (`pki/ta.key`) continua ativo e vai embutido no
`client.ovpn` junto com a CA.

## Como funciona a automação

`openvpn-init.sh` roda como entrypoint a cada start do container:

| Quando | O que faz |
|---|---|
| Só na 1ª execução (volume `openvpn-data` sem `pki/ca.crt`) | Gera PKI e `openvpn.conf` base (`ovpn_genconfig` + `ovpn_initpki`). |
| Só se não existir `users.txt` | Cria com o usuário inicial (`OVPN_USER` + secret `openvpn_password`). |
| **A cada start** | Reescreve `auth.sh`, remove compressão do `openvpn.conf`, reescreve o bloco gerenciado (auth, pushes) e **regera o `client.ovpn`** a partir da PKI existente. |

Redeploy/restart **nunca** regera certificados nem apaga usuários — perfis já
distribuídos continuam válidos. Mas qualquer ajuste de config feito no script
chega ao servidor e ao `client.ovpn` no próximo deploy.

> **Ao alterar o `openvpn-init.sh`, incremente o sufixo de `name: openvpn_init_vN`**
> em `configs:` no `docker-compose.yml`. Docker Config é imutável no Swarm: sem
> trocar o nome, o "Pull and redeploy" mantém o script antigo no container.
> Confira com `docker exec $(docker ps -qf name=openvpn_openvpn) cat /usr/local/bin/openvpn-init.sh`.

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

Acompanhar a inicialização (a geração do DH/PKI leva alguns minutos na 1ª vez):

```bash
docker service logs -f openvpn_openvpn
```

## Atualizar a stack

Editar `openvpn-init.sh` (incrementando `openvpn_init_vN` no compose) → push →
Portainer → **Pull and redeploy**. O container reinicia com o script novo, que
reaplica a config e regera o `client.ovpn`. Depois é só buscar o perfil de novo
(seção abaixo) e reimportar no cliente.

## Obter o `client.ovpn`

O perfil fica no volume, em `/etc/openvpn/client.ovpn`, e é regerado a cada
start (espere `[openvpn-init] Pronto` no log). É o mesmo arquivo para todos os
usuários — a identificação é por usuário/senha.

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

**4. No OpenVPN Connect** — apagar o perfil anterior, se houver (o Connect
guarda cópia própria e não relê o arquivo) → **+** → aba **Upload File** (não
**URL**: essa aba é para OpenVPN Access Server e falha com "Incorrect response
from server") → arrastar o arquivo → informar usuário/senha → Connect.

### Configuração do OpenVPN Connect (uma vez por máquina)

**☰ → Settings → Advanced Settings**:

- **Security Level: Preferred** — com **Legacy** o Connect recusa o DCO.
- **Data Channel Offload (DCO): ligado** (fim da tela) — sem ele o Connect cai
  no driver TAP.

| Sintoma no OpenVPN Connect | Causa |
|---|---|
| "Missing external certificate" | Perfil antigo, sem `setenv CLIENT_CERT 0` → buscar o perfil de novo |
| "TAP adapter is disabled" | DCO desligado no cliente |
| "non-preferred data channel algorithms are not compatible with dco" | Security Level em **Legacy**, ou perfil antigo com CBC |
| "server pushed compression settings that are not allowed" | Servidor rodando script antigo → conferir `openvpn_init_vN` e fazer Pull and redeploy |

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
`openvpn_password` só é lido quando `users.txt` não existe).

## Firewall

A porta `1194/udp` é pública por desenho do ambiente (ver `VPS/Firewall/README.md`, que fica fora do git) —
não há restrição de origem no `firewall-setup-lognet.sh`.
