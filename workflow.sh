#!/bin/bash

set -e

echo "Toxic Repos Translation Workflow for CI/CD"
echo "=============================================="

USE_DOCKER=true
SKIP_LIBRETRANSLATE_START=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --pipx)
            USE_DOCKER=false
            shift
            ;;
        --docker)
            USE_DOCKER=true
            shift
            ;;
        --skip-libretranslate-start)
            SKIP_LIBRETRANSLATE_START=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--pipx|--docker] [--skip-libretranslate-start]"
            echo "  --pipx                      Use pipx for LibreTranslate (default: docker)"
            echo "  --docker                    Use Docker for LibreTranslate"
            echo "  --skip-libretranslate-start Skip starting LibreTranslate (assume it's running)"
            echo "  --help                      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [[ ! -f "./data/csv/toxic-repos.csv" ]]; then
    echo "Original data not found at ./data/csv/toxic-repos.csv"
    echo "Please ensure you have the original data available"
    exit 1
fi

echo ""
echo "Original data found:"
original_lines=$(wc -l < "./data/csv/toxic-repos.csv")
echo "  Lines: $((original_lines - 1)) records (+ 1 header)"

if [[ "$SKIP_LIBRETRANSLATE_START" == "false" ]]; then
    echo ""
    echo "Starting LibreTranslate..."
    
    if [[ "$USE_DOCKER" == "true" ]]; then
        echo "Using Docker for LibreTranslate..."
        
        if ! command -v docker &> /dev/null; then
            echo "Docker is not available"
            echo "Install Docker or use --pipx flag"
            exit 1
        fi
        
        echo "Starting LibreTranslate Docker container in background..."
        docker run -d --name libretranslate-temp -p 5000:5000 libretranslate/libretranslate --load-only en,ru
        
        echo "Waiting for LibreTranslate to be ready..."
        for i in {1..30}; do
            if curl -s "http://127.0.0.1:5000/languages" > /dev/null; then
                echo "LibreTranslate is ready"
                break
            fi
            echo "  Waiting... ($i/30)"
            sleep 2
        done
        
        if ! curl -s "http://127.0.0.1:5000/languages" > /dev/null; then
            echo "LibreTranslate failed to start"
            docker logs libretranslate-temp
            docker rm -f libretranslate-temp
            exit 1
        fi
        
    else
        echo "Using pipx for LibreTranslate..."
        
        ./scripts/libretranslate.sh --pipx &
        LIBRETRANSLATE_PID=$!
        
        echo "Waiting for LibreTranslate to be ready..."
        for i in {1..30}; do
            if curl -s "http://127.0.0.1:5000/languages" > /dev/null; then
                echo "LibreTranslate is ready"
                break
            fi
            echo "  Waiting... ($i/30)"
            sleep 2
        done
        
        if ! curl -s "http://127.0.0.1:5000/languages" > /dev/null; then
            echo "LibreTranslate failed to start"
            kill $LIBRETRANSLATE_PID 2>/dev/null || true
            exit 1
        fi
    fi
else
    echo ""
    echo "Skipping LibreTranslate startup (assuming it's already running)"
    
    if ! curl -s "http://127.0.0.1:5000/languages" > /dev/null; then
        echo "LibreTranslate is not running at http://127.0.0.1:5000"
        echo "Please start LibreTranslate or remove --skip-libretranslate-start flag"
        exit 1
    fi
    echo "LibreTranslate is running"
fi

echo ""
echo "Starting translation process..."
./scripts/translate.sh

if [[ "$SKIP_LIBRETRANSLATE_START" == "false" ]]; then
    echo ""
    echo "Cleaning up LibreTranslate..."
    
    if [[ "$USE_DOCKER" == "true" ]]; then
        docker rm -f libretranslate-temp
        echo "Docker container removed"
    else
        kill $LIBRETRANSLATE_PID 2>/dev/null || true
        echo "LibreTranslate process terminated"
    fi
fi

echo ""
echo "Translation workflow completed!"
echo ""
echo "Generated files:"
if [[ -f "./data-en/csv/toxic-repos.csv" ]]; then
    translated_lines=$(wc -l < "./data-en/csv/toxic-repos.csv")
    echo "  - ./data-en/csv/toxic-repos.csv ($((translated_lines - 1)) records)"
fi
if [[ -f "./data-en/json/toxic-repos.json" ]]; then
    echo "  - ./data-en/json/toxic-repos.json"
fi
if [[ -f "./data-en/sqlite/toxic-repos.sqlite3" ]]; then
    echo "  - ./data-en/sqlite/toxic-repos.sqlite3"
fi

echo ""
echo "Workflow completed successfully!"