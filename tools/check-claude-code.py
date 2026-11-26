"""Checks town-link against the Claude Code installed here, with a real headless session.

town-link depends on things Claude Code does that no unit test can pin down, because the plugin
tests feed in what we wrote, not what Claude Code sends. This runs one short `claude -p` session
with this checkout's town-link (`--plugin-dir plugin`) and a throwaway Stop hook that sends the
work back once, then checks what town-link sent:

- the session opens with this checkout's town-link version, and every batch passes the schema;
- the Stop hook's block reaches the app as `ticket.return` with the hook's reason. town-link
  reads it from the note Claude Code stores, which starts "Stop hook feedback:"; if Claude
  Code rewords that note, this check fails (docs/verification.md item 15);
- Claude Code shows no "town-link: its ... hook was skipped" line. Where an organization manages
  Claude Code, it shows one for each hook its guard passes over; only `session.compact` may be
  skipped (no compaction happens here, so none is expected).

Run it for every change to town-link or to an app, and after Claude Code updates itself:

    python3 tools/check-claude-code.py            (on Windows: python tools\\check-claude-code.py)

It needs `claude` on PATH, signed in, and makes one small Haiku request (about 20 seconds). It
does not touch a running agent-town: Claude Code runs with APPDATA pointed at a temporary
folder, so town-link reports to this script instead (town-link reads the endpoint file from
APPDATA when it is set). Exit code 0 when every check passes, 1 otherwise.

Standard library only.
"""

import argparse
import base64
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from protocol_check import check_batch, load_schema  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN = os.path.join(REPO, "plugin")
PROTOCOL = 1
REASON = "agent-town check: say goodbye too"
SKIP_NOTICE = re.compile(r"town-link: its (\S+) hook was skipped")
ALLOWED_SKIPS = {"session.compact"}

# The Stop hook: block the first stop with REASON, let the second one through.
STOP_HOOK = f"""import json, sys
data = json.load(sys.stdin)
if not data.get("stop_hook_active"):
    print(json.dumps({{"decision": "block", "reason": {REASON!r}}}))
"""


def receiver(token, schema, events, errors):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):  # noqa: A002 - silence access log
            pass

        def do_POST(self):
            ok = self.path == "/v1/events" and self.headers.get("Authorization") == f"Bearer {token}"
            body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
            self.send_response(204 if ok else 401)
            self.send_header("Content-Length", "0")
            self.end_headers()
            if not ok:
                errors.append("a batch came with a wrong path or token")
                return
            try:
                batch = json.loads(body)
            except ValueError:
                errors.append("a batch was not JSON")
                return
            errors.extend(f"schema: {e}" for e in check_batch(batch, schema))
            events.extend(batch.get("events", []))

    return ThreadingHTTPServer(("127.0.0.1", 0), Handler)


def main():
    ap = argparse.ArgumentParser(description="Check town-link against the installed Claude Code")
    ap.add_argument("--model", default="haiku")
    ap.add_argument("--timeout", type=int, default=240, help="seconds for the session")
    ap.add_argument("--plugin", default=PLUGIN, help="the town-link folder to check (default: this checkout's)")
    ap.add_argument("--verbose", action="store_true", help="print every event and Claude Code's output")
    args = ap.parse_args()

    claude = shutil.which("claude")
    if not claude:
        sys.exit("claude is not on PATH")
    plugin = os.path.abspath(args.plugin)
    with open(os.path.join(plugin, ".claude-plugin", "plugin.json")) as fh:
        version = json.load(fh)["version"]

    events, errors = [], []
    token = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    server = receiver(token, load_schema(), events, errors)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    work = tempfile.mkdtemp(prefix="agent-town-check-")
    try:
        # town-link joins APPDATA and the rest with backslashes. On Windows that is a real path;
        # elsewhere it is one file name with backslashes in it, in the APPDATA folder.
        appdata = os.path.join(work, "appdata")
        project = os.path.join(work, "project")
        os.makedirs(appdata)
        os.makedirs(project)
        endpoint = appdata + "\\agent-town-claude-code\\endpoint.json"
        if os.name == "nt":
            os.makedirs(os.path.dirname(endpoint), exist_ok=True)
        with open(endpoint, "w") as fh:
            json.dump({"protocol": PROTOCOL, "port": server.server_address[1], "token": token,
                       "pid": os.getpid(), "app": "agent-town", "appVersion": "0.0.0-check"}, fh)

        hook = os.path.join(work, "stop_hook.py")
        with open(hook, "w") as fh:
            fh.write(STOP_HOOK)
        settings = os.path.join(work, "settings.json")
        with open(settings, "w") as fh:
            command = f'"{sys.executable}" "{hook}"'
            json.dump({"hooks": {"Stop": [{"hooks": [{"type": "command", "command": command}]}]}}, fh)

        env = dict(os.environ, APPDATA=appdata)
        try:
            run = subprocess.run(
                [claude, "-p", "Reply with just: hi", "--model", args.model,
                 "--plugin-dir", plugin, "--settings", settings],
                cwd=project, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                encoding="utf-8", errors="replace", timeout=args.timeout,
            )
        except subprocess.TimeoutExpired:
            print(f"FAIL  the session did not end within {args.timeout} s")
            return 1
        # town-link sends every 250 ms and once more as the session ends; give the last batch time.
        threading.Event().wait(1.0)
    finally:
        server.shutdown()
        shutil.rmtree(work, ignore_errors=True)

    output = (run.stdout or "") + (run.stderr or "")
    if args.verbose:
        print(output.rstrip())
        for ev in events:
            extra = {k: v for k, v in ev.items() if k not in ("sessionId", "seq", "ts", "projectId", "type")}
            print(f"  {ev.get('type'):16} {json.dumps(extra, ensure_ascii=False)[:160]}")

    types = [ev.get("type") for ev in events]
    opened = next((ev for ev in events if ev.get("type") == "session.open"), None)
    returns = [ev for ev in events if ev.get("type") == "ticket.return"]
    skipped = sorted(set(SKIP_NOTICE.findall(output)) - ALLOWED_SKIPS)

    checks = [
        ("the session ran", run.returncode == 0, f"claude exited with {run.returncode}"),
        ("town-link reported the session", opened is not None and "ticket.submit" in types and "ticket.done" in types,
         f"events seen: {types or 'none'}"),
        (f"the town-link checked ({version}) ran", opened is not None and opened.get("pluginVersion") == version,
         f"session.open had pluginVersion {opened and opened.get('pluginVersion')!r}"),
        ("every batch passed the schema", not errors, "; ".join(errors[:5])),
        ("the Stop hook's block reached the app with its reason",
         len(returns) == 1 and returns[0].get("reason") == REASON,
         f"ticket.return events: {[r.get('reason') for r in returns]} (has Claude Code reworded "
         "\"Stop hook feedback:\"? see docs/verification.md item 15)"),
        ("Claude Code skipped none of town-link's hooks", not skipped,
         f"skipped: {', '.join(skipped)} (where an organization manages Claude Code, its guard passes "
         "these over plugins the user installed; see docs/known-issues.md)"),
    ]
    failed = 0
    for name, ok, why in checks:
        print(f"{'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f": {why}"))
        failed += not ok
    print(f"{len(checks) - failed} of {len(checks)} checks passed")
    if failed and not args.verbose:
        print("Run again with --verbose to see the events and Claude Code's output.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
