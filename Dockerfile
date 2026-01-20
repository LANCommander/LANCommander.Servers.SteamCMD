# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim

# Runtime directories (mount these as volumes)
ENV CONFIG_DIR=/config
ENV OVERLAY_DIR=/config/overlay
ENV GAME_DIR=/config/game

# SteamCMD settings
ENV STEAM_APP_ID=""
ENV STEAM_APP_UPDATE="true"
ENV STEAM_BETA=""
ENV STEAMCMD_ARGS=""

# ----------------------------
# Dependencies
# ----------------------------
# Enable multiarch for 32-bit libraries (required for SteamCMD)
RUN dpkg --add-architecture i386 && \
  apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    gzip \
    gosu \
    lib32gcc-s1 \
    lib32stdc++6 \
    libc6-i386 \
  && rm -rf /var/lib/apt/lists/*

# Install SteamCMD
RUN set -eux; \
  mkdir -p /opt/steamcmd && \
  curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -o /tmp/steamcmd.tar.gz && \
  tar -xzf /tmp/steamcmd.tar.gz -C /opt/steamcmd && \
  rm -f /tmp/steamcmd.tar.gz && \
  chmod +x /opt/steamcmd/steamcmd.sh && \
  find /opt/steamcmd -type f -name "steamcmd" -exec chmod +x {} \;

# ----------------------------
# Create a non-root user
# ----------------------------
RUN useradd -m -u 10001 -s /usr/sbin/nologin steamcmd \
  && mkdir -p "${CONFIG_DIR}" "${OVERLAY_DIR}" "${GAME_DIR}" \
  && chown -R steamcmd:steamcmd "${CONFIG_DIR}" /opt/steamcmd

# ----------------------------
# Entrypoint
# ----------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/config"]

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]