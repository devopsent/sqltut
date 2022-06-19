#!/usr/bin/env bash

PG_IMAGE="${PG_IMAGE:-"postgres"}"
PG_VERSION="${PG_VERSION:-"13.7-alpine"}"
PG_VOL_PATH="${VOL_PATH:-"${HOME}/docker/${PG_IMAGE}"}"
PG_VOL_PATH_INT="${PG_VOL_PATH_INT:-"/var/lib/postgresql/data"}"
PG_USER="${PG_USER:-"postgres"}"
PG_PASS="${PG_PASS:-"postgres"}"
PG_PORT_INT="${PG_PORT_INT:-"5432"}"
PG_PORT_EXT="${PG_PORT_EXT:-"5432"}"
PG_DAEMON_GID="${PG_DAEMON_GID:-70}"
PG_DAEMON_UID="${PG_DAEMON_UID:-70}"
PG_CLIENT_APP="${PG_CLIENT_APP:-"psql"}"
PG_CLIENT_PKG="${PG_CLIENT_PKG:-"libpq"}"
NEED_PG_SERVER="${NEED_PG_SERVER:-"0"}"

function ensure_user() {
  local \
    username
  username="${1:-"root"}"
  if [[ $(whoami) != "${username}" ]]; then
    echo "Current user is $(whoami). Expected: ${username}"
    return 1
  fi
  return 0
}

function validate_tool() {
  local \
    tool \
    rc
  tool="${1?missing mandatory parameter tool}"
  command -v "${tool}" > /dev/null 2>/dev/null && rc=$? || rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    echo "tool ${tool} is not installed"
  fi
  return "${rc}"
}

function validate_tools() {
  local -a \
    tools
  local \
    tool \
    rc
  tools+=("${@}")
  if [[ "${#tools[@]}" -eq 0 ]]; then
    return 0
  fi  
  for tool in "${tools[@]}"; do
    validate_tool "${tool}" > /dev/null 2>/dev/null && rc=$? || rc=$?
    if [[ "${rc}" -ne 0 ]]; then
      return "${rc}"
    fi
  done
  return "${rc}"
}

function install_brew() {
  local -a \
    pkgs
  pkgs=("${@}")
  brew install "${pkgs[@]}"
}

function install_debian() {
  local -a \
    pkgs
  local \
    rc
  pkgs=("${@}")
  command -v apt > /dev/null 2>/dev/null && rc=$? || rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    echo "Unsupported Linux system"
    return "${rc}"
  fi
  apt install -y "${pkgs[@]}" && rc=$? || rc=$?
  return "${rc}"
}


function setup_libpq() {
  local \
    rc \
    pkg \
    app \
    system \
    version
  app="${1:-"psql"}"
  pkg="${2:-"libpq"}"
  command -v "${app}" > /dev/null 2> /dev/null && rc=$? || rc=$?
  if [[ "${rc}" -eq 0 ]]; then
    echo "${app} is already installed"
    return "${rc}"
  fi
  system=$(uname -s)
  echo "detected ${system}"
  case "${system}" in
    "Darwin")
      install_brew "${pkg}" && rc=$? || rc=$?
      if [[ "${rc}" -ne 0 ]]; then
          echo "failed to install ${pkg}, exitting"
          return "${rc}"
      fi
      version="$( brew info "${pkg}" --json | jq -r '.[].versions.stable' )"
      rm "/usr/local/bin/${app}"
      ln -s "/usr/local/Cellar/${pkg}/${version}/bin/${app}" "/usr/local/bin/${app}"
    ;;
    "Linux")
      install_debian "${pkg}" && rc=$? || rc=$? 
      if [[ "${rc}" -ne 0 ]]; then
          echo "failed to install ${pkg}, exitting"
          return "${rc}"
      fi
    ;;
  esac
  return "${rc}"
}

function setup_pg_server() {
  local \
    rc
  local -a \
    cmd
  [[ "${NEED_PG_SERVER}" -ne 0 ]] || {
    echo "skip setting up pg server: NEED_PG_SERVER=${NEED_PG_SERVER}";
    exit 1;
  }
  [[ -d "${PG_VOL_PATH}" ]] || mkdir -p "${PG_VOL_PATH}"
  cmd+=(docker run --rm \
    --name "${PG_IMAGE}-docker" \
    --user "${PG_DAEMON_UID}:${PG_DAEMON_GID}" \
    -e "POSTGRES_USER=${PG_USER}" \
    -e "POSTGRES_PASSWORD=${PG_PASS}" \
    -e "PG_TRUST_LOCALNET=true" -d \
    -p "${PG_PORT_INT}:${PG_PORT_EXT}" \
    -v "${PG_VOL_PATH}:${PG_VOL_PATH_INT}" \
    "${PG_IMAGE}:${PG_VERSION}")
  echo "About to run: ${cmd[*]}"
  "${cmd[@]}" && rc=$? || rc=$?
  echo "docker run returned: ${rc}"
  return "${rc}"
}


ensure_user "root" || { echo "Failed validating user, Exitting"; exit 1; }
validate_tools "docker" "jq" || { echo "Failed validating tools, Exitting"; exit 1; }
setup_libpq "${PG_CLIENT_APP}" "${PG_CLIENT_PKG}" && \
setup_pg_server && \
exit $? || exit $?
