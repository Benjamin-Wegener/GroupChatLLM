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

# Map internal targets to Debian architectures (x64 and ARM64 only)
declare -A TARGETS=(
  ["native"]="amd64"
  ["cross-aarch64"]="arm64"
  ["cross-mingw64"]="amd64"
)

# Friendly names for logs
declare -A FRIENDLY_NAMES=(
  ["native"]="Native x86_64 Linux"
  ["cross-aarch64"]="ARM64 Linux"
  ["cross-mingw64"]="Windows x86_64"
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
    sudo umount -l "$CHROOT_DIR/mnt/project" || log_error "❌ Failed to unmount"
    sync && sleep 1
  fi

  if [[ -d "$CHROOT_DIR" ]]; then
    log_warn "🗑️ Removing old chroot directory: $CHROOT_DIR"
    sync && sleep 1  # Give kernel a moment to flush and finalize unmount
    sudo rm -rf "$CHROOT_DIR"
  fi

  log_success "✅ Cleanup completed."
}

clear
print_banner

read -p "🚀 Continue? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "🚫 Aborted." && exit 1

log_info "🛠️ Installing host tools (debootstrap, schroot, qemu)..."
sudo apt update
sudo apt install -y debootstrap schroot qemu-user-static binfmt-support

for TARGET in "${!TARGETS[@]}"; do
  DEB_ARCH="${TARGETS[$TARGET]}"
  FRIENDLY_NAME="${FRIENDLY_NAMES[$TARGET]}"

  log_info "🏗️ Building: $TARGET ($FRIENDLY_NAME)"

  cleanup_previous
  log_info "🏡 Creating chroot for $DEB_ARCH..."
  
  if [[ "$DEB_ARCH" == "arm64" ]]; then
    log_info "🔄 Setting up QEMU for ARM64 emulation..."
    # Enable binfmt support
    sudo systemctl restart systemd-binfmt.service
    
    # Use --foreign mode for initial stage
    sudo debootstrap --arch=$DEB_ARCH --foreign $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
    
    # Copy qemu binary inside chroot
    sudo mkdir -p "$CHROOT_DIR/usr/bin"
    sudo cp /usr/bin/qemu-aarch64-static "$CHROOT_DIR/usr/bin/" || {
      log_error "❌ Failed to copy qemu-aarch64-static. Is qemu-user-static installed?"
      exit 1
    }
    
    # Complete second stage of debootstrap
    log_info "🔄 Running second stage of debootstrap..."
    sudo chroot "$CHROOT_DIR" /debootstrap/debootstrap --second-stage
    
    # Update apt sources
    echo "deb http://deb.debian.org/debian $DISTRO main" | sudo tee "$CHROOT_DIR/etc/apt/sources.list"
  else
    # For native architecture, proceed normally
    sudo debootstrap --arch=$DEB_ARCH $DISTRO "$CHROOT_DIR" http://deb.debian.org/debian
  fi

  log_info "🔗 Mounting project..."
  sudo mkdir -p "$CHROOT_DIR/mnt/project"
  sudo mount --bind "$TARGET_DIR" "$CHROOT_DIR/mnt/project"

  log_info "📄 Copying build script..."
  sudo cp ./chroot_build_inside.sh "$CHROOT_DIR/tmp/build_inside.sh"
  sudo chmod +x "$CHROOT_DIR/tmp/build_inside.sh"

  log_info "📦 Installing dependencies..."
  case "$TARGET" in
    cross-mingw64)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y mingw-w64 cmake build-essential git"
      ;;
    cross-aarch64)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y crossbuild-essential-arm64 cmake build-essential git"
      ;;
    native)
      sudo chroot "$CHROOT_DIR" bash -c "apt update && apt install -y cmake build-essential git"
      ;;
    *)
      log_error "❌ Unknown target: $TARGET"
      exit 1
      ;;
  esac

  log_info "⚙️ Running build inside chroot..."
  sudo chroot "$CHROOT_DIR" bash -c "/tmp/build_inside.sh $TARGET"
  BUILD_STATUS=$?
  if [[ $BUILD_STATUS -ne 0 ]]; then
    log_error "❌ Build failed for target: $TARGET"
    exit $BUILD_STATUS
  fi

  log_info "🧹 Cleaning up mount..."
  sudo umount -l "$CHROOT_DIR/mnt/project"
  sync && sleep 1

  log_info "📤 Copying output binary..."
  BIN_NAME="llama-server-$TARGET"
  OUTPUT_DIR="./bin/$TARGET"
  mkdir -p "$OUTPUT_DIR"
  
  # Try more specific server binary locations first with better error handling
  SERVER_BIN=""
  POSSIBLE_PATHS=(
    "$CHROOT_DIR/mnt/project/build-$TARGET/bin/llama-server"
    "$CHROOT_DIR/mnt/project/build-$TARGET/bin/server"
    "$CHROOT_DIR/mnt/project/build-$TARGET/server/llama-server"
    "$CHROOT_DIR/mnt/project/build-$TARGET/server/server"
  )
  
  # Check Windows binary path separately
  if [[ "$TARGET" == "cross-mingw64" ]]; then
    POSSIBLE_PATHS+=("$CHROOT_DIR/mnt/project/build-$TARGET/bin/llama-server.exe")
  fi
  
  # Try to find the binary in the known locations
  for path in "${POSSIBLE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
      SERVER_BIN="$path"
      log_info "🔍 Found server binary at: $path"
      break
    fi
  done
  
  # If not found in expected locations, do a broader search
  if [[ -z "$SERVER_BIN" ]]; then
    log_warn "⚠️ Server binary not found in expected locations, performing broader search..."
    SERVER_BIN=$(find "$CHROOT_DIR/mnt/project/build-$TARGET" -name "llama-server*" -type f -executable 2>/dev/null || echo "")
    
    if [[ -n "$SERVER_BIN" ]]; then
      log_info "🔍 Found server binary at: $SERVER_BIN"
    else
      log_error "❌ Could not find llama-server binary. Build may have succeeded but binary is missing."
      exit 1
    fi
  fi
  
  sudo cp "$SERVER_BIN" "$OUTPUT_DIR/$BIN_NAME"
  sudo chmod +x "$OUTPUT_DIR/$BIN_NAME"

  log_success "📦 Binary available at: $OUTPUT_DIR/$BIN_NAME"
done

log_success "🎉 All targets built successfully!"
