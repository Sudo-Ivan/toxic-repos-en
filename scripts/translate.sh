#!/bin/bash

set -e

LIBRETRANSLATE_URL="http://127.0.0.1:5000"
INPUT_CSV="./data/csv/toxic-repos.csv"
OUTPUT_CSV="./data-en/csv/toxic-repos.csv"
TEMP_DIR="/tmp/toxic-repos-translate"
TEMP_CSV="$TEMP_DIR/toxic-repos-temp.csv"

echo "Starting translation process..."
echo "Input: $INPUT_CSV"
echo "Output: $OUTPUT_CSV"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Check if input file exists
if [[ ! -f "$INPUT_CSV" ]]; then
    echo "Error: Input file $INPUT_CSV not found"
    echo "Please ensure the original data exists in ./data/csv/"
    exit 1
fi

# Check if LibreTranslate is running
if ! curl -s "$LIBRETRANSLATE_URL/languages" > /dev/null; then
    echo "Error: LibreTranslate is not running at $LIBRETRANSLATE_URL"
    echo "Please start LibreTranslate first by running: ./scripts/libretranslate.sh"
    exit 1
fi

# Function to detect if text needs translation (contains Cyrillic characters)
needs_translation() {
    local text="$1"
    # Check if text contains Cyrillic characters
    if [[ "$text" =~ [А-Яа-яЁё] ]]; then
        return 0  # true
    else
        return 1  # false
    fi
}

# Function to translate text
translate_text() {
    local text="$1"
    local source_lang="$2"
    local target_lang="$3"
    
    # Skip translation if text is empty, is a header, or doesn't need translation
    if [[ -z "$text" || "$text" == "description" || "$text" == "name" || "$text" == "commit_link" ]]; then
        echo "$text"
        return
    fi
    
    # Skip if text doesn't contain Cyrillic characters
    if ! needs_translation "$text"; then
        echo "$text"
        return
    fi
    
    # Use curl to call LibreTranslate API
    local response=$(curl -s -X POST "$LIBRETRANSLATE_URL/translate" \
        -H "Content-Type: application/json" \
        -d "{\"q\":\"$text\",\"source\":\"$source_lang\",\"target\":\"$target_lang\"}")
    
    # Extract translated text from JSON response
    local translated=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin)['translatedText'])" 2>/dev/null || echo "$text")
    echo "$translated"
}

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_CSV")"

echo "Processing CSV file: $INPUT_CSV"
echo "Output will be saved to: $OUTPUT_CSV"

# Copy original CSV to temp directory for processing
cp "$INPUT_CSV" "$TEMP_CSV"

# Read the CSV file line by line
{
    # Read header
    IFS= read -r header
    echo "$header" > "$TEMP_CSV.translated"
    
    line_count=1
    total_lines=$(wc -l < "$INPUT_CSV")
    
    while IFS= read -r line; do
        ((line_count++))
        echo "Processing line $line_count/$total_lines..."
        
        # Parse CSV fields (simple parsing - assumes no commas in quoted fields for this use case)
        IFS=',' read -ra FIELDS <<< "$line"
        
        # Translate multiple fields that might contain Russian text
        # Field 3: name, Field 4: commit_link, Field 5: description
        
        # Translate name field (index 3)
        if [[ ${#FIELDS[@]} -gt 3 ]]; then
            name="${FIELDS[3]}"
            # Remove quotes if present
            name="${name#\"}"
            name="${name%\"}"
            
            if needs_translation "$name"; then
                echo "  Translating name: $name"
                translated_name=$(translate_text "$name" "ru" "en")
                echo "  Result: $translated_name"
                FIELDS[3]="\"$translated_name\""
            fi
        fi
        
        # Translate commit_link field (index 4) - might contain Russian text in URLs or descriptions
        if [[ ${#FIELDS[@]} -gt 4 ]]; then
            commit_link="${FIELDS[4]}"
            # Remove quotes if present
            commit_link="${commit_link#\"}"
            commit_link="${commit_link%\"}"
            
            if needs_translation "$commit_link"; then
                echo "  Translating commit_link: $commit_link"
                translated_commit_link=$(translate_text "$commit_link" "ru" "en")
                echo "  Result: $translated_commit_link"
                FIELDS[4]="\"$translated_commit_link\""
            fi
        fi
        
        # Translate description field (index 5)
        if [[ ${#FIELDS[@]} -gt 5 ]]; then
            description="${FIELDS[5]}"
            # Remove quotes if present
            description="${description#\"}"
            description="${description%\"}"
            
            if needs_translation "$description"; then
                echo "  Translating description: $description"
                translated_desc=$(translate_text "$description" "ru" "en")
                echo "  Result: $translated_desc"
                FIELDS[5]="\"$translated_desc\""
            fi
        fi
        
        output_line=""
        for i in "${!FIELDS[@]}"; do
            if [[ $i -eq 0 ]]; then
                output_line="${FIELDS[i]}"
            else
                output_line="${output_line},${FIELDS[i]}"
            fi
        done
        echo "$output_line" >> "$TEMP_CSV.translated"
        
        # Add a small delay to avoid overwhelming the API
        sleep 0.1
    done
} < "$INPUT_CSV"

# Create output directory
mkdir -p "$(dirname "$OUTPUT_CSV")"

# Move translated CSV to final location
mv "$TEMP_CSV.translated" "$OUTPUT_CSV"

echo "Translation completed! Translated CSV saved to: $OUTPUT_CSV"

# Convert to other formats using the Python script
if [[ -f "./scripts/convert_database_to_other_formats.py" ]]; then
    echo "Converting translated CSV to JSON and SQLite formats..."
    
    # Run the conversion script with the translated CSV as input
    python3 ./scripts/convert_database_to_other_formats.py "$OUTPUT_CSV" "./data-en/"
    
    echo "All formats created in data-en directory:"
    echo "  - CSV: ./data-en/csv/toxic-repos.csv"
    echo "  - JSON: ./data-en/json/toxic-repos.json"
    echo "  - SQLite: ./data-en/sqlite/toxic-repos.sqlite3"
else
    echo "Warning: convert_database_to_other_formats.py not found, only CSV format created"
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"
echo "Cleanup completed."