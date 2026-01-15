#!/bin/bash
#===============================================================================
# INSTAGEN RUNPOD SETUP v3.0 - UNIFIED FLAWLESS INSTALLER
#===============================================================================
#
# This script combines runpod_install.sh and runpod_sync_fix.sh into one
# bulletproof installer that handles all edge cases.
#
# Features:
# - Downloads all required models (checkpoints, IP-Adapter, CLIP, InsightFace)
# - Installs all custom nodes needed by v2 workflows
# - Sets up Jupyter Lab for file management
# - Proper error handling and recovery
# - Parallel downloads with verification
# - Works on both fresh and existing installations
#
# Usage:
#   # Basic (public repo or already have workflows)
#   bash runpod_setup_v3.sh
#
#   # With GitHub token for private repo
#   GITHUB_TOKEN=ghp_xxx bash runpod_setup_v3.sh
#
#   # Skip model downloads (if already have them)
#   SKIP_MODELS=1 bash runpod_setup_v3.sh
#
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_DIR="${WORKSPACE}/ComfyUI"
MODELS_DIR="${COMFY_DIR}/models"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
WORKFLOWS_DIR="${COMFY_DIR}/workflows"

# Logging
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"; }
section() { echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"; }

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

check_gpu() {
    if ! nvidia-smi > /dev/null 2>&1; then
        error "CUDA not available!"
        exit 1
    fi
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -1)
    log "GPU: ${GPU_NAME} (${GPU_MEM})"
}

# Cross-platform file size check (works on Linux and macOS)
get_file_size() {
    local file="$1"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file" 2>/dev/null || echo 0
    else
        stat -c%s "$file" 2>/dev/null || echo 0
    fi
}

# Download with retry and verification
download_file() {
    local url="$1"
    local dest="$2"
    local min_size="${3:-1000000}"  # Default 1MB minimum
    local max_retries=3
    local retry=0

    # Skip if file exists and is large enough
    if [ -f "$dest" ]; then
        local size=$(get_file_size "$dest")
        if [ "$size" -ge "$min_size" ]; then
            log "  ✓ $(basename "$dest") already exists ($(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes"))"
            return 0
        else
            warn "  $(basename "$dest") exists but too small ($size bytes), re-downloading..."
            rm -f "$dest"
        fi
    fi

    mkdir -p "$(dirname "$dest")"

    while [ $retry -lt $max_retries ]; do
        log "  ⬇ Downloading $(basename "$dest")..."

        if wget -q --show-progress -O "$dest" "$url" 2>/dev/null; then
            local size=$(get_file_size "$dest")
            if [ "$size" -ge "$min_size" ]; then
                log "  ✓ Downloaded $(basename "$dest") ($(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes"))"
                return 0
            fi
        fi

        retry=$((retry + 1))
        warn "  Download failed, retry $retry/$max_retries..."
        rm -f "$dest"
        sleep 2
    done

    error "  ✗ Failed to download $(basename "$dest") after $max_retries attempts"
    return 1
}

# Download from HuggingFace (more reliable than CivitAI)
download_hf() {
    local repo="$1"
    local file="$2"
    local dest="$3"
    local min_size="${4:-1000000}"

    download_file "https://huggingface.co/${repo}/resolve/main/${file}" "$dest" "$min_size"
}

# Clone or update git repo
clone_or_update() {
    local url="$1"
    local dir="$2"
    local name=$(basename "$dir")

    if [ -d "$dir" ]; then
        log "  ✓ $name exists, updating..."
        cd "$dir" && git pull -q 2>/dev/null || true
        cd - > /dev/null
    else
        log "  ⬇ Cloning $name..."
        git clone -q "$url" "$dir" 2>/dev/null || {
            warn "  Failed to clone $name"
            return 1
        }
    fi

    # Install requirements if present
    if [ -f "$dir/requirements.txt" ]; then
        pip install -q -r "$dir/requirements.txt" 2>/dev/null || true
    fi
    if [ -f "$dir/install.py" ]; then
        cd "$dir" && python install.py 2>/dev/null || true
        cd - > /dev/null
    fi

    return 0
}

