# Generic SteamCMD Game Server (Docker)

This repository provides a Dockerized **generic SteamCMD-based game server** suitable for running any Steam game server in a clean, reproducible way.
The image is designed for **headless operation**, automatically downloads and updates game servers via SteamCMD, and supports file overlaying using OverlayFS.

---

## Features

- Runs any **Steam dedicated server** via SteamCMD
- Automatically downloads and updates game servers on startup
- Supports file overlaying using OverlayFS (no file copying required)
- Automated build & push via GitHub Actions

## Docker Compose Example

```yaml
services:
  game-server:
    image: lancommander/steamcmd:latest
    container_name: game-server

    # Adjust ports to match your game
    ports:
      - "27015:27015/udp"

    # Bind mounts so files appear on the host
    volumes:
      - ./config:/config

    environment:
      STEAM_APP_ID: "730"         # CS:GO App ID
      # START_ARGS: "./srcds_run -game csgo -console -usercon +map de_dust2"

    cap_add:
      - SYS_ADMIN

    security_opt:
      - apparmor:unconfined

    # Ensure container restarts if the server crashes or host reboots
    restart: unless-stopped
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Game files downloaded by SteamCMD (auto-created)
    ├── Overlay/           # Files to overlay on game directory (optional)
    │   ├── maps/          # Example: Custom maps
    │   └── ...            # Any files you want to overlay
    ├── Merged/            # OverlayFS merged view (auto-created)
    ├── .overlay-work/     # OverlayFS work directory (auto-created)
    └── Scripts/
        └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
```

Both directories **must be writable** by Docker.

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_ID` | Steam App ID of the game server to install | *(required)* |
| `STEAM_APP_UPDATE` | Enable automatic updates on startup (`true`/`false`) | `true` |
| `STEAM_BRANCH` | Steam beta branch name | *(empty)* |
| `STEAM_BRANCH_PASSWORD` | Password for the beta branch | *(empty)* |
| `STEAM_VALIDATE` | Validate game files on install/update | `true` |
| `STEAM_USERNAME` | Steam account username | `anonymous` |
| `STEAM_PASSWORD` | Steam account password | *(empty)* |
| `STEAMCMD_ARGS` | Additional arguments passed to SteamCMD | *(empty)* |
| `START_EXE` | Executable to run after installation | *(empty)* |
| `START_ARGS` | Arguments passed to the server executable | *(empty)* |

### `STEAM_APP_ID`

The Steam App ID of the game server to install. Common examples:

- **CS:GO**: `730`
- **CS: Source**: `232330`
- **Team Fortress 2**: `232250`
- **Left 4 Dead 2**: `222860`
- **ARK: Survival Evolved**: `376030`
- **Rust**: `258550`

You can find App IDs on [SteamDB](https://steamdb.info/) or by checking the game's Steam store page URL.

---

## Running the Server

### Basic run (recommended)

```bash
mkdir -p config

docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_APP_ID="730" \
  -e START_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2" \
  lancommander/steamcmd:latest
```

### With a beta branch

```bash
docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_APP_ID="730" \
  -e STEAM_BRANCH="beta" \
  -e STEAM_BRANCH_PASSWORD="mypassword" \
  -e START_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2" \
  lancommander/steamcmd:latest
```

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
