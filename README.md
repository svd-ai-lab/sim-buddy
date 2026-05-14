# sim-buddy

**Drive local CAE, CFD, and FEA tools from a desktop AI assistant.**

sim-buddy is a WorkBuddy / CodeBuddy plugin marketplace that lets an AI agent
call the local [`sim` CLI](https://github.com/svd-ai-lab/sim-cli) and operate
engineering simulation software on your machine.

For Simplified Chinese docs, see [README.zh-CN.md](README.zh-CN.md).

## Plugins

**Tier 1 — installed by default:**

| Plugin | Solver | License |
|---|---|---|
| `sim-comsol` | COMSOL Multiphysics | Commercial (offline `.mph` inspection works without COMSOL) |
| `sim-openfoam` | OpenFOAM | Open source (GPL); supports local or remote sim-server |
| `sim-ltspice` | LTspice | ADI freeware (free for personal use) |
| `sim-installer` | meta — teaches the agent how to install more solvers | — |

**Tier 2 — opt-in (ask the agent or run the magic incantation below):**

| Plugin | Solver | Notes |
|---|---|---|
| `sim-matlab` | MATLAB / Simulink | needs MATLAB on the machine (matlabengine links at install time) |
| `sim-abaqus` | Abaqus | needs Abaqus to run |
| `sim-fluent` | Ansys Fluent | pulls `ansys-fluent-core` (~100MB); needs Ansys + Fluent |
| `sim-hfss` | Ansys HFSS | pulls `pyaedt` (~100MB); needs Ansys AEDT |
| `sim-mechanical` | Ansys Mechanical | pulls `ansys-mechanical-core`; needs Mechanical |
| `sim-simscale` | SimScale cloud CAE | needs SimScale API key, no local CAE software |
| `sim-workbench` | Ansys Workbench | pulls `ansys-workbench-core`; needs Workbench |

## How It Works

```text
You describe an engineering task
    |
    v
WorkBuddy / CodeBuddy loads the sim-buddy marketplace
    |
    v
The matching plugin SKILL shells out to the local sim CLI
    |
    v
sim CLI loads the installed driver (sim-plugin-<solver>)
    |
    v
The solver runs locally and returns artifacts/results
```

## Install

Prerequisites:

- Windows 10/11
- [WorkBuddy](https://copilot.tencent.com/work/) or a compatible CodeBuddy
  marketplace host, launched at least once
- Git for Windows

In a WorkBuddy / CodeBuddy chat, ask the assistant to run this PowerShell:

```powershell
irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
```

You can also run the same command directly in PowerShell.

The installer will:

1. Install `uv` if not already on `PATH`.
2. Install the global `sim` command with all Tier 1 plugins
   (`uv tool install sim-cli-core --with sim-plugin-comsol --with sim-plugin-openfoam --with sim-plugin-ltspice --upgrade --force`).
3. Clone / refresh this marketplace under
   `~/.workbuddy/plugins/marketplaces/sim-buddy/`.
4. For each installed sim-plugin-`<X>`, junction `plugins/sim-<X>/skill/`
   at its bundled `_skills/<X>/` directory. SKILL.md ships with the driver
   release, so skill and driver can never drift. Tier 2 entries get appended
   to `marketplace.json` automatically.
5. Register the local marketplace in
   `~/.workbuddy/plugins/known_marketplaces.json` and prompt you to restart
   WorkBuddy / CodeBuddy.

## Add a Tier 2 solver

Either ask the agent ("install the Fluent plugin"), or run directly:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent
```

Multiple at once:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent,mechanical,matlab
```

The installer detects previously-installed plugins via `uv tool list` —
no state file, just re-run and it stays current. Tier 2 install failures
(e.g., `sim-plugin-matlab` when MATLAB is not on the machine) are soft —
Tier 1 still ends up working.

## Try It

After installation, restart WorkBuddy / CodeBuddy and ask:

> Inspect this `.mph` file and summarize its physics, parameters, studies,
> and mesh state.

> Run an OpenFOAM steady-state cavity tutorial and report the residuals.

> Simulate this LTspice schematic, sweep R1 from 1k to 100k, plot output.

The agent loads the matching plugin SKILL, verifies the local `sim`
environment, and runs commands like:

```powershell
sim --version
sim plugin list
sim plugin doctor <solver>
sim check <solver>
sim connect --solver <solver>
```

## Other Solver Plugins (still in flight)

sim-cli has ~50 solver plugin repos under [svd-ai-lab](https://github.com/svd-ai-lab);
only the 10 listed above are published to PyPI as of now. The rest
(CalculiX, SU2, Elmer, gmsh, LS-DYNA, MAPDL, ...) are tracked in
[sim-plugin-index](https://github.com/svd-ai-lab/sim-plugin-index) and will
land here once they release.

## Troubleshooting

If the assistant cannot find `sim`, rerun the installer or run:

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --with sim-plugin-openfoam --with sim-plugin-ltspice --upgrade --force
```

If a solver is not detected, the plugin may still work offline (e.g.,
COMSOL `.mph` inspection); live solving requires the local software:

```powershell
sim check <solver>
sim plugin doctor <solver>
```

## License

Apache-2.0. See [LICENSE](LICENSE).

## Feedback

Open an issue at [svd-ai-lab/sim-buddy](https://github.com/svd-ai-lab/sim-buddy/issues).
