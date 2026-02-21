---
sidebar_label: Docker
---

# SteamCMD Docker Container
This Docker container provides a generic SteamCMD-based game server that automatically downloads and updates game servers via SteamCMD, and supports file overlaying using OverlayFS.

## Quick Start

```yaml
services:
  game-server:
    image: lancommander/steamcmd:latest
    container_name: game-server

    ports:
      - 27015:27015/udp

    volumes:
      - "/data/Servers/MyGame:/config"

    environment:
      STEAM_APP_ID: "730"
      # START_ARGS: "./srcds_run -game csgo -console -usercon +map de_dust2"

    cap_add:
      - SYS_ADMIN

    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

## Configuration Options

### Ports

SteamCMD-based game servers use varying ports depending on the game. Common examples:

- **27015/udp** - Default Source engine game server port (CS:GO, TF2, L4D2, etc.)
- **7777/udp** - ARK: Survival Evolved
- **28015/udp** - Rust

Adjust the port mapping in your `docker-compose.yml` to match the game you are running.

### Volumes

The container requires a volume mount for the `/config` directory, which stores:

- **Server/** - Base game files downloaded by SteamCMD (auto-created)
- **Overlay/** - Custom files that overlay on top of the game directory
- **Merged/** - OverlayFS merged view (auto-created)
- **Scripts/** - Custom PowerShell scripts for hooks

**Example:**
```yaml
volumes:
  - "/data/Servers/MyGame:/config"
```

The host path can be:
- An absolute path (Windows: `C:\data\...`, Linux: `/data/...`)
- A relative path (e.g., `./config:/config`)
- A named volume (e.g., `game-server-data:/config`)

**Important:** The mounted directory must be writable by the container.

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `STEAM_APP_ID` | Steam App ID of the game server to install | *(empty)* | Yes |
| `STEAM_APP_UPDATE` | Enable automatic updates on startup | `true` | No |
| `STEAM_BRANCH` | Steam beta branch name | *(empty)* | No |
| `STEAM_BRANCH_PASSWORD` | Password for the beta branch | *(empty)* | No |
| `STEAM_VALIDATE` | Validate game files on install/update | `true` | No |
| `STEAM_USERNAME` | Steam account username | `anonymous` | No |
| `STEAM_PASSWORD` | Steam account password | *(empty)* | No |
| `STEAMCMD_ARGS` | Additional arguments passed to SteamCMD | *(empty)* | No |
| `START_EXE` | Executable to run after installation | *(empty)* | No |
| `START_ARGS` | Arguments passed to the server executable | *(empty)* | No |

### Authentication

Most dedicated server apps are available anonymously. For games that require a Steam account:

```yaml
environment:
  STEAM_APP_ID: "some_app_id"
  STEAM_USERNAME: "your_steam_username"
  STEAM_PASSWORD: "your_steam_password"
```

**Note:** Use environment secrets or a `.env` file rather than embedding credentials directly in `docker-compose.yml`.

### Security Options

The container requires elevated privileges to use OverlayFS for file overlaying.

#### `cap_add: SYS_ADMIN`

Adds the `SYS_ADMIN` capability, which is required for mounting OverlayFS. This is the recommended approach as it provides minimal necessary privileges.

```yaml
cap_add:
  - SYS_ADMIN
```

#### `security_opt: apparmor:unconfined`

On Ubuntu hosts with AppArmor enabled, you may need to disable AppArmor restrictions for the container. This is often necessary for OverlayFS to function properly.

```yaml
security_opt:
  - apparmor:unconfined
```

**Alternative Options:**

If you prefer less security but simpler configuration, you can use privileged mode:

```yaml
privileged: true
```

**Note:** Privileged mode grants the container extensive access to the host system and is less secure than using `cap_add: SYS_ADMIN`.

### Restart Policy

```yaml
restart: unless-stopped
```

This ensures the container automatically restarts if it stops unexpectedly, but won't restart if you manually stop it.

**Other options:**
- `no` - Never restart
- `always` - Always restart, even after manual stop
- `on-failure` - Restart only on failure

## Directory Structure

The `/config` directory contains the following structure:

```
/config/
├── Server/              # Game files from SteamCMD (auto-created)
├── Overlay/             # Custom files overlay (your modifications)
├── Merged/              # OverlayFS merged view (auto-created)
├── .overlay-work/       # OverlayFS work directory (auto-created)
└── Scripts/
    └── Hooks/           # Custom PowerShell scripts for hooks
```

## OverlayFS

The container uses Linux OverlayFS to merge the base game files with your custom files:

- **Lower layer**: `/config/Server` (base game files from SteamCMD)
- **Upper layer**: `/config/Overlay` (your custom files)
- **Merged view**: `/config/Merged` (where the game server runs from)

**Benefits:**
- Replace files without modifying the base installation
- Add custom content (maps, plugins, configs)
- No file copying required - OverlayFS is a union filesystem
- Easy updates - base game files can be updated without losing customizations

If OverlayFS cannot be mounted (e.g., missing privileges), the container will fall back to using `/config/Server` directly and log a warning.

## Troubleshooting

### Container Won't Start

1. **Check logs:**
   ```bash
   docker logs game-server
   ```

2. **Verify permissions:**
   Ensure the mounted volume is writable:
   ```bash
   # Linux
   chmod -R 755 "/data/Servers/MyGame"
   ```

3. **Check security options:**
   Ensure `cap_add: SYS_ADMIN` is set, or use `privileged: true`

### Game Server Not Starting

1. **Verify STEAM_APP_ID:**
   Ensure `STEAM_APP_ID` is set to a valid Steam App ID.

2. **Check server directory:**
   Verify that game files were downloaded:
   ```bash
   docker exec game-server ls -la /config/Server
   ```

3. **Review server logs:**
   Check container logs for server startup messages and errors.

### SteamCMD Download Failures

1. **Check network access:**
   Ensure the container can reach Steam's servers.

2. **Verify credentials:**
   For non-anonymous apps, double-check `STEAM_USERNAME` and `STEAM_PASSWORD`.

3. **Try disabling validation:**
   Set `STEAM_VALIDATE=false` if validation is causing repeated re-downloads.

### OverlayFS Warnings

If you see warnings about OverlayFS:

1. **Verify capabilities:**
   Ensure `cap_add: SYS_ADMIN` is present in your docker-compose.yml

2. **Check AppArmor:**
   On Ubuntu, add `security_opt: apparmor:unconfined`

3. **Alternative:**
   Use `privileged: true` (less secure but simpler)

### Port Already in Use

If you get port binding errors:

1. **Check for existing containers:**
   ```bash
   docker ps -a
   ```

2. **Use different ports:**
   Change the port mapping in docker-compose.yml:
   ```yaml
   ports:
     - 27016:27015/udp  # Use a different host port
   ```

3. **Stop conflicting containers:**
   ```bash
   docker stop <container-name>
   ```

## Advanced Usage

### Custom Hooks

You can create custom PowerShell scripts that execute at various points in the container's lifecycle. Place scripts in:

```
/config/Scripts/Hooks/{HookName}/
```

**Available hooks:**
- `PreSteamInstallGame` - Before SteamCMD downloads/updates the game
- `PostSteamInstallGame` - After the game is installed or updated

**Example hook script** (`/config/Scripts/Hooks/PostSteamInstallGame/10-CustomSetup.ps1`):
```powershell
Write-Host "Running custom post-install setup..."
# Your custom commands here
```

## Additional Resources

- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [SteamDB App ID Search](https://steamdb.info/)
