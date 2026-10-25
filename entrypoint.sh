#!/bin/sh
# Builds the access-control snippet imported by the Caddyfile, then starts Caddy.
#
# ACCESS_PASSWORD set:   the whole site asks for ACCESS_USER / ACCESS_PASSWORD
#                        (HTTP basic auth), except the paths listed below.
# ACCESS_PASSWORD empty: the site stays open to anyone with the URL.
set -e

AUTH_FILE=/etc/caddy/auth.caddy
ACCESS_USER="${ACCESS_USER:-workadventure}"

if [ -n "$ACCESS_PASSWORD" ]; then
  case "$ACCESS_USER" in
    *[!A-Za-z0-9._-]*)
      echo "[proxy] ACCESS_USER may only contain letters, digits, '.', '_' and '-'" >&2
      exit 1
      ;;
  esac
  HASH="$(caddy hash-password --plaintext "$ACCESS_PASSWORD")"
  # Paths left open:
  #   /map-storage*  has its own login (map upload page) and serves map files
  #   /roomArea      called by map-storage with its own API token
  {
    printf '@protected not path /map-storage /map-storage/* /roomArea\n'
    printf 'basic_auth @protected {\n'
    printf '\t%s %s\n' "$ACCESS_USER" "$HASH"
    printf '}\n'
  } > "$AUTH_FILE"
  echo "[proxy] Access control enabled for user '$ACCESS_USER'"
else
  : > "$AUTH_FILE"
  echo "[proxy] WARNING: ACCESS_PASSWORD is not set; anyone with the URL can join"
fi

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
