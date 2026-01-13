#!/bin/bash
cd /home/david/Documents/InstaGen/ComfyUI/custom_nodes

echo "Installing Caption Generation nodes..."
git clone https://github.com/kijai/ComfyUI-Florence2.git
git clone https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git

echo "Installing RPG (Reality Prompt Generator)..."
git clone https://github.com/Anibaaal/ComfyUI-RPG.git

echo "Installing NanoBanana nodes..."
git clone https://github.com/nanowell/ComfyUI-NanoBanana.git

echo "Installing ZImage nodes..."
git clone https://github.com/ZHO-ZHO-ZHO/ComfyUI-Z-Image.git

echo "Installing Efficiency Nodes..."
git clone https://github.com/jags111/efficiency-nodes-comfyui.git

echo "Installing additional detailer nodes..."
git clone https://github.com/Bing-su/adetailer.git

echo "Done! Restart ComfyUI to use new nodes."
