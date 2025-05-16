FROM alpine:3.19

# Install Java, wget, and other dependencies in a single layer
RUN apk add --no-cache openjdk17-jre wget bash

# Set Fuseki version and install directory
ENV FUSEKI_VERSION=4.10.0
ENV FUSEKI_HOME=/fuseki
ENV FUSEKI_BASE=/fuseki-data
ENV JAVA_OPTS="-Xmx512m"

# Create directories first
RUN mkdir -p ${FUSEKI_HOME} /fuseki-data/databases /fuseki-data/configuration /app

WORKDIR /app

# Download and extract Fuseki directly (no separate layer)
RUN wget -q -O fuseki.tar.gz https://repo.maven.apache.org/maven2/org/apache/jena/apache-jena-fuseki/${FUSEKI_VERSION}/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz && \
    tar -xzf fuseki.tar.gz -C ${FUSEKI_HOME} --strip-components=1 && \
    rm fuseki.tar.gz

# Copy your datasets directory
COPY datasets/ /app/datasets/

# Create a simple configuration file
RUN echo '@prefix :      <#> .\n\
@prefix fuseki: <http://jena.apache.org/fuseki#> .\n\
@prefix rdf:   <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n\
@prefix rdfs:  <http://www.w3.org/2000/01/rdf-schema#> .\n\
@prefix tdb2:  <http://jena.hpl.hp.com/2016/tdb#> .\n\
\n\
[] rdf:type fuseki:Server .\n' > /app/config.ttl

# Create a startup script that will process datasets and start Fuseki
RUN echo '#!/bin/bash\n\
# Process each dataset directory\n\
for ENDPOINT in $(ls /app/datasets); do\n\
  if [ -d "/app/datasets/$ENDPOINT" ]; then\n\
    echo "Configuring endpoint: $ENDPOINT"\n\
    \n\
    # Create database directory\n\
    DB_PATH="/fuseki-data/databases/$ENDPOINT"\n\
    mkdir -p $DB_PATH\n\
    \n\
    # Add the service configuration for this endpoint\n\
    cat >> /app/config.ttl << EOT\n\
\n\
# Service for $ENDPOINT\n\
<#service_$ENDPOINT> rdf:type fuseki:Service ;\n\
    fuseki:name "$ENDPOINT" ;\n\
    fuseki:endpoint [ fuseki:operation fuseki:query ] ;\n\
    fuseki:endpoint [ fuseki:operation fuseki:update ] ;\n\
    fuseki:endpoint [ fuseki:operation fuseki:gsp-r ] ;\n\
    fuseki:endpoint [ fuseki:operation fuseki:gsp-rw ] ;\n\
    fuseki:dataset <#dataset_$ENDPOINT> .\n\
\n\
<#dataset_$ENDPOINT> rdf:type tdb2:DatasetTDB2 ;\n\
    tdb2:location "$DB_PATH" .\n\
\n\
EOT\n\
\n\
    # Load TTL files\n\
    for TTL_FILE in $(ls /app/datasets/$ENDPOINT/*.ttl 2>/dev/null); do\n\
      echo "Loading $TTL_FILE into $ENDPOINT dataset..."\n\
      java -jar /fuseki/tdb2.tdbloader --loc=$DB_PATH $TTL_FILE || echo "Warning: Could not load $TTL_FILE"\n\
    done\n\
  fi\n\
done\n\
\n\
echo "Configuration built. Starting Fuseki..."\n\
# Start Fuseki with the config\n\
exec java $JAVA_OPTS -jar /fuseki/fuseki-server.jar --config=/app/config.ttl\n' > /app/start.sh && \
    chmod +x /app/start.sh

# Expose the default Fuseki port
EXPOSE 3030

# Run the startup script
CMD ["/app/start.sh"]