#!/usr/bin/env bash

PG_IMAGE="${PG_IMAGE:-"postgres"}"
PG_VERSION="${PG_VERSION:-"13.7-alpine"}"
PG_VOL_PATH="${VOL_PATH:-"${HOME}/docker/${PG_IMAGE}"}"
PG_VOL_PATH_INT="${PG_VOL_PATH_INT:-"/var/lib/postgresql/data"}"
PG_USER="${PG_USER:-"postgres"}"
PG_PASS="${PG_PASS:-"postgres"}"
PG_PORT_INT="${PG_PORT_INT:-"5432"}"
PG_PORT_EXT="${PG_PORT_EXT:-"5432"}"


setup_libpq() {
  local \
    rc \
    pkg \
    app \
    version
  app="${1:-"psql"}"
  pkg="${2:-"libpq"}"
  command -v "${app}" > /dev/null 2> /dev/null && rc=$? || rc=$?
  if [[ "${rc}" -eq 0 ]]; then
    echo "${app} is already installed"
    return "${rc}"
  fi
  brew install "${pkg}"
  version="$( brew info "${pkg}" --json | jq -r '.[].versions.stable' )"
  rm "/usr/local/bin/${app}"
  ln -s "/usr/local/Cellar/${pkg}/${version}/bin/${app}" "/usr/local/bin/${app}"
}

setup_pg_server() {
  [[ -d "${PG_VOL_PATH}" ]] || mkdir -p "${PG_VOL_PATH}"
  docker run --rm \
    --name "${PG_IMAGE}-docker" \
    -e "POSTGRES_USER=${PG_USER}" \
    -e "POSTGRES_PASSWORD=${PG_PASS}" \
    -e "PG_TRUST_LOCALNET=true" -d \
    -p "${PG_PORT_INT}:${PG_PORT_EXT}" \
    -v "${PG_VOL_PATH}:${PG_VOL_PATH_INT}" \
    "${PG_IMAGE}:${PG_VERSION}"
  return "$?"
}


setup_libpq
setup_pg_server
