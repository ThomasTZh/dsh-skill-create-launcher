---
name: create-launcher
description: Create a double-click launcher for the current project's product that opens a new terminal, starts its backend and frontend, opens the app, and stops both cleanly on Ctrl+C. A second Ctrl+C force-stops. Use for launcher, double-click shortcut, start/stop script, or terminal run wrapper requests.
---

# Create a product launcher

Build a double-clickable launcher for **this project's** product. The launcher must be a foreground supervisor process: the terminal window is its user interface, and the terminal closes when the supervisor exits.

## Required behavior

| Event | Required result |
| --- | --- |
| Double-click launcher | A new terminal window opens. |
| Startup | Every product process starts; the frontend URL is reachable; the browser opens the frontend. |
| While running | The product keeps running; the terminal shows service logs and stays open. |
| Ctrl+C once | SIGTERM every service process group, wait for a clean exit, SIGKILL survivors after a timeout, then exit. The terminal window closes. |
| Ctrl+C twice | SIGKILL every service process group immediately, then exit. The terminal window closes. |
| Terminal window closed | Treat as a stop request; do not leave orphan processes. |

"Backend" and "frontend" mean the tiers that actually exist. If one process serves both, supervise that one process group. If Docker Compose runs both, supervise the compose process and verify the published URLs.

## 1. Discover how this product runs

Do not guess commands, ports, or URLs. Inspect:

- `README*`, `AGENTS.md`, `Makefile`, `justfile`, `compose.yaml`, `docker-compose*.yml`
- `package.json` scripts and workspaces, `pnpm-workspace.yaml`, `pyproject.toml`, `Cargo.toml`, `go.mod`
- existing `launchers/`, `scripts/`, `dev.sh`, `.env`, `.env.example`
- lockfiles to select npm/pnpm/yarn/bun without mixing package managers

Record:

- backend command, working directory, expected URL or health endpoint, port
- frontend command, working directory, URL, port
- tool paths needed at launch (see the desktop PATH pitfall below)
- required environment variables, and whether the app loads `.env` itself
- one-time setup (installs, builds) that the launcher must **check for** and report, not silently repeat

Prefer the project's documented local run mode. If dev and production modes both exist, use the one a developer would click around in locally. Ask the user only if the run mode is genuinely ambiguous or no commands can be found.

Run each command once by hand to confirm it works and to capture the real readiness URL. If the frontend proxies the backend, confirm the actual page loads, not only that two servers bound ports.

## 2. Create the launcher files

Place files in `launchers/` at the project root (reuse the directory if it exists). Use a kebab-case product slug, for example `acme`:

- `launchers/run-acme.py`: supervisor, Python 3.9+ standard library only
- `launchers/Acme.desktop`: Linux double-click entry
- `launchers/Acme.command`: macOS double-click entry

Create the entry for the OS in use. Create both only when the project is used on both systems. If a launcher for this product already exists, update it; never overwrite an unrelated launcher.

Copy these resources from this skill's directory (resolve them against the skill base path):

- `references/supervisor.py` → `launchers/run-<slug>.py`
- `references/linux.desktop` → `launchers/<Product>.desktop`
- `references/macos.command` → `launchers/<Product>.command`

Keep the supervisor code unchanged except for its CONFIG block unless the project genuinely needs an extension. The control flow, process-group handling, and signal handling are the tested part.

Fill every placeholder; no `REPLACE_ME`, `@@...@@`, or angle-bracket placeholder may remain.

### Supervisor CONFIG

