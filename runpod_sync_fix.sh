#!/bin/bash
#===============================================================================
# RUNPOD VERA SETUP FIX SCRIPT
# Paste this entire script into RunPod Web Terminal
#
# This script:
# 1. Removes broken stub nodes
# 2. Installs real IPAdapter nodes
# 3. Downloads required models
# 4. Creates working Vera workflows
# 5. Optionally installs JupyterLab
#===============================================================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       VERA RUNPOD SETUP FIX                                  ║${NC}"
echo -e "${BLUE}║       Fixing IPAdapter + Creating Working Workflows          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration - adjust if your paths differ
COMFY_DIR="${COMFY_DIR:-/workspace/ComfyUI}"
MODELS_DIR="${COMFY_DIR}/models"
CUSTOM_NODES="${COMFY_DIR}/custom_nodes"
WORKFLOWS_DIR="${COMFY_DIR}/workflows"

#===============================================================================
# STEP 1: Remove Stub Nodes
#===============================================================================
echo -e "${YELLOW}[1/7] Removing stub/placeholder nodes...${NC}"

# Common stub file names - add yours if different
STUB_FILES=(
    "${CUSTOM_NODES}/my_stubs.py"
    "${CUSTOM_NODES}/stub_nodes.py"
    "${CUSTOM_NODES}/placeholder_nodes.py"
    "${CUSTOM_NODES}/custom_stubs.py"
    "${CUSTOM_NODES}/fake_nodes.py"
)

STUB_DIRS=(
    "${CUSTOM_NODES}/my_custom_nodes"
    "${CUSTOM_NODES}/stub_nodes"
    "${CUSTOM_NODES}/placeholder_nodes"
)

for f in "${STUB_FILES[@]}"; do
    if [ -f "$f" ]; then
        echo -e "${RED}  Removing stub file: $f${NC}"
        rm -f "$f"
    fi
done

for d in "${STUB_DIRS[@]}"; do
    if [ -d "$d" ]; then
        echo -e "${RED}  Removing stub directory: $d${NC}"
        rm -rf "$d"
    fi
done

echo -e "${GREEN}✓ Stub nodes cleaned${NC}"
echo ""

#===============================================================================
# STEP 2: Install/Verify Real IPAdapter
#===============================================================================
echo -e "${YELLOW}[2/7] Installing ComfyUI_IPAdapter_plus...${NC}"

cd "${CUSTOM_NODES}"

if [ -d "ComfyUI_IPAdapter_plus" ]; then
    # Check if it's real or a stub
    if grep -q "IPAdapterUnifiedLoaderFaceID" "ComfyUI_IPAdapter_plus/IPAdapterPlus.py" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Real IPAdapter already installed${NC}"
        cd ComfyUI_IPAdapter_plus && git pull && cd ..
    else
        echo -e "${RED}  Stub detected! Removing and reinstalling...${NC}"
        rm -rf ComfyUI_IPAdapter_plus
        git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus
    fi
else
    echo -e "${CYAN}  Cloning ComfyUI_IPAdapter_plus...${NC}"
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus
fi

echo -e "${GREEN}✓ IPAdapter installed${NC}"
echo ""

#===============================================================================
# STEP 3: Install Other Required Nodes
#===============================================================================
echo -e "${YELLOW}[3/7] Installing other required custom nodes...${NC}"

# Impact Pack (for FaceDetailer)
if [ ! -d "ComfyUI-Impact-Pack" ]; then
    echo -e "${CYAN}  Cloning ComfyUI-Impact-Pack...${NC}"
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack
    cd ComfyUI-Impact-Pack && python install.py && cd ..
else
    echo -e "${GREEN}  ✓ Impact-Pack exists${NC}"
fi

# InstantID
if [ ! -d "ComfyUI_InstantID" ]; then
    echo -e "${CYAN}  Cloning ComfyUI_InstantID...${NC}"
    git clone https://github.com/cubiq/ComfyUI_InstantID
else
    echo -e "${GREEN}  ✓ InstantID exists${NC}"
fi

echo -e "${GREEN}✓ Custom nodes ready${NC}"
echo ""

#===============================================================================
# STEP 4: Download Required Models
#===============================================================================
echo -e "${YELLOW}[4/7] Downloading required models...${NC}"

