#!/bin/zsh
# Concepts for the Colab notebook (045, tools/gen3d/trellis_colab.ipynb): each picked concept
# art/concepts/machines/<id>.png cut out with our own mask (cut_background.py, as next_part.sh does)
# into shots/colab_in/<id>.png -- upload those into the notebook's /content (Files panel).
#
#   tools/gen3d/colab_prep.sh ar_hammer ar_saw co_slug
# Then, with the notebook's GLBs downloaded to a folder:
#   tools/gen3d/colab_prep.sh --import ~/Downloads/out     # -> raw kept, rigged where a spec exists
cd "$(dirname "$0")/../.." || exit 1
if [ "$1" = "--import" ]; then
  for glb in $2/*.glb; do
    id=$(basename $glb .glb)
    mkdir -p tools/gen3d/raw/parts && cp $glb tools/gen3d/raw/parts/$id.glb && echo "$id: raw kept"
    tools/gen3d/next_part.sh $id --rig
  done
  exit 0
fi
mkdir -p shots/colab_in
for id in $@; do
  [ -f art/concepts/machines/$id.png ] || { echo "no concept art/concepts/machines/$id.png"; continue; }
  blender --background --python tools/gen3d/cut_background.py -- art/concepts/machines/$id.png shots/colab_in/$id.png 2>&1 | grep -E "^cut:" | sed "s/^/$id: /"
done
echo "upload shots/colab_in/*.png into the Colab notebook's /content (Files panel), run cell 2"
