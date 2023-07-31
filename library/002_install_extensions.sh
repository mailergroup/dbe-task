#!/bin/sh

cat <<EOT >> ${PGDATA}/postgresql.conf
shared_preload_libraries='pg_cron,pg_stat_statements'
cron.database_name='${POSTGRES_DB}'
EOT

# Required to load pg_cron
pg_ctl restart