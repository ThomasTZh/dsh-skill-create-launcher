# Third-party software and attribution

No upstream code, text, or binary is included in this repository. The instruction file, supervisor template, desktop entries, and documentation are original.

## Host and dependencies

| Component | Role here | Project | Licence | Distribution |
|---|---|---|---|---|
| Agent Skills specification | Front matter and discovery format followed by the skill | <https://agentskills.io/specification> | specification, not software | referenced only |
| DeepSeek Harness | Host that discovers and loads the skill | [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) | MIT | installed separately |
| Pi | Second host used for the discovery test | [earendil-works/pi](https://github.com/earendil-works/pi) | MIT | installed separately |
| Python | Runtime for the generated supervisor | [python/cpython](https://github.com/python/cpython) | PSF-2.0 | installed separately |
| Git | Installation and version control | [git/git](https://github.com/git/git) | GPL-2.0 | installed separately |
| KDE Plasma and Konsole | Desktop and terminal used for the graphical launch test | [KDE](https://invent.kde.org/plasma/plasma-desktop) | GPL-2.0-or-later | installed separately |
| curl | Readiness and HTTP checks during verification | [curl/curl](https://github.com/curl/curl) | curl licence | installed separately |
| desktop-file-validate | Desktop entry syntax check during verification | [freedesktop.org](https://www.freedesktop.org/wiki/Software/desktop-file-utils/) | GPL-2.0-or-later | installed separately |

## Copyright and licence compliance

- **Original files:** the MIT [`LICENSE`](LICENSE) covers `SKILL.md`, `references/supervisor.py`, `references/linux.desktop`, `references/macos.command`, `README.md`, and `THIRD_PARTY.md`.
- **Upstream notices:** none are redistributed, because no upstream file is present here.
- **Unresolved:** none.
