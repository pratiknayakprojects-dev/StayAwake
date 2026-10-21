#!/bin/bash
# Checks for what unit tests can't reach. Run on a Mac with StayAwake installed in /Applications.
# Usage: scripts/verify.sh lid | kill | dup | trial
set -u
APP=/Applications/StayAwake.app
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }
sleep_disabled() { pmset -g | awk '/SleepDisabled/{print $2}'; }

case "${1:-}" in
lid)
  echo "In the StayAwake menu choose 'Keep Awake When Lid Closed', then press Return."; read -r
  LOG=$(mktemp)
  echo "Logging every 5s. Close the lid for about 90 seconds, reopen it, then press Ctrl-C."
  trap 'gap=$(awk "NR>1{g=\$1-p; if(g>m)m=g} {p=\$1} END{print m+0}" "$LOG"); echo; \
        [ "$gap" -le 15 ] && pass "no sleep gap (longest gap ${gap}s)" || fail "Mac slept: longest gap ${gap}s"; exit' INT
  while true; do date +%s >> "$LOG"; sleep 5; done ;;
kill)
  echo "In the StayAwake menu choose 'Keep Awake When Lid Closed', then press Return."; read -r
  [ "$(sleep_disabled)" = 1 ] || fail "closed-lid mode was not on (SleepDisabled=$(sleep_disabled))"
  pkill -9 -x StayAwake; sleep 4
  [ "$(sleep_disabled)" = 0 ] && pass "sleep restored after kill -9" || fail "SleepDisabled still 1 after kill -9"
  open "$APP" ;;
quit)
  echo "In the StayAwake menu choose 'Keep Awake When Lid Closed', then press Return."; read -r
  [ "$(sleep_disabled)" = 1 ] || fail "closed-lid mode was not on (SleepDisabled=$(sleep_disabled))"
  pkill -x StayAwake; sleep 6  # SIGTERM takes the same shutdown path as menu Quit
  [ "$(sleep_disabled)" = 0 ] && pass "sleep restored after a normal quit" || fail "SleepDisabled still 1 after a normal quit"
  open "$APP" ;;
dup)
  open -n "$APP"; sleep 4
  n=$(pgrep -x StayAwake | wc -l | tr -d ' ')
  [ "$n" = 1 ] && pass "one copy running" || fail "$n copies running" ;;
trial)
  echo "This removes your saved license and starts a trial that expires in 2 minutes."
  echo "Afterwards re-enter your key via 'Enter License Key...'. Press Return to continue."; read -r
  security delete-generic-password -s com.pratiknayak.stayawake -a licenseKey >/dev/null 2>&1
  security delete-generic-password -s com.pratiknayak.stayawake -a trialStart >/dev/null 2>&1
  pkill -x StayAwake; sleep 1
  security add-generic-password -U -s com.pratiknayak.stayawake -a trialStart -w "$(( $(date +%s) - 7*86400 + 120 ))"
  open "$APP"
  echo "In the menu choose 'Keep Awake' and set Auto-Stop After to 'Until Off'. Press Return."; read -r
  pmset -g assertions | grep -q "StayAwake: user requested" || fail "no session was running (the trial may have expired before you chose Keep Awake); rerun"
  for _ in $(seq 1 40); do
    pmset -g assertions | grep -q "StayAwake: user requested" || { pass "session stopped when trial expired"; exit 0; }
    sleep 5
  done
  fail "session still running 200s after the trial expired" ;;
*) echo "usage: $0 lid | kill | quit | dup | trial"; exit 2 ;;
esac
