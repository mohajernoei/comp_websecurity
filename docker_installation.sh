#!/usr/bin/env bash

set -euo pipefail

usage() {
cat <<'EOF'

install-docker.sh

Linux:
- Ubuntu/Debian: installs Docker Engine via Docker apt repo
- Fedora: installs Docker Engine via Docker dnf repo

macOS:
- Installs Docker Desktop; if you don't provide a Docker.dmg, it will auto-download one

Windows:
- Prints the official command-line install command for Docker Desktop (you still must download the .exe)

Examples:
sudo ./install-docker.sh
./install-docker.sh --mac-dmg /path/to/Docker.dmg

EOF
}

MAC_DMG="${DOCKER_DMG:-}"

if [[ "${1:-}" == "--help" ]]; then usage; exit 0; fi
if [[ "${1:-}" == "--mac-dmg" ]]; then MAC_DMG="${2:-}"; shift 2; fi

need_root_linux() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root on Linux (e.g., sudo $0)"; exit 1
  fi
}

install_linux_ubuntu_debian() {
  need_root_linux
  apt-get update -y
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker.service containerd.service
  systemctl restart docker.service containerd.service
  echo "Docker installed. Test with: sudo docker run --rm hello-world"
}

install_linux_fedora() {
  need_root_linux
  dnf -y install dnf-plugins-core
  dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
  dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker.service containerd.service
  systemctl restart docker.service containerd.service
  echo "Docker installed. Test with: sudo docker run --rm hello-world"
}

install_macos_desktop() {
  # Auto-download Docker.dmg if not provided
  if [[ -z "${MAC_DMG:-}" || ! -f "${MAC_DMG:-}" ]]; then
    arch="$(uname -m)"
    tmp_dmg="/tmp/Docker.dmg"

    if [[ "$arch" == "arm64" ]]; then
      dmg_url="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    else
      dmg_url="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
    fi

    echo "macOS detected. Downloading Docker Desktop DMG for ${arch}..."
    curl -L --fail --retry 3 -o "$tmp_dmg" "$dmg_url"
    MAC_DMG="$tmp_dmg"
  fi

  # Docker's documented CLI install flow: attach DMG, run install binary, detach volume
  # https://docs.docker.com/desktop/setup/install/mac-install/ [page:2]
  sudo hdiutil attach "$MAC_DMG"
  sudo /Volumes/Docker/Docker.app/Contents/MacOS/install
  sudo hdiutil detach /Volumes/Docker

  echo "Docker Desktop installed. Launch /Applications/Docker.app once to finish setup."
}

windows_instructions() {
cat <<'EOF'
Windows detected.

Docker Desktop is installed with the downloaded installer.
Official command line install after downloading "Docker Desktop Installer.exe":

PowerShell (run as admin):
  Start-Process 'Docker Desktop Installer.exe' -Wait install

CMD:
  start /w "" "Docker Desktop Installer.exe" install
EOF
}

OS="$(uname -s)"
case "${OS}" in
  Darwin)
    install_macos_desktop
    ;;
  Linux)
    . /etc/os-release
    case "${ID}" in
      ubuntu|debian) install_linux_ubuntu_debian ;;
      fedora) install_linux_fedora ;;
      *)
        echo "Linux distro not supported by this script (ID=${ID}). See Docker docs: https://docs.docker.com/engine/install/"
        exit 2
        ;;
    esac
    ;;
  MINGW*|MSYS*|CYGWIN*)
    windows_instructions
    ;;
  *)
    echo "Unsupported OS: ${OS}"
    exit 2
    ;;
esac

