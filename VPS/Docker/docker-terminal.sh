#!/bin/bash

mapfile -t containers < <(docker ps --format '{{.Names}}')

if [ ${#containers[@]} -eq 0 ]; then
    echo "Nenhum container esta rodando."
    exec bash
fi

if [ ${#containers[@]} -eq 1 ]; then
    sel="${containers[0]}"
    echo "Container encontrado: $sel"
else
    echo "Containers encontrados:"
    for i in "${!containers[@]}"; do
        printf "  [%d] %s\n" $((i + 1)) "${containers[$i]}"
    done
    echo ""
    read -p "Escolha o numero do container: " n
    idx=$((n - 1))
    sel="${containers[$idx]}"
fi

if [ -z "$sel" ]; then
    echo "Escolha invalida."
    exec bash
fi

echo "Abrindo terminal em '$sel'..."
docker exec -it "$sel" bash || docker exec -it "$sel" sh
