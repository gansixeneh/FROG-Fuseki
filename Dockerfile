FROM eclipse-temurin:17-jre-jammy

# Set environment variables
ENV FUSEKI_VERSION=5.4.0
ENV JENA_VERSION=5.4.0
ENV FUSEKI_HOME=/opt/fuseki
ENV JENA_HOME=/opt/jena
ENV FUSEKI_BASE=/fuseki-base
ENV FUSEKI_CONFIG=/fuseki-base/config.ttl
ENV PATH="${PATH}:${JENA_HOME}/bin:${FUSEKI_HOME}/bin"

# Install curl and cleanup
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and unpack Fuseki
RUN mkdir -p $FUSEKI_HOME && \
    curl -L https://dlcdn.apache.org/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz | \
    tar -xz --strip-components=1 -C $FUSEKI_HOME

# Download and unpack Jena tools (needed for tdbloader)
RUN mkdir -p $JENA_HOME && \
    curl -L https://dlcdn.apache.org/jena/binaries/apache-jena-$JENA_VERSION.tar.gz | \
    tar -xz --strip-components=1 -C $JENA_HOME

# Create directories
RUN mkdir -p $FUSEKI_BASE/databases $FUSEKI_BASE/configuration $FUSEKI_BASE/system_files

# Copy configuration files
COPY config/fuseki-config.ttl $FUSEKI_CONFIG
COPY config/shiro.ini $FUSEKI_HOME/shiro.ini

# Copy data and scripts
COPY data /data
COPY scripts/setup-datasets.sh /setup-datasets.sh
COPY scripts/entrypoint.sh /entrypoint.sh

# Set permissions
RUN chmod +x /setup-datasets.sh /entrypoint.sh

# Expose the default Fuseki port
EXPOSE 3030

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]