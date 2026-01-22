#!/usr/bin/env bash
set -euo pipefail
npm ci
set +H 2>/dev/null || true # disable history expansion (safe for passwords with !)

# Optional overrides:
# CLEAN_FIRST=0 ./setup_and_run.sh
# PROJECT_DIR=/app DB_NAME=twitter_miniapp APP_DB_USER=twitter_admin APP_DB_PASS='MyAppPassw0rd!' ./setup_and_run.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_DIR="$(pwd)"

PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"

# Must match app.js unless you edit app.js
DB_NAME="${DB_NAME:-twitter_miniapp}"
APP_DB_USER="${APP_DB_USER:-twitter_admin}"
APP_DB_HOST="${APP_DB_HOST:-localhost}"
APP_DB_PASS="${APP_DB_PASS:-MyAppPassw0rd!}"

# These files are copied into /app/scripts by the Dockerfile
CREATE_TABLE_SQL="${CREATE_TABLE_SQL:-$SCRIPT_DIR/create_table.sql}"
FALLBACK_DUMP_SQL="${FALLBACK_DUMP_SQL:-$SCRIPT_DIR/twitter_miniapp.sql}"

CLEAN_FIRST="${CLEAN_FIRST:-0}"

MYSQL_SOCK="/run/mysqld/mysqld.sock"

cd "$PROJECT_DIR"

mysql_socket() {
  mysql --protocol=socket --socket="$MYSQL_SOCK" "$@"
}

start_mysql() {
  echo "[+] Starting MySQL (no systemctl)..."

  mkdir -p /run/mysqld
  chown -R mysql:mysql /run/mysqld

  mkdir -p /var/lib/mysql
  chown -R mysql:mysql /var/lib/mysql

  mysqld_safe --datadir=/var/lib/mysql --socket="$MYSQL_SOCK" >/tmp/mysqld_safe.log 2>&1 &

  for i in {1..40}; do
    if mysql_socket -e "SELECT 1" >/dev/null 2>&1; then
      echo "[+] MySQL is ready."
      return 0
    fi
    sleep 1
  done

  echo "[-] MySQL did not become ready. Last logs:"
  tail -n 200 /tmp/mysqld_safe.log || true
  exit 1
}

relax_validate_password_if_present() {
  echo "[+] DEV: Relax validate_password rules if present..."

  local has_component_table="0"
  has_component_table="$(
    mysql_socket -Nse \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='mysql' AND table_name='component';" \
      2>/dev/null || echo "0"
  )"

  if [[ "${has_component_table}" != "0" ]]; then
    mysql_socket <<'SQL' || true
SET @vp_installed := (
  SELECT COUNT(*)
  FROM mysql.component
  WHERE component_urn='file://component_validate_password'
);

SET @stmt := IF(
  @vp_installed > 0,
  "SET GLOBAL validate_password.policy = 0",
  "SELECT 'validate_password component not installed; skipping policy changes.' AS info"
);
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

SET @stmt := IF(
  @vp_installed > 0,
  "SET GLOBAL validate_password.length = 8",
  "SELECT 1"
);
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;
SQL
  else
    mysql_socket -e "SET GLOBAL validate_password_policy = 0;" >/dev/null 2>&1 || true
    mysql_socket -e "SET GLOBAL validate_password_length = 8;" >/dev/null 2>&1 || true
    mysql_socket -e "SET GLOBAL validate_password.policy = 0;" >/dev/null 2>&1 || true
    mysql_socket -e "SET GLOBAL validate_password.length = 8;" >/dev/null 2>&1 || true
  fi

  mysql_socket -e "SHOW VARIABLES LIKE 'validate_password%';" 2>/dev/null || true
}

free_port_3000() {
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -t -iTCP:3000 -sTCP:LISTEN || true)"
    if [[ -n "${pids}" ]]; then
      echo "[+] Stopping process(es) listening on :3000: ${pids}"
      kill ${pids} 2>/dev/null || true
      sleep 0.5
      kill -9 ${pids} 2>/dev/null || true
    fi
  elif command -v fuser >/dev/null 2>&1; then
    echo "[+] Attempting to free :3000 with fuser..."
    fuser -k 3000/tcp >/dev/null 2>&1 || true
  else
    echo "[!] Skipping port 3000 cleanup (lsof/fuser not installed)."
  fi
}

clean_first() {
  echo "[+] Cleaning project + MySQL state..."
  free_port_3000

  # Drop app users if they exist (ignore errors)
  mysql_socket <<SQL || true
DROP USER IF EXISTS '${APP_DB_USER}'@'localhost';
DROP USER IF EXISTS '${APP_DB_USER}'@'127.0.0.1';
DROP USER IF EXISTS '${APP_DB_USER}'@'::1';
FLUSH PRIVILEGES;
SQL

  echo "[+] Clean complete."
}

init_db() {
  echo "[+] Creating database ${DB_NAME}..."
  mysql_socket -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;" || \
  mysql_socket -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

  echo "[+] Loading schema/data..."
  if [[ -f "${CREATE_TABLE_SQL}" ]]; then
    echo "[+] Using ${CREATE_TABLE_SQL}"
    mysql_socket "${DB_NAME}" < "${CREATE_TABLE_SQL}"
  elif [[ -f "${FALLBACK_DUMP_SQL}" ]]; then
    echo "[+] Using fallback ${FALLBACK_DUMP_SQL}"
    mysql_socket "${DB_NAME}" < "${FALLBACK_DUMP_SQL}"
  else
    echo "[-] Missing schema file."
    echo "    Expected: ${CREATE_TABLE_SQL}"
    echo "    Or fallback: ${FALLBACK_DUMP_SQL}"
    exit 1
  fi

  echo "[+] Creating/resetting MySQL user for the Node app..."
  mysql_socket <<SQL
CREATE USER IF NOT EXISTS '${APP_DB_USER}'@'localhost' IDENTIFIED BY '${APP_DB_PASS}';
CREATE USER IF NOT EXISTS '${APP_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${APP_DB_PASS}';
CREATE USER IF NOT EXISTS '${APP_DB_USER}'@'::1' IDENTIFIED BY '${APP_DB_PASS}';

ALTER USER '${APP_DB_USER}'@'localhost' IDENTIFIED BY '${APP_DB_PASS}';
ALTER USER '${APP_DB_USER}'@'127.0.0.1' IDENTIFIED BY '${APP_DB_PASS}';
ALTER USER '${APP_DB_USER}'@'::1' IDENTIFIED BY '${APP_DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${APP_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${APP_DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${APP_DB_USER}'@'::1';

FLUSH PRIVILEGES;
SQL
}

echo "[+] Preflight: checking Node mysql module..."
node -e "require('mysql')" >/dev/null 2>&1 || {
  echo "[-] Node module 'mysql' is missing."
  echo "    Fix: add it to package.json (dependencies) and rebuild, or install it during docker build."
  exit 1
}

echo "[+] Enabling MySQL..."
start_mysql

if [[ "${CLEAN_FIRST}" == "1" ]]; then
  clean_first
fi

relax_validate_password_if_present
init_db

echo "[+] Starting app..."
echo "[+] Open http://localhost:3000/register"
exec node ./app.js

