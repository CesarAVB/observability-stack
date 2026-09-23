# Script de acesso rápido a containers (MobaXterm)

Script auxiliar para abrir um terminal dentro de um container Docker sem precisar digitar `docker ps` + `docker exec -it <nome> bash` manualmente. Pensado para uso como comando remoto de uma sessão SSH no MobaXterm (campo "Execute the following commands at startup" ou como bookmark de sessão), mas funciona igualmente rodado direto via SSH/terminal.

## O que o script faz

`docker-terminal.sh`:

1. Lista os containers Docker em execução (`docker ps --format '{{.Names}}'`).
2. Se houver **apenas um** container, entra nele direto.
3. Se houver **mais de um**, mostra uma lista numerada e pede para escolher.
4. Se **nenhum** for encontrado, cai num `bash` local (não trava o terminal).
5. Ao entrar no container, tenta `bash`; se não existir, usa `sh`.

## Uso com MobaXterm

1. Copie o script para o servidor (ex.: `~/scripts/docker-terminal.sh`) e dê permissão de execução: `chmod +x docker-terminal.sh`.
2. Crie uma sessão SSH no MobaXterm apontando para o servidor.
3. Em **Advanced SSH settings → Terminal settings**, use o campo de comando de execução automática (ou configure via *macro*) para rodar `bash ~/scripts/docker-terminal.sh` assim que a sessão abrir.