- `PRODUCT_SLUG`: stable kebab-case name used under `$XDG_STATE_HOME` for logs and the instance lock. Keep logs out of the repository.
- `PRODUCT_NAME`: display name.
- `PROJECT_ROOT`: keep the template's `Path(__file__).resolve().parent.parent` when the script is in `launchers/`.
- `FRONTEND_URL`: the exact URL a user should open after launch.
- `SERVICES`: one `ServiceConfig` per process group.
  - `command`: argument list, no shell. Use absolute executable paths. The desktop session does **not** load `.bashrc`, `.zshrc`, nvm, pyenv, conda, or a venv. Resolve tools with `command -v` and embed absolute paths, or set the needed `PATH` in `env`. Prefer `.venv/bin/python`, `uv`, `poetry`, or the Node tool's absolute path over `source activate`.
  - `cwd`: absolute or `PROJECT_ROOT`-relative directory that command expects.
  - `readiness`: HTTP URL that returns below 500, or `tcp://host:port`. Prefer a real health endpoint, then the frontend root, then TCP.
  - `env`: non-secret variables only. Never commit secrets. If the service does not load `.env` itself, run it through a shell that sources the file at runtime (for example `/bin/bash -lc 'set -a; . ./.env; exec <command>'`) instead of copying secrets into Python.
- Timeouts: keep `GRACEFUL_TIMEOUT` at 10-15 seconds unless the product needs longer. Keep `HOLD_ON_FAILURE = True` so a double-click startup failure leaves the error visible.
- If the documented command needs a shell pipeline, use `/bin/bash -lc <single-string-command>` and quote carefully; do not feed untrusted strings into it.

### Desktop entry

Fill `references/linux.desktop`:

- `@@PYTHON@@`: absolute `python3` path from `command -v python3`
- `@@PROJECT_ROOT@@`: absolute project root
- `@@PRODUCT_SLUG@@`, `@@PRODUCT_NAME@@`

Keep `Terminal=true`; do not add `--hold`, `read`, `pause`, or a shell that stays open after exit. Make the `.desktop` file and supervisor executable (`chmod +x`). On GNOME, mark the file trusted with `gio set "<file>" metadata::trusted true`; if that is unavailable, tell the user to right-click the file and choose **Allow Launching**. On KDE Plasma the executable bit is normally enough.

For macOS, fill `references/macos.command`, make it executable, and note that the first launch may require right-click → **Open**. The Terminal window closes on exit unless the user changed the profile's "When the shell exits" setting.

## 3. Behavior the implementation must preserve

The copied supervisor already implements these. Verify they remain true after editing:

- **Terminal window**: the supervisor is the foreground process. No `nohup`, `setsid`, `disown`, or trailing `&` around the main process, or Ctrl+C will not reach the supervisor.
- **Isolated process groups**: every service starts with `start_new_session=True`. Terminal SIGINT reaches only the supervisor, so it can decide between graceful and forced shutdown.
- **Startup preflight**: check working directories, executable paths, and configured ports before spawning anything. Report actionable errors instead of flashing a terminal that closes immediately.
- **Readiness**: wait for every configured probe, with a startup timeout. On timeout or early exit, stop all services, print the failure, and keep the window open for diagnosis.
- **Browser**: open `FRONTEND_URL` after readiness with `xdg-open`/`open`. Browser failure is not fatal; print the URL. `--no-browser` exists for tests.
- **One Ctrl+C**: send SIGTERM to every child process group; wait up to the graceful timeout; SIGKILL any survivor; reap children; exit 0. The foreground process exiting closes the terminal.
- **Two Ctrl+C**: the second SIGINT during shutdown SIGKILLs every process group immediately and exits, without waiting for the graceful timeout. A SIGKILL escalation after timeout is not a substitute for this path.
- **SIGTERM/SIGHUP**: treat closing the terminal window or a desktop session shutdown as a graceful stop.
- **Unexpected child exit**: stop the remaining services, report which service exited and its code, and exit non-zero.
- **Single instance**: the advisory lock prevents a second double-click from starting a second copy. A second launch exits and may focus/open the existing frontend.
- **Cleanup**: kill only recorded process groups. Never use `pkill -f node`, `killall`, or name-based kills; they can hit unrelated user processes.
- **Logs**: write to `$XDG_STATE_HOME/<slug>/launcher/logs/` (the template does), not into a watched source tree. Vite and similar dev servers may reload on new files under the project.

