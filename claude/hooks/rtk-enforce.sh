#!/usr/bin/env bash
# PreToolUse(Bash) enforcement wrapper around `rtk hook claude`.
#
# `rtk hook claude` already detects raw commands with a dedicated rtk
# equivalent and silently rewrites them via hookSpecificOutput.updatedInput.
# That's too quiet: raw commands keep executing successfully (just
# transparently corrected), so the habit of typing them raw never gets
# corrected. This wrapper turns a detected rewrite into an explicit `deny`
# with the correct command in the reason, so the caller sees the block and
# must resubmit through rtk. Commands with no rtk equivalent (or already
# rtk-prefixed) pass through unchanged, exactly as before.
input="$(cat)"

command -v rtk >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

result="$(printf '%s' "$input" | rtk hook claude 2>/dev/null)"
[ -z "$result" ] && exit 0

printf '%s' "$result" | python3 -c '
import json, sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except ValueError:
    sys.exit(0)

new_cmd = (data.get("hookSpecificOutput") or {}).get("updatedInput", {}).get("command")
if not new_cmd:
    sys.stdout.write(raw)
    sys.exit(0)

reason = (
    "RTK pre-flight: this command has a dedicated rtk equivalent and must be "
    "run through rtk, not raw. Re-run it as: " + new_cmd
)
json.dump(
    {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    },
    sys.stdout,
)
'
