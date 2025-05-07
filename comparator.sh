#!/bin/bash

# Vérifie les arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <ssh@source_dir> <ssh@target_dir> <output_csv_name>"
    echo "<output_csv_name> : Contient seulement le nom du CSV, sans l'extension"
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"
PROMPTED_CSV="$3"

# Formate l'output pour fluidifier l'utilisation du script
OUTPUT_CSV="."/"reports"/"$PROMPTED_CSV$(date +%F_%H:%M:%S).csv"

# Vérifie que rsync est disponible
if ! command -v rsync &> /dev/null; then
    echo "Erreur : rsync n'est pas installé."
    exit 1
fi

# Initialise le rapport CSV
echo "ChangeType,ChangeDetails,FilePath,Size(Bytes),ModDate,BirthDate" > "$OUTPUT_CSV"

# Exécution de rsync en dry-run pour détecter les différences
rsync -rvnci --delete "$TARGET_DIR"/ "$SOURCE_DIR"/ | while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^sending ]] && continue
    [[ "$line" =~ ^total ]] && continue
    if [[ "$line" =~ ^\*deleting\ (.+) ]]; then
        FILE="${BASH_REMATCH[1]}"
        FULL_PATH="$TARGET_DIR/$FILE"
        if [ -e "$FULL_PATH" ]; then
            SIZE=$(stat -f "%z" "$FULL_PATH")
            MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$FULL_PATH")
        else
            SIZE=0
            MOD_DATE="Deleted"
            BIRTH_DATE="Deleted"

        fi
        echo "Deleted,---------,\"$FILE\",$SIZE,\"$MOD_DATE\",\"$BIRTH_DATE\"" >> "$OUTPUT_CSV"

    elif [[ "$line" =~ ^([><ch\.]+)\ *(.+) ]]; then
        CODE="${BASH_REMATCH[1]}"
        FILE="${BASH_REMATCH[2]}"
        PARSED_FILE="${FILE:9}"
        PARSED_UPDATE="${FILE:0:9}"
        FULL_PATH="$SOURCE_DIR/$PARSED_FILE"
        echo $FULL_PATH
        if [ -e "$FULL_PATH" ]; then
            SIZE=$(stat -f "%z" "$FULL_PATH")
            MOD_DATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$FULL_PATH")
            BIRTH_DATE=$(stat -f "%w" -t "%Y-%m-%d %H:%M:%S" "$FULL_PATH")
        else
            SIZE="NAN"
            MOD_DATE="NAN"
            BIRTH_DATE="NAN"
        fi

        if [[ "$CODE" == *"+"* ]]; then
            CHANGE_TYPE="Added"
        else
            CHANGE_TYPE="Modified"
        fi

        echo "$CHANGE_TYPE,$PARSED_UPDATE,\"$PARSED_FILE\",\"$SIZE\",\"$MOD_DATE\",\"$BIRTH_DATE\"" >> "$OUTPUT_CSV"
    fi
done

echo "✅ Rapport généré dans $OUTPUT_CSV"