## 4. Verify before reporting

Run these checks and fix failures. Replace placeholders with the real values.

### Static checks

```bash
python3 -m py_compile launchers/run-<slug>.py
desktop-file-validate "launchers/<Product>.desktop"   # if installed
grep -RIn --exclude-dir=.git -E '@@|REPLACE_ME' launchers/   # expect no placeholders
```

### Graceful stop

```bash
launchers/run-<slug>.py --no-browser --no-hold >/tmp/<slug>-launcher.log 2>&1 &
pid=$!
for _ in $(seq 1 180); do
  curl -fsS -o /dev/null --max-time 1 "http://127.0.0.1:<frontend-port>/" 2>/dev/null &&
  curl -fsS -o /dev/null --max-time 1 "http://127.0.0.1:<backend-port>/health" 2>/dev/null &&
  break
  sleep 1
done
grep -q "is running" /tmp/<slug>-launcher.log || { echo "FAIL: not ready"; cat /tmp/<slug>-launcher.log; kill -INT "$pid"; exit 1; }

kill -INT "$pid"
wait "$pid"; echo "exit=$?"          # expect 0
```

After it exits, assert all of the following:

- each frontend/backend URL refuses connections
- `grep "All services stopped." /tmp/<slug>-launcher.log` succeeds
- every `process group <n>` printed in the log is gone: `ps -eo pgid= | tr -d ' ' | grep -qx "<n>"` returns nothing
- the window closes when launched via the `.desktop` entry

### Forced stop

Real dev servers may stop before a second Ctrl+C can arrive. Verify the force path deterministically with temporary stub services that ignore SIGTERM:

1. Copy the supervisor to `/tmp/<slug>-force-test/` and point its services at two stub HTTP servers that ignore SIGTERM on distinct free ports, keeping `GRACEFUL_TIMEOUT = 12`.
2. Start it, wait for readiness, send SIGINT, wait about 0.2 s, send SIGINT again.
3. Assert it exits in well under the 12 s graceful timeout, both ports are closed, and both process groups are gone.

### Startup failure

```bash
python3 -m http.server <frontend-port> --bind 127.0.0.1 &
blocker=$!
sleep 0.5
launchers/run-<slug>.py --no-browser --no-hold; echo "exit=$?"   # expect 1
kill "$blocker"
```

Assert the message names the occupied port and that no product service started.

### Desktop-like environment

Desktop launches do not inherit an interactive shell's PATH. Re-run the graceful test with a minimal environment:

```bash
env -i HOME="$HOME" XDG_STATE_HOME=/tmp/<slug>-state PATH=/usr/local/bin:/usr/bin:/bin \
  launchers/run-<slug>.py --no-browser --no-hold
```

### Terminal window

In a graphical session, launch the entry the way the user will (double-click in the file manager, or on KDE `kioclient5 exec "launchers/<Product>.desktop"`). Confirm a new terminal opens, the product becomes reachable, one Ctrl+C stops it, and the terminal window disappears. If no display is available, state clearly that this manual check was not performed.

Clean up test processes, temporary stubs, and blocked ports. Do not leave a test instance running.

## 5. Report

Give the user:

- launcher paths and the URL it opens
- how to start it (double-click the `.desktop`/`.command` file)
- what Ctrl+C and double Ctrl+C do
- where logs are stored and where startup failures are shown
- verification commands and observed results, separating automated checks from manual GUI checks
- any one-time step (GNOME **Allow Launching**, macOS **Open**)

## Guardrails

- Do not modify product code, install packages, or change application behavior.
- Do not add a systemd service, autostart entry, or Desktop shortcut unless the user asks.
- Do not kill pre-existing processes, including a product instance the launcher did not start.
- Do not commit secrets or machine-specific state; the `.desktop` Exec path is machine-specific and must be regenerated if the project moves.
- Do not leave the terminal open after a successful stop.
- If the product cannot run non-interactively (requires a prompt, license acceptance, or manual login), stop and ask the user how to provide that input.
