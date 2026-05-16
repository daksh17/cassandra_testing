# Client toolbox for demo-hub: SQL/NoSQL CLIs, curl, OpenSearch CLI, ora2pg + DBD::Oracle.
# Instant Client libs copied from the same Oracle Free image used by demo-hub (arm64 + amd64).
FROM gvenzl/oracle-free:23-full-faststart AS oracle-client

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PATH="/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget jq dnsutils netcat-openbsd unzip gnupg lsb-release \
    postgresql-client redis-tools perl cpanminus \
    libdbd-pg-perl libdbi-perl python3 python3-pip python3-venv \
    libaio1 libaio-dev libperl-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

# Oracle client from gvenzl/oracle-free dbhomeFree (full tree for DBD::Oracle link + headers)
COPY --from=oracle-client /opt/oracle/product/26ai/dbhomeFree /opt/oracle/dbhome
RUN ln -sfn /opt/oracle/dbhome /opt/oracle/instantclient

ENV ORACLE_HOME=/opt/oracle/dbhome
ENV LD_LIBRARY_PATH=/opt/oracle/dbhome/lib

RUN ldconfig /opt/oracle/dbhome/lib \
    && cpanm --notest DBD::Oracle

# ora2pg from upstream git (v25.0)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git perl make \
    libjson-perl libconfig-tiny-perl liblog-log4perl-perl \
    && git clone --depth 1 --branch v25.0 https://github.com/darold/ora2pg.git /tmp/ora2pg \
    && cd /tmp/ora2pg && perl Makefile.PL && make && make install \
    && rm -rf /tmp/ora2pg \
    && rm -rf /var/lib/apt/lists/*

# cqlsh (Cassandra)
RUN pip3 install --no-cache-dir 'cqlsh>=6.1.0'

# mongosh (MongoDB 7.x repo — jammy packages run on noble)
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
    | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg \
    && echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      > /etc/apt/sources.list.d/mongodb-org-7.0.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

# OpenSearch CLI (arch-specific)
ARG OPENSEARCH_CLI_VERSION=1.2.0
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      arm64) OS_ARCH=arm64 ;; \
      amd64) OS_ARCH=amd64 ;; \
      *) OS_ARCH=amd64 ;; \
    esac; \
    curl -fsSL "https://github.com/opensearch-project/opensearch-cli/releases/download/v${OPENSEARCH_CLI_VERSION}/opensearch-cli-${OPENSEARCH_CLI_VERSION}-linux-${OS_ARCH}.zip" \
      -o /tmp/opensearch-cli.zip; \
    unzip -q /tmp/opensearch-cli.zip -d /tmp; \
    mv /tmp/opensearch-cli /usr/local/bin/opensearch-cli; \
    chmod +x /usr/local/bin/opensearch-cli; \
    rm -rf /tmp/opensearch-cli.zip /tmp/opensearch-cli

COPY demo-hub-shell-env.sh /etc/profile.d/demo-hub-tools.sh
COPY oracle/network/admin/tnsnames.ora oracle/network/admin/sqlnet.ora /etc/oracle/network/admin/
COPY ora2pg/ora2pg.conf /etc/ora2pg/ora2pg.conf
COPY demo-ora2pg-check.sh /usr/local/bin/demo-ora2pg-check.sh
RUN chmod 644 /etc/profile.d/demo-hub-tools.sh \
    && chmod 644 /etc/oracle/network/admin/tnsnames.ora /etc/oracle/network/admin/sqlnet.ora \
    && chmod 644 /etc/ora2pg/ora2pg.conf \
    && chmod 755 /usr/local/bin/demo-ora2pg-check.sh

ENV TNS_ADMIN=/etc/oracle/network/admin \
    ORA2PG_CONFIG=/etc/ora2pg/ora2pg.conf

WORKDIR /demo-hub
CMD ["sleep", "infinity"]
