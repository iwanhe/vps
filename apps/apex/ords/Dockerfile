FROM eclipse-temurin:21-jre

ARG ORDS_URL=https://download.oracle.com/otn_software/java/ords/ords-latest.zip
ARG APEX_URL=https://download.oracle.com/otn_software/apex/apex-latest.zip

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN curl -fsSL "$ORDS_URL" -o ords.zip \
    && unzip -q ords.zip -d /opt/ords \
    && rm -f ords.zip \
    && chmod +x /opt/ords/bin/ords

# Only the images/ folder is served at runtime (APEX static resources);
# the rest of the distribution isn't needed in this container.
RUN curl -fsSL "$APEX_URL" -o apex.zip \
    && unzip -q apex.zip 'apex/images/*' -d /opt \
    && rm -f apex.zip

ENV PATH="/opt/ords/bin:${PATH}"

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/opt/entrypoint.sh"]
