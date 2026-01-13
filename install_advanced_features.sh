#!/bin/bash
cd /home/david/Documents/InstaGen/ComfyUI/custom_nodes

echo "Installing prompt management nodes..."
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git

echo "Installing batch processing..."
git clone https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git

echo "Installing inpaint nodes..."
git clone https://github.com/Acly/comfyui-inpaint-nodes.git

echo "Installing image saver with EXIF..."
git clone https://github.com/giriss/comfy-image-saver.git

echo "Done! Restart ComfyUI to use new nodes."
echo ""
echo "Next steps:"
echo "1. Download PonyDiffusionV6XL: https://civitai.com/models/257749"
echo "2. Download Lustify LoRA: https://civitai.com/models/158688"
echo "3. Create prompt library with generate_prompts.py"
echo "4. Build workflows from implementation_plan.md"
