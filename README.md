# Generic SteamCMD Game Server (Docker)

This repository provides a Dockerized **generic SteamCMD-based game server** suitable for running any Steam game server in a clean, reproducible way.  
The image is designed for **headless operation**, automatically downloads and updates game servers via SteamCMD, and supports file overlaying using overlayfs.

---

## Features

- Generic SteamCMD-based game server support
- Automatically downloads and updates game servers via SteamCMD
- Supports file overlaying using overlayfs (no file copying required)
- Pre-execution script support (`/config/autoexec.sh`)
- Non-root runtime using `gosu`
- Configurable automatic updates

## Docker Compose Example

```yaml
services:
  game-server:
    image: lancommander/steamcmd:latest
    container_name: my-game-server

    # Expose game server ports (adjust as needed)
    ports:
      - "27015:27015/udp"  # Example: CS:GO
      - "27005:27005/udp"

    # Bind mounts
    volumes:
      - ./config:/config      # Game server configuration and overlay directory

    environment:
      STEAM_APP_ID: "730"                    # CS:GO App ID
      STEAM_APP_UPDATE: "true"               # Enable automatic updates
      STEAMCMD_ARGS: "./srcds_run -game csgo -console -usercon +map de_dust2"

    # For overlayfs support, add one of these:
    # Option 1: Full privileges (less secure)
    privileged: true
    # Option 2: Minimal privileges (recommended)
    # cap_add:
    #   - SYS_ADMIN

    restart: unless-stopped
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── game/              # Game files downloaded by SteamCMD (auto-created)
    ├── overlay/          # Files to overlay on game directory (optional)
    │   ├── maps/          # Example: Custom maps
    │   ├── scripts/       # Example: Custom scripts
    │   └── ...            # Any files you want to overlay
    ├── merged/            # Overlayfs merged view (auto-created, if overlayfs enabled)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── autoexec.sh        # Optional: Script executed before SteamCMD update
    └── ...                # Your game server configuration files
```

The `config` directory **must be writable** by Docker. The `game` directory is automatically created and populated by SteamCMD on first startup.

---

## Configuration

### Pre-Execution Script

You can create a script at `/config/autoexec.sh` that will be executed **before** SteamCMD runs. This is useful for:
- Installing additional dependencies
- Setting up environment variables
- Downloading additional files
- Modifying configuration before the game server starts

Example `config/autoexec.sh`:
```bash
#!/usr/bin/env bash
echo "Running pre-execution setup..."
# Download custom files, set environment variables, etc.
export MY_CUSTOM_VAR="value"
```

The script will be made executable automatically if it's not already.

### File Overlaying

The overlay directory (`/config/overlay`) allows you to overlay files on top of the game directory without copying files. This is useful for:
- Replacing game files (maps, scripts, assets)
- Adding custom content
- Modifying game files without touching the base installation

**How it works:**
- Files in `/config/overlay` will appear in the merged view at `/config/merged`
- If a file exists in both `/config/game` and `/config/overlay`, the version in `/config/overlay` takes precedence
- The game server runs from the merged directory when overlayfs is active

**Requirements:**
- Container must run with `--cap-add SYS_ADMIN` or `--privileged` flag
- If overlayfs cannot be mounted, the container falls back to using the game directory directly

**Example overlay structure:**
```text
config/overlay/
├── maps/
│   └── custom_map.bsp
├── scripts/
│   └── server.cfg
└── addons/
    └── custom_addon.vdf
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_ID` | Steam App ID of the game server to install/update | *(required)* |
| `STEAM_APP_UPDATE` | Enable automatic game updates on startup (`true`/`false`) | `true` |
| `STEAMCMD_ARGS` | Command to run the game server (see examples below) | *(required if no command args provided)* |

### `STEAM_APP_ID`

The Steam App ID of the game server you want to run. Common examples:

- **CS:GO**: `730`
- **CS: Source**: `232330`
- **Team Fortress 2**: `232250`
- **Left 4 Dead 2**: `222860`
- **ARK: Survival Evolved**: `376030`
- **Rust**: `258550`

You can find App IDs on [SteamDB](https://steamdb.info/) or by checking the game's Steam store page URL.

### `STEAM_APP_UPDATE`

Set to `false` or `0` to disable automatic updates. When disabled, SteamCMD will not run on container startup.

### `STEAMCMD_ARGS`

The command to start your game server. This varies by game. Examples:

**CS:GO:**
```bash
STEAMCMD_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2"
```

**CS: Source:**
```bash
STEAMCMD_ARGS="./srcds_run -game cstrike -console +map de_dust2"
```

**Team Fortress 2:**
```bash
STEAMCMD_ARGS="./srcds_run -game tf -console +map cp_dustbowl"
```

**Left 4 Dead 2:**
```bash
STEAMCMD_ARGS="./srcds_run -game left4dead2 -console +map c1m1_hotel"
```

**ARK: Survival Evolved:**
```bash
STEAMCMD_ARGS="./ShooterGame/Bin/Linux/ShooterGameServer TheIsland?listen?SessionName=MyServer"
```

---

## Running the Server

### Basic run (with automatic updates)

```bash
mkdir -p config

docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "./config:/config" \
  -e STEAM_APP_ID="730" \
  -e STEAMCMD_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2" \
  lancommander/steamcmd:latest
```

### With custom configuration and overlay

```bash
docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_APP_ID="730" \
  -e STEAM_APP_UPDATE="true" \
  -e STEAMCMD_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2 +maxplayers 16" \
  lancommander/steamcmd:latest
```

### Disable automatic updates

```bash
docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_APP_ID="730" \
  -e STEAM_APP_UPDATE="false" \
  -e STEAMCMD_ARGS="./srcds_run -game csgo -console -usercon +map de_dust2" \
  lancommander/steamcmd:latest
```

### Using command arguments instead of STEAMCMD_ARGS

You can also pass the server command as arguments to the container:

```bash
docker run --rm -it \
  --cap-add SYS_ADMIN \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_APP_ID="730" \
  lancommander/steamcmd:latest \
  ./srcds_run -game csgo -console -usercon +map de_dust2
```

---

## Overlayfs Details

The container uses Linux overlayfs to merge the game directory (`/config/game`) with the overlay directory (`/config/overlay`) into a merged view (`/config/merged`). This allows you to:

1. **Replace files** without modifying the base game installation
2. **Add files** that don't exist in the base game
3. **Avoid copying** large files - overlayfs is a union filesystem

**Technical details:**
- **Lower layer**: `/config/game` (base game files from SteamCMD)
- **Upper layer**: `/config/overlay` (your custom files)
- **Merged view**: `/config/merged` (where the game server runs from)
- **Work directory**: `/config/.overlay-work` (required by overlayfs)

If overlayfs cannot be mounted (e.g., missing privileges), the container will fall back to using `/config/game` directly and log a warning.

---

## Troubleshooting

### Overlayfs not working

If you see warnings about overlayfs, ensure your container has the required privileges:

```bash
# Option 1: Add SYS_ADMIN capability (recommended)
docker run --cap-add SYS_ADMIN ...

# Option 2: Use privileged mode (less secure)
docker run --privileged ...
```

### Game server not starting

1. Check that `STEAM_APP_ID` is set correctly
2. Verify `STEAMCMD_ARGS` contains the correct command for your game
3. Check container logs: `docker logs <container-name>`
4. Ensure the game directory was downloaded: check `/config/game` in the container

### Permission errors

The container runs as a non-root user (`steamcmd`, UID 10001). If you encounter permission errors:

1. Ensure mounted volumes are writable
2. Check file ownership in the container
3. Review logs for specific permission error messages

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