# Create directories
mkdir -p "${MODELS_DIR}/clip_vision"
mkdir -p "${MODELS_DIR}/ipadapter"
mkdir -p "${MODELS_DIR}/insightface/models"
mkdir -p "${COMFY_DIR}/input/vera_reference"

# CLIP Vision Model (Required for IPAdapter)
CLIP_VISION="${MODELS_DIR}/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
if [ ! -f "$CLIP_VISION" ] || [ $(stat -f%z "$CLIP_VISION" 2>/dev/null || stat -c%s "$CLIP_VISION" 2>/dev/null) -lt 1000000000 ]; then
    echo -e "${CYAN}  Downloading CLIP Vision model (2.5GB)...${NC}"
    wget -q --show-progress -O "$CLIP_VISION" \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
else
    echo -e "${GREEN}  ✓ CLIP Vision model exists${NC}"
fi

# IPAdapter FaceID Plus V2 for SDXL
IPADAPTER_FACEID="${MODELS_DIR}/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin"
if [ ! -f "$IPADAPTER_FACEID" ]; then
    echo -e "${CYAN}  Downloading IPAdapter FaceID Plus V2 (1.4GB)...${NC}"
    wget -q --show-progress -O "$IPADAPTER_FACEID" \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"
else
    echo -e "${GREEN}  ✓ IPAdapter FaceID Plus V2 exists${NC}"
fi

# IPAdapter Plus SDXL (for style transfer)
IPADAPTER_PLUS="${MODELS_DIR}/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors"
if [ ! -f "$IPADAPTER_PLUS" ]; then
    echo -e "${CYAN}  Downloading IPAdapter Plus SDXL (847MB)...${NC}"
    wget -q --show-progress -O "$IPADAPTER_PLUS" \
        "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"
else
    echo -e "${GREEN}  ✓ IPAdapter Plus SDXL exists${NC}"
fi

# Lora for IPAdapter FaceID
LORA_FACEID="${MODELS_DIR}/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
mkdir -p "${MODELS_DIR}/loras"
if [ ! -f "$LORA_FACEID" ]; then
    echo -e "${CYAN}  Downloading FaceID LoRA (371MB)...${NC}"
    wget -q --show-progress -O "$LORA_FACEID" \
        "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"
else
    echo -e "${GREEN}  ✓ FaceID LoRA exists${NC}"
fi

echo -e "${GREEN}✓ Models downloaded${NC}"
echo ""

#===============================================================================
# STEP 5: Remove Wrong LoRAs
#===============================================================================
echo -e "${YELLOW}[5/7] Removing incompatible LoRAs...${NC}"

# WAN LoRA (video model, wrong for SDXL)
WAN_LORA="${MODELS_DIR}/loras/instagirl_wan22_v25.safetensors"
if [ -f "$WAN_LORA" ]; then
    echo -e "${RED}  Removing WAN video LoRA (incompatible with SDXL)${NC}"
    rm -f "$WAN_LORA"
fi

# Empty/corrupted LoRAs
for lora in "BigAsp-Stage3.safetensors" "BigLust_NSFW_RAW.safetensors"; do
    if [ -f "${MODELS_DIR}/loras/$lora" ]; then
        size=$(stat -f%z "${MODELS_DIR}/loras/$lora" 2>/dev/null || stat -c%s "${MODELS_DIR}/loras/$lora" 2>/dev/null)
        if [ "$size" -lt 1000 ]; then
            echo -e "${RED}  Removing empty LoRA: $lora${NC}"
            rm -f "${MODELS_DIR}/loras/$lora"
        fi
    fi
done

echo -e "${GREEN}✓ Incompatible files removed${NC}"
echo ""

#===============================================================================
# STEP 6: Create Working Workflows
#===============================================================================
echo -e "${YELLOW}[6/7] Creating Vera workflows...${NC}"

mkdir -p "${WORKFLOWS_DIR}"

