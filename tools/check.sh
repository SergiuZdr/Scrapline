#!/bin/bash
# Every headless test at once, one line each (070).
#
#   tools/check.sh                 # all suites in parallel
#   tools/check.sh combat run      # only the suites whose names contain these words
#   tools/check.sh --bot 30        # then 30 bot runs on every core (THE test that plays the game)
#   tools/check.sh --fingerprint   # then the sim fingerprint, compared with the last one kept
#
# Logs go to shots/check/<suite>.log. A suite fails on a non-zero exit, a FAIL line, a SCRIPT
# ERROR, or running past its time limit (a script error inside a test coroutine hangs it).
# Exit status: 0 only if everything passed.

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/Users/Sergiu/DevG/KingdomRebuilt/Godot.app/Contents/MacOS/Godot}"
LOGS=shots/check
LIMIT=900
SUITES="verify_combat verify_combat_input verify_run verify_run_ui verify_save verify_onboarding verify_meta verify_assembly verify_animation stats"

BOT=0
PRINT=0
WANT=""
while [ $# -gt 0 ]; do
	case "$1" in
		--bot) BOT="$2"; shift 2 ;;
		--fingerprint) PRINT=1; shift ;;
		*) WANT="$WANT $1"; shift ;;
	esac
done

PICKED=""
for s in $SUITES; do
	if [ -z "$WANT" ]; then
		PICKED="$PICKED $s"
	else
		for w in $WANT; do
			case "$s" in *"$w"*) PICKED="$PICKED $s"; break ;; esac
		done
	fi
done

mkdir -p "$LOGS"
START=$(date +%s)
echo "running:$PICKED"
for s in $PICKED; do
	(
		t0=$(date +%s)
		"$GODOT" --headless --path . --script "res://tools/$s.gd" > "$LOGS/$s.log" 2>&1 &
		pid=$!
		while kill -0 $pid 2>/dev/null; do
			if [ $(( $(date +%s) - t0 )) -gt $LIMIT ]; then
				kill $pid
				echo "  KILLED after ${LIMIT}s" >> "$LOGS/$s.log"
			fi
			sleep 1
		done
		wait $pid
		rc=$?
		echo "$rc $(( $(date +%s) - t0 ))" > "$LOGS/$s.status"
	) &
done
wait

FAILED=0
printf "\n%-22s %-6s %6s  %s\n" suite result time checks
for s in $PICKED; do
	read rc secs < "$LOGS/$s.status"
	log="$LOGS/$s.log"
	counts=$(grep -Eo "[0-9]+ passed, [0-9]+ failed" "$log" | tail -1)
	bad=$(grep -cE "^\s*FAIL|SCRIPT ERROR|KILLED after" "$log")
	if [ "$rc" = "0" ] && [ "$bad" = "0" ]; then result=ok; else result=FAIL; FAILED=1; fi
	printf "%-22s %-6s %5ss  %s\n" "$s" "$result" "$secs" "$counts"
	if [ "$result" = "FAIL" ]; then
		grep -E "^\s*FAIL|SCRIPT ERROR|KILLED after" "$log" | head -5 | sed 's/^/      /'
	fi
done
echo "suites took $(( $(date +%s) - START ))s (logs in $LOGS/)"

if [ "$BOT" -gt 0 ] 2>/dev/null; then
	echo ""
	"$GODOT" --headless --no-header --path . --script res://tools/run_bot.gd -- --runs "$BOT" | tee "$LOGS/run_bot.log" | grep -v "done,"
	[ "${PIPESTATUS[0]}" = "0" ] || FAILED=1
fi

if [ "$PRINT" = "1" ]; then
	echo ""
	"$GODOT" --headless --no-header --path . --script res://tools/sim_fingerprint.gd 2>&1 \
		| grep -E "^(fight|run|TOTAL) " > "$LOGS/fingerprint.txt"
	tail -1 "$LOGS/fingerprint.txt"
	if [ -f "$LOGS/fingerprint.last" ]; then
		if diff -q <(grep -v TOTAL "$LOGS/fingerprint.last") <(grep -v TOTAL "$LOGS/fingerprint.txt") > /dev/null; then
			echo "  the sim plays exactly as it did last time"
		else
			echo "  the sim plays DIFFERENTLY from last time; first differences:"
			diff <(grep -v TOTAL "$LOGS/fingerprint.last") <(grep -v TOTAL "$LOGS/fingerprint.txt") | head -6 | sed 's/^/      /'
		fi
	fi
	cp "$LOGS/fingerprint.txt" "$LOGS/fingerprint.last"
fi

exit $FAILED
