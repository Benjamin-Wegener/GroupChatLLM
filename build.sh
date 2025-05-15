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
FAST_MODE=1
CLEAN_MODE=0

# Parse arguments
for arg in "$@"; do
  case $arg in
    --clean|-c)
      CLEAN_MODE=1
      ;;
    --no-fast)
      FAST_MODE=0
      ;;
  esac
  shift
done

# Map internal targets to Debian architectures
declare -A TARGETS=(
  ["cross-aarch64"]="arm64"
)
declare -A FRIENDLY_NAMES=(
  ["cross-aarch64"]="ARM64 Linux"
)

print_banner() {
  echo -e "\n${BLUE}==============================================="
  echo "      🧠 GroupChatLLM - Fast Build Mode"
  echo "        Powered by ik_llama.cpp"
  echo "===============================================${NC}\n"
}

cleanup_previous() {
  if [[ $CLEAN_MODE -eq 0 ]]; then
    log_warn "🐞 Skipping full cleanup (use --clean to force)"
    return
  fi
  log_info "🔍 Checking for previous mounts..."
  sudo umount -l "$CHROOT_DIR/mnt/project" 2>/dev/null || true
  sudo rm -rf "$CHROOT_DIR"
  log_success "✅ Cleaned previous chroot."
}

clear
print_banner

log_info "🛠️ Installing host tools..."
sudo apt update
sudo apt install -y debootstrap schroot qemu-user-static binfmt-support

for TARGET in "${!TARGETS[@]}"; do
  ARCH="${TARGETS[$TARGET]}"
  NAME="${FRIENDLY_NAMES[$TARGET]}"

  log_info "🌿 Building: $NAME"
  cleanup_previous

  if [[ ! -d "$CHROOT_DIR" ]]; then
    log_info "🏠 Creating chroot for $ARCH..."
    sudo debootstrap --arch=$ARCH --foreign $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
    sudo cp /usr/bin/qemu-aarch64-static "$CHROOT_DIR/usr/bin/"
    sudo chroot "$CHROOT_DIR" /debootstrap/debootstrap --second-stage
    echo "deb http://deb.debian.org/debian $DISTRO main" | sudo tee "$CHROOT_DIR/etc/apt/sources.list"
  fi

  log_info "🔗 Binding project directory..."
  sudo mkdir -p "$CHROOT_DIR/mnt/project"
  sudo mount --bind "$TARGET_DIR" "$CHROOT_DIR/mnt/project"

  log_info "📁 Copying build script..."
  sudo cp ./chroot_build_inside.sh "$CHROOT_DIR/tmp/build_inside.sh"
  sudo chmod +x "$CHROOT_DIR/tmp/build_inside.sh"

  log_info "📦 Installing dependencies inside chroot..."
  sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y crossbuild-essential-arm64 cmake build-essential git libopenblas-dev"

  log_info "⚙️ Running build..."
  sudo chroot "$CHROOT_DIR" bash -c "/tmp/build_inside.sh $TARGET"

  log_info "🔍 Locating server binary..."
  SERVER_BIN=$(find "$CHROOT_DIR/mnt/project/build-$TARGET/bin" -name 'llama-server' -type f -executable 2>/dev/null | head -n1)
  CLI_BIN=$(find "$CHROOT_DIR/mnt/project/build-$TARGET/bin" -name 'llama-cli' -type f -executable 2>/dev/null | head -n1)

  mkdir -p ./bin/$TARGET
  [[ -n "$SERVER_BIN" ]] && sudo cp "$SERVER_BIN" ./bin/$TARGET/llama-server && sudo chmod +x ./bin/$TARGET/llama-server
  [[ -n "$CLI_BIN" ]] && sudo cp "$CLI_BIN" ./bin/$TARGET/llama-cli && sudo chmod +x ./bin/$TARGET/llama-cli

  log_success "✅ Binaries copied to ./bin/$TARGET"

  read -p "🧹 Do you want to unmount and clean the chroot? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo umount -l "$CHROOT_DIR/mnt/project"
    sudo umount -l "$CHROOT_DIR/dev" || true
    sudo umount -l "$CHROOT_DIR/proc" || true
    sudo umount -l "$CHROOT_DIR/sys" || true
    log_success "✅ Chroot unmounted and cleaned."
  else
    log_warn "⚠️ Chroot still mounted. You may unmount manually later."
  fi

done

log_success "🎉 Done!"
