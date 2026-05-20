# Custom PostgreSQL + PostGIS image for KerjaDekat Kubernetes deployment.
# Extends the official postgis image to add init scripts.
FROM postgis/postgis:17-3.5

LABEL maintainer="KerjaDekat Engineering"
LABEL description="PostgreSQL 17 with PostGIS 3.5 — Kubernetes ready"

# Copy init script that enables PostGIS extensions after DB creation.
# The /docker-entrypoint-initdb.d/ directory is executed on first boot.
COPY init-postgis.sh /docker-entrypoint-initdb.d/01-init-postgis.sh
RUN chmod +x /docker-entrypoint-initdb.d/01-init-postgis.sh

EXPOSE 5432