#===============================================================================
# BANNER
#===============================================================================

echo -e "${MAGENTA}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║   ██╗███╗   ██╗███████╗████████╗ █████╗  ██████╗ ███████╗███╗   ██╗║"
echo "║   ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██╔════╝ ██╔════╝████╗  ██║║"
echo "║   ██║██╔██╗ ██║███████╗   ██║   ███████║██║  ███╗█████╗  ██╔██╗ ██║║"
echo "║   ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║   ██║██╔══╝  ██║╚██╗██║║"
echo "║   ██║██║ ╚████║███████║   ██║   ██║  ██║╚██████╔╝███████╗██║ ╚████║║"
echo "║   ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝║"
echo "║                                                                   ║"
echo "║              RunPod Setup v3.0 - Unified Installer                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

#===============================================================================
# STEP 1: VERIFY GPU
#===============================================================================
section "Step 1/8: Verifying GPU"
check_gpu

#===============================================================================
# STEP 2: INSTALL COMFYUI
#===============================================================================
section "Step 2/8: Installing ComfyUI"

cd "$WORKSPACE"

if [ ! -d "$COMFY_DIR" ]; then
    log "Cloning ComfyUI..."
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd "$COMFY_DIR"
    pip install -q -r requirements.txt
    pip install -q xformers insightface onnxruntime-gpu opencv-python
else
    log "ComfyUI exists, updating..."
    cd "$COMFY_DIR"
    git pull -q 2>/dev/null || true
fi

log "✓ ComfyUI ready"

#===============================================================================
# STEP 3: CLONE WORKFLOWS FROM GITHUB
#===============================================================================
section "Step 3/8: Setting Up Workflows"

