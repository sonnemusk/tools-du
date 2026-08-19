#!/usr/bin/env bash
#
# Reset Typeless device identifier on macOS.
# Portable: works on any macOS user account; no Node.js required.
#
# Usage:
#   bash reset-device-macos.sh
#   TYPELESS_APP_PATH="/path/to/Typeless.app" bash reset-device-macos.sh
#   SKIP_LAUNCH=1 bash reset-device-macos.sh
#
# Env:
#   TYPELESS_APP_PATH  Optional absolute path to Typeless.app
#   SKIP_LAUNCH=1      Do not reopen Typeless after cleanup
#
set -euo pipefail

echo "[reset-device] Typeless device identifier reset tool (macOS)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[reset-device] ERROR: This script only runs on macOS." >&2
  exit 1
fi

TYPELESS_DIR="${HOME}/Library/Application Support/Typeless"
DEVICE_CACHE_DIR="${HOME}/Library/Application Support/now.typeless.desktop"
KEYCHAIN_SERVICE="now.typeless.desktop.deviceIdentifier"
KEYCHAIN_ACCOUNT="now.typeless.desktop.security.auth_key"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[reset-device] ERROR: required command not found: $1" >&2
    exit 1
  fi
}

need_cmd pgrep
need_cmd osascript
need_cmd open
need_cmd security
need_cmd python3

