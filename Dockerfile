FROM eclipse-temurin:17-jre-jammy

# Install wget for downloads
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Set Fuseki version and install directory
ENV FUSEKI_VERSION=4.10.0
ENV FUSEKI_HOME=/fuseki
ENV FUSEKI_BASE=/fuseki-data
ENV JAVA_OPTS="-Xmx512m -Dlog4j.configurationFile=file:///fuseki/log4j2.properties"

# Download and extract Fuseki
RUN wget -O fuseki.tar.gz https://repo.maven.apache.org/maven2/org/apache/jena/apache-jena-fuseki/${FUSEKI_VERSION}/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz && \
    mkdir -p ${FUSEKI_HOME} && \
    tar -xf fuseki.tar.gz -C ${FUSEKI_HOME} --strip-components=1 && \
    rm fuseki.tar.gz

WORKDIR /app

# Create directories
RUN mkdir -p /fuseki-data/databases /fuseki-data/configuration

# Copy your datasets and scripts
COPY datasets/ /app/datasets/
COPY build-config.sh /app/
RUN chmod +x /app/build-config.sh

# Build the configuration
RUN /app/build-config.sh

# Expose the default Fuseki port
EXPOSE 3030

# Create a wrapper script for startup
RUN echo '#!/bin/bash\njava $JAVA_OPTS -jar /fuseki/fuseki-server.jar --config=/app/config.ttl' > /app/start.sh && \
    chmod +x /app/start.sh

# Run using the wrapper script 
CMD ["/app/start.sh"]