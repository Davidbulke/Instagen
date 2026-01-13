#!/bin/bash
# Instaraw V2.0 - RunPod Auto-Install Script (Private Repo Version)
# Usage: GITHUB_TOKEN=your_token bash runpod_install.sh

set -e
cd /workspace

echo "🚀 Instaraw V2.0 - RunPod Deployment"
echo "===================================="
echo ""

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "⚠️  WARNING: GITHUB_TOKEN not set!"
    echo "For private repos, set your token:"
    echo "export GITHUB_TOKEN=ghp_your_token_here"
    echo ""
    echo "Continuing with public clone attempt..."
fi

# Check CUDA
echo "[0/6] Verifying CUDA..."
if ! nvidia-smi > /dev/null 2>&1; then
    echo "❌ ERROR: CUDA not available!"
    exit 1
fi
echo "✅ GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
echo ""

# Install ComfyUI
echo "[1/6] Installing ComfyUI..."
if [ ! -d "ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    pip install -q -r requirements.txt
    pip install -q torch torchvision --index-url https://download.pytorch.org/whl/cu121
else
    echo "ComfyUI already exists, skipping..."
    cd ComfyUI
fi
echo ""

# Clone workflows
echo "[2/6] Cloning workflows from GitHub..."
if [ ! -d "workflows/v2" ]; then
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Using GitHub token for private repo..."
        git clone https://${GITHUB_TOKEN}@github.com/Davidbulke/Instagen.git temp
    else
        echo "Attempting public clone..."
        git clone https://github.com/Davidbulke/Instagen.git temp || {
            echo "❌ ERROR: Clone failed! Repo is private."
            echo ""
            echo "SOLUTION 1: Use GitHub Token"
            echo "  export GITHUB_TOKEN=ghp_your_token_here"
            echo "  bash runpod_install.sh"
            echo ""
            echo "SOLUTION 2: Make repo public temporarily"
            echo "  GitHub → Settings → Change visibility → Public"
            echo ""
            echo "SOLUTION 3: Upload workflows manually"
            echo "  Upload runpod_workflows.tar.gz to RunPod"
            echo "  tar -xzf runpod_workflows.tar.gz"
            exit 1
        }
    fi
    mkdir -p workflows
    cp -r temp/workflows/v2 workflows/
    rm -rf temp
    echo "✅ Cloned 14 workflows"
else
    echo "Workflows already exist, skipping..."
fi
echo ""

# Install custom nodes
echo "[3/6] Installing custom nodes..."
cd custom_nodes

nodes=(
    "https://github.com/ltdrdata/ComfyUI-Manager.git"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    "https://github.com/WASasquatch/was-node-suite-comfyui.git"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"
    "https://github.com/cubiq/ComfyUI_InstantID.git"
    "https://github.com/ZHO-ZHO-ZHO/ComfyUI-PhotoMaker-ZHO.git"
    "https://github.com/huchenlei/ComfyUI_segment_anything.git"
    "https://github.com/jags111/efficiency-nodes-comfyui.git"
    "https://github.com/kijai/ComfyUI-Florence2.git"
    "https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git"
    "https://github.com/Zuellni/ComfyUI-Custom-Scripts.git"
    "https://github.com/giriss/comfy-image-saver.git"
)

for repo in "${nodes[@]}"; do
    dir=$(basename "$repo" .git)
    if [ ! -d "$dir" ]; then
        echo "Installing $dir..."
        git clone -q "$repo" || echo "Failed to clone $repo"
    fi
done

# Install dependencies
echo "Installing node dependencies..."
for dir in */; do
    if [ -f "$dir/requirements.txt" ]; then
        pip install -q -r "$dir/requirements.txt" 2>/dev/null || true
    fi
done
echo ""

# Download models
cd /workspace/ComfyUI/models
echo "[4/6] Downloading models (19.5GB)..."
echo "This will take 3-5 minutes..."

mkdir -p checkpoints loras

# Download checkpoints in parallel
cd checkpoints
if [ ! -f "realvisxl_v40_bakedvae.safetensors" ]; then
    echo "Downloading RealVisXL V4.0 (6.5GB)..."
    wget -q --show-progress "https://civitai.com/api/download/models/501240" -O realvisxl_v40_bakedvae.safetensors &
fi

if [ ! -f "ponydiffusion_v6xl.safetensors" ]; then
    echo "Downloading PonyDiffusion V6 (6.5GB)..."
    wget -q --show-progress "https://civitai.com/api/download/models/290640" -O ponydiffusion_v6xl.safetensors &
fi

if [ ! -f "bigLust_v16.safetensors" ]; then
    echo "Downloading BigLust v1.6 (6.5GB)..."
    wget -q --show-progress "https://civitai.com/api/download/models/1018066" -O bigLust_v16.safetensors &
fi

wait

# Download LoRAs
cd ../loras
if [ ! -f "instagirl_wan22_v25.safetensors" ]; then
    echo "Downloading WAN 2.2 v2.5 LoRA (2.3GB)..."
    wget -q --show-progress "https://huggingface.co/allyourtech/instagirl/resolve/main/Instagirlv2.5-LOW.safetensors" -O instagirl_wan22_v25.safetensors
fi

echo ""

# Verify installation
cd /workspace/ComfyUI
echo "[5/6] Verifying installation..."
echo "CUDA: $(python -c 'import torch; print(torch.cuda.is_available())')"
echo "GPU: $(python -c 'import torch; print(torch.cuda.get_device_name(0))')"
echo "Workflows: $(ls workflows/v2/*.json 2>/dev/null | wc -l)"
echo "Checkpoints: $(ls models/checkpoints/*.safetensors 2>/dev/null | wc -l)"
echo "LoRAs: $(ls models/loras/*.safetensors 2>/dev/null | wc -l)"
echo ""

# Create start script
cat > /workspace/start_comfyui.sh << 'SCRIPT'
#!/bin/bash
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
SCRIPT
chmod +x /workspace/start_comfyui.sh

echo "[6/6] Setup complete!"
echo ""
echo "================================"
echo "✅ INSTALLATION SUCCESSFUL!"
echo "================================"
echo ""
echo "🌐 Start ComfyUI:"
echo "   /workspace/start_comfyui.sh"
echo ""
echo "📁 Workflows: /workspace/ComfyUI/workflows/v2/"
echo "🎯 Test: Load 02_wan22_complete.json"
echo ""
echo "🚀 Access ComfyUI at:"
echo "   http://$(hostname -I | awk '{print $1}'):8188"
echo "   Or use RunPod's HTTP Service [Port 8188]"
echo ""
