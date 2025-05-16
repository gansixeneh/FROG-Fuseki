#!/bin/bash
set -e

# Setup datasets
/setup-datasets.sh

# Load Turtle data into TDB2 databases
DATA_DIR="/data"
JENA_HOME="/opt/jena"
FUSEKI_HOME="/opt/fuseki"

# Find all endpoint directories
ENDPOINTS=$(find "${DATA_DIR}" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

for ENDPOINT in ${ENDPOINTS}; do
    DB_DIR="/fuseki-base/databases/${ENDPOINT}"
    TURTLE_FILES=$(find "${DATA_DIR}/${ENDPOINT}" -name "*.ttl")
    
    if [ -n "${TURTLE_FILES}" ]; then
        echo "Loading data for ${ENDPOINT}..."
        # Create a temporary file with the list of TTL files
        TTL_LIST=$(mktemp)
        find "${DATA_DIR}/${ENDPOINT}" -name "*.ttl" > "${TTL_LIST}"
        
        # Use Jena's tdb2.tdbloader (trying multiple possible paths)
        if [ -x "${JENA_HOME}/bin/tdb2.tdbloader" ]; then
            "${JENA_HOME}/bin/tdb2.tdbloader" --loc="${DB_DIR}" @"${TTL_LIST}"
        elif [ -x "${FUSEKI_HOME}/bin/tdb2.tdbloader" ]; then
            "${FUSEKI_HOME}/bin/tdb2.tdbloader" --loc="${DB_DIR}" @"${TTL_LIST}"
        elif [ -x "${JENA_HOME}/bin/tdbloader2" ]; then
            "${JENA_HOME}/bin/tdbloader2" --loc="${DB_DIR}" @"${TTL_LIST}"
        elif command -v tdbloader > /dev/null; then
            tdbloader --loc="${DB_DIR}" @"${TTL_LIST}"
        else
            # Fallback to direct loading via Fuseki's SPARQL update endpoint
            echo "TDB loader not found. Will load data via SPARQL Update after server start."
            
            # Create a loading script to be executed after server start
            LOAD_SCRIPT="/tmp/load-data-${ENDPOINT}.sh"
            cat > "${LOAD_SCRIPT}" << EOF
#!/bin/bash
sleep 5 # Wait for Fuseki to start
echo "Loading data for ${ENDPOINT} via SPARQL update..."
for TTL_FILE in \$(cat ${TTL_LIST}); do
    echo "Loading \${TTL_FILE}..."
    curl -u admin:${FUSEKI_ADMIN_PASSWORD:-admin} -X POST -H "Content-Type: text/turtle" \
         --data-binary @"\${TTL_FILE}" \
         "http://localhost:3030/${ENDPOINT}/data?default"
done
EOF
            chmod +x "${LOAD_SCRIPT}"
            
            # Start this script in the background
            ${LOAD_SCRIPT} &
        fi
        
        rm "${TTL_LIST}"
        echo "Data loading process initiated for ${ENDPOINT}"
    fi
done

# Start Fuseki
echo "Starting Fuseki server..."
exec "${FUSEKI_HOME}/fuseki-server" --config="${FUSEKI_CONFIG}"