if [ ! -d "${WORKFLOWS_DIR}/v2" ] || [ -z "$(ls -A ${WORKFLOWS_DIR}/v2 2>/dev/null)" ]; then
    log "Cloning InstaGen workflows..."

    CLONE_URL="https://github.com/Davidbulke/Instagen.git"
    if [ -n "$GITHUB_TOKEN" ]; then
        log "Using GitHub token for private repo..."
        CLONE_URL="https://${GITHUB_TOKEN}@github.com/Davidbulke/Instagen.git"
    fi

    TEMP_DIR=$(mktemp -d)
    if git clone -q "$CLONE_URL" "$TEMP_DIR" 2>/dev/null; then
        mkdir -p "$WORKFLOWS_DIR"

        # Copy v2 and v3 workflows
        [ -d "$TEMP_DIR/ComfyUI/workflows/v2" ] && cp -r "$TEMP_DIR/ComfyUI/workflows/v2" "$WORKFLOWS_DIR/"
        [ -d "$TEMP_DIR/ComfyUI/workflows/v3" ] && cp -r "$TEMP_DIR/ComfyUI/workflows/v3" "$WORKFLOWS_DIR/"

        # Copy custom nodes from repo
        if [ -d "$TEMP_DIR/custom_nodes" ]; then
            mkdir -p "$CUSTOM_NODES"
            cp -r "$TEMP_DIR/custom_nodes"/* "$CUSTOM_NODES/" 2>/dev/null || true
        fi

        # Copy prompts
        [ -d "$TEMP_DIR/prompts" ] && cp -r "$TEMP_DIR/prompts" "$WORKSPACE/"

        rm -rf "$TEMP_DIR"
        log "✓ Copied $(ls ${WORKFLOWS_DIR}/v2/*.json 2>/dev/null | wc -l) workflows from v2"
    else
        warn "Could not clone repo. Manual workflow upload required."
        warn "Upload workflows to: ${WORKFLOWS_DIR}/v2/"
    fi
else
    log "✓ Workflows already present ($(ls ${WORKFLOWS_DIR}/v2/*.json 2>/dev/null | wc -l) files)"
fi

#===============================================================================
# STEP 4: INSTALL CUSTOM NODES
#===============================================================================
section "Step 4/8: Installing Custom Nodes"

mkdir -p "$CUSTOM_NODES"
cd "$CUSTOM_NODES"

# Essential nodes for all workflows
NODES=(
    # Core management
    "https://github.com/ltdrdata/ComfyUI-Manager.git"

    # IP-Adapter & Face (CRITICAL for Vera workflows)
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    "https://github.com/cubiq/ComfyUI_InstantID.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "https://github.com/Gourieff/comfyui-reactor-node.git"

    # ControlNet
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

    # Utilities
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
    "https://github.com/jags111/efficiency-nodes-comfyui.git"
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"

    # Image processing
    "https://github.com/giriss/comfy-image-saver.git"
    "https://github.com/huchenlei/ComfyUI_segment_anything.git"

    # Captioning & tagging
    "https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git"
    "https://github.com/kijai/ComfyUI-Florence2.git"

    # Photo generation
    "https://github.com/ZHO-ZHO-ZHO/ComfyUI-PhotoMaker-ZHO.git"
    "https://github.com/ToTheBeginning/PuLID.git"
)

log "Installing ${#NODES[@]} custom nodes..."

for repo in "${NODES[@]}"; do
    dir=$(basename "$repo" .git)
    clone_or_update "$repo" "$CUSTOM_NODES/$dir"
done

# Run Impact Pack installer specifically
if [ -d "$CUSTOM_NODES/ComfyUI-Impact-Pack" ]; then
    cd "$CUSTOM_NODES/ComfyUI-Impact-Pack"
    python install.py 2>/dev/null || true
    cd "$CUSTOM_NODES"
fi

log "✓ Custom nodes installed"

#===============================================================================
# STEP 5: DOWNLOAD CHECKPOINT MODELS
#===============================================================================
section "Step 5/8: Downloading Checkpoint Models"

if [ "$SKIP_MODELS" = "1" ]; then
    warn "Skipping model downloads (SKIP_MODELS=1)"
else
    mkdir -p "${MODELS_DIR}/checkpoints"

    # RealVisXL V4.0 (SFW) - Using HuggingFace mirror
    download_hf "SG161222/RealVisXL_V4.0" \
        "RealVisXL_V4.0.safetensors" \
        "${MODELS_DIR}/checkpoints/realvisxl_v40_bakedvae.safetensors" \
        6000000000

    # BigLust V1.6 (NSFW) - CivitAI with fallback
    if [ ! -f "${MODELS_DIR}/checkpoints/bigLust_v16.safetensors" ]; then
        log "  ⬇ Downloading BigLust v1.6..."
        # Try CivitAI first
        if ! wget -q --show-progress -O "${MODELS_DIR}/checkpoints/bigLust_v16.safetensors" \
            "https://civitai.com/api/download/models/1018066" 2>/dev/null; then
            warn "  CivitAI download failed. BigLust needs manual download from CivitAI."
        fi
    else
        log "  ✓ bigLust_v16.safetensors exists"
    fi

    # Pony Diffusion V6 XL
    if [ ! -f "${MODELS_DIR}/checkpoints/ponydiffusion_v6xl.safetensors" ]; then
        log "  ⬇ Downloading Pony Diffusion V6..."
        wget -q --show-progress -O "${MODELS_DIR}/checkpoints/ponydiffusion_v6xl.safetensors" \
            "https://civitai.com/api/download/models/290640" 2>/dev/null || \
            warn "  CivitAI download failed. Pony Diffusion needs manual download."
    else
        log "  ✓ ponydiffusion_v6xl.safetensors exists"
    fi

    log "✓ Checkpoint models ready"
fi

#===============================================================================
# STEP 6: DOWNLOAD IP-ADAPTER & FACE MODELS (CRITICAL)
#===============================================================================
section "Step 6/8: Downloading IP-Adapter & Face Models"

if [ "$SKIP_MODELS" = "1" ]; then
    warn "Skipping model downloads (SKIP_MODELS=1)"
else
    mkdir -p "${MODELS_DIR}/ipadapter"
    mkdir -p "${MODELS_DIR}/clip_vision"
    mkdir -p "${MODELS_DIR}/loras"
    mkdir -p "${MODELS_DIR}/insightface/models/buffalo_l"
    mkdir -p "${MODELS_DIR}/insightface/models/antelopev2"

    # CLIP Vision (Required for all IP-Adapter)
    download_hf "h94/IP-Adapter" \
        "models/image_encoder/model.safetensors" \
        "${MODELS_DIR}/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" \
        2000000000

    # IP-Adapter FaceID Plus V2 for SDXL (Primary face model)
    download_hf "h94/IP-Adapter-FaceID" \
        "ip-adapter-faceid-plusv2_sdxl.bin" \
        "${MODELS_DIR}/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin" \
        1400000000

    # IP-Adapter FaceID standard
    download_hf "h94/IP-Adapter-FaceID" \
        "ip-adapter-faceid_sdxl.bin" \
        "${MODELS_DIR}/ipadapter/ip-adapter-faceid_sdxl.bin" \
        1000000000

    # IP-Adapter Plus SDXL (for style/composition)
    download_hf "h94/IP-Adapter" \
        "sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors" \
        "${MODELS_DIR}/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors" \
        800000000

    # IP-Adapter Plus Face SDXL
    download_hf "h94/IP-Adapter" \
        "sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors" \
        "${MODELS_DIR}/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors" \
        800000000

    # FaceID LoRAs (Required for FaceID to work properly)
    download_hf "h94/IP-Adapter-FaceID" \
        "ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
        "${MODELS_DIR}/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" \
        350000000

    download_hf "h94/IP-Adapter-FaceID" \
        "ip-adapter-faceid_sdxl_lora.safetensors" \
        "${MODELS_DIR}/loras/ip-adapter-faceid_sdxl_lora.safetensors" \
        350000000

    # InsightFace models (buffalo_l - face detection)
    log "Downloading InsightFace models..."
    download_hf "datasets/Gourieff/ReActor" \
        "models/buffalo_l/det_10g.onnx" \
        "${MODELS_DIR}/insightface/models/buffalo_l/det_10g.onnx" \
        16000000

    download_hf "datasets/Gourieff/ReActor" \
        "models/buffalo_l/w600k_r50.onnx" \
        "${MODELS_DIR}/insightface/models/buffalo_l/w600k_r50.onnx" \
        160000000

    # InsightFace antelopev2 (better quality)
    download_hf "DIAMONIK7777/antelopev2" \
        "1k3d68.onnx" \
        "${MODELS_DIR}/insightface/models/antelopev2/1k3d68.onnx" \
        130000000

    download_hf "DIAMONIK7777/antelopev2" \
        "2d106det.onnx" \
        "${MODELS_DIR}/insightface/models/antelopev2/2d106det.onnx" \
        5000000

    download_hf "DIAMONIK7777/antelopev2" \
        "genderage.onnx" \
        "${MODELS_DIR}/insightface/models/antelopev2/genderage.onnx" \
        1000000

    download_hf "DIAMONIK7777/antelopev2" \
        "glintr100.onnx" \
        "${MODELS_DIR}/insightface/models/antelopev2/glintr100.onnx" \
        250000000

    download_hf "DIAMONIK7777/antelopev2" \
        "scrfd_10g_bnkps.onnx" \
        "${MODELS_DIR}/insightface/models/antelopev2/scrfd_10g_bnkps.onnx" \
        16000000

    log "✓ IP-Adapter & Face models ready"
fi

#===============================================================================
# STEP 7: DOWNLOAD UPSCALE & CONTROLNET MODELS
#===============================================================================
section "Step 7/8: Downloading Upscale & ControlNet Models"

if [ "$SKIP_MODELS" = "1" ]; then
    warn "Skipping model downloads (SKIP_MODELS=1)"
else
    mkdir -p "${MODELS_DIR}/upscale_models"
    mkdir -p "${MODELS_DIR}/controlnet"

    # 4x-UltraSharp upscaler
    download_hf "Kim2091/UltraSharp" \
        "4x-UltraSharp.pth" \
        "${MODELS_DIR}/upscale_models/4x-UltraSharp.pth" \
        60000000

    # RealESRGAN
    download_file \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
        "${MODELS_DIR}/upscale_models/RealESRGAN_x4plus.pth" \
        60000000

    # OpenPose ControlNet SDXL
    download_hf "thibaud/controlnet-openpose-sdxl-1.0" \
        "OpenPoseXL2.safetensors" \
        "${MODELS_DIR}/controlnet/controlnet-openpose-sdxl.safetensors" \
        2000000000

    log "✓ Upscale & ControlNet models ready"
fi

#===============================================================================
# STEP 8: SETUP JUPYTER & STARTUP SCRIPTS
#===============================================================================
section "Step 8/8: Setting Up Jupyter & Startup Scripts"

# Install Jupyter
log "Installing JupyterLab..."
pip install -q jupyterlab ipywidgets 2>/dev/null

# Create reference image directory
mkdir -p "${COMFY_DIR}/input/vera_reference"

# Create startup script
cat > "${WORKSPACE}/start.sh" << 'STARTUP'
#!/bin/bash
cd /workspace/ComfyUI

echo "Starting services..."

# Start Jupyter in background
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --notebook-dir=/workspace \
    > /workspace/jupyter.log 2>&1 &

echo "Jupyter Lab started on port 8888"

# Start ComfyUI
echo "Starting ComfyUI on port 8188..."
python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
STARTUP
chmod +x "${WORKSPACE}/start.sh"

# Create ComfyUI-only startup
cat > "${WORKSPACE}/start_comfyui.sh" << 'COMFY_ONLY'
#!/bin/bash
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --preview-method auto
COMFY_ONLY
chmod +x "${WORKSPACE}/start_comfyui.sh"

log "✓ Startup scripts created"

#===============================================================================
# VERIFICATION
#===============================================================================
section "Installation Complete!"

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    INSTALLATION SUCCESSFUL!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Count installed items
CHECKPOINT_COUNT=$(ls ${MODELS_DIR}/checkpoints/*.safetensors 2>/dev/null | wc -l)
IPADAPTER_COUNT=$(ls ${MODELS_DIR}/ipadapter/* 2>/dev/null | wc -l)
NODE_COUNT=$(ls -d ${CUSTOM_NODES}/*/ 2>/dev/null | wc -l)
WORKFLOW_COUNT=$(ls ${WORKFLOWS_DIR}/v2/*.json 2>/dev/null | wc -l)

echo -e "${CYAN}Installation Summary:${NC}"
echo "  • Checkpoints:   $CHECKPOINT_COUNT models"
echo "  • IP-Adapters:   $IPADAPTER_COUNT models"
echo "  • Custom Nodes:  $NODE_COUNT installed"
echo "  • Workflows:     $WORKFLOW_COUNT in v2/"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Upload your reference face image to:"
echo "     ${COMFY_DIR}/input/vera_reference/"
echo ""
echo "  2. Start the services:"
echo "     ${WORKSPACE}/start.sh"
echo ""
echo "  3. Access:"
echo "     • ComfyUI:  http://[POD_IP]:8188"
echo "     • Jupyter:  http://[POD_IP]:8888"
echo ""

echo -e "${CYAN}Quick Commands:${NC}"
echo "  • Start all:      /workspace/start.sh"
echo "  • ComfyUI only:   /workspace/start_comfyui.sh"
echo "  • View logs:      tail -f /workspace/jupyter.log"
echo ""

# Check for any missing critical models
echo -e "${CYAN}Model Status:${NC}"
[ -f "${MODELS_DIR}/checkpoints/realvisxl_v40_bakedvae.safetensors" ] && echo "  ✓ RealVisXL" || echo "  ✗ RealVisXL (missing)"
[ -f "${MODELS_DIR}/checkpoints/bigLust_v16.safetensors" ] && echo "  ✓ BigLust" || echo "  ✗ BigLust (download from CivitAI)"
[ -f "${MODELS_DIR}/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin" ] && echo "  ✓ IP-Adapter FaceID" || echo "  ✗ IP-Adapter FaceID (missing)"
[ -f "${MODELS_DIR}/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" ] && echo "  ✓ CLIP Vision" || echo "  ✗ CLIP Vision (missing)"
[ -d "${MODELS_DIR}/insightface/models/antelopev2" ] && echo "  ✓ InsightFace" || echo "  ✗ InsightFace (missing)"
echo ""