find_typeless_app() {
  if [[ -n "${TYPELESS_APP_PATH:-}" && -d "${TYPELESS_APP_PATH}" ]]; then
    printf '%s\n' "${TYPELESS_APP_PATH}"
    return 0
  fi

  local candidate
  for candidate in \
    "${HOME}/Applications/Typeless.app" \
    "/Applications/Typeless.app"
  do
    if [[ -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  # Last resort: Spotlight (may be empty on freshly imaged Macs)
  if command -v mdfind >/dev/null 2>&1; then
    candidate="$(mdfind 'kMDItemCFBundleIdentifier == "now.typeless.desktop"' 2>/dev/null | head -n 1 || true)"
    if [[ -n "${candidate}" && -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
    candidate="$(mdfind 'kMDItemDisplayName == "Typeless.app"' 2>/dev/null | head -n 1 || true)"
    if [[ -n "${candidate}" && -d "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  fi

  return 1
}

read_device_id_cache() {
  if [[ -f "${DEVICE_CACHE_DIR}/device.cache" ]]; then
    tr -d '\r\n' < "${DEVICE_CACHE_DIR}/device.cache"
  fi
}

TYPELESS_APP_PATH_FOUND="$(find_typeless_app || true)"
OLD_DEVICE_ID="$(read_device_id_cache || true)"
if [[ -n "${OLD_DEVICE_ID}" ]]; then
  echo "[reset-device] Current device.cache: ${OLD_DEVICE_ID}"
fi

# 1. Kill Typeless if running
# Soft quit first; if still alive ~5s later, force kill by PID.
if pgrep -f "Typeless.app" >/dev/null 2>&1; then
  echo "[reset-device] Stopping Typeless..."
  osascript -e 'quit app "Typeless"' 2>/dev/null || true
  for _ in $(seq 1 10); do
    pgrep -f "Typeless.app" >/dev/null 2>&1 || break
    sleep 0.5
  done
  if pgrep -f "Typeless.app" >/dev/null 2>&1; then
    echo "[reset-device] Still running after quit, force killing by PID..."
    # shellcheck disable=SC2046
    kill $(pgrep -f "Typeless.app") 2>/dev/null || true
    sleep 1
    if pgrep -f "Typeless.app" >/dev/null 2>&1; then
      # shellcheck disable=SC2046
      kill -9 $(pgrep -f "Typeless.app") 2>/dev/null || true
      sleep 0.5
    fi
  fi
  if pgrep -f "Typeless.app" >/dev/null 2>&1; then
    echo "[reset-device] ERROR: Typeless is still running. Quit it manually and re-run." >&2
    exit 1
  fi
  echo "[reset-device] Typeless stopped"
else
  echo "[reset-device] Typeless is not running"
fi

# 2a. Delete device.cache
if [[ -f "${DEVICE_CACHE_DIR}/device.cache" ]]; then
  rm -f "${DEVICE_CACHE_DIR}/device.cache"
  echo "[reset-device] Removed device.cache"
else
  echo "[reset-device] device.cache not found (already clean)"
fi

# 2b. Delete device identifier from Keychain
# May prompt the user for Keychain access on some machines.
if security delete-generic-password \
  -s "${KEYCHAIN_SERVICE}" \
  -a "${KEYCHAIN_ACCOUNT}" >/dev/null 2>&1; then
  echo "[reset-device] Device identifier removed from Keychain"
else
  echo "[reset-device] Device identifier not found in Keychain (already clean)"
fi

# 3. Delete user-data.json
if [[ -f "${TYPELESS_DIR}/user-data.json" ]]; then
  rm -f "${TYPELESS_DIR}/user-data.json"
  echo "[reset-device] Removed user-data.json"
else
  echo "[reset-device] user-data.json not found (already clean)"
fi

# 4. Clear login state from app-storage.json (keep other settings)
# Prefer python3 (ships with macOS); fall back to node if present.
if [[ -f "${TYPELESS_DIR}/app-storage.json" ]]; then
  APP_STORAGE_PATH="${TYPELESS_DIR}/app-storage.json"
  export APP_STORAGE_PATH
  if python3 - <<'PY'
import json, os, pathlib, sys
path = pathlib.Path(os.environ["APP_STORAGE_PATH"])
try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as e:
    print(f"[reset-device] Could not clean app-storage.json: {e}")
    sys.exit(0)
removed = [k for k in ("userData", "quotaUsage") if k in data]
for k in removed:
    data.pop(k, None)
path.write_text(json.dumps(data, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
if removed:
    print("[reset-device] Cleared login state from app-storage.json (" + ", ".join(removed) + ")")
else:
    print("[reset-device] app-storage.json had no userData/quotaUsage (already clean)")
PY
  then
    :
  else
    echo "[reset-device] ERROR: failed to patch app-storage.json with python3" >&2
    exit 1
  fi
else
  echo "[reset-device] app-storage.json not found"
fi

# 5. Clear login session cookies
for cookie_file in "${TYPELESS_DIR}/Cookies" "${TYPELESS_DIR}/Cookies-journal"; do
  if [[ -f "${cookie_file}" ]]; then
    rm -f "${cookie_file}"
    echo "[reset-device] Removed $(basename "${cookie_file}")"
  fi
done

# 6. Clear frontend Local Storage
if [[ -d "${TYPELESS_DIR}/Local Storage" ]]; then
  rm -rf "${TYPELESS_DIR}/Local Storage"
  echo "[reset-device] Cleared Local Storage"
else
  echo "[reset-device] Local Storage not found (already clean)"
fi

# 7. Optionally restart Typeless
if [[ "${SKIP_LAUNCH:-0}" == "1" ]]; then
  echo "[reset-device] SKIP_LAUNCH=1 set; not starting Typeless"
elif [[ -n "${TYPELESS_APP_PATH_FOUND}" ]]; then
  echo "[reset-device] Starting Typeless: ${TYPELESS_APP_PATH_FOUND}"
  open "${TYPELESS_APP_PATH_FOUND}"
  echo "[reset-device] Typeless started"
else
  echo "[reset-device] Typeless.app not found. Set TYPELESS_APP_PATH or start it manually."
fi

echo ""
echo "[reset-device] Done."
echo "[reset-device] Log in again inside Typeless."
echo "[reset-device] Success check:"
echo "  1) device.cache / Keychain show a NEW UUID"
echo "  2) target account login no longer hits device-user limit"
if [[ -n "${OLD_DEVICE_ID}" ]]; then
  echo "[reset-device] Previous device.cache was: ${OLD_DEVICE_ID}"
fi
