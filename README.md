# sim-buddy

**Drive local CAE, CFD, and FEA tools from a desktop AI assistant.**

sim-buddy is a WorkBuddy / CodeBuddy plugin marketplace that lets an AI agent
call the local [`sim` CLI](https://github.com/svd-ai-lab/sim-cli) and operate
engineering simulation software on your machine.

This repository currently ships one marketplace plugin:

| Plugin | Solver | What it covers |
|---|---|---|
| `sim-comsol` | COMSOL Multiphysics | Live COMSOL sessions through the sim CLI, shared-desktop collaboration, saved `.mph` inspection, and COMSOL workflow guidance |

For Simplified Chinese docs, see [README.zh-CN.md](README.zh-CN.md).

## How It Works

```text
You describe an engineering task
    |
    v
WorkBuddy / CodeBuddy loads the sim-buddy marketplace
    |
    v
The sim-comsol skill shells out to the local sim CLI
    |
    v
sim CLI loads the installed COMSOL driver plugin
    |
    v
COMSOL Multiphysics runs locally and returns artifacts/results
```

## Install

Prerequisites:

- Windows 10/11
- [WorkBuddy](https://copilot.tencent.com/work/) or a compatible CodeBuddy
  marketplace host, launched at least once
- Git for Windows
- COMSOL Multiphysics if you want to solve or modify live COMSOL models

In a WorkBuddy / CodeBuddy chat, ask the assistant to run this PowerShell:

```powershell
irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
```

You can also run the same command directly in PowerShell.

The installer will:

1. Install `uv` if it is not already on `PATH`.
2. Install the global `sim` command with COMSOL plugin support:
   `uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force`
3. Clone or refresh this marketplace under
   `~/.workbuddy/plugins/marketplaces/sim-buddy/`.
4. Register the local marketplace in
   `~/.workbuddy/plugins/known_marketplaces.json`.
5. Ask you to restart WorkBuddy / CodeBuddy.

## Try It

After installation, restart WorkBuddy / CodeBuddy and ask:

> Inspect this `.mph` file and summarize its physics, parameters, studies, and
> mesh state.

Or, if COMSOL is installed and licensed on the machine:

> Use COMSOL to solve `block.mph` for steady-state temperature under 100 W of
> heating, then report the result files.

The agent should load `sim-comsol`, verify the local `sim` environment, and use
commands such as:

```powershell
sim --version
sim plugin list
sim plugin info comsol
sim plugin doctor comsol
sim check comsol
sim connect --solver comsol
```

## Other Solver Plugins

sim-cli supports solver plugins as normal Python packages. This marketplace
currently bundles the WorkBuddy / CodeBuddy skill for COMSOL only.

For the current public plugin list and install package specs, use the
[sim-plugin-index](https://github.com/svd-ai-lab/sim-plugin-index). In ordinary
agent projects, install solver packages with `uv`, for example:

```powershell
uv add sim-cli-core sim-plugin-comsol
uv run sim plugin sync-skills --target .agents/skills --copy
uv run sim check comsol
```

## Troubleshooting

If the assistant cannot find `sim`, rerun the installer or run:

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force
```

If COMSOL is not detected, the plugin may still inspect saved `.mph` files, but
live solving requires a local COMSOL installation and license:

```powershell
sim check comsol
sim plugin doctor comsol
```

## License

Apache-2.0. See [LICENSE](LICENSE).

## Feedback

Open an issue at [svd-ai-lab/sim-buddy](https://github.com/svd-ai-lab/sim-buddy/issues).