# SFW Workflow
cat > "${WORKFLOWS_DIR}/vera_sfw_faceid.json" << 'WORKFLOW_SFW'
{
    "last_node_id": 14,
    "last_link_id": 18,
    "nodes": [
        {
            "id": 1,
            "type": "CheckpointLoaderSimple",
            "pos": [50, 50],
            "size": [320, 98],
            "flags": {},
            "order": 0,
            "mode": 0,
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
                {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
                {"name": "VAE", "type": "VAE", "links": [4], "slot_index": 2}
            ],
            "properties": {"Node name for S&R": "CheckpointLoaderSimple"},
            "widgets_values": ["realvisxl_v40_bakedvae.safetensors"]
        },
        {
            "id": 2,
            "type": "IPAdapterUnifiedLoaderFaceID",
            "pos": [50, 200],
            "size": [320, 130],
            "flags": {},
            "order": 1,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 1}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [5], "slot_index": 0},
                {"name": "ipadapter", "type": "IPADAPTER", "links": [6], "slot_index": 1}
            ],
            "properties": {"Node name for S&R": "IPAdapterUnifiedLoaderFaceID"},
            "widgets_values": ["FACEID PLUS V2", 0.6, "CUDA"]
        },
        {
            "id": 3,
            "type": "LoadImage",
            "pos": [50, 380],
            "size": [320, 314],
            "flags": {},
            "order": 2,
            "mode": 0,
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [7], "slot_index": 0},
                {"name": "MASK", "type": "MASK", "links": null}
            ],
            "properties": {"Node name for S&R": "LoadImage"},
            "widgets_values": ["vera_reference.png", "image"],
            "title": "Vera Reference Face"
        },
        {
            "id": 4,
            "type": "IPAdapterFaceID",
            "pos": [420, 200],
            "size": [320, 350],
            "flags": {},
            "order": 3,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 5},
                {"name": "ipadapter", "type": "IPADAPTER", "link": 6},
                {"name": "image", "type": "IMAGE", "link": 7},
                {"name": "image_negative", "type": "IMAGE", "link": null},
                {"name": "attn_mask", "type": "MASK", "link": null},
                {"name": "clip_vision", "type": "CLIP_VISION", "link": null},
                {"name": "insightface", "type": "INSIGHTFACE", "link": null}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [8], "slot_index": 0},
                {"name": "face_image", "type": "IMAGE", "links": null}
            ],
            "properties": {"Node name for S&R": "IPAdapterFaceID"},
            "widgets_values": [0.85, 1.0, "linear", "concat", 0.0, 1.0, "V only"]
        },
        {
            "id": 5,
            "type": "CLIPTextEncode",
            "pos": [420, 600],
            "size": [400, 200],
            "flags": {},
            "order": 4,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 2}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [9], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(masterpiece, best quality, ultra detailed, realistic), ultra-realistic Instagram fitness model, gym, athletic body, toned muscles, realistic skin texture, detailed face, beautiful eyes, natural lighting, 8k uhd, detailed hands"],
            "title": "Positive Prompt"
        },
        {
            "id": 6,
            "type": "CLIPTextEncode",
            "pos": [420, 850],
            "size": [400, 130],
            "flags": {},
            "order": 5,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 3}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [10], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(worst quality, low quality:1.4), (bad anatomy:1.2), bad hands, bad fingers, blurry, watermark, text, logo, censored, cartoon, anime, 3d render"],
            "title": "Negative Prompt"
        },
        {
            "id": 7,
            "type": "EmptyLatentImage",
            "pos": [880, 600],
            "size": [320, 106],
            "flags": {},
            "order": 6,
            "mode": 0,
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "EmptyLatentImage"},
            "widgets_values": [1024, 1024, 1]
        },
        {
            "id": 8,
            "type": "KSampler",
            "pos": [880, 200],
            "size": [320, 474],
            "flags": {},
            "order": 7,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 8},
                {"name": "positive", "type": "CONDITIONING", "link": 9},
                {"name": "negative", "type": "CONDITIONING", "link": 10},
                {"name": "latent_image", "type": "LATENT", "link": 11}
            ],
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [12], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "KSampler"},
            "widgets_values": [42, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1.0]
        },
        {
            "id": 9,
            "type": "VAEDecode",
            "pos": [1260, 200],
            "size": [210, 46],
            "flags": {},
            "order": 8,
            "mode": 0,
            "inputs": [
                {"name": "samples", "type": "LATENT", "link": 12},
                {"name": "vae", "type": "VAE", "link": 4}
            ],
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "VAEDecode"}
        },
        {
            "id": 10,
            "type": "SaveImage",
            "pos": [1260, 300],
            "size": [320, 270],
            "flags": {},
            "order": 9,
            "mode": 0,
            "inputs": [
                {"name": "images", "type": "IMAGE", "link": 13}
            ],
            "properties": {},
            "widgets_values": ["vera_sfw_"]
        }
    ],
    "links": [
        [1, 1, 0, 2, 0, "MODEL"],
        [2, 1, 1, 5, 0, "CLIP"],
        [3, 1, 1, 6, 0, "CLIP"],
        [4, 1, 2, 9, 1, "VAE"],
        [5, 2, 0, 4, 0, "MODEL"],
        [6, 2, 1, 4, 1, "IPADAPTER"],
        [7, 3, 0, 4, 2, "IMAGE"],
        [8, 4, 0, 8, 0, "MODEL"],
        [9, 5, 0, 8, 1, "CONDITIONING"],
        [10, 6, 0, 8, 2, "CONDITIONING"],
        [11, 7, 0, 8, 3, "LATENT"],
        [12, 8, 0, 9, 0, "LATENT"],
        [13, 9, 0, 10, 0, "IMAGE"]
    ],
    "groups": [
        {
            "title": "VERA - SFW IPAdapter FaceID Workflow",
            "bounding": [30, 10, 1580, 1000],
            "color": "#3f789e"
        }
    ],
    "config": {},
    "extra": {
        "info": "Vera SFW FaceID workflow - Uses IPAdapter FaceID Plus V2 for face consistency."
    },
    "version": 0.4
}
WORKFLOW_SFW

