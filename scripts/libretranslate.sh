#!/bin/bash

set -e

USE_DOCKER=false
USE_PIPX=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --docker)
            USE_DOCKER=true
            USE_PIPX=false
            shift
            ;;
        --pipx)
            USE_PIPX=true
            USE_DOCKER=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--pipx|--docker]"
            echo "  --pipx    Install using pipx (default)"
            echo "  --docker  Install using Docker"
            echo "  --help    Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "Setting up LibreTranslate..."

if [ "$USE_DOCKER" = true ]; then
    echo "Using Docker installation method..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed."
        echo "Please install Docker first or use --pipx flag"
        exit 1
    fi
    
    # Pull LibreTranslate Docker image
    echo "Pulling LibreTranslate Docker image..."
    if docker pull libretranslate/libretranslate:latest; then
        echo "Successfully pulled LibreTranslate Docker image"
        
        echo "Starting LibreTranslate with Docker..."
        echo "LibreTranslate will be available at http://127.0.0.1:5000"
        echo "Press Ctrl+C to stop the server"
        
        docker run -it --rm -p 5000:5000 libretranslate/libretranslate --load-only en,ru
        exit 0
    else
        echo "Error: Failed to pull Docker image"
        exit 1
    fi
fi

if [ "$USE_PIPX" = true ]; then
    echo "Using pipx installation method..."
    
    # Check if pipx is installed
    if ! command -v pipx &> /dev/null; then
        echo "pipx not found. Installing pipx..."
        
        # Check if python3 is available
        if ! command -v python3 &> /dev/null; then
            echo "Error: python3 is required but not installed."
            echo "Please install python3 first."
            exit 1
        fi
        
        # Try to install pipx
        if command -v pip3 &> /dev/null; then
            pip3 install --user pipx
            export PATH="$HOME/.local/bin:$PATH"
        elif command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y pipx
        elif command -v yum &> /dev/null; then
            sudo yum install -y pipx
        elif command -v pacman &> /dev/null; then
            sudo pacman -S python-pipx
        else
            echo "Error: Could not install pipx automatically."
            echo "Please install pipx manually or use --docker flag"
            exit 1
        fi
        
        # Ensure pipx is in PATH
        pipx ensurepath
    fi
    
    echo "Installing LibreTranslate with pipx..."
    
    # Try installing with specific stable versions
    if pipx install libretranslate==1.3.11; then
        echo "Successfully installed LibreTranslate 1.3.11"
    elif pipx install libretranslate==1.4.2; then
        echo "Successfully installed LibreTranslate 1.4.2"
    else
        echo "Error: Failed to install LibreTranslate with pipx"
        echo "Try using --docker flag instead"
        exit 1
    fi
    
    echo "Starting LibreTranslate with English and Russian language support..."
    echo "LibreTranslate will be available at http://127.0.0.1:5000"
    echo "Press Ctrl+C to stop the server"
    
    libretranslate --load-only en,ru
fi