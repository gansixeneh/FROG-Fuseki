#!/bin/bash

CONFIG_FILE="/fuseki-data/configuration/config.ttl"
DATASETS_DIR="/fuseki-data/datasets"

echo "Starting Fuseki setup process..."

# Copy the template as the base
cp /app/config-template.ttl $CONFIG_FILE
echo "Created base configuration from template"

# Check if datasets directory exists and has contents
if [ -d "$DATASETS_DIR" ] && [ "$(ls -A $DATASETS_DIR 2>/dev/null)" ]; then
  # For each directory in the datasets folder, create a dataset
  for ENDPOINT in $(ls $DATASETS_DIR); do
    if [ -d "$DATASETS_DIR/$ENDPOINT" ]; then
      echo "Processing dataset: $ENDPOINT"
      
      # Create TDB2 database directory
      DB_PATH="/fuseki-data/databases/$ENDPOINT"
      mkdir -p $DB_PATH
      echo "Created database directory: $DB_PATH"
      
      # Check if there are TTL files to load
      TTL_FILES=$(ls $DATASETS_DIR/$ENDPOINT/*.ttl 2>/dev/null)
      if [ -n "$TTL_FILES" ]; then
        # Load TTL files into the TDB2 database
        for TTL_FILE in $TTL_FILES; do
          echo "Loading $TTL_FILE into $ENDPOINT dataset..."
          # Pass JAVA_OPTS to the tdbloader command
          JAVA_OPTS="$JAVA_OPTS" /fuseki/tdb2.tdbloader --loc=$DB_PATH $TTL_FILE
          LOADER_RESULT=$?
          if [ $LOADER_RESULT -ne 0 ]; then
            echo "WARNING: Loading $TTL_FILE returned non-zero exit code: $LOADER_RESULT"
            # Continue anyway, as we want the server to start even if some data fails to load
          fi
        done
      else
        echo "No TTL files found for dataset $ENDPOINT, creating empty dataset"
      fi
      
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
      echo "Added configuration for dataset: $ENDPOINT"
    fi
  done
else
  echo "No datasets found. Creating a default empty dataset for testing."
  # Create a default dataset for healthcheck to pass
  DEFAULT_DB_PATH="/fuseki-data/databases/default"
  mkdir -p $DEFAULT_DB_PATH
  
  # Add a default dataset configuration
  cat >> $CONFIG_FILE << EOT

:service_default rdf:type fuseki:Service ;
    fuseki:name "default" ;
    fuseki:endpoint [ fuseki:operation fuseki:query ] ;
    fuseki:endpoint [ fuseki:operation fuseki:update ] ;
    fuseki:endpoint [ fuseki:operation fuseki:gsp-r ] ;
    fuseki:endpoint [ fuseki:operation fuseki:gsp-rw ] ;
    fuseki:dataset :dataset_default .

:dataset_default rdf:type tdb2:DatasetTDB2 ;
    tdb2:location "$DEFAULT_DB_PATH" .
EOT
  echo "Created default empty dataset configuration"
fi

echo "Starting Fuseki server with configuration: $CONFIG_FILE"
# Start Fuseki server with the generated configuration and JAVA_OPTS
# The exec ensures proper signal handling
exec env JAVA_OPTS="$JAVA_OPTS" /fuseki/fuseki-server --config=$CONFIG_FILE