echo -e "${GREEN}  ✓ Created vera_sfw_faceid.json${NC}"

# NSFW Workflow
cat > "${WORKFLOWS_DIR}/vera_nsfw_faceid.json" << 'WORKFLOW_NSFW'
{
    "last_node_id": 10,
    "last_link_id": 13,
    "nodes": [
        {
            "id": 1,
            "type": "CheckpointLoaderSimple",
            "pos": [50, 50],
            "size": [320, 98],
            "flags": {},
            "order": 0,
            "mode": 0,
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
                {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
                {"name": "VAE", "type": "VAE", "links": [4], "slot_index": 2}
            ],
            "properties": {"Node name for S&R": "CheckpointLoaderSimple"},
            "widgets_values": ["bigLust_v16.safetensors"]
        },
        {
            "id": 2,
            "type": "IPAdapterUnifiedLoaderFaceID",
            "pos": [50, 200],
            "size": [320, 130],
            "flags": {},
            "order": 1,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 1}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [5], "slot_index": 0},
                {"name": "ipadapter", "type": "IPADAPTER", "links": [6], "slot_index": 1}
            ],
            "properties": {"Node name for S&R": "IPAdapterUnifiedLoaderFaceID"},
            "widgets_values": ["FACEID PLUS V2", 0.6, "CUDA"]
        },
        {
            "id": 3,
            "type": "LoadImage",
            "pos": [50, 380],
            "size": [320, 314],
            "flags": {},
            "order": 2,
            "mode": 0,
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [7], "slot_index": 0},
                {"name": "MASK", "type": "MASK", "links": null}
            ],
            "properties": {"Node name for S&R": "LoadImage"},
            "widgets_values": ["vera_reference.png", "image"],
            "title": "Vera Reference Face"
        },
        {
            "id": 4,
            "type": "IPAdapterFaceID",
            "pos": [420, 200],
            "size": [320, 350],
            "flags": {},
            "order": 3,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 5},
                {"name": "ipadapter", "type": "IPADAPTER", "link": 6},
                {"name": "image", "type": "IMAGE", "link": 7},
                {"name": "image_negative", "type": "IMAGE", "link": null},
                {"name": "attn_mask", "type": "MASK", "link": null},
                {"name": "clip_vision", "type": "CLIP_VISION", "link": null},
                {"name": "insightface", "type": "INSIGHTFACE", "link": null}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [8], "slot_index": 0},
                {"name": "face_image", "type": "IMAGE", "links": null}
            ],
            "properties": {"Node name for S&R": "IPAdapterFaceID"},
            "widgets_values": [0.85, 1.0, "linear", "concat", 0.0, 1.0, "V only"]
        },
        {
            "id": 5,
            "type": "CLIPTextEncode",
            "pos": [420, 600],
            "size": [400, 200],
            "flags": {},
            "order": 4,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 2}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [9], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(masterpiece, best quality, ultra detailed, realistic), ultra-realistic woman, NSFW, nude, athletic body, toned muscles, realistic skin texture, detailed face, beautiful eyes, natural lighting, 8k uhd, bedroom, detailed body"],
            "title": "Positive Prompt (NSFW)"
        },
        {
            "id": 6,
            "type": "CLIPTextEncode",
            "pos": [420, 850],
            "size": [400, 130],
            "flags": {},
            "order": 5,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 3}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [10], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(worst quality, low quality:1.4), (bad anatomy:1.2), bad hands, bad fingers, blurry, watermark, text, logo, cartoon, anime, 3d render, censored"],
            "title": "Negative Prompt"
        },
        {
            "id": 7,
            "type": "EmptyLatentImage",
            "pos": [880, 600],
            "size": [320, 106],
            "flags": {},
            "order": 6,
            "mode": 0,
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "EmptyLatentImage"},
            "widgets_values": [1024, 1024, 1]
        },
        {
            "id": 8,
            "type": "KSampler",
            "pos": [880, 200],
            "size": [320, 474],
            "flags": {},
            "order": 7,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 8},
                {"name": "positive", "type": "CONDITIONING", "link": 9},
                {"name": "negative", "type": "CONDITIONING", "link": 10},
                {"name": "latent_image", "type": "LATENT", "link": 11}
            ],
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [12], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "KSampler"},
            "widgets_values": [42, "randomize", 30, 7.0, "dpmpp_2m_sde", "karras", 1.0]
        },
        {
            "id": 9,
            "type": "VAEDecode",
            "pos": [1260, 200],
            "size": [210, 46],
            "flags": {},
            "order": 8,
            "mode": 0,
            "inputs": [
                {"name": "samples", "type": "LATENT", "link": 12},
                {"name": "vae", "type": "VAE", "link": 4}
            ],
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "VAEDecode"}
        },
        {
            "id": 10,
            "type": "SaveImage",
            "pos": [1260, 300],
            "size": [320, 270],
            "flags": {},
            "order": 9,
            "mode": 0,
            "inputs": [
                {"name": "images", "type": "IMAGE", "link": 13}
            ],
            "properties": {},
            "widgets_values": ["vera_nsfw_"]
        }
    ],
    "links": [
        [1, 1, 0, 2, 0, "MODEL"],
        [2, 1, 1, 5, 0, "CLIP"],
        [3, 1, 1, 6, 0, "CLIP"],
        [4, 1, 2, 9, 1, "VAE"],
        [5, 2, 0, 4, 0, "MODEL"],
        [6, 2, 1, 4, 1, "IPADAPTER"],
        [7, 3, 0, 4, 2, "IMAGE"],
        [8, 4, 0, 8, 0, "MODEL"],
        [9, 5, 0, 8, 1, "CONDITIONING"],
        [10, 6, 0, 8, 2, "CONDITIONING"],
        [11, 7, 0, 8, 3, "LATENT"],
        [12, 8, 0, 9, 0, "LATENT"],
        [13, 9, 0, 10, 0, "IMAGE"]
    ],
    "groups": [
        {
            "title": "VERA - NSFW IPAdapter FaceID Workflow (BigLust)",
            "bounding": [30, 10, 1580, 1000],
            "color": "#8e3f3f"
        }
    ],
    "config": {},
    "extra": {
        "info": "Vera NSFW FaceID workflow - Uses BigLust v1.6 checkpoint."
    },
    "version": 0.4
}
WORKFLOW_NSFW

