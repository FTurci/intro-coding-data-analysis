#!/bin/bash

SOURCE_DIR="."
DEST_DIR="quarto"

# Ensure quarto exists
if ! command -v quarto &>/dev/null; then
    echo "Error: Quarto is not installed or in PATH"
    exit 1
fi

mkdir -p "$DEST_DIR"

copied_count=0
converted_count=0
links_fixed=0

echo "Looking for numerical folders..."

for folder in "$SOURCE_DIR"/*; do
    if [ -d "$folder" ] && [ "$folder" != "./quarto" ]; then
        folder_name=$(basename "$folder")
        if [[ "$folder_name" =~ ^[0-9]+$ ]]; then
            echo "Found: $folder_name"

            # Ensure target folder exists
            mkdir -p "$DEST_DIR/$folder_name"

            for notebook in "$folder"/*.ipynb; do
                [ -f "$notebook" ] || continue

                base_name=$(basename "$notebook" .ipynb)
                qmd_file="$DEST_DIR/$folder_name/$base_name.qmd"

                # Convert only if qmd is missing or older than ipynb
                if [ ! -f "$qmd_file" ] || [ "$notebook" -nt "$qmd_file" ]; then
                    echo "  Converting: $base_name.ipynb → $base_name.qmd"
                    if quarto convert "$notebook" --output "$qmd_file" 2>/dev/null; then
                        ((converted_count++))
                        echo "    ✓ Converted"

                        # Fix links
                        sed -i.bak 's/\.ipynb)/\.qmd)/g; s/\.ipynb#/\.qmd#/g' "$qmd_file" \
                          && rm "$qmd_file.bak"
                        ((links_fixed++))

                        # Remove ipynb copy from destination if it slipped in
                        rm -f "$DEST_DIR/$folder_name/$base_name.ipynb"
                    else
                        echo "    ✗ Failed to convert $base_name.ipynb"
                    fi
                else
                    echo "  Skipping $base_name.ipynb (no changes)"
                fi
            done
        fi
    fi
done

# Replace {python} → {pyodide} in all qmds under quarto
find "$DEST_DIR" -name "*.qmd" -exec sed -i '' 's/{python}/{pyodide}/g' {} +

#add caption
find . -name "*.qmd" -exec perl -i -pe 's/{pyodide}/{pyodide}\n#| caption: "▶ Ctrl\/Cmd+Enter | ⇥ Ctrl\/Cmd+] | ⇤ Ctrl\/Cmd+\["/g' {} +
echo ""
echo "Summary:"
echo "- Converted: $converted_count notebooks"
echo "- Links fixed: $links_fixed"
