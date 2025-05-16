#!/bin/bash

CONFIG_FILE="/fuseki-data/configuration/config.ttl"
DATASETS_DIR="/fuseki-data/datasets"

# Copy the template as the base
cp /app/config-template.ttl $CONFIG_FILE

# For each directory in the datasets folder, create a dataset
for ENDPOINT in $(ls $DATASETS_DIR); do
  if [ -d "$DATASETS_DIR/$ENDPOINT" ]; then
    # Create TDB2 database directory
    DB_PATH="/fuseki-data/databases/$ENDPOINT"
    mkdir -p $DB_PATH
    
    # Load TTL files into the TDB2 database
    for TTL_FILE in $(ls $DATASETS_DIR/$ENDPOINT/*.ttl 2>/dev/null); do
      echo "Loading $TTL_FILE into $ENDPOINT dataset..."
      # Pass JAVA_OPTS to the tdbloader command
      JAVA_OPTS="$JAVA_OPTS" /fuseki/tdb2.tdbloader --loc=$DB_PATH $TTL_FILE
    done
    
    # Add dataset configuration to the config file
    cat >> $CONFIG_FILE << EOT

:service_$ENDPOINT rdf:type fuseki:Service ;
    fuseki:name "$ENDPOINT" ;
    fuseki:endpoint [ fuseki:operation fuseki:query ] ;
    fuseki:endpoint [ fuseki:operation fuseki:update ] ;
    fuseki:endpoint [ fuseki:operation fuseki:gsp-r ] ;
    fuseki:endpoint [ fuseki:operation fuseki:gsp-rw ] ;
    fuseki:dataset :dataset_$ENDPOINT .

:dataset_$ENDPOINT rdf:type tdb2:DatasetTDB2 ;
    tdb2:location "$DB_PATH" .
EOT
  fi
done

# Start Fuseki server with the generated configuration and JAVA_OPTS
# The exec ensures proper signal handling
exec env JAVA_OPTS="$JAVA_OPTS" /fuseki/fuseki-server --config=$CONFIG_FILE