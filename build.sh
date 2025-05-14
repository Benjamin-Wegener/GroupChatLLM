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

print_banner() {
  echo -e "\n${BLUE}==============================================="
  echo "      🧠 GroupChatLLM - Multiarch Build"
  echo "         Powered by ik_llama.cpp"
  echo "===============================================${NC}\n"
}

# === CONFIG ===
CHROOT_DIR="$HOME/groupchatllm-chroot"
TARGET_DIR="$HOME/GroupChatLLM"
DISTRO="bookworm"

# Map internal targets to Debian architectures
declare -A TARGETS=(
  ["native"]="amd64"
  ["cross-aarch64"]="arm64"
  ["cross-i386"]="i386"
  ["cross-mingw64"]="amd64"
  ["cross-mingw32"]="i386"
)

# Friendly names for logs
declare -A FRIENDLY_NAMES=(
  ["native"]="Native x86_64 Linux"
  ["cross-aarch64"]="ARM64 Linux"
  ["cross-i386"]="32-bit i386 Linux"
  ["cross-mingw64"]="Windows x86_64"
  ["cross-mingw32"]="Windows i686 (32-bit)"
)

# Optional debug mode
DEBUG_MODE=0
for arg in "$@"; do
  [[ "$arg" == "--debug" || "$arg" == "-d" ]] && DEBUG_MODE=1 && log_warn "🐞 Debug mode: Skipping cleanup"
done

cleanup_previous() {
  if [[ $DEBUG_MODE -eq 1 ]]; then
    log_warn "🐞 Debug mode: Skipping cleanup"
    return
  fi

  log_info "🔍 Checking for existing mounts..."

  if mountpoint -q "$CHROOT_DIR/mnt/project"; then
    log_warn "🧹 Forcing unmount of previous project bind mount..."
    sudo umount -l "$CHROOT_DIR/mnt/project" || log_error "Failed to unmount"
  fi

  if [[ -d "$CHROOT_DIR" ]]; then
    log_warn "🗑️ Removing old chroot directory: $CHROOT_DIR"
    sudo rm -rf "$CHROOT_DIR"
  fi

  log_success "✅ Cleanup completed."
}

clear
print_banner

read -p "🚀 Continue? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "🚫 Aborted." && exit 1

log_info "🛠️ Installing host tools (debootstrap, schroot)..."
sudo apt update
sudo apt install -y debootstrap schroot

for TARGET in "${!TARGETS[@]}"; do
  DEB_ARCH="${TARGETS[$TARGET]}"
  FRIENDLY_NAME="${FRIENDLY_NAMES[$TARGET]}"

  log_info "🏗️ Building: $TARGET ($FRIENDLY_NAME)"

  if [[ $DEBUG_MODE -eq 0 ]]; then
    cleanup_previous
    log_info "🏡 Creating chroot for $DEB_ARCH..."
    sudo debootstrap --arch=$DEB_ARCH $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
  elif [[ ! -d "$CHROOT_DIR" ]]; then
    log_info "📦 Creating new chroot (debug mode)"
    sudo debootstrap --arch=$DEB_ARCH $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
  fi

  log_info "🔧 Setting up locale..."
  sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y locales && locale-gen en_US.UTF-8"

  log_info "🔗 Mounting project..."
  sudo mkdir -p "$CHROOT_DIR/mnt/project"
  sudo mount --bind "$TARGET_DIR" "$CHROOT_DIR/mnt/project"

  log_info "📄 Copying build script..."
  sudo cp ./chroot_build_inside.sh "$CHROOT_DIR/tmp/build_inside.sh"
  sudo chmod +x "$CHROOT_DIR/tmp/build_inside.sh"

  log_info "📦 Installing dependencies..."
  case "$TARGET" in
    cross-mingw64|cross-mingw32)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y mingw-w64 cmake build-essential git"
      ;;
    cross-aarch64)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y crossbuild-essential-arm64 cmake build-essential git"
      ;;
    cross-i386)
      sudo chroot "$CHROOT_DIR" bash -c "dpkg --add-architecture i386 && apt update && apt install -y crossbuild-essential-i386 cmake build-essential git"
      ;;
    native)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y cmake build-essential git"
      ;;
    *)
      log_error "Unknown target: $TARGET"
      exit 1
      ;;
  esac

  log_info "⚙️ Running build inside chroot..."
  sudo chroot "$CHROOT_DIR" /tmp/build_inside.sh "$TARGET"

  if [[ $DEBUG_MODE -eq 0 ]]; then
    log_info "🧹 Cleaning up mount..."
    sudo umount "$CHROOT_DIR/mnt/project"
  else
    log_warn "🐞 Debug mode: Skipping mount unmount"
  fi

  log_info "📤 Copying output binary..."
  BIN_NAME="llama-server-$TARGET"
  OUTPUT_DIR="./bin/$TARGET"
  mkdir -p "$OUTPUT_DIR"

  sudo cp "$CHROOT_DIR/mnt/project/build-$TARGET/bin/llama-server" "$OUTPUT_DIR/$BIN_NAME"
  chmod +x "$OUTPUT_DIR/$BIN_NAME"

  log_success "📦 Binary available at: $OUTPUT_DIR/$BIN_NAME"
done

log_success "🎉 All targets built successfully!"
