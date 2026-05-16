# Demo-hub in-cluster endpoints (source in an interactive shell: . /etc/profile.d/demo-hub-tools.sh)
export DEMO_HUB_NS="${DEMO_HUB_NS:-demo-hub}"
export DEMO_HUB_PG="postgresql://demo:demopass@postgresql-primary.${DEMO_HUB_NS}.svc.cluster.local:5432/demo"
export DEMO_HUB_REDIS="redis://:demoredispass@redis.${DEMO_HUB_NS}.svc.cluster.local:6379/0"
export DEMO_HUB_MONGO="mongodb://mongo-mongos1.${DEMO_HUB_NS}.svc.cluster.local:27017/"
export DEMO_HUB_CASSANDRA="cassandra-0.cassandra-headless.${DEMO_HUB_NS}.svc.cluster.local"
export DEMO_HUB_OPENSEARCH="http://opensearch.${DEMO_HUB_NS}.svc.cluster.local:9200"
export DEMO_HUB_ORACLE="demo/demopass@//oracle.${DEMO_HUB_NS}.svc.cluster.local:1521/FREEPDB1"
export OS_URL="${DEMO_HUB_OPENSEARCH}"

# Oracle SQL*Net (ora2pg / DBD::Oracle) — tnsnames.ora aliases: DEMO_ORACLE, FREEPDB1
export TNS_ADMIN="${TNS_ADMIN:-/etc/oracle/network/admin}"
export ORACLE_HOME="${ORACLE_HOME:-/opt/oracle/dbhome}"
export ORA2PG_CONFIG="${ORA2PG_CONFIG:-/etc/ora2pg/ora2pg.conf}"
export LD_LIBRARY_PATH="${ORACLE_HOME}/lib:${LD_LIBRARY_PATH:-}"

alias demo-psql='psql "$DEMO_HUB_PG"'
alias demo-redis='redis-cli -u "$DEMO_HUB_REDIS"'
alias demo-mongosh='mongosh "$DEMO_HUB_MONGO"'
alias demo-cqlsh='cqlsh "$DEMO_HUB_CASSANDRA" 9042'
alias demo-os-health='curl -s "${DEMO_HUB_OPENSEARCH}/_cluster/health?pretty"'
alias demo-ora2pg-check='/usr/local/bin/demo-ora2pg-check.sh'
alias demo-ora2pg-version='ora2pg -t SHOW_VERSION -c "$ORA2PG_CONFIG"'
alias demo-ora2pg-tables='ora2pg -t SHOW_TABLE -c "$ORA2PG_CONFIG"'