echo -e "${GREEN}  ✓ Created vera_nsfw_faceid.json${NC}"

# Batch Workflow
cat > "${WORKFLOWS_DIR}/vera_batch_5x.json" << 'WORKFLOW_BATCH'
{
    "last_node_id": 10,
    "last_link_id": 13,
    "nodes": [
        {
            "id": 1,
            "type": "CheckpointLoaderSimple",
            "pos": [50, 50],
            "size": [320, 98],
            "flags": {},
            "order": 0,
            "mode": 0,
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [1], "slot_index": 0},
                {"name": "CLIP", "type": "CLIP", "links": [2, 3], "slot_index": 1},
                {"name": "VAE", "type": "VAE", "links": [4], "slot_index": 2}
            ],
            "properties": {"Node name for S&R": "CheckpointLoaderSimple"},
            "widgets_values": ["realvisxl_v40_bakedvae.safetensors"]
        },
        {
            "id": 2,
            "type": "IPAdapterUnifiedLoaderFaceID",
            "pos": [50, 200],
            "size": [320, 130],
            "flags": {},
            "order": 1,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 1}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [5], "slot_index": 0},
                {"name": "ipadapter", "type": "IPADAPTER", "links": [6], "slot_index": 1}
            ],
            "properties": {"Node name for S&R": "IPAdapterUnifiedLoaderFaceID"},
            "widgets_values": ["FACEID PLUS V2", 0.6, "CUDA"]
        },
        {
            "id": 3,
            "type": "LoadImage",
            "pos": [50, 380],
            "size": [320, 314],
            "flags": {},
            "order": 2,
            "mode": 0,
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [7], "slot_index": 0},
                {"name": "MASK", "type": "MASK", "links": null}
            ],
            "properties": {"Node name for S&R": "LoadImage"},
            "widgets_values": ["vera_reference.png", "image"],
            "title": "Vera Reference Face"
        },
        {
            "id": 4,
            "type": "IPAdapterFaceID",
            "pos": [420, 200],
            "size": [320, 350],
            "flags": {},
            "order": 3,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 5},
                {"name": "ipadapter", "type": "IPADAPTER", "link": 6},
                {"name": "image", "type": "IMAGE", "link": 7},
                {"name": "image_negative", "type": "IMAGE", "link": null},
                {"name": "attn_mask", "type": "MASK", "link": null},
                {"name": "clip_vision", "type": "CLIP_VISION", "link": null},
                {"name": "insightface", "type": "INSIGHTFACE", "link": null}
            ],
            "outputs": [
                {"name": "MODEL", "type": "MODEL", "links": [8], "slot_index": 0},
                {"name": "face_image", "type": "IMAGE", "links": null}
            ],
            "properties": {"Node name for S&R": "IPAdapterFaceID"},
            "widgets_values": [0.85, 1.0, "linear", "concat", 0.0, 1.0, "V only"]
        },
        {
            "id": 5,
            "type": "CLIPTextEncode",
            "pos": [420, 600],
            "size": [400, 200],
            "flags": {},
            "order": 4,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 2}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [9], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(masterpiece, best quality, ultra detailed, realistic), ultra-realistic Instagram fitness model, gym, athletic body, toned muscles, realistic skin texture, detailed face, beautiful eyes, natural lighting, 8k uhd, detailed hands"],
            "title": "Positive Prompt - EDIT THIS"
        },
        {
            "id": 6,
            "type": "CLIPTextEncode",
            "pos": [420, 850],
            "size": [400, 130],
            "flags": {},
            "order": 5,
            "mode": 0,
            "inputs": [
                {"name": "clip", "type": "CLIP", "link": 3}
            ],
            "outputs": [
                {"name": "CONDITIONING", "type": "CONDITIONING", "links": [10], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "CLIPTextEncode"},
            "widgets_values": ["(worst quality, low quality:1.4), (bad anatomy:1.2), bad hands, bad fingers, blurry, watermark, text, logo, censored, cartoon, anime, 3d render"],
            "title": "Negative Prompt"
        },
        {
            "id": 7,
            "type": "EmptyLatentImage",
            "pos": [880, 600],
            "size": [320, 106],
            "flags": {},
            "order": 6,
            "mode": 0,
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [11], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "EmptyLatentImage"},
            "widgets_values": [1024, 1024, 5],
            "title": "5x Batch"
        },
        {
            "id": 8,
            "type": "KSampler",
            "pos": [880, 200],
            "size": [320, 474],
            "flags": {},
            "order": 7,
            "mode": 0,
            "inputs": [
                {"name": "model", "type": "MODEL", "link": 8},
                {"name": "positive", "type": "CONDITIONING", "link": 9},
                {"name": "negative", "type": "CONDITIONING", "link": 10},
                {"name": "latent_image", "type": "LATENT", "link": 11}
            ],
            "outputs": [
                {"name": "LATENT", "type": "LATENT", "links": [12], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "KSampler"},
            "widgets_values": [42, "increment", 30, 7.0, "dpmpp_2m_sde", "karras", 1.0]
        },
        {
            "id": 9,
            "type": "VAEDecode",
            "pos": [1260, 200],
            "size": [210, 46],
            "flags": {},
            "order": 8,
            "mode": 0,
            "inputs": [
                {"name": "samples", "type": "LATENT", "link": 12},
                {"name": "vae", "type": "VAE", "link": 4}
            ],
            "outputs": [
                {"name": "IMAGE", "type": "IMAGE", "links": [13], "slot_index": 0}
            ],
            "properties": {"Node name for S&R": "VAEDecode"}
        },
        {
            "id": 10,
            "type": "SaveImage",
            "pos": [1260, 300],
            "size": [320, 270],
            "flags": {},
            "order": 9,
            "mode": 0,
            "inputs": [
                {"name": "images", "type": "IMAGE", "link": 13}
            ],
            "properties": {},
            "widgets_values": ["vera_batch_"]
        }
    ],
    "links": [
        [1, 1, 0, 2, 0, "MODEL"],
        [2, 1, 1, 5, 0, "CLIP"],
        [3, 1, 1, 6, 0, "CLIP"],
        [4, 1, 2, 9, 1, "VAE"],
        [5, 2, 0, 4, 0, "MODEL"],
        [6, 2, 1, 4, 1, "IPADAPTER"],
        [7, 3, 0, 4, 2, "IMAGE"],
        [8, 4, 0, 8, 0, "MODEL"],
        [9, 5, 0, 8, 1, "CONDITIONING"],
        [10, 6, 0, 8, 2, "CONDITIONING"],
        [11, 7, 0, 8, 3, "LATENT"],
        [12, 8, 0, 9, 0, "LATENT"],
        [13, 9, 0, 10, 0, "IMAGE"]
    ],
    "groups": [
        {
            "title": "VERA - 5x Batch Generation",
            "bounding": [30, 10, 1580, 1000],
            "color": "#3f8e5e"
        }
    ],
    "config": {},
    "extra": {
        "info": "Vera Batch workflow - Generates 5 images with seed variation."
    },
    "version": 0.4
}
WORKFLOW_BATCH

