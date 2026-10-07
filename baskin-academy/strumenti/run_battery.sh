#!/usr/bin/env bash
# Portable runner: accepts GODOT and PROJECT overrides. Non-zero on failed probes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-$ROOT/baskin_academy}"
GODOT="${GODOT:-$HOME/.cache/godot/godot}"
LOGS="${LOGS:-$ROOT/test-results}"
mkdir -p "$LOGS"
if [[ ! -x "$GODOT" ]]; then GODOT="$(command -v godot || true)"; fi
if [[ -z "$GODOT" ]]; then echo "Godot 4.3 non trovato: imposta GODOT=/percorso/godot" >&2; exit 2; fi
failed=0
run_test() {
  local name="$1" expected="$2"; shift 2
  local log="$LOGS/$name.log"
  if timeout 600 "$GODOT" --headless --path "$PROJECT" "res://tools/$name.tscn" "$@" > "$log" 2>&1 \
      && grep -q "$expected" "$log" \
      && ! grep -Eq 'SCRIPT ERROR|Parse Error|FAILURES=[1-9]|FAIL:|FAILED TO LOAD' "$log"; then
    echo "PASS $name"
  else
    echo "FAIL $name — $log"
    failed=1
  fi
  if grep -Eq '^ERROR:|^WARNING:' "$log"; then
    echo "  Diagnostica Godot presente: consulta $log"
  fi
}
for name in BaskinProbe FlowTest QProbe PadProbe DunkProbe LProbe RuleProbe Rule6Probe Rule7Probe Rule8Probe Rule9Probe Rule10Probe Rule11Probe Rule12Probe Rule13Probe Rule14Probe; do
  run_test "$name" 'ALL OK'
done
run_test PracticeSubProbe 'ALL OK'
run_test PlayerFeedbackProbe '25 checks, 0 failures'
run_test AITeamworkProbe '10 checks, 0 failures'
run_test AIPassLifetimeProbe '5 checks, 0 failures'
run_test ContinuityProbe '11 checks, 0 failures'
run_test DribbleContinuityProbe '11 checks, 0 failures'
run_test InboundUXProbe '23 checks, 0 failures'
run_test ReliabilityProbe '15 checks, 0 failures'
run_test LoadTest 'LOAD TEST DONE'
run_test MatchTest 'MATCH TEST OK' 90
run_test BalanceProbe 'BALANCE score' 180
exit "$failed"
