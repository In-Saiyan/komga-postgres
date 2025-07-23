# Multi-stage build following official Dockerfile.tpl pattern
# Stage 1: Build the application (following release.yml build process)
FROM eclipse-temurin:21-jdk AS app-builder

WORKDIR /app

# Copy gradle wrapper and build files
COPY gradlew gradlew.bat ./
COPY gradle/ gradle/
COPY settings.gradle build.gradle.kts ./
COPY gradle.properties conventionalcommit.json ./

# Copy .git directory for git properties generation
COPY .git/ .git/

# Copy all source code
COPY komga/ komga/
COPY komga-tray/ komga-tray/
COPY komga-webui/ komga-webui/

# Install Node.js and PostgreSQL for frontend build and JOOQ schema generation
RUN apt-get update && \
    apt-get install -y curl dos2unix postgresql postgresql-contrib sudo git && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Setup PostgreSQL for JOOQ schema generation
RUN service postgresql start && \
    sudo -u postgres psql -c "CREATE USER komga WITH PASSWORD 'komga_password' SUPERUSER;" && \
    sudo -u postgres createdb -O komga komga && \
    sudo -u postgres createdb -O komga komga_tasks

# Build the application (following release.yml build commands)
# JOOQ needs PostgreSQL to generate correct schema
RUN dos2unix gradlew
RUN chmod +x gradlew
RUN ls -la gradlew
RUN service postgresql start && \
    ./gradlew :komga:prepareThymeLeaf :komga:bootJar -x test
ENV NODE_OPTIONS="--max-old-space-size=8192"

# Stage 2: Extract jar layers (following official Dockerfile.tpl)
FROM eclipse-temurin:21-jre AS builder
WORKDIR /builder
COPY --from=app-builder /app/komga/build/libs/komga-*.jar application.jar
RUN java -Djarmode=tools -jar application.jar extract --layers --destination extracted

# amd64 runtime stage (following official Dockerfile.tpl)
FROM ubuntu:25.04 AS build-amd64
ENV JAVA_HOME=/opt/java/openjdk
COPY --from=eclipse-temurin:23-jre $JAVA_HOME $JAVA_HOME
ENV PATH="${JAVA_HOME}/bin:${PATH}"
RUN apt -y update && \
    apt -y install ca-certificates locales libjxl-dev libheif-dev libwebp-dev libarchive-dev wget curl && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    wget "https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-64bit" -O /usr/bin/kepubify && \
    chmod +x /usr/bin/kepubify && \
    apt -y autoremove && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu"

# # arm64 runtime stage (following official Dockerfile.tpl)
# FROM ubuntu:25.04 AS build-arm64
# ENV JAVA_HOME=/opt/java/openjdk
# COPY --from=eclipse-temurin:23-jre $JAVA_HOME $JAVA_HOME
# ENV PATH="${JAVA_HOME}/bin:${PATH}"
# RUN apt -y update && \
#     apt -y install ca-certificates locales libjxl-dev libheif-dev libwebp-dev libarchive-dev wget curl && \
#     echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
#     locale-gen en_US.UTF-8 && \
#     wget "https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-arm64" -O /usr/bin/kepubify && \
#     chmod +x /usr/bin/kepubify && \
#     apt -y autoremove && rm -rf /var/lib/apt/lists/*
# ENV LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu"

# # arm runtime stage (following official Dockerfile.tpl)
# FROM eclipse-temurin:21-jre AS build-arm
# RUN apt -y update && \
#     apt -y install wget curl && \
#     wget "https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-arm" -O /usr/bin/kepubify && \
#     chmod +x /usr/bin/kepubify && \
#     apt -y autoremove && rm -rf /var/lib/apt/lists/*

# Final runtime stage (following official Dockerfile.tpl)
FROM build-amd64 AS runner
VOLUME /tmp
VOLUME /config
WORKDIR /app
COPY --from=builder /builder/extracted/dependencies/ ./
COPY --from=builder /builder/extracted/spring-boot-loader/ ./
COPY --from=builder /builder/extracted/snapshot-dependencies/ ./
COPY --from=builder /builder/extracted/application/ ./
ENV KOMGA_CONFIGDIR="/config"
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENTRYPOINT ["java", "-Dspring.profiles.include=docker", "--enable-native-access=ALL-UNNAMED", "-jar", "application.jar", "--spring.config.additional-location=file:/config/"]
EXPOSE 25600

# Labels for image metadata
LABEL org.opencontainers.image.source="https://github.com/jindalpratik/komga"
LABEL org.opencontainers.image.version="postgresql-v2"
