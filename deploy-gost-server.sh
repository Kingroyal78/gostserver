#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="${3:-}"
  local input

  if [[ -n "${default_value}" ]]; then
    read -r -p "${prompt_text} [${default_value}]: " input
    input="${input:-${default_value}}"
  else
    read -r -p "${prompt_text}: " input
  fi

  printf -v "${var_name}" '%s' "${input}"
}

echo "==== GOST Server Quick Deploy ===="
echo
echo "Supported transports: ws / wss / mws / mwss / tls / mtls"
echo

prompt_default INSTANCE "Instance name" "ss-ws-8388"
prompt_default TRANSPORT "Transport" "ws"
prompt_default LISTEN_HOST "Listen host" "0.0.0.0"
prompt_default LISTEN_PORT "Listen port" "80"
prompt_default TARGET_HOST "Target host" "127.0.0.1"
prompt_default TARGET_PORT "Target port" "8388"

case "${TRANSPORT}" in
  ws|wss|mws|mwss|tls|mtls) ;;
  *)
    echo "Unsupported TRANSPORT: ${TRANSPORT}"
    exit 1
    ;;
esac

if [[ "${TRANSPORT}" == "ws" || "${TRANSPORT}" == "wss" || "${TRANSPORT}" == "mws" || "${TRANSPORT}" == "mwss" ]]; then
  prompt_default WS_PATH "WS path" "/ws"
  prompt_default WS_HEADERS "WS headers (key=value,key2=value2, optional)" ""
fi

if [[ "${TRANSPORT}" == "wss" || "${TRANSPORT}" == "mwss" || "${TRANSPORT}" == "tls" || "${TRANSPORT}" == "mtls" ]]; then
  prompt_default CERT_FILE "TLS cert file" ""
  prompt_default KEY_FILE "TLS key file" ""
  if [[ -z "${CERT_FILE}" || -z "${KEY_FILE}" ]]; then
    echo "CERT_FILE and KEY_FILE are required for ${TRANSPORT}"
    exit 1
  fi
  prompt_default CA_FILE "TLS CA file (optional)" ""
fi

if [[ "${TRANSPORT}" == "mws" || "${TRANSPORT}" == "mwss" || "${TRANSPORT}" == "mtls" ]]; then
  prompt_default MUX_VERSION "MUX version" "2"
  prompt_default MUX_KEEPALIVE_INTERVAL "MUX keepalive interval" "10s"
  prompt_default MUX_KEEPALIVE_DISABLED "MUX keepalive disabled" "false"
  prompt_default MUX_KEEPALIVE_TIMEOUT "MUX keepalive timeout" "30s"
  prompt_default MUX_MAX_FRAME_SIZE "MUX max frame size" "32768"
  prompt_default MUX_MAX_RECEIVE_BUFFER "MUX max receive buffer" "4194304"
  prompt_default MUX_MAX_STREAM_BUFFER "MUX max stream buffer" "65536"
fi

prompt_default LOG_LEVEL "Log level" "info"

install_gost() {
  if command -v gost >/dev/null 2>&1; then
    return
  fi
  bash /root/cate/gost/install.sh --install
}

yaml_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

render_ws_headers() {
  local headers="${WS_HEADERS:-}"
  if [[ -z "${headers}" ]]; then
    return
  fi

  echo "      header:"
  IFS=',' read -ra PAIRS <<< "${headers}"
  for pair in "${PAIRS[@]}"; do
    [[ -z "${pair}" ]] && continue
    local key="${pair%%=*}"
    local value="${pair#*=}"
    echo "        $(yaml_escape "${key}"): '$(yaml_escape "${value}")'"
  done
}

render_mux_metadata() {
  cat <<EOF
      mux.version: ${MUX_VERSION:-2}
      mux.keepaliveInterval: ${MUX_KEEPALIVE_INTERVAL:-10s}
      mux.keepaliveDisabled: ${MUX_KEEPALIVE_DISABLED:-false}
      mux.keepaliveTimeout: ${MUX_KEEPALIVE_TIMEOUT:-30s}
      mux.maxFrameSize: ${MUX_MAX_FRAME_SIZE:-32768}
      mux.maxReceiveBuffer: ${MUX_MAX_RECEIVE_BUFFER:-4194304}
      mux.maxStreamBuffer: ${MUX_MAX_STREAM_BUFFER:-65536}
EOF
}

write_yaml() {
  local out="/etc/gost-server/${INSTANCE}.yaml"
  mkdir -p /etc/gost-server

  cat > "${out}" <<EOF
services:
  - name: ${INSTANCE}
    addr: "${LISTEN_HOST}:${LISTEN_PORT}"
    handler:
      type: forward
    listener:
      type: ${TRANSPORT}
EOF

  if [[ "${TRANSPORT}" == "wss" || "${TRANSPORT}" == "mwss" || "${TRANSPORT}" == "tls" || "${TRANSPORT}" == "mtls" ]]; then
    cat >> "${out}" <<EOF
      tls:
        certFile: "${CERT_FILE}"
        keyFile: "${KEY_FILE}"
EOF
    if [[ -n "${CA_FILE:-}" ]]; then
      cat >> "${out}" <<EOF
        caFile: "${CA_FILE}"
EOF
    fi
  fi

  cat >> "${out}" <<EOF
    forwarder:
      nodes:
        - name: target
          addr: "${TARGET_HOST}:${TARGET_PORT}"
    metadata:
EOF

  case "${TRANSPORT}" in
    ws|wss|mws|mwss)
      cat >> "${out}" <<EOF
      ws.path: "${WS_PATH}"
EOF
      render_ws_headers >> "${out}"
      ;;
  esac

  case "${TRANSPORT}" in
    mws|mwss|mtls)
      render_mux_metadata >> "${out}"
      ;;
  esac

  cat >> "${out}" <<EOF

log:
  level: ${LOG_LEVEL:-info}
  output: stderr
EOF

  echo "Wrote ${out}"
}

install_service() {
  local unit="/etc/systemd/system/gost-server-${INSTANCE}.service"
  cp "${SCRIPT_DIR}/gost-server.service.tpl" "${unit}"
  sed -i "s/%i/${INSTANCE}/g" "${unit}"
  systemctl daemon-reload
  systemctl enable --now "gost-server-${INSTANCE}.service"
}

show_status() {
  systemctl --no-pager --full status "gost-server-${INSTANCE}.service" || true
}

echo
echo "==== Summary ===="
echo "INSTANCE=${INSTANCE}"
echo "TRANSPORT=${TRANSPORT}"
echo "LISTEN=${LISTEN_HOST}:${LISTEN_PORT}"
echo "TARGET=${TARGET_HOST}:${TARGET_PORT}"
if [[ "${TRANSPORT}" == "ws" || "${TRANSPORT}" == "wss" || "${TRANSPORT}" == "mws" || "${TRANSPORT}" == "mwss" ]]; then
  echo "WS_PATH=${WS_PATH}"
fi
if [[ "${TRANSPORT}" == "wss" || "${TRANSPORT}" == "mwss" || "${TRANSPORT}" == "tls" || "${TRANSPORT}" == "mtls" ]]; then
  echo "CERT_FILE=${CERT_FILE}"
  echo "KEY_FILE=${KEY_FILE}"
fi
echo

install_gost
write_yaml
install_service
show_status
