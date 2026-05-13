---
name: sim-comsol
description: Use when the user asks for COMSOL Multiphysics work — building, debugging, solving, or inspecting `.mph` models through the `sim` CLI's COMSOL driver. Covers JPype Java API sessions, shared-desktop GUI collaboration, offline `.mph` introspection, and a fragile Desktop attach fallback. Always prefer `sim connect --solver comsol` over raw COMSOL APIs.
---

# COMSOL via sim CLI (WorkBuddy plugin)

This skill teaches an LLM agent how to drive **COMSOL Multiphysics** from
inside a WorkBuddy or CodeBuddy session by shelling out to the `sim` CLI.

## Prerequisite check (before the first COMSOL command)

If you are not sure whether the user has sim + the COMSOL driver installed,
run these once at the start of a COMSOL conversation:

```powershell
sim --version              # confirms sim CLI is on PATH
sim check comsol           # confirms COMSOL driver is registered AND a local COMSOL install is detected
```

If `sim --version` fails: tell the user to run `pip install sim-cli-core`
(or `uv tool install sim-cli-core`) and re-open the prompt.

If `sim check comsol` reports the driver is missing: run
`sim plugin install comsol` (this is the `sim-plugin-comsol` PyPI package).

If `sim check comsol` reports the driver is present but no local COMSOL is
found: the user does not have COMSOL Multiphysics installed. Don't try to
solve. Offer to inspect a saved `.mph` archive instead (works without a
live COMSOL — see "Saved `.mph` inspection" below).

## Control path — pick first

| Path | Use for | Avoid for |
|---|---|---|
| `sim connect --solver comsol` (JPype, server-backed) | Building, solving, inspecting, saving `.mph`, repeatable case generation. Default. | Rarely. |
| `sim connect --solver comsol --ui-mode gui --driver-option visual_mode=shared-desktop` | Same as above, **plus** the user wants to watch the Model Builder tree update live. | Headless / unattended runs. |
| Saved `.mph` archive inspection (no JVM) | Offline summaries, "what's in this file?", diffs. | Mutating a model. |
| Desktop attach (Java Shell, UIA) | Tiny edits inside an already-open ordinary COMSOL Desktop. Fragile. | Default routing. Long builds. Anything that needs structured exceptions. |
| `comsolcompile` + `comsolbatch` | Sandboxed one-shot Java workflows. Used by benchmarks when sim CLI isn't available. | Anything stateful. Prefer sim runtime when available. |

## Required protocol — the model is a live engineering state

Treat COMSOL as a stateful Java tree, not a code generator. Many `set(...)`
calls mutate the model but downstream objects don't refresh until the
relevant sequence is built or run. Use `run()` calls as **intentional
synchronization points** when the next step depends on updated state — not
mechanically after every line.

1. **For saved-`.mph` questions** (parameters, physics tags, mesh size,
   solved vs. unsolved): use offline `.mph` inspection. No `sim connect`
   needed.
2. **For live work**: choose a control path, then `sim check comsol`,
   then `sim connect --solver comsol [--ui-mode gui ...]`.
3. **Establish identity and workdir** before mutating: set a model tag
   derived from the case name, save the `.mph` early to an absolute path,
   keep files under `<workdir>/{model,input,output,scripts,logs}/`.
4. **Inspect the baseline** with `sim inspect session.health` and
   `sim inspect comsol.model.describe_text` before touching anything.
5. **Execute ONE bounded modeling step** — geometry, then materials, then
   physics, then mesh, then study, then results. Don't write a 200-line
   monolithic builder.
6. **Inspect after every step**: `sim inspect last.result` and
   `sim inspect comsol.node.properties:<tag>`. Save a checkpoint `.mph`
   after each major layer (`<case>_01_geometry.mph` etc.).
7. **Continue only after the live model matches intent**.

## COMSOL-specific hard constraints

1. **Never call `mph.start()` or `client.create()` from a snippet.**
   sim CLI already started a COMSOL JVM and bound a `model` handle.
   A second `start()` spawns a conflicting JVM.
2. **Image export is broken on Windows for the JPype path.** Prefer
   `EvalGlobal` / `EvalPoint` / Numeric probes / exported CSV data over
   `model.result().export()` PNGs.
3. **Never hardcode property names before inspecting the live node.**
   Use `sim inspect comsol.node.properties:<tag-or-dot-path>` first.
4. **Don't run long monolithic builders.** Build one layer, inspect,
   continue.
5. **`comsolcompile` path**: Java MUST be **chain-style**
   `model.X("tag").Y("tag2")...`. There is NO public `Component`,
   `Geometry`, `HeatTransfer`, etc. type. Writing `Component c = ...`
   produces `cannot be resolved to a type`.

## Saved `.mph` inspection (offline, no JVM)

For "what's in this `.mph`?" questions, use the stdlib reader instead of
spinning up COMSOL:

```python
from sim_plugin_comsol.lib import inspect_mph
summary = inspect_mph("path/to/case.mph")   # dict of parameters, physics, mesh, solved status
```

`MphArchive` (context manager) and `mph_diff` (two-file delta) are also
available. The `.mph` file is a ZIP archive; the global parameter
`T="33"` convention identifies COMSOL 6.x format files. This works
without a COMSOL license.

## Live introspection (during a sim session)

After `sim connect --solver comsol`, the following inspect targets are
the canonical ones. Don't guess — inspect first.

```powershell
sim inspect session.health                       # ports, PIDs, ui_mode, model_builder_live
sim inspect session.versions                     # active solver layer + SDK
sim inspect last.result                          # most recent exec result + .mph probe
sim inspect comsol.model.identity                # tag, file_path, checkpoint_ready
sim inspect comsol.model.describe_text           # text dump of the model tree
sim inspect comsol.node.properties:<dot-path>    # one node's properties before set()
```

