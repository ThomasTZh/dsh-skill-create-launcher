# dsh-skill-create-launcher

This repository holds a short instruction file that helps an AI assistant add a double-click start button to a software project. The button opens a command window, starts the program's visible part and its background service, and shows the page in a web browser. One press of Ctrl+C stops everything safely and closes the window; pressing it twice stops everything at once.

## Purpose and gaps

Starting a two-part web project by hand means knowing two commands, two working directories, and the order in which to close things. A simple start script often solves only the first step: it leaves child processes behind, and Ctrl+C stops one part while the other keeps running.

The skill turns that work into a checked sequence. The assistant inspects the project, fills a tested supervisor template, adds a desktop entry, and runs the documented checks before reporting. The supervisor places each service in its own process group, waits for both tiers to answer, and owns the shutdown sequence.

## Features

- **Project discovery:** the instructions require reading the README, manifests, lockfiles, and existing scripts instead of guessing commands, ports, or readiness endpoints.
- **Tested supervisor template:** a standard-library Python program starts each service in its own process group, waits for HTTP or TCP readiness, opens the frontend, and keeps the terminal attached.
- **Defined stop sequence:** the first Ctrl+C sends SIGTERM to every process group, waits up to the configured timeout, SIGKILLs survivors, reaps children, and exits 0 so the terminal closes. A second Ctrl+C during shutdown sends SIGKILL immediately.
- **Failure handling:** preflight checks cover working directories, executable paths, and ports. Startup failures and early child exits stop everything, print the cause, and hold the terminal open for diagnosis.
- **Two desktop entries:** a Linux `.desktop` file with `Terminal=true`, and a macOS `.command` file. Both are launched by double-click.
- **Safe process ownership:** only recorded process groups are signalled. There are no name-based kills, no `nohup`, and no backgrounding of the supervisor.
- **Single instance and logs:** an advisory lock rejects a second copy, and logs are written outside the source tree with private permissions.
- **Verification checklist:** the skill lists static checks, graceful and forced stop tests, a startup-failure test, a minimal-PATH test, and a graphical launch check.

## Not for / limitations

- **Not a ready-made launcher.** The skill is an instruction set; the agent fills project-specific commands, ports, and working directories before the launcher runs.
- **POSIX only.** The supervisor template targets Linux and macOS. Windows has no equivalent process-group or signal model and is not covered.
- **Desktop coverage is partial.** The terminal open and close path was verified on KDE Plasma with Konsole. GNOME Terminal and macOS Terminal behavior is documented but not tested.
- **Generated launchers need per-project verification.** The supervisor was tested with stub HTTP services, not with every framework or product layout.
- **Automatic skill selection is untested.** Whether a model chooses this skill from its description depends on the model and the request.
- **Browser opening is best effort.** A missing browser handler prints the URL and does not stop the product.
- **No dependency installation.** The skill checks for prerequisites and reports missing ones; it does not install packages or build products.

## Reproduction environment

| Component | Requirement |
| --- | --- |
| Operating system | Nobara Linux 44, kernel 7.3.1, KDE Plasma on Wayland |
| Runtime | Python 3.14.8, standard library only |
| Harness | DeepSeek Harness and Pi for discovery tests |
| Tools | Git, `curl`, `desktop-file-validate`, `kioclient5` for the graphical launch test |
| Hardware | None beyond a desktop session; the supervisor starts two local HTTP stub servers |
| Input | The cloned repository and a project directory during verification |

## Install and run

```bash
LOCAL_AI=${LOCAL_AI:-$HOME/.config/local-ai}
mkdir -p "$HOME/.agents/skills" "$LOCAL_AI/skills/on-request"
git clone https://github.com/ThomasTZh/dsh-skill-create-launcher "$HOME/.agents/skills/create-launcher"
ln -sfn "$HOME/.agents/skills/create-launcher" "$LOCAL_AI/skills/on-request/create-launcher"
```

`~/.agents/skills` is the shared Agent Skills root read by DeepSeek Harness's `standard` preset and by Pi. The symlink into the on-request directory is read by the harness `general` and `matlab` presets, which set `includeDefaultRoots: false`.

Expected output: the agent lists a `create-launcher` skill. Ask it to create a launcher for the current project's product; the skill loads from [`SKILL.md`](SKILL.md) and copies the templates under [`references/`](references/).

## Uninstall

```bash
LOCAL_AI=${LOCAL_AI:-$HOME/.config/local-ai}
rm -f "$LOCAL_AI/skills/on-request/create-launcher"
rm -rf "$HOME/.agents/skills/create-launcher"
```

