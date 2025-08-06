import csv
import sys
import json
import urllib.request
import urllib.parse
import re
import time
import os
from pathlib import Path

def needs_translation(text):
    """Check if text contains Cyrillic characters"""
    if not text:
        return False
    return bool(re.search(r'[А-Яа-яЁё]', text))

def translate_text(text, source_lang="ru", target_lang="en", api_url="http://127.0.0.1:5000"):
    """Translate text using LibreTranslate API"""
    if not text or not needs_translation(text):
        return text
    
    try:
        url = f"{api_url}/translate"
        data = {
            "q": text,
            "source": source_lang,
            "target": target_lang
        }
        
        req = urllib.request.Request(
            url, 
            data=json.dumps(data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get('translatedText', text)
    except Exception as e:
        print(f"Translation error for '{text[:50]}...': {e}", file=sys.stderr)
        return text

def translate_csv(input_file, output_file, api_url="http://127.0.0.1:5000"):
    """Translate CSV file from Russian to English"""
    
    print(f"Processing CSV file: {input_file}")
    print(f"Output will be saved to: {output_file}")
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    translated_count = 0
    total_count = 0
    
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        
        # Process header
        header = next(reader)
        writer.writerow(header)
        print(f"CSV columns: {header}")
        
        for row_num, row in enumerate(reader, 1):
            total_count += 1
            print(f"Processing line {row_num}...")
            
            if len(row) >= 6:  # Ensure we have all expected columns
                # CSV structure: id,datetime,problem_type,name,commit_link,description,PURL-link,PURL
                # Translate fields: name (index 3), description (index 5)
                
                # Translate name field (index 3)
                if len(row) > 3 and needs_translation(row[3]):
                    original = row[3]
                    print(f"  Translating name: {original}")
                    row[3] = translate_text(original, api_url=api_url)
                    print(f"  Result: {row[3]}")
                    translated_count += 1
                
                # Translate description field (index 5)  
                if len(row) > 5 and needs_translation(row[5]):
                    original = row[5]
                    print(f"  Translating description: {original}")
                    row[5] = translate_text(original, api_url=api_url)
                    print(f"  Result: {row[5]}")
                    translated_count += 1
            
            writer.writerow(row)
            
            # Small delay to avoid overwhelming the API
            time.sleep(0.1)
    
    print(f"CSV processing completed!")
    print(f"Total rows processed: {total_count}")
    print(f"Fields translated: {translated_count}")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 translate.py <input_csv> <output_csv> [api_url]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    api_url = sys.argv[3] if len(sys.argv) > 3 else "http://127.0.0.1:5000"
    
    if not os.path.exists(input_file):
        print(f"Error: Input file {input_file} not found")
        sys.exit(1)
    
    # Test API connection
    try:
        urllib.request.urlopen(f"{api_url}/languages", timeout=5)
        print(f"LibreTranslate API is accessible at {api_url}")
    except Exception as e:
        print(f"Error: Cannot connect to LibreTranslate at {api_url}: {e}")
        sys.exit(1)
    
    translate_csv(input_file, output_file, api_url)

if __name__ == "__main__":
    main()