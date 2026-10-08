#!/bin/zsh
# Concepts for a generated machine part (045): FLUX.1-schnell on its Hugging Face Space, prompt
# from tools/gen3d/part_concepts.json, N seeds into art/concepts/machines/<id>_<seed>.png.
# FLUX's Space spends the SAME ZeroGPU allowance as TRELLIS (about 10 s an image): exit 2 = none left.
# The user picks one and it is copied to art/concepts/machines/<id>.png for next_part.sh.
#
#   tools/gen3d/part_concept.sh ar_hammer 1 2 3
cd "$(dirname "$0")/../.." || exit 1
B=https://black-forest-labs-flux-1-schnell.hf.space
export HF_TOKEN=$(cat ~/.cache/huggingface/token 2>/dev/null)
id=$1; shift
# STYLE=comic (051): the comic-illustration style, files <id>_c<seed>.png.
key=style; tag=""; [ "$STYLE" = comic ] && { key=style_comic; tag=c; }
prompt=$(python3 -c "import json,sys; c=json.load(open('tools/gen3d/part_concepts.json')); print(c['parts'][sys.argv[1]] + ', ' + c[sys.argv[2]])" $id $key) || { echo "no prompt for $id"; exit 1; }
mkdir -p art/concepts/machines
for seed in $@; do
  [ -f art/concepts/machines/${id}_$tag$seed.png ] && continue   # a queue retry keeps what it has
  work=$(mktemp -d)
  args=$(python3 -c "import json,sys; print(json.dumps([['infer', [sys.argv[1], int(sys.argv[2]), False, 1024, 1024, 4]]]))" "$prompt" $seed)
  STEP_LIMIT=240 python3 tools/gen3d/gradio_queue.py $B $work "$args" > $work/log 2>&1
  grep -q "quota" $work/log && { echo "$id $seed: no GPU allowance left (shared with TRELLIS)"; exit 2; }
  img=$(ls $work/*.(webp|png|jpg)(N) | head -1)
  [ -z "$img" ] && { echo "$id $seed: failed"; tail -2 $work/log | cut -c1-300; continue; }
  sips -s format png "$img" --out art/concepts/machines/${id}_$tag$seed.png >/dev/null && echo "$id $seed: art/concepts/machines/${id}_$tag$seed.png"
done
