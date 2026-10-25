#!/bin/sh
# Builds the access-control snippet imported by the Caddyfile, then starts Caddy.
#
# ACCESS_PASSWORD set:   visitors must enter ACCESS_USER / ACCESS_PASSWORD once
#                        (HTTP basic auth). After that, a session cookie lets
#                        them in. The cookie is needed because the game sends its
#                        own Authorization header on some requests (e.g. the Woka
#                        list), which replaces the browser's basic auth header.
# ACCESS_PASSWORD empty: the site stays open to anyone with the URL.
set -e

AUTH_FILE=/etc/caddy/auth.caddy
ACCESS_USER="${ACCESS_USER:-workadventure}"
COOKIE_NAME="wa_access"
COOKIE_MAX_AGE="${ACCESS_COOKIE_MAX_AGE:-2592000}" # 30 days

if [ -n "$ACCESS_PASSWORD" ]; then
  case "$ACCESS_USER" in
    *[!A-Za-z0-9._-]*)
      echo "[proxy] ACCESS_USER may only contain letters, digits, '.', '_' and '-'" >&2
      exit 1
      ;;
  esac
  case "$COOKIE_MAX_AGE" in
    ''|*[!0-9]*)
      echo "[proxy] ACCESS_COOKIE_MAX_AGE must be a number of seconds" >&2
      exit 1
      ;;
  esac

  HASH="$(caddy hash-password --plaintext "$ACCESS_PASSWORD")"
  # Cookie value derived from the credentials: stable across restarts, and
  # changing the password signs everyone out.
  TOKEN="$(printf '%s:%s:workadventure-railway' "$ACCESS_USER" "$ACCESS_PASSWORD" | sha256sum | cut -d' ' -f1)"

  # Paths left open:
  #   /map-storage*  has its own login (map upload page) and serves map files
  #   /roomArea      called by map-storage with its own API token
  {
    printf '@needs_auth {\n'
    printf '\tnot path /map-storage /map-storage/* /roomArea\n'
    printf '\tnot header_regexp Cookie "(^|;[ ]*)%s=%s(;|$)"\n' "$COOKIE_NAME" "$TOKEN"
    printf '}\n'
    printf 'basic_auth @needs_auth {\n'
    printf '\t%s %s\n' "$ACCESS_USER" "$HASH"
    printf '}\n'
    # Only reached when basic auth succeeded (inside a route block, a failed
    # basic_auth stops before this line).
    printf 'header @needs_auth +Set-Cookie "%s=%s; Path=/; Max-Age=%s; HttpOnly; Secure; SameSite=Lax"\n' \
      "$COOKIE_NAME" "$TOKEN" "$COOKIE_MAX_AGE"
  } > "$AUTH_FILE"
  echo "[proxy] Access control enabled for user '$ACCESS_USER'"
else
  : > "$AUTH_FILE"
  echo "[proxy] WARNING: ACCESS_PASSWORD is not set; anyone with the URL can join"
fi

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
