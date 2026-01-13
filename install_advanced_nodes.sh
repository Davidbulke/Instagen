#!/bin/bash
cd /home/david/Documents/InstaGen/ComfyUI/custom_nodes

echo "Installing face consistency nodes..."
git clone https://github.com/cubiq/ComfyUI_InstantID.git
git clone https://github.com/cubiq/PuLID_ComfyUI.git
git clone https://github.com/cubiq/ComfyUI_essentials.git

echo "Installing character consistency..."
git clone https://github.com/ZHO-ZHO-ZHO/ComfyUI-PhotoMaker-ZHO.git

echo "Installing body control..."
git clone https://github.com/storyicon/comfyui_segment_anything.git

echo "Installing prompt tools..."
git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git

echo "Done! Restart ComfyUI to use new nodes."
