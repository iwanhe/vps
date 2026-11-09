FROM gvenzl/oracle-free:23-full-faststart

# Must stay on the "full" flavor: "slim" strips rdbms/xml and the XDK, which
# Oracle APEX's prerequisite check needs (XDB registers as INVALID without
# them, and the APEX install aborts before it starts).
ARG APEX_URL=https://download.oracle.com/otn_software/apex/apex-latest.zip

USER root
RUN curl -fsSL "$APEX_URL" -o /tmp/apex.zip \
    && unzip -q /tmp/apex.zip -d /opt \
    && rm -f /tmp/apex.zip \
    && chown -R oracle:oinstall /opt/apex
USER oracle

# Runs once on first startup: installs the APEX engine + sets the ADMIN password.
COPY --chown=oracle:oinstall apex-install.sh /container-entrypoint-initdb.d/10-apex-install.sh
RUN chmod +x /container-entrypoint-initdb.d/10-apex-install.sh
