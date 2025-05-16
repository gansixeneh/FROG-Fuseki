FROM openjdk:11-jre-slim

# Install wget to download Fuseki
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*

# Set Fuseki version and install directory
ENV FUSEKI_VERSION=4.10.0
ENV FUSEKI_HOME=/fuseki

# Download and extract Fuseki
RUN wget -O fuseki.tar.gz https://dlcdn.apache.org/jena/binaries/apache-jena-fuseki-${FUSEKI_VERSION}.tar.gz && \
    mkdir -p ${FUSEKI_HOME} && \
    tar -xf fuseki.tar.gz -C ${FUSEKI_HOME} --strip-components=1 && \
    rm fuseki.tar.gz

# Set working directory
WORKDIR /app

# Create directories for app, data and configuration
RUN mkdir -p /fuseki-data/configuration /fuseki-data/databases /fuseki-data/datasets

# Copy your config template, setup script, and datasets
COPY config-template.ttl ./
COPY setup.sh ./
COPY datasets/ /fuseki-data/datasets/

# Make the setup script executable
RUN chmod +x setup.sh

# Expose the default Fuseki port
EXPOSE 3030

# Run the setup script which will configure and start Fuseki
CMD ["./setup.sh"]