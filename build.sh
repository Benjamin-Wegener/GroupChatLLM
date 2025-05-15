#!/bin/bash
set -e

# === Color Definitions ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error()   { echo -e "${RED}❌ $1${NC}"; }

# === CONFIG ===
CHROOT_DIR="$HOME/groupchatllm-chroot"
TARGET_DIR="$HOME/GroupChatLLM"
DISTRO="bookworm"

declare -A TARGETS=(["cross-aarch64"]="arm64")
declare -A FRIENDLY_NAMES=(["cross-aarch64"]="ARM64 Linux")

CLEAN_MODE=0

for arg in "$@"; do
  [[ "$arg" == "--clean" ]] && CLEAN_MODE=1
done

print_banner() {
  echo -e "\n${BLUE}==============================================="
  echo "      🧠 GroupChatLLM - Fast Server Build"
  echo "         Powered by ik_llama.cpp"
  echo "===============================================${NC}\n"
}

cleanup_previous() {
  log_info "🔍 Checking for existing mounts..."
  if mountpoint -q "$CHROOT_DIR/mnt/project"; then
    log_warn "🧹 Forcing unmount of previous project bind mount..."
    sudo umount -l "$CHROOT_DIR/mnt/project" || log_error "❌ Failed to unmount"
    sync && sleep 1
  fi

  if [[ $CLEAN_MODE -eq 1 && -d "$CHROOT_DIR" ]]; then
    log_warn "🗑️ Removing old chroot directory: $CHROOT_DIR"
    sudo rm -rf "$CHROOT_DIR"
    sync && sleep 1
  fi

  log_success "✅ Cleanup (if any) completed."
}

clear
print_banner
read -p "🚀 Continue? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "🚫 Aborted." && exit 1

log_info "🛠️ Installing host tools (debootstrap, qemu)..."
sudo apt update
sudo apt install -y debootstrap schroot qemu-user-static binfmt-support

for TARGET in "${!TARGETS[@]}"; do
  DEB_ARCH="${TARGETS[$TARGET]}"
  FRIENDLY_NAME="${FRIENDLY_NAMES[$TARGET]}"

  log_info "🏗️ Building: $TARGET ($FRIENDLY_NAME)"
  cleanup_previous

  if [[ ! -d "$CHROOT_DIR" ]]; then
    log_info "🏡 Creating chroot for $DEB_ARCH..."
    if [[ "$DEB_ARCH" == "arm64" ]]; then
      sudo systemctl restart systemd-binfmt.service
      sudo debootstrap --arch=$DEB_ARCH --foreign $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
      sudo mkdir -p "$CHROOT_DIR/usr/bin"
      sudo cp /usr/bin/qemu-aarch64-static "$CHROOT_DIR/usr/bin/"
      sudo chroot "$CHROOT_DIR" /debootstrap/debootstrap --second-stage
      echo "deb http://deb.debian.org/debian $DISTRO main" | sudo tee "$CHROOT_DIR/etc/apt/sources.list"
    else
      sudo debootstrap --arch=$DEB_ARCH $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
    fi
  fi

  log_info "🔗 Mounting project..."
  sudo mkdir -p "$CHROOT_DIR/mnt/project"
  sudo mount --bind "$TARGET_DIR" "$CHROOT_DIR/mnt/project"

  log_info "📦 Installing chroot build dependencies..."
  sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y crossbuild-essential-arm64 cmake build-essential git libopenblas-dev"

  log_info "⚙️ Running build inside chroot..."
  sudo cp ./chroot_build_inside.sh "$CHROOT_DIR/tmp/build_inside.sh"
  sudo chmod +x "$CHROOT_DIR/tmp/build_inside.sh"
  sudo chroot "$CHROOT_DIR" bash -c "/tmp/build_inside.sh $TARGET"
  BUILD_STATUS=$?

  if [[ $BUILD_STATUS -ne 0 ]]; then
    log_error "❌ Build failed for target: $TARGET"
    exit $BUILD_STATUS
  fi

  read -p "🧹 Unmount and clean chroot? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "🧹 Cleaning up mount..."
    sudo umount -l "$CHROOT_DIR/mnt/project"
    sudo umount -l "$CHROOT_DIR/dev"
    sudo umount -l "$CHROOT_DIR/proc"
    sudo umount -l "$CHROOT_DIR/sys"
    log_success "✅ Unmounted and cleaned."
  else
    log_warn "⚠️ Chroot left mounted. Clean manually if needed."
  fi

  log_success "🎉 Done building for $TARGET"
done
