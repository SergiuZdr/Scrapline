#!/bin/zsh
# Works through a list of generation jobs on the free allowance (045): each job is retried every
# WAIT seconds while the allowance is empty (exit 2), so a day's queue runs unattended.
#
#   tools/gen3d/queue_parts.sh "part ch_brute" "part ar_hammer" "concept ar_saw 1 2 3"
cd "$(dirname "$0")/../.." || exit 1
WAIT=${WAIT:-1200}
for job in "$@"; do
  kind=${job%% *}; rest=${job#* }
  while true; do
    echo "$(date +%H:%M) $job"
    if [ $kind = part ]; then tools/gen3d/next_part.sh ${=rest}; else tools/gen3d/part_concept.sh ${=rest}; fi
    code=$?
    [ $code -ne 2 ] && break
    sleep $WAIT
  done
  [ $code -ne 0 ] && { echo "$job failed ($code)"; exit $code; }
done
echo "$(date +%H:%M) queue done"
