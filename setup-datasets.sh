#!/bin/bash
set -e

# Base directories
FUSEKI_CONFIG="${FUSEKI_CONFIG:-/fuseki-base/config.ttl}"
DATA_DIR="/data"
FUSEKI_BASE="/fuseki-base"
DATABASES_DIR="${FUSEKI_BASE}/databases"

# Ensure directories exist
mkdir -p "${DATABASES_DIR}"

# Create temporary config file
TMP_CONFIG="/tmp/fuseki-config.ttl"
cp "${FUSEKI_CONFIG}" "${TMP_CONFIG}"

# Find all endpoint directories
ENDPOINTS=$(find "${DATA_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

# Create service entries for each endpoint
SERVICES=""
for ENDPOINT in ${ENDPOINTS}; do
    echo "Setting up endpoint: ${ENDPOINT}"
    
    # Create database directory
    DB_DIR="${DATABASES_DIR}/${ENDPOINT}"
    mkdir -p "${DB_DIR}"
    
    # Add service configuration
    SERVICE_CONFIG=$(cat <<EOT

# Service for ${ENDPOINT}
:service_${ENDPOINT} rdf:type fuseki:Service ;
    rdfs:label "SPARQL Endpoint for ${ENDPOINT}" ;
    fuseki:name "${ENDPOINT}" ;
    fuseki:serviceQuery "query" ;
    fuseki:serviceQuery "sparql" ;
    fuseki:serviceUpdate "update" ;
    fuseki:serviceUpload "upload" ;
    fuseki:serviceReadWriteGraphStore "data" ;
    fuseki:serviceReadGraphStore "get" ;
    fuseki:dataset [
        rdf:type tdb2:DatasetTDB2 ;
        tdb2:location "${DB_DIR}" ;
    ] .
EOT
)
    echo "${SERVICE_CONFIG}" >> "${TMP_CONFIG}"
    
    # Add to services list
    if [ -z "${SERVICES}" ]; then
        SERVICES=":service_${ENDPOINT}"
    else
        SERVICES="${SERVICES} :service_${ENDPOINT}"
    fi
    
    # Import Turtle files
    TURTLE_FILES=$(find "${DATA_DIR}/${ENDPOINT}" -name "*.ttl")
    if [ -n "${TURTLE_FILES}" ]; then
        echo "Loading Turtle files for ${ENDPOINT}:"
        for TTL_FILE in ${TURTLE_FILES}; do
            echo "  - $(basename ${TTL_FILE})"
            # We'll load data using tdbloader in the entrypoint script
        done
    else
        echo "No Turtle files found for ${ENDPOINT}"
    fi
done

# Update services list in config
sed -i "s|fuseki:services (.*)|fuseki:services (${SERVICES}) .|" "${TMP_CONFIG}"

# Copy the final config to the right place
mv "${TMP_CONFIG}" "${FUSEKI_CONFIG}"

echo "Finished setting up datasets"