Treat `checkpoint_ready: false`, missing `file_path`, or a bound tag
that does not match `active_model_tag` as **pause-and-repair** state.

## Shared-desktop GUI mode (user watches Model Builder)

When the user wants to see the Model Builder tree update live as the
agent works:

```powershell
sim connect --solver comsol --ui-mode gui --driver-option visual_mode=shared-desktop
sim inspect session.health
```

Confirm `effective_ui_mode: shared-desktop`,
`ui_capabilities.model_builder_live: true`, and `active_model_tag` names
the model your snippets will mutate. If `model_builder_live: false`, the
Desktop and JPype are not in sync — fix that before continuing.

Gotcha: launching `comsol.exe mphclient -host localhost -port <port>`
DOES attach a full Desktop to `comsolmphserver`. However, if JPype calls
`ModelUtil.create("SomeTag")`, the Desktop won't switch to that new tag —
it stays on its active `Model1`. The shared-desktop mode therefore
discovers / negotiates the active Desktop tag and routes agent edits to
THAT tag.

## Attach-only external server (multi-session sharing)

For repeated API client disconnects or "one COMSOL server survives
multiple sim sessions":

```powershell
# User starts the server first in a Windows shell:
comsolmphserver.exe -port 2036 -multi on -login auto -silent

# Then sim attaches in attach-only mode:
sim connect --solver comsol --ui-mode gui `
  --driver-option attach_only=true `
  --driver-option port=2036 `
  --driver-option visual_mode=shared-desktop
```

In attach-only mode, `session.health` shows `server_owner: "external"`
and `attach_only: true`. `sim disconnect` releases the JPype client and
any plugin-launched Desktop, but does **not** kill the external
`comsolmphserver`.

## Fragile fallback: Desktop attach (Java Shell)

Skip this section for normal COMSOL work. Use it only when the user
explicitly wants a small edit in an already-open ordinary Desktop and
refuses the server-backed `shared-desktop` path.

```powershell
uvx --from sim-plugin-comsol sim-comsol-attach open --json --timeout 120
uvx --from sim-plugin-comsol sim-comsol-attach health --json
uvx --from sim-plugin-comsol sim-comsol-attach exec --file step.java --submit-key ctrl_enter --json
```

Gotchas:
- COMSOL 6.4 Desktop windows may be titled `Untitled.mph - COMSOL
  Multiphysics`; target discovery must match substring, not prefix.
- Use `--submit-key ctrl_enter`. Click-targeting the Run button can paste
  code without reliably executing it.
- Java Shell may not have a current `model` / `m` variable. Probe with a
  tiny `System.out.println(...)` first.
- File-system writes from Java Shell can be denied by COMSOL's Security
  preference. Use in-model tables or have the user enable file access.
- Avoid duplicate plot labels — COMSOL throws before later plot setup
  lines run.
- For result plots from table data, the Java feature type is `Table`
  (under a `PlotGroup1D`), NOT `TableGraph`.

## COMSOL-specific dialogs

- **"连接到 COMSOL Multiphysics Server"** / **"Connect to COMSOL
  Multiphysics Server"** — may be a stale or separate Desktop login
  dialog. Does NOT prove the JPype server session failed. Verify with
  `sim inspect session.health` first.
- **"是否保存更改?"** / **"Save changes?"** — appears on Desktop close
  if a separately opened `.mph` has unsaved edits. Choose Save / Don't
  Save according to user intent.

## Screenshot responsibility

If you have access to the user's desktop (e.g. through WorkBuddy's own
screen-capture capability), prefer that over `sim screenshot` — it sees
exactly what the user sees. Use `sim screenshot` only when the solver GUI
is on a remote host.

## Working folder convention

```
<workdir>/
  model/<case_slug>.mph           ← the main model
  model/<case_slug>_01_geometry.mph  ← checkpoint after geometry
  model/<case_slug>_02_materials.mph
  model/<case_slug>_03_solved.mph
  input/                          ← user data / meshes / CAD imports
  output/                         ← exported CSV / VTU / images
  scripts/                        ← Python or Java snippets
  logs/                           ← solver logs
```

Set `model.modelPath(...)` to `input/` and `model/` when the workflow
uses external files. Prefer absolute paths for save / export / log
targets — don't rely on COMSOL's launch directory.

## When you're stuck

1. `sim inspect session.health` first — most "stuck" cases are
   `model_builder_live: false`, a disconnected JPype, or a stale
   Desktop dialog blocking the server.
2. `sim inspect last.result` — gives you the exception + workdir state
   from the most recent `sim exec`.
3. For Java compile errors in the `comsolcompile` path: it's almost
   always typed-variable usage. Re-write as chain-style.
4. For "image export failed on Windows": it's a known issue — switch to
   numeric probes + CSV export, then plot in matplotlib / pyvista from
   the exported data.

## Reference

Full plugin reference (deep API patterns, Java batch examples, MPH file
format) ships with the `sim-plugin-comsol` Python package. After
`sim plugin install comsol`, the reference docs are at:

```
<sim plugin install prefix>/sim_plugin_comsol/_skills/comsol/base/reference/
```

The four most useful files:

| File | When to read |
|---|---|
| `runtime_introspection.md` | Building any new inspect target / interpreting an inspect result |
| `java_api_patterns.md` | Writing live JPype snippets — tags, properties, selections |
| `java_batch_patterns.md` | Writing `.java` for `comsolcompile` — chain-style rules, anti-patterns |
| `mph_file_format.md` | `.mph` archive layout, `nodeType` variants, T-parameter contract |
