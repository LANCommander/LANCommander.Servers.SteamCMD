# syntax=docker/dockerfile:1.7

FROM lancommander/base:latest

# SteamCMD settings
ENV STEAM_APP_ID=""
ENV STEAM_APP_UPDATE="true"
ENV STEAM_BRANCH=""
ENV STEAM_BRANCH_PASSWORD=""
ENV STEAM_VALIDATE="true"
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
  find /opt/steamcmd -type f -name "steamcmd" -exec chmod +x {} \; && \
  ln -s /opt/steamcmd/linux32/steamcmd /usr/local/bin/steamcmd

COPY Modules/ "${BASE_MODULES}/"
COPY Hooks/ "${BASE_HOOKS}/"

VOLUME ["/config"]

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]