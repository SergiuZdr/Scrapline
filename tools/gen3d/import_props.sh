#!/bin/zsh
# 081: battlefield props from the Colab notebook (concepts art/concepts/props/pr_<name>.png, cut into
# shots/colab_props/ with cut_background.py) -> art/props/<name>.glb, drawn by `Models.prop`.
#
#   tools/gen3d/import_props.sh <folder of pr_*.glb>     # every GLB in it (tr_*: terrain tiles, yd_*: yard pieces, sk_*: map skyline, art/props/<name>.glb)
#   tools/gen3d/import_props.sh --again wall              # re-clean a kept raw model
#
# The raw TRELLIS model is kept (tools/gen3d/raw/props/, gitignored): cleaning again costs no GPU.
cd "$(dirname "$0")/../.." || exit 1
GODOT=/Users/Sergiu/DevG/KingdomRebuilt/Godot.app/Contents/MacOS/Godot
# Footprint in metres (the widest side after squaring; the drum and coolant 40% under 081's first cut, the user). A hex is 0.78 m centre to corner, so the
# wall block (corner to corner) is 1.56 and closes on its neighbours; the hatch sits inside its hex.
typeset -A SIZE=(barrel 0.47 coolant 0.43 pylon 0.8 cache 0.95 scrap_pile 1.0 hive_pad 1.4 wall 1.56 mine 0.6 terminal 0.62)
# Terrain tiles (tr_*) fill their hex as the slab does: 0.96 of a hex, corner to corner.
for t in rubble slag ridge pit heap flue wire floor_1 floor_2 floor_3 floor_4 floor_5; SIZE[tr_$t]=1.5
# The skyline on the region map (sk_*): unit size, the map scales them.
SIZE+=(sk_factory_a 1.0 sk_factory_b 1.0)
# Yard pieces (yd_*) near the arena kit's sizes (art/arena): widest side, set so the height matches too
# (the floodlight 4.9 m tall, the gantry ~7; container B is drawn slimmer, so longer); the car stack and service gantry are turned long side on X.
SIZE+=(yd_container_0 5.2 yd_container_1 7.0 yd_car_stack 3.2 yd_tyre_stack 0.94 yd_barrier 1.72
  yd_floodlight 3.9 yd_gantry 9.0 yd_service_gantry 4.61)
typeset -A TURN=(yd_car_stack 90 yd_service_gantry 90)
# Flat colours in the texture; the pile keeps more, or its green paint merges into the rust.
typeset -A COLOURS=(scrap_pile 48 tr_flue 48)
# The plain floor tiles keep their grain (tread, cracks, gravel): 16 colours turn it to blotches.
for t in 1 2 3 4 5; COLOURS[tr_floor_$t]=32
typeset -A NAME=(pile_a scrap_pile)
mkdir -p tools/gen3d/raw/props art/props
clean() {
  local name=$1 raw=tools/gen3d/raw/props/$1.glb extra=()
  # The hexes are drawn square to the grid: the cleaner's own squaring would turn the wall a corner off.
  case $name in wall|hive_pad|tr_*) extra=(--no-square) ;; esac
  blender --background --python tools/blender/clean_generated.py -- --keep-texture --in $raw \
    --out art/props/$name.glb --size ${SIZE[$name]:-0.8} --budget 6000 --posterize ${COLOURS[$name]:-16} --sharp 45 \
    ${extra[@]} --yaw ${YAW:-${TURN[$name]:-0}} 2>&1 | grep -E "^kept|Error" | sed "s/^/$name: /"
}
if [ "$1" = "--again" ]; then
  clean $2
else
  for glb in $1/tr_*.glb(N) $1/yd_*.glb(N) $1/sk_*.glb(N); do
    name=$(basename $glb .glb)
    cp $glb tools/gen3d/raw/props/$name.glb && clean $name
  done
  for glb in $1/pr_*.glb(N); do
    id=$(basename $glb .glb); id=${id#pr_}; name=${NAME[$id]:-$id}
    cp $glb tools/gen3d/raw/props/$name.glb && clean $name
  done
fi
$GODOT --headless --path . --import 2>&1 | grep -i "error" | head -3