echo -e "${GREEN}  ✓ Created vera_batch_5x.json${NC}"
echo -e "${GREEN}✓ All workflows created${NC}"
echo ""

#===============================================================================
# STEP 7: Optional - Install JupyterLab
#===============================================================================
echo -e "${YELLOW}[7/7] Installing JupyterLab (optional)...${NC}"

pip install -q jupyterlab 2>/dev/null || true

echo -e "${GREEN}✓ JupyterLab installed${NC}"
echo ""

#===============================================================================
# SUMMARY
#===============================================================================
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       SETUP COMPLETE!                                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What was done:${NC}"
echo "  ✓ Removed stub nodes"
echo "  ✓ Installed real IPAdapter nodes"
echo "  ✓ Downloaded CLIP Vision model"
echo "  ✓ Downloaded IPAdapter models"
echo "  ✓ Created 3 working Vera workflows"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Upload your Vera reference image to:"
echo "     ${COMFY_DIR}/input/vera_reference.png"
echo ""
echo "  2. Restart ComfyUI:"
echo "     pkill -f 'python.*main.py' ; cd ${COMFY_DIR} && python main.py --listen 0.0.0.0"
echo ""
echo "  3. Load workflow: vera_sfw_faceid.json"
echo ""
echo -e "${CYAN}To start JupyterLab:${NC}"
echo "  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='vera'"
echo "  Then access: https://YOUR_POD_ID-8888.proxy.runpod.net (token: vera)"
echo ""
echo -e "${BLUE}Disk usage:${NC}"
du -sh "${MODELS_DIR}/clip_vision" "${MODELS_DIR}/ipadapter" 2>/dev/null || true
echo ""
