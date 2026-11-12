#!/bin/bash

set -e

# openerp-server refuses to run as root.
if [ "$(id -u)" = "0" ]; then
    exec su -s /bin/bash odoo -c "exec /bin/bash /entrypoint.sh $(printf '%q ' "$@")"
fi

# Odoo 8 image (Debian Jessie, Python 2.7). Do not apt-get or pip3 here:
# Jessie mirrors are archived and the image has no Python 3.

# set the postgres database host, port, user and password according to the environment
# and pass them as arguments to the openerp process if not present in the config file
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

# Odoo 8 reads OPENERP_SERVER. Later versions use ODOO_RC=/etc/odoo/odoo.conf.
: ${OPENERP_SERVER:=/etc/odoo/openerp-server.conf}
export OPENERP_SERVER

# install extra Python 2 packages only when requirements.txt has real lines
if [ -f /etc/odoo/requirements.txt ] && grep -vE '^[[:space:]]*(#|$)' /etc/odoo/requirements.txt | grep -q .; then
    if command -v pip >/dev/null 2>&1; then
        pip install -r /etc/odoo/requirements.txt
    else
        echo "pip is not available in odoo:8.0; cannot install /etc/odoo/requirements.txt" >&2
        exit 1
    fi
fi

# logrotate is optional; the base image does not ship it and apt repos are dead
if command -v logrotate >/dev/null 2>&1 && [ -f /etc/odoo/logrotate ]; then
    cp /etc/odoo/logrotate /etc/logrotate.d/odoo
    if command -v cron >/dev/null 2>&1; then
        cron || true
    fi
fi

echo "Waiting for Postgres at ${HOST}:${PORT}..."
python - "$HOST" "$PORT" <<'PY'
import socket
import sys
import time

host = sys.argv[1]
port = int(sys.argv[2])
for _ in range(60):
    try:
        sock = socket.create_connection((host, port), 2)
        sock.close()
        sys.exit(0)
    except Exception:
        time.sleep(1)
sys.stderr.write("Postgres %s:%s was not ready after 60s\n" % (host, port))
sys.exit(1)
PY

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if [ -f "$OPENERP_SERVER" ] && grep -q -E "^[[:space:]]*${param}[[:space:]]*=" "$OPENERP_SERVER"; then
        value=$(grep -E "^[[:space:]]*${param}[[:space:]]*=" "$OPENERP_SERVER" | head -n1 | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/["\r]//g')
    fi
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | openerp-server)
        shift
        exec openerp-server "$@" "${DB_ARGS[@]}"
        ;;
    -*)
        exec openerp-server "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
        ;;
esac

exit 1
