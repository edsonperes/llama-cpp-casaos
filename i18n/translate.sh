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

    # Aplicar substituicoes em 4 contextos diferentes (em ordem):
    # 1. Texto entre tags: >TextoEN<     -> >TextoPT<
    # 2. Atributos texto seguros: aria-label="..", title="..", placeholder="..", alt="..", label="..", description="..", text="..", message="..", tooltip="..", confirmText="..", cancelText="..", submitText="..", helpText="..", errorMessage="..", successMessage="..", warningMessage="..", infoMessage="..", legend="..", caption="..", summary="..", heading="..", subtitle="..", subheading="..", placeholder='..'
    #
    # Em vez de bloquear atributos tecnicos (lookbehind),
    # explicitamente APLICAMOS apenas em atributos UI conhecidos.
    # Atributos tecnicos como type=, name=, id=, class=, bind:, on:, use:
    # NUNCA serao tocados.

    printf '%s\0' "${TARGET_FILES[@]}" | xargs -0 sed -i \
        -e "s/>${en_esc}</>${pt_esc}</g" \
        -e "s/aria-label=\"${en_esc}\"/aria-label=\"${pt_esc}\"/g" \
        -e "s/aria-description=\"${en_esc}\"/aria-description=\"${pt_esc}\"/g" \
        -e "s/aria-placeholder=\"${en_esc}\"/aria-placeholder=\"${pt_esc}\"/g" \
        -e "s/aria-valuetext=\"${en_esc}\"/aria-valuetext=\"${pt_esc}\"/g" \
        -e "s/aria-roledescription=\"${en_esc}\"/aria-roledescription=\"${pt_esc}\"/g" \
        -e "s/title=\"${en_esc}\"/title=\"${pt_esc}\"/g" \
        -e "s/placeholder=\"${en_esc}\"/placeholder=\"${pt_esc}\"/g" \
        -e "s/alt=\"${en_esc}\"/alt=\"${pt_esc}\"/g" \
        -e "s/label=\"${en_esc}\"/label=\"${pt_esc}\"/g" \
        -e "s/description=\"${en_esc}\"/description=\"${pt_esc}\"/g" \
        -e "s/text=\"${en_esc}\"/text=\"${pt_esc}\"/g" \
        -e "s/message=\"${en_esc}\"/message=\"${pt_esc}\"/g" \
        -e "s/tooltip=\"${en_esc}\"/tooltip=\"${pt_esc}\"/g" \
        -e "s/confirmText=\"${en_esc}\"/confirmText=\"${pt_esc}\"/g" \
        -e "s/cancelText=\"${en_esc}\"/cancelText=\"${pt_esc}\"/g" \
        -e "s/submitText=\"${en_esc}\"/submitText=\"${pt_esc}\"/g" \
        -e "s/helperText=\"${en_esc}\"/helperText=\"${pt_esc}\"/g" \
        -e "s/helpText=\"${en_esc}\"/helpText=\"${pt_esc}\"/g" \
        -e "s/errorMessage=\"${en_esc}\"/errorMessage=\"${pt_esc}\"/g" \
        -e "s/successMessage=\"${en_esc}\"/successMessage=\"${pt_esc}\"/g" \
        -e "s/warningMessage=\"${en_esc}\"/warningMessage=\"${pt_esc}\"/g" \
        -e "s/legend=\"${en_esc}\"/legend=\"${pt_esc}\"/g" \
        -e "s/caption=\"${en_esc}\"/caption=\"${pt_esc}\"/g" \
        -e "s/heading=\"${en_esc}\"/heading=\"${pt_esc}\"/g" \
        -e "s/subtitle=\"${en_esc}\"/subtitle=\"${pt_esc}\"/g"

    # Para strings em codigo TS/JS:
    # 1. Strings literais em contexto de propriedade: label: "EN" -> label: "PT"
    # 2. Strings em chamadas: toast.x("EN"), throw new Error("EN"), etc
    # Aplicar SOMENTE quando precedidas de espaco/(/,/:/= e seguidas de ),;,], etc
    # Isso evita matches em meio a outras strings.
    printf '%s\0' "${TARGET_FILES[@]}" | xargs -0 sed -i \
        -e "s/\\([(,:= 	]\\)\"${en_esc}\"\\([),;\\.]\\)/\\1\"${pt_esc}\"\\2/g" \
        -e "s/\\([(,:= 	]\\)'${en_esc}'\\([),;\\.]\\)/\\1'${pt_esc}'\\2/g"

    count=$((count + 1))
done < "$TRANSLATIONS_FILE"

echo "Concluido. $count traducoes aplicadas."
