#!/bin/bash
# UDK.exe keeps its console on the virtual display and writes Launch.log.
# AMP only reads this process, so follow that file on stdout.

LOGFILE="../../UDKGame/Logs/Launch.log"
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

TAILPID=
WINEPID=

cleanup() {
  if [[ -n "$WINEPID" ]]; then
    kill "$WINEPID" 2>/dev/null || true
    wait "$WINEPID" 2>/dev/null || true
  fi
  if [[ -n "$TAILPID" ]]; then
    kill "$TAILPID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

tail -n 0 -F "$LOGFILE" &
TAILPID=$!

/usr/bin/xvfb-run -a /usr/bin/wine ./UDK.exe "$@" &
WINEPID=$!
wait "$WINEPID"
exit $?
