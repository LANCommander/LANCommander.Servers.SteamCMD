#!/usr/bin/env bash
set -euo pipefail

log() { echo "[SteamCMD] $*"; }

STEAMCMD_USER="steamcmd"
STEAMCMD_BIN="/opt/steamcmd/steamcmd.sh"

: "${CONFIG_DIR:=/config}"
: "${OVERLAY_DIR:=/config/overlay}"
: "${GAME_DIR:=/config/game}"
: "${MERGED_DIR:=/config/merged}"
: "${HOOK_DIR:=/config/hooks}"
: "${STEAM_APP_ID:=}"
: "${STEAM_APP_UPDATE:=true}"
: "${STEAM_BETA:=}"
: "${STEAMCMD_ARGS:=}"

ensure_dirs() {
  mkdir -p "${CONFIG_DIR}" "${OVERLAY_DIR}" "${GAME_DIR}" "${MERGED_DIR}" "${HOOK_DIR}"
}

setup_overlayfs() {
  # Check if overlay directory has any content
  if [[ -z "$(ls -A "${OVERLAY_DIR}" 2>/dev/null)" ]]; then
    log "Overlay directory is empty, skipping overlayfs setup"
    return 0
  fi

  log "Setting up overlayfs to merge game files with overlay directory"
  log "NOTE: Container needs --cap-add SYS_ADMIN or --privileged for overlayfs"
  
  # Create workdir for overlayfs (required by overlayfs)
  local workdir="${CONFIG_DIR}/.overlay-work"
  mkdir -p "${workdir}"
  
  # Mount overlayfs: lower=${GAME_DIR}, upper=${OVERLAY_DIR}, workdir=${workdir}, merged=${MERGED_DIR}
  # Note: This requires SYS_ADMIN capability or --privileged
  if mount -t overlay overlay \
    -o lowerdir="${GAME_DIR}",upperdir="${OVERLAY_DIR}",workdir="${workdir}" \
    "${MERGED_DIR}" 2>/dev/null; then
    log "Overlayfs mounted successfully at ${MERGED_DIR}"
    log "  Lower (game files): ${GAME_DIR}"
    log "  Upper (overlay): ${OVERLAY_DIR}"
    log "  Merged view: ${MERGED_DIR}"
  else
    log "WARNING: Failed to mount overlayfs. Falling back to direct game directory."
    log "  Container may need --cap-add SYS_ADMIN or --privileged flag"
    # Create symlinks as fallback (less ideal, but works without privileges)
    if [[ ! -L "${MERGED_DIR}" ]]; then
      rm -rf "${MERGED_DIR}"
      ln -sf "${GAME_DIR}" "${MERGED_DIR}"
    fi
  fi
}

