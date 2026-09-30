#!/bin/zsh
# The next site (or the Reclaimer) with no model yet: concept -> TRELLIS -> cleaned -> art/sites/.
# 020: the free Hugging Face allowance covers one or two TRELLIS runs a day, so run this daily.
#
#   tools/gen3d/next_site.sh            # the next missing kind
#   tools/gen3d/next_site.sh tower      # a named kind (again: overwrites it)
#
# Needs a token in ~/.cache/huggingface/token (never printed). Exit 2 = no allowance left today.
cd "$(dirname "$0")/../.." || exit 1
KINDS=(trader start skirmish elite scrapyard tower signal boss reclaimer)
GODOT=/Users/Sergiu/DevG/KingdomRebuilt/Godot.app/Contents/MacOS/Godot
B=https://trellis-community-trellis.hf.space
Q=tools/gen3d/gradio_queue.py
export HF_TOKEN=$(cat ~/.cache/huggingface/token 2>/dev/null)
[ -z "$HF_TOKEN" ] && { echo "no token in ~/.cache/huggingface/token"; exit 1; }
kind=$1
if [ -z "$kind" ]; then
  for k in $KINDS; do [ -f art/sites/$k.glb ] || { kind=$k; break; }; done
fi
[ -z "$kind" ] && { echo "every site has a model"; exit 0; }
[ -f art/concepts/$kind.png ] || { echo "no concept art/concepts/$kind.png"; exit 1; }
work=$(mktemp -d)
up=$(curl -sS -m 120 -H "Authorization: Bearer $HF_TOKEN" -F "files=@art/concepts/$kind.png" "$B/gradio_api/upload")
remote=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])[0])" "$up") || { echo "$kind: upload failed"; exit 1; }
# TRELLIS generates from the background-removed image, so that step's output feeds the next.
pre=$(python3 $Q $B $work/pre "[[\"start_session\", []], [\"preprocess_image\", [{\"path\": \"$remote\", \"meta\": {\"_type\": \"gradio.FileData\"}}]]]" 2>&1 | grep -o '"path": "[^"]*"' | head -1 | sed 's/"path": "//; s/"$//')
[ -z "$pre" ] && { echo "$kind: preprocess failed"; exit 1; }
log=$(python3 $Q $B $work "[[\"start_session\", []], [\"generate_and_extract_glb\", [{\"path\": \"$pre\", \"meta\": {\"_type\": \"gradio.FileData\"}}, [], null, 0, 7.5, 12, 3.0, 12, \"stochastic\", 0.95, 1024]]]" 2>&1)
if echo "$log" | grep -q "quota"; then
  echo "$kind: no GPU allowance left today ($(echo "$log" | grep -o '[0-9]*s requested vs. [0-9]*s left' | head -1))"; exit 2
fi
glb=$(ls $work/*sample.glb 2>/dev/null | head -1)
[ -z "$glb" ] && { echo "$kind: TRELLIS failed"; echo "$log" | tail -3 | cut -c1-300; exit 1; }
size=2.6; [ $kind = boss ] && size=4.2; [ $kind = reclaimer ] && size=5.0
blender --background --python tools/blender/clean_generated.py -- --keep-texture --in $glb \
  --out art/sites/$kind.glb --size $size --budget 12000 --posterize 16 --sharp 45 2>&1 | grep -E "^kept|Error"
$GODOT --headless --path . --import 2>&1 | grep -i "error" | head -3
echo "$kind: on the map (art/sites/$kind.glb)"
