#!/bin/bash
# RunPod Instaraw V2.0 Setup Script

echo "🚀 Installing Instaraw V2.0 on RunPod..."

# Install ComfyUI
cd /workspace
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Install dependencies
pip install -r requirements.txt

# Install custom nodes via Manager
cd custom_nodes
git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# Clone workflows from GitHub
cd /workspace/ComfyUI
git clone https://github.com/Davidbulke/Instagen.git temp
cp -r temp/workflows/v2 workflows/
rm -rf temp

echo "✅ Setup complete! Start ComfyUI with:"
echo "python main.py --listen 0.0.0.0 --port 8188"
