#!/bin/bash
# Ejecutar en el servidor ark10.es
# Requiere: Python 3.11+, PostgreSQL, Redis

set -e

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Virtualenv creado"
fi

source venv/bin/activate
pip install -r requirements.txt -q

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "ATENCION: Edita .env con tus datos antes de continuar"
    echo "  nano .env"
    exit 1
fi

uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
