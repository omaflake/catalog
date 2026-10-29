#!/bin/bash
# SPDX-License-Identifier: MIT
# omaflake Test (macOS guest, lab recipe): checks sound, microphone and clipboard from inside the VM.
# A small app made of a shell script and AppleScript dialogs (no compiler needed in the image).
export LANG=en_US.UTF-8
TMP="${TMPDIR:-/tmp}"

dialog() { # text, buttons… → the chosen button ("" when closed)
  local text="$1"; shift
  local list; list=$(printf '"%s",' "$@"); list="{${list%,}}"
  osascript -e "button returned of (display dialog \"$text\" buttons $list default button 1 with title \"omaflake Test\")" 2>/dev/null
}

status() {
  local clip mic
  # omaflake starts the agent over SSH once the VM answers (no LaunchAgent, plan BM25)
  pgrep -f clipboard-agent-macos.py >/dev/null && clip="agent running" || clip="agent not running (omaflake starts it once the VM answers on SSH)"
  [ -e /dev/cu.org.omaflake.clipboard ] && clip="on – $clip" || clip="off for this VM"
  mic=$(system_profiler SPAudioDataType 2>/dev/null | grep -c "Input Channels")
  printf 'Clipboard: %s\nMicrophone inputs: %s\nCamera: not in macOS VMs yet (needs signing, M12)' "$clip" "$mic"
}

# The status dialog closes itself every 5 s and comes back with fresh values (the agent starts about a minute after boot)
status_dialog() {
  local list; list='{"Close","Record","Play Tone"}'
  osascript -e "set r to display dialog \"$(status)\" buttons $list default button 3 giving up after 5 with title \"omaflake Test\"" \
            -e 'if gave up of r then return "refresh"' -e 'return button returned of r' 2>/dev/null
}

while :; do
  choice=$(status_dialog)
  case "$choice" in
    refresh) continue ;;
    "Play Tone")
      afplay /System/Library/Sounds/Ping.aiff; afplay /System/Library/Sounds/Glass.aiff
      dialog "Played two sounds on the Mac's speakers. Heard them?" "OK" >/dev/null ;;
    "Record")
      rm -f "$TMP/omaflake-test.wav"
      dialog "Records 4 seconds from the microphone, then plays it back. macOS in the VM asks for permission the first time." "Start" >/dev/null || continue
      if ffmpeg -loglevel error -f avfoundation -i ":0" -t 4 -y "$TMP/omaflake-test.wav"; then
        peak=$(ffmpeg -i "$TMP/omaflake-test.wav" -af volumedetect -f null - 2>&1 | sed -n 's/.*max_volume: //p')
        afplay "$TMP/omaflake-test.wav"
        dialog "Peak level: ${peak:-?} (about -90 dB = silence). Played it back." "OK" >/dev/null
      else
        dialog "Recording failed – is the microphone switched on for this VM, and allowed in System Settings → Privacy & Security → Microphone?" "OK" >/dev/null
      fi ;;
    *) exit 0 ;;
  esac
done
