#!/bin/bash
# Crear base de datos y usuario en PostgreSQL
# Ejecutar UNA VEZ en el servidor como root o postgres

DB_NAME="webhookbridge"
DB_USER="webhook"
DB_PASS="cambia-esta-password"

sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "Base de datos '$DB_NAME' creada. Actualiza DATABASE_URL en .env"
