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
  echo "      🧠 ik_llama.cpp - Bitnet Server Setup"
  echo "         Native Build | ARM64 Optimized"
  echo "===============================================${NC}\n"
}

print_banner
read -p "🚀 Continue? (y/N) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "🚫 Aborted." && exit 1

# === Install Dependencies ===
log_info "🔧 Installing dependencies..."
sudo apt update && sudo apt install -y wget cmake git build-essential libopenblas-dev

# === Clone Repository ===
LLAMA_DIR="$HOME/ik_llama.cpp"
if [ -d "$LLAMA_DIR" ]; then
  log_warn "📁 Existing ik_llama.cpp found. Reusing folder."
else
  log_info "📂 Cloning ik_llama.cpp repository..."
  git clone https://github.com/ikawrakow/ik_llama.cpp.git  "$LLAMA_DIR"
fi

cd "$LLAMA_DIR"

log_info "🔄 Fetching latest changes..."
git pull origin master

# === Build Only the Server ===
log_info "🏗️ Building ik_llama.cpp server..."

mkdir -p build
cd build

cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CUDA=OFF \
  -DGGML_BLAS=ON \
  -DENABLE_SERVER=ON \
  -DENABLE_CLI=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DGGML_ARCH_FLAGS="-march=armv8.2-a+dotprod+fp16" ..

make -j$(nproc)

log_success "🎉 Build complete!"

# === Download Bitnet Model ===
MODEL_DIR="$LLAMA_DIR/models"
MODEL_URL="https://huggingface.co/microsoft/bitnet-b1.58-2B-4T-gguf/resolve/main/ggml-model-i2_s.gguf?download=true "
INPUT_MODEL="$MODEL_DIR/ggml-model-i2_s.gguf"
OUTPUT_MODEL="$MODEL_DIR/bitnet.gguf"

log_info "🧠 Downloading Bitnet GGUF model..."
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"
wget -O "$INPUT_MODEL" "$MODEL_URL"

log_info "⚙️ Requantizing model to iq2_bn_r4 format..."
cd ..
./build/bin/llama-quantize --allow-requantize "$INPUT_MODEL" "$OUTPUT_MODEL" iq2_bn_r4

# === Start Server ===
log_info "⚡ Starting server with MLA mode..."
./build/bin/llama-server -mla 3 --model "$OUTPUT_MODEL"

log_success "🏁 Done!"
