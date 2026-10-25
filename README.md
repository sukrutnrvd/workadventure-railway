# WorkAdventure on Railway

Deploy [WorkAdventure](https://workadventu.re), a virtual office where people walk around a 2D map and start video calls by walking up to each other, on [Railway](https://railway.com) in one click.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/workadventure)

This repository holds the reverse proxy for the template. Every other service runs from the official WorkAdventure Docker images.

## What gets deployed

| Service | Source | Purpose |
| --- | --- | --- |
| `proxy` | This repository (Caddy) | Public entry point. Routes requests to the other services and asks for the site password. |
| `play` | `thecodingmachine/workadventure-play` | Game front end and WebSocket server |
| `back` | `thecodingmachine/workadventure-back` | Room state and game logic |
| `mapstorage` | `thecodingmachine/workadventure-map-storage` | Stores maps and serves the map management page. Uses a volume at `/maps`. |
| `uploader` | `thecodingmachine/workadventure-uploader` | File uploads in the chat |
| `icon` | `matthiasluedtke/iconserver` | Fetches favicons for websites embedded in maps |
| `Redis` | Railway Redis | Map variables and chat uploads |

Only `proxy` has a public domain. The other services talk to each other over Railway's private network.

## Why this repository exists

The official `docker-compose.prod.yaml` uses Traefik, which finds its routes by reading the Docker socket. Railway does not expose a Docker socket, so this template replaces Traefik with Caddy and writes the same routes out by hand:

| Path | Service | Prefix stripped |
| --- | --- | --- |
| `/ws/*` | `play` (port 3001) | No |
| `/api*` | `back` (port 8080) | Yes |
| `/map-storage*` | `mapstorage` (port 3000) | Yes |
| `/uploader*` | `uploader` (port 8080) | Yes |
| `/icon*` | `icon` (port 8080) | Yes |
| `/lettericons*` | `icon` (port 8080) | No |
| Everything else | `play` (port 3000) | No |

The proxy also adds something the official setup does not have: a shared password for the whole site.

## Logging in

WorkAdventure has no login system of its own. Without one, anyone who finds the URL can join. To prevent that, the proxy asks for a username and password before the game loads:

- **Username:** `ACCESS_USER` on the `proxy` service (default `workadventure`)
- **Password:** `ACCESS_PASSWORD` on the `proxy` service (generated on deploy)

After a correct login the browser receives a session cookie, so the password is asked only once. The cookie is valid for 30 days by default (`ACCESS_COOKIE_MAX_AGE`). Changing `ACCESS_PASSWORD` signs everyone out.

The cookie is required because the game sends its own `Authorization` header on some requests, such as loading the list of characters. That header replaces the browser's basic auth credentials, so basic auth alone would ask for the password again on those requests.

Leave `ACCESS_PASSWORD` empty to make the site public.

## Adding maps

Visitors land on the map in `START_ROOM_URL` on the `play` service. By default this is WorkAdventure's starter office. WorkAdventure has no map picker; each map has its own URL.

Manage maps at `https://<your-domain>/map-storage/`. Log in with `AUTHENTICATION_USER` and `AUTHENTICATION_PASSWORD` from the `mapstorage` service. This login is separate from the site password. On that page you can:

- see all uploaded maps
- upload a map built with [Tiled](https://www.mapeditor.org) as a ZIP file
- add a map hosted elsewhere by its `.tmj` URL

An uploaded map is available at `https://<your-domain>/~/<directory>/<map>.wam`. To make it the landing map, set `START_ROOM_URL` to that path, for example `/~/office.wam`.

To build and upload maps from your computer, use the [map-starter-kit](https://github.com/workadventure/map-starter-kit). In its publishing settings, enter `https://<your-domain>/map-storage/` as the map storage URL and `AUTHENTICATION_TOKEN` from the `mapstorage` service as the API key.

## Limitations

- **Chat history is not stored.** The proximity chat is temporary and is cleared when the page reloads. Persistent chat needs a Matrix server and personal logins, which this template does not include.
- **The in-game map editor is off.** Without personal logins, everyone who can enter the site could edit maps. It stays disabled (`ENABLE_MAP_EDITOR="false"`).
- **Meeting rooms use the public Jitsi server.** Areas marked as meeting rooms open a call on `meet.jit.si`, which limits embedded calls to 5 minutes. For longer meetings, point `JITSI_URL` to your own Jitsi server.
- **Video may fail on strict networks.** Video calls connect browsers directly. On mobile data or strict corporate networks this needs a TURN server, which Railway cannot host because it requires UDP. Add a hosted TURN service through `TURN_SERVER`, `TURN_USER` and `TURN_PASSWORD` on the `play` and `back` services.
- **Deploy into a new project.** The services connect to each other over IPv4. Railway's private network supports IPv4 in environments created after October 16, 2025, which includes every new deploy of this template.

## Files

| File | Purpose |
| --- | --- |
| `Caddyfile` | Routing rules. Upstream hostnames come from `PLAY_HOST`, `BACK_HOST`, `MAP_STORAGE_HOST`, `UPLOADER_HOST` and `ICON_HOST`. |
| `entrypoint.sh` | Turns `ACCESS_USER` / `ACCESS_PASSWORD` into Caddy's password and cookie rules at startup, then starts Caddy |
| `Dockerfile` | Copies both files into the official Caddy image |

## Updating WorkAdventure

The WorkAdventure images are pinned to a release (currently `v1.34.4`). To upgrade, change the image tag on `play`, `back`, `mapstorage` and `uploader` to the same new version. Always keep the four services on the same version. Check the [WorkAdventure releases](https://github.com/workadventure/workadventure/releases) and `UPGRADE.md` in their repository before upgrading.

## License

The files in this repository are released under the MIT License.

WorkAdventure itself is developed by TheCodingMachine and licensed under the GNU AGPL v3 with the Commons Clause. See the [WorkAdventure repository](https://github.com/workadventure/workadventure) for details.
