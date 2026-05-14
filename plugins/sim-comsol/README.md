# sim-comsol

`sim-comsol` is the WorkBuddy / CodeBuddy skill in this marketplace for
COMSOL Multiphysics workflows through the
[`sim` CLI](https://github.com/svd-ai-lab/sim-cli).

It helps an agent choose and use the right COMSOL control path:

- live COMSOL sessions through `sim connect --solver comsol`
- shared-desktop collaboration when the engineer wants to watch the model tree
- saved `.mph` inspection without launching COMSOL
- small legacy desktop-attach fallback guidance when explicitly needed

## After Installation

WorkBuddy / CodeBuddy reads [`SKILL.md`](./SKILL.md) and invokes this plugin
when the task is about COMSOL. You can ask:

> Inspect this `.mph` file and summarize its physics, parameters, studies, and
> mesh state.

Or, if COMSOL is installed and licensed:

> Use COMSOL to solve `block.mph` for steady-state temperature under 100 W of
> heating, then report the result files.

The agent should verify the local runtime with:

```powershell
sim --version
sim plugin list
sim plugin info comsol
sim plugin doctor comsol
sim check comsol
```

## Runtime Setup

The top-level sim-buddy installer configures a global `sim` command with the
COMSOL plugin:

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force
```

For ordinary agent projects outside this marketplace, use a project
environment instead:

```powershell
uv add sim-cli-core sim-plugin-comsol
uv run sim plugin sync-skills --target .agents/skills --copy
uv run sim check comsol
```

COMSOL Multiphysics itself is not bundled. Live solving requires a local COMSOL
installation and license. Saved `.mph` inspection can still be useful without a
live COMSOL session.

## Skill Details

See [`SKILL.md`](./SKILL.md). WorkBuddy / CodeBuddy loads that file as the
agent-facing COMSOL workflow guide.