This removes the skill and its link. Launchers the skill generated inside project directories are deliberately left in place.

## Layout

| Component | Path | Contents | Class |
| --- | --- | --- | --- |
| Skill method | `SKILL.md` | Routing description, required behavior, discovery steps, configuration rules, verification workflow, guardrails | Original |
| Supervisor template | `references/supervisor.py` | Python process-group supervisor with readiness checks, browser opening, signal handling, and logging | Original |
| Linux desktop entry | `references/linux.desktop` | Double-click entry with `Terminal=true` and placeholders | Original |
| macOS command entry | `references/macos.command` | Double-click `.command` wrapper with placeholders | Original |
| Documentation | `README.md`, `THIRD_PARTY.md` | This page and the attribution record | Original |
| Licence | `LICENSE` | MIT, covering the original files | Original |
| Agent Skills specification | none | Front matter and discovery format [1] | Third-party |
| DeepSeek Harness | none | Host that discovers and loads the skill [2] | Third-party |
| Pi | none | Second host used for the discovery test [3] | Third-party |
| Python, Git, KDE, curl | none | Runtime and verification tools, not bundled | Third-party |

No upstream code, text, or binary is copied into this repository.

## Results

| Check | Conditions | Result |
| --- | --- | --- |
| Front matter | Parse `SKILL.md`; check `name`, description, and directory match | Pass: `name: create-launcher`, description present |
| pi discovery | Temporary `HOME`; `pi --mode rpc --offline` with a `get_commands` request | Pass: one `skill:create-launcher` entry; three commands total |
| Install and uninstall | Copy into a temporary `~/.agents/skills/create-launcher`, symlink into the on-request root, discover, remove, discover again | Pass: present after install, absent after uninstall |
| DSH general preset | Inspect the live on-request root and resolve the symlink | Pass: `create-launcher` resolves to the shared skill directory |
| DSH standard preset | Inspect the shipped preset and the default shared skill root | Pass: default roots include `~/.agents/skills`, where the skill is installed |
| Graceful stop | Two stub HTTP services; one SIGINT to the supervisor | Pass: exit 0, both ports closed, both process groups gone, clean stop logged |
| Forced stop | Stub services ignore SIGTERM; two SIGINTs 0.2 s apart with a 12 s graceful timeout | Pass: exit 0 in 415 ms, both ports and process groups gone |
| Single instance | Start a second copy while the first serves | Pass: second exits 0, reports already running, and creates no log |
| Port conflict | Occupy the configured frontend port, then start | Pass: exit 1, names the occupied port, starts no service |
| Desktop entry | `desktop-file-validate` on the filled Linux entry | Pass |
| Graphical launch | Filled Linux entry launched through `kioclient5` on KDE Plasma | Pass: a KDE launch opened and closed a new Konsole window on these byte-identical files; a later release-tree launch started and stopped both services |
| Private logs | Inspect the created log file and directory modes | Pass: file `0600`, directory `0700` |
| Privacy | Search tracked contents for the local home path and token-shaped strings | Pass: clean |

**Not tested:** GNOME Terminal, macOS Terminal, Windows, a real frontend/backend framework, and whether a model automatically selects the skill from its description.

## Acknowledgements

- The Agent Skills specification [1] defines the front matter and discovery shape this skill follows.
- DeepSeek Harness [2] and Pi [3] are the hosts used to check discovery. Both read the shared `~/.agents/skills` root; the harness `general` and `matlab` presets read the on-request directory through the symlink.
- Python's standard library provides the supervisor's HTTP, socket, process, signal, and threading primitives. KDE Plasma and Konsole provided the graphical launch check.

## References

1. Agent Skills specification. <https://agentskills.io/specification>.
2. DeepSeek Harness. <https://github.com/deepseek-ai/deepseek-harness>. MIT.
3. Pi. <https://github.com/earendil-works/pi>. MIT.

## Licenses

- **Original files:** `SKILL.md`, `references/supervisor.py`, `references/linux.desktop`, `references/macos.command`, `README.md`, and `THIRD_PARTY.md` are covered by the MIT [`LICENSE`](LICENSE), copyright 2026 Thomas.
- **Third-party components:** none are redistributed. The specification, hosts, runtime, and verification tools listed above keep their own terms; see [`THIRD_PARTY.md`](THIRD_PARTY.md).
- **Installed separately:** Python, Git, DeepSeek Harness, Pi, KDE Plasma, Konsole, curl, and `desktop-file-validate` are not bundled.
