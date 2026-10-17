# agent-addon/ — the headless core build of this fork

This fork of [storytold/figcraft](https://github.com/storytold/figcraft) is the **core engine** of a
local Code ↔ Figma agent toolchain. The agent-facing part (MCP server, token slicing, code → design
conversion) lives in a separate repository, `fig-agent-addon`, which only calls the binary built
here. Nothing in this directory changes FigCraft's Rust code.

## Branch model

| Branch | Contents | Rule |
|---|---|---|
| `upstream-sync` | exact mirror of `upstream/main` | fast-forward only, never commit here |
| `agent-addon` | `upstream-sync` + this `agent-addon/` directory | rebased onto `upstream-sync` on every sync |
| `main` | GitHub's default fork branch | unused; kept in sync with upstream by GitHub's "Sync fork" |

Upstream ships everything the toolchain needs headless already (`apps/figcraft-cli`: `info`,
`convert`, `export`, `render`, `run`, `mcp`; `crates/mcp`: `get_node {id, depth}`, `inspect.code`,
`.fig` import/export), so `agent-addon` carries **no Rust changes**. If one ever becomes
necessary, keep it to a minimal CLI surface in `apps/figcraft-cli` and prefer sending it upstream
so the fork can drop it again.

## Scripts

```sh
agent-addon/sync-upstream.sh          # fetch upstream → ff upstream-sync → rebase agent-addon → build
agent-addon/sync-upstream.sh --push   # …and push both branches to origin
agent-addon/build.sh                  # cargo build --release -p figcraft-cli → agent-addon/dist/figcraft-cli + VERSION
agent-addon/build.sh --link           # …and symlink ~/.local/bin/figcraft-cli to it (for a global fig-agent install)
agent-addon/fonts.sh                  # clone/update ../craft-fonts (embedded fonts), then rebuild
```

### Fonts

`crates/text/build.rs` embeds [storytold/craft-fonts](https://github.com/storytold/craft-fonts)
when it is checked out at `../craft-fonts` (`.cargo/config.toml` sets `CRAFT_FONTS_DIR`). That
repository holds fallback fonts for Japanese, Simplified Chinese, Arabic and Thai, not Inter or
other Latin presentation fonts, and its CJK set does not cover Hangul, so Korean and Latin text
lay out with the installed system fonts in any case (macOS: Apple SD Gothic Neo, Helvetica, Inter
if installed). Without the checkout the binary has **no built-in fonts** and `--no-system-fonts`
renders no text at all. `agent-addon/fonts.sh` is optional; leave system fonts on (the default) for
renders and reserve `--no-system-fonts` for CI-style runs that must not depend on the machine.

`agent-addon/dist/` is ignored by git. `VERSION` records the CLI version, the fork commit and the
upstream tag the binary was built from, so the addon can report what it is running on.

A first checkout:

```sh
git clone https://github.com/doooss/figcraft-agent-addon.git figcraft-agent-addon
cd figcraft-agent-addon
git remote add upstream https://github.com/storytold/figcraft.git
git checkout agent-addon
agent-addon/fonts.sh
agent-addon/build.sh
```

## How the addon finds the binary

In order: the `FIGCRAFT_CLI` environment variable, `../figcraft-agent-addon/agent-addon/dist/figcraft-cli`
relative to the addon checkout, then `figcraft-cli` on `PATH` (`build.sh --link` puts it there).

## Useful headless commands

```sh
CLI=agent-addon/dist/figcraft-cli
$CLI info file.figcraft --json                 # pages, top-level frames, counts
$CLI convert file.fig file.figcraft            # Figma .fig → native (best effort)
$CLI convert file.figcraft file.json           # native → FigCraft JSON (document.json)
$CLI export file.figcraft -o out.fig           # native → Figma .fig (experimental)
$CLI run script.json --out out.figcraft        # headless command script (see docs/cli.md)
$CLI mcp                                       # MCP on stdio (see docs/mcp.md)
```

Text layout uses installed system fonts plus the embedded fallbacks (see Fonts above).

## Licence

FigCraft is dual-licensed `MIT OR Apache-2.0` (`LICENSE-MIT`, `LICENSE-APACHE`, `NOTICE`). This fork
keeps those files and the original copyright notices unchanged. Anything distributed from this fork
must keep them too; a product built on it uses its own name and branding, not FigCraft's or
ArtCraft's (see `docs/brand/LICENSE-brand.txt`).
