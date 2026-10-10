#!/bin/zsh
# A generated machine part (045): concept -> TRELLIS -> raw kept -> rigged into art/parts_gen_scrap/.
#
#   tools/gen3d/next_part.sh ch_brute_scrap        # TRELLIS (one run of the allowance), then rig
#   tools/gen3d/next_part.sh ch_brute_scrap --rig  # rig again from the kept raw model (no GPU)
#
# The name is the concept's, raw model's and spec's (`ch_brute_scrap`); the part is written
# without the `_scrap` (art/parts_gen_scrap/ch_brute.glb), as the game looks it up.
#
# The concept is art/concepts/machines/<id>.png (the one the user picked from part_concept.sh);
# the rig is told where the hips, sockets and mount are by tools/gen3d/parts/<id>.json
# (tools/blender/rig_generated_part.py). Exit 2 = no allowance left (a rolling 24 h).
cd "$(dirname "$0")/../.." || exit 1
id=$1
part=${id%_scrap}
GODOT=/Users/Sergiu/DevG/KingdomRebuilt/Godot.app/Contents/MacOS/Godot
B=https://trellis-community-trellis.hf.space
Q=tools/gen3d/gradio_queue.py
raw=tools/gen3d/raw/parts/$id.glb
if [ "$2" != "--rig" ]; then
  export HF_TOKEN=$(cat ~/.cache/huggingface/token 2>/dev/null)
  [ -z "$HF_TOKEN" ] && { echo "no token in ~/.cache/huggingface/token"; exit 1; }
  [ -f art/concepts/machines/$id.png ] || { echo "no concept art/concepts/machines/$id.png"; exit 1; }
  work=$(mktemp -d)
  blender --background --python tools/gen3d/cut_background.py -- art/concepts/machines/$id.png $work/concept.png 2>&1 | grep -E "^cut:"
  up=$(curl -sS -m 120 -H "Authorization: Bearer $HF_TOKEN" -F "files=@$work/concept.png" "$B/gradio_api/upload")
  remote=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])[0])" "$up") || { echo "$id: upload failed"; exit 1; }
  for attempt in 1 2; do
    pre=$(STEP_LIMIT=180 python3 $Q $B $work/pre "[[\"start_session\", []], [\"preprocess_image\", [{\"path\": \"$remote\", \"meta\": {\"_type\": \"gradio.FileData\"}}]]]" 2>&1 | grep -o '"path": "[^"]*"' | head -1 | sed 's/"path": "//; s/"$//')
    [ -n "$pre" ] && break
    echo "$id: preprocess did not finish (try $attempt of 2)"
  done
  [ -z "$pre" ] && { echo "$id: preprocess failed"; exit 1; }
  log=$(python3 $Q $B $work "[[\"start_session\", []], [\"generate_and_extract_glb\", [{\"path\": \"$pre\", \"meta\": {\"_type\": \"gradio.FileData\"}}, [], null, 0, 7.5, 12, 3.0, 12, \"stochastic\", 0.95, 1024]]]" 2>&1)
  if echo "$log" | grep -q "quota"; then
    echo "$id: no GPU allowance left ($(echo "$log" | grep -o '[0-9]*s requested vs. [0-9]*s left' | head -1))"; exit 2
  fi
  glb=$(ls $work/*sample.glb 2>/dev/null | head -1)
  [ -z "$glb" ] && { echo "$id: TRELLIS failed"; echo "$log" | tail -3 | cut -c1-300; exit 1; }
  mkdir -p tools/gen3d/raw/parts && cp "$glb" $raw
  echo "$id: raw model kept ($raw)"
fi
[ -f $raw ] || { echo "no raw model $raw"; exit 1; }
[ -f tools/gen3d/parts/$id.json ] || { echo "$id: write tools/gen3d/parts/$id.json, then: $0 $id --rig"; exit 0; }
mkdir -p shots
blender --background --python tools/blender/rig_generated_part.py -- --in $raw --spec tools/gen3d/parts/$id.json \
  --out art/parts_gen_scrap/$part.glb --preview shots/045_$id 2>&1 | grep -E "^  |^rigged|^arms|^shadow|^cut|^floor|Error|no leg"
[ -f project.godot ] && $GODOT --headless --path . --import 2>&1 | grep -i "error" | head -3
echo "$id: art/parts_gen_scrap/$part.glb (previews shots/045_${id}_0..3.png)"
