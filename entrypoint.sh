#!/bin/bash
set -e

# Setup datasets
/setup-datasets.sh

# Load Turtle data into TDB2 databases
DATA_DIR="/data"
FUSEKI_HOME="/opt/fuseki"
TDBLOADER="${FUSEKI_HOME}/bin/tdb2.tdbloader"

# Find all endpoint directories
ENDPOINTS=$(find "${DATA_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

for ENDPOINT in ${ENDPOINTS}; do
    DB_DIR="/fuseki-base/databases/${ENDPOINT}"
    TURTLE_FILES=$(find "${DATA_DIR}/${ENDPOINT}" -name "*.ttl")
    
    if [ -n "${TURTLE_FILES}" ]; then
        echo "Loading data for ${ENDPOINT}..."
        ${TDBLOADER} --loc="${DB_DIR}" ${TURTLE_FILES}
        echo "Data loaded for ${ENDPOINT}"
    fi
done

# Start Fuseki
echo "Starting Fuseki server..."
exec "${FUSEKI_HOME}/fuseki-server" --config="${FUSEKI_CONFIG}"