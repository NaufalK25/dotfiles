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
import json, re, shlex, subprocess, sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except ValueError:
    sys.exit(0)

new_cmd = (data.get("hookSpecificOutput") or {}).get("updatedInput", {}).get("command")
if not new_cmd:
    sys.stdout.write(raw)
    sys.exit(0)

# Dynamic bypass: some rtk subcommands cannot express every invocation of
# the tool they wrap (e.g. `rtk find` rejects -o/-not/-exec with "does not
# support compound predicates or actions"). Rather than hardcoding which
# flags trip this, actually run rtk'"'"'s proposed rewrite and read ITS OWN
# error back. If rtk itself says it cannot do this, denying and pointing
# the caller at that same unusable command would just send them in a
# circle -- so let the original raw command through instead.
#
# This probe only ever executes for a fixed allow-list of read-only/
# inspection subcommands, and only when new_cmd is a single plain command
# (no ;, &&, |, backticks, $(), redirects). Mutating subcommands (git, npm,
# docker, ...) are never pre-executed to "check" them -- that would perform
# the real action -- so for those the normal deny-and-redirect-to-rtk
# behavior below is unconditional.
SAFE_PROBE = {"find", "grep", "cat", "ls", "head", "tail", "wc", "sort", "diff", "stat", "file", "du", "tree"}

subcmd = None
if not re.search(r"[;&|`$<>]", new_cmd):
    try:
        toks = shlex.split(new_cmd)
    except ValueError:
        toks = []
    for i, tok in enumerate(toks):
        if tok == "rtk" and i + 1 < len(toks):
            subcmd = toks[i + 1]
            break

    if subcmd in SAFE_PROBE:
        try:
            probe = subprocess.run(toks, capture_output=True, text=True, timeout=10)
            probe_out = (probe.stdout or "") + (probe.stderr or "")
            if probe.returncode != 0 and re.search(
                r"does not support|not supported|unsupported|unknown flag",
                probe_out,
                re.IGNORECASE,
            ):
                sys.exit(0)
        except Exception:
            pass  # any probe failure just falls through to the normal deny path

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
