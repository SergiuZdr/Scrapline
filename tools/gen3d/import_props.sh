#!/bin/zsh
# 081: battlefield props from the Colab notebook (concepts art/concepts/props/pr_<name>.png, cut into
# shots/colab_props/ with cut_background.py) -> art/props/<name>.glb, drawn by `Models.prop`.
#
#   tools/gen3d/import_props.sh <folder of pr_*.glb>     # every GLB in it
#   tools/gen3d/import_props.sh --again wall              # re-clean a kept raw model
#
# The raw TRELLIS model is kept (tools/gen3d/raw/props/, gitignored): cleaning again costs no GPU.
cd "$(dirname "$0")/../.." || exit 1
GODOT=/Users/Sergiu/DevG/KingdomRebuilt/Godot.app/Contents/MacOS/Godot
# Footprint in metres (the widest side after squaring). A hex is 0.78 m centre to corner, so the
# wall block (corner to corner) is 1.56 and closes on its neighbours; the hatch sits inside its hex.
typeset -A SIZE=(barrel 0.78 coolant 0.72 pylon 0.8 cache 0.95 scrap_pile 1.0 hive_pad 1.4 wall 1.56)
# Flat colours in the texture; the pile keeps more, or its green paint merges into the rust.
typeset -A COLOURS=(scrap_pile 48)
typeset -A NAME=(pile_a scrap_pile)
mkdir -p tools/gen3d/raw/props art/props
clean() {
  local name=$1 raw=tools/gen3d/raw/props/$1.glb extra=()
  # The hexes are drawn square to the grid: the cleaner's own squaring would turn the wall a corner off.
  case $name in wall|hive_pad) extra=(--no-square) ;; esac
  blender --background --python tools/blender/clean_generated.py -- --keep-texture --in $raw \
    --out art/props/$name.glb --size ${SIZE[$name]:-0.8} --budget 6000 --posterize ${COLOURS[$name]:-16} --sharp 45 \
    ${extra[@]} ${=YAW:+--yaw $YAW} 2>&1 | grep -E "^kept|Error" | sed "s/^/$name: /"
}
if [ "$1" = "--again" ]; then
  clean $2
else
  for glb in $1/pr_*.glb; do
    id=$(basename $glb .glb); id=${id#pr_}; name=${NAME[$id]:-$id}
    cp $glb tools/gen3d/raw/props/$name.glb && clean $name
  done
fi
$GODOT --headless --path . --import 2>&1 | grep -i "error" | head -3