run_hooks() {
  local stage="${1:-}"
  local hook_stage_dir="${HOOK_DIR}"
  
  # If a stage is specified, look for hooks in a stage-specific subdirectory
  if [[ -n "${stage}" ]]; then
    hook_stage_dir="${HOOK_DIR}/${stage}"
  fi
  
  # Check if hook directory exists
  if [[ ! -d "${hook_stage_dir}" ]]; then
    return 0
  fi
  
  # Find all executable scripts in the hook directory
  local hooks
  readarray -t hooks < <(find "${hook_stage_dir}" -maxdepth 1 -type f -executable 2>/dev/null | sort)
  
  if [[ ${#hooks[@]} -eq 0 ]]; then
    return 0
  fi
  
  local stage_label="${stage:+${stage} }"
  log "Running ${stage_label}hooks from ${hook_stage_dir}..."
  
  for hook in "${hooks[@]}"; do
    log "  Executing hook: $(basename "${hook}")"
    if "${hook}"; then
      log "  Hook $(basename "${hook}") completed successfully"
    else
      log "  WARNING: Hook $(basename "${hook}") exited with non-zero status"
    fi
  done
  
  log "${stage_label}Hooks completed"
}

run_autoexec() {
  local autoexec="${CONFIG_DIR}/autoexec.sh"
  if [[ -f "${autoexec}" ]] && [[ -x "${autoexec}" ]]; then
    log "Executing ${autoexec}..."
    "${autoexec}"
    log "autoexec.sh completed"
  elif [[ -f "${autoexec}" ]]; then
    log "autoexec.sh found but not executable, making it executable..."
    chmod +x "${autoexec}"
    "${autoexec}"
    log "autoexec.sh completed"
  fi
}

update_game() {
  if [[ "${STEAM_APP_UPDATE}" != "true" ]] && [[ "${STEAM_APP_UPDATE}" != "1" ]]; then
    log "Automatic updates disabled (STEAM_APP_UPDATE=${STEAM_APP_UPDATE}), skipping update"
    return 0
  fi

  if [[ -z "${STEAM_APP_ID}" ]]; then
    log "WARNING: STEAM_APP_ID is not set, skipping game update"
    return 0
  fi

  log "Updating game server (App ID: ${STEAM_APP_ID})..."
  
  # Best-effort ownership fix for mounted volume
  chown -R "${STEAMCMD_USER}:${STEAMCMD_USER}" "${CONFIG_DIR}" "${GAME_DIR}" "${HOOK_DIR}" \
    >/dev/null 2>&1 || true

  # Ensure SteamCMD home directory exists and is writable
  local steam_home="/home/${STEAMCMD_USER}"
  mkdir -p "${steam_home}/Steam" "${steam_home}/.steam"
  chown -R "${STEAMCMD_USER}:${STEAMCMD_USER}" "${steam_home}" \
    >/dev/null 2>&1 || true

  # First, let SteamCMD update itself (this prevents self-update errors during game download)
  log "Updating SteamCMD..."
  gosu "${STEAMCMD_USER}" \
    env HOME="${steam_home}" \
    bash -c "cd /opt/steamcmd && ${STEAMCMD_BIN} +@sSteamCmdForcePlatformType linux +quit" || true

  # Wait a moment for SteamCMD to finish its update
  sleep 2

  # Now run steamcmd to install/update the game
  # +@sSteamCmdForcePlatformType linux - Force Linux platform
  # +force_install_dir forces the installation directory
  # +login anonymous - Login as anonymous user
  # +app_update downloads/updates the app (with optional -beta branch)
  # +quit exits steamcmd after update
  log "Downloading/updating game server..."
  
  # Build app_update command with optional beta branch
  local app_update_cmd="+app_update ${STEAM_APP_ID}"
  if [[ -n "${STEAM_BETA}" ]]; then
    app_update_cmd="${app_update_cmd} -beta ${STEAM_BETA}"
    log "  Using beta branch: ${STEAM_BETA}"
  fi
  app_update_cmd="${app_update_cmd} validate"
  
  gosu "${STEAMCMD_USER}" \
    env HOME="${steam_home}" \
    bash -c "cd /opt/steamcmd && ${STEAMCMD_BIN} +@sSteamCmdForcePlatformType linux +force_install_dir '${GAME_DIR}' +login anonymous ${app_update_cmd} +quit"

  log "Game update completed"
}

run_server() {
  # Determine which directory to use (merged if overlayfs worked, otherwise game)
  local server_dir="${GAME_DIR}"
  if mountpoint -q "${MERGED_DIR}" 2>/dev/null; then
    server_dir="${MERGED_DIR}"
    log "Using merged directory with overlayfs: ${server_dir}"
  else
    log "Using game directory: ${server_dir}"
  fi

  # Change to server directory
  cd "${server_dir}"

  log "Starting game server"
  log "  App ID: ${STEAM_APP_ID}"
  log "  Game dir: ${server_dir}"
  log "  Config dir: ${CONFIG_DIR}"

  # Execute the remaining arguments as the server command
  # If STEAMCMD_ARGS is set, use it; otherwise use any arguments passed to entrypoint
  if [[ -n "${STEAMCMD_ARGS}" ]]; then
    log "  Server args: ${STEAMCMD_ARGS}"
    exec gosu "${STEAMCMD_USER}" sh -c "${STEAMCMD_ARGS}"
  elif [[ $# -gt 0 ]]; then
    log "  Server command: $*"
    exec gosu "${STEAMCMD_USER}" "$@"
  else
    log "ERROR: No server command provided. Set STEAMCMD_ARGS or pass command as arguments."
    log "Example: STEAMCMD_ARGS='./srcds_run -game csgo -console'"
    exit 1
  fi
}

main() {
  ensure_dirs

  # Best-effort ownership fix for mounted volumes
  chown -R "${STEAMCMD_USER}:${STEAMCMD_USER}" "${CONFIG_DIR}" "${OVERLAY_DIR}" "${GAME_DIR}" "${HOOK_DIR}" \
    >/dev/null 2>&1 || true

  # Run pre-autoexec hooks
  run_hooks "pre-autoexec"
  
  # Run hooks from base hook directory (for backward compatibility)
  run_hooks

  # Execute autoexec.sh if it exists
  run_autoexec

  # Run post-autoexec hooks
  run_hooks "post-autoexec"

  # Run pre-update hooks
  run_hooks "pre-update"

  # Update game if enabled
  update_game

  # Run post-update hooks
  run_hooks "post-update"

  # Setup overlayfs if overlay directory has content
  setup_overlayfs

  # Run pre-server hooks
  run_hooks "pre-server"

  # Run the server
  run_server "$@"
}

main "$@"
