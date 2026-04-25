#!/bin/bash
# translate.sh - Aplica traducoes PT-BR ao codigo fonte da WebUI do llama.cpp
#
# Uso: translate.sh <webui_src_dir> <translations_file>
# Ex:  translate.sh /app/tools/server/webui/src /app/i18n/pt-br.txt

set -e

WEBUI_DIR="$1"
TRANSLATIONS_FILE="$2"

if [ -z "$WEBUI_DIR" ] || [ -z "$TRANSLATIONS_FILE" ]; then
    echo "Uso: $0 <webui_src_dir> <translations_file>"
    exit 1
fi

if [ ! -d "$WEBUI_DIR" ]; then
    echo "Erro: diretorio '$WEBUI_DIR' nao existe"
    exit 1
fi

if [ ! -f "$TRANSLATIONS_FILE" ]; then
    echo "Erro: arquivo de traducoes '$TRANSLATIONS_FILE' nao existe"
    exit 1
fi

echo "Aplicando traducoes PT-BR de $TRANSLATIONS_FILE em $WEBUI_DIR"

# Encontrar todos os arquivos relevantes uma unica vez
mapfile -t TARGET_FILES < <(find "$WEBUI_DIR" -type f \( -name "*.svelte" -o -name "*.ts" -o -name "*.js" \) ! -path "*/node_modules/*" ! -path "*/.svelte-kit/*" ! -path "*/build/*" ! -path "*/dist/*")

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
    echo "Nenhum arquivo .svelte/.ts/.js encontrado em $WEBUI_DIR"
    exit 1
fi

echo "Total de arquivos alvo: ${#TARGET_FILES[@]}"

count=0
linenum=0

while IFS= read -r line || [ -n "$line" ]; do
    linenum=$((linenum + 1))

    # Pular linhas vazias e comentarios
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Extrair "EN" e "PT" do formato: "EN" => "PT"
    # Aceita aspas duplas em ambos os lados
    en=$(printf '%s' "$line" | sed -n 's/^"\(.*\)"[[:space:]]*=>[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p')
    pt=$(printf '%s' "$line" | sed -n 's/^"\(.*\)"[[:space:]]*=>[[:space:]]*"\(.*\)"[[:space:]]*$/\2/p')

    if [ -z "$en" ] || [ -z "$pt" ]; then
        echo "  ! Linha $linenum ignorada (formato invalido): $line"
        continue
    fi

    # Escapar caracteres especiais do sed no padrao de busca
    en_esc=$(printf '%s' "$en" | sed -e 's/[][\.*^$/]/\\&/g')
    # Escapar / e & na substituicao
    pt_esc=$(printf '%s' "$pt" | sed -e 's/[\/&]/\\&/g')

    # Aplicar substituicoes em 4 contextos diferentes:
    # 1. Texto entre tags: >TextoEN<     -> >TextoPT<
    # 2. Atributo aspas duplas: ="TextoEN"  -> ="TextoPT"
    # 3. Atributo aspas simples: ='TextoEN'  -> ='TextoPT'
    # 4. String em codigo entre aspas duplas com contexto: : "TextoEN", -> : "TextoPT",
    # 5. String em codigo entre aspas simples
    printf '%s\0' "${TARGET_FILES[@]}" | xargs -0 sed -i \
        -e "s/>${en_esc}</>${pt_esc}</g" \
        -e "s/=\"${en_esc}\"/=\"${pt_esc}\"/g" \
        -e "s/='${en_esc}'/='${pt_esc}'/g" \
        -e "s/\"${en_esc}\"/\"${pt_esc}\"/g" \
        -e "s/'${en_esc}'/'${pt_esc}'/g"

    count=$((count + 1))
done < "$TRANSLATIONS_FILE"

echo "Concluido. $count traducoes aplicadas."
