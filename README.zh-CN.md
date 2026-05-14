# sim-buddy

**用桌面 AI 助手驱动本地 CAE / CFD / FEA 仿真工具。**

sim-buddy 是一个 WorkBuddy / CodeBuddy plugin marketplace。它让 AI Agent
可以调用本地 [`sim` CLI](https://github.com/svd-ai-lab/sim-cli),并在你的电脑
上操作工程仿真软件。

English docs: [README.md](README.md)

## 包含的 plugin

**Tier 1 — 默认装上即开局:**

| Plugin | Solver | License |
|---|---|---|
| `sim-comsol` | COMSOL Multiphysics | 商业(没装 COMSOL 也能离线 inspect `.mph` 文件) |
| `sim-openfoam` | OpenFOAM | 开源 (GPL);本地或远程 sim-server 都行 |
| `sim-ltspice` | LTspice | ADI freeware,个人使用免费 |
| `sim-installer` | meta — 教 agent 怎么装更多 solver | — |

**Tier 2 — 按需安装(让 agent 一句话搞定,或者自己跑下面那条命令):**

| Plugin | Solver | 注意 |
|---|---|---|
| `sim-matlab` | MATLAB / Simulink | 需本机装 MATLAB(matlabengine 装包时 link MATLAB lib) |
| `sim-abaqus` | Abaqus | 运行时需 Abaqus |
| `sim-fluent` | Ansys Fluent | 拉 `ansys-fluent-core`(~100MB);运行需 Ansys + Fluent |
| `sim-hfss` | Ansys HFSS | 拉 `pyaedt`(~100MB);运行需 Ansys AEDT |
| `sim-mechanical` | Ansys Mechanical | 拉 `ansys-mechanical-core`;运行需 Mechanical |
| `sim-simscale` | SimScale 云端 CAE | 需 SimScale API key,不需要本机 CAE 软件 |
| `sim-workbench` | Ansys Workbench | 拉 `ansys-workbench-core`;运行需 Workbench |

## 工作方式

```text
你描述一个工程任务
    |
    v
WorkBuddy / CodeBuddy 加载 sim-buddy marketplace
    |
    v
匹配 solver 的 plugin SKILL 调用本地 sim CLI
    |
    v
sim CLI 加载对应 driver (sim-plugin-<solver>)
    |
    v
仿真器在本机运行并返回结果
```

## 安装

前提条件:

- Windows 10/11
- 已安装 [WorkBuddy](https://copilot.tencent.com/work/) 或兼容的 CodeBuddy
  marketplace host,并至少启动过一次
- Git for Windows

在 WorkBuddy / CodeBuddy 聊天框里,让助手运行这个 PowerShell:

```powershell
irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
```

你也可以直接在 PowerShell 中运行同一条命令。

安装脚本会:

1. 如果 `PATH` 上没有 `uv`,先安装 `uv`。
2. 装全局 `sim` 命令 + 全部 Tier 1 plugin
   (`uv tool install sim-cli-core --with sim-plugin-comsol --with sim-plugin-openfoam --with sim-plugin-ltspice --upgrade --force`)。
3. clone / refresh 本 marketplace 到
   `~/.workbuddy/plugins/marketplaces/sim-buddy/`。
4. 对每个装上的 `sim-plugin-<X>`,junction `plugins/sim-<X>/skill/` 到包内的
   `_skills/<X>/`。SKILL.md 跟着 driver release 走,sim-buddy 只是 manifest
   壳,skill 和 driver 永远不会 drift。Tier 2 plugin 会自动追加到 marketplace.json。
5. 注册到 `~/.workbuddy/plugins/known_marketplaces.json` 并提示重启 WorkBuddy。

## 加装 Tier 2 solver

可以让 agent 一句话搞定("装个 Fluent plugin"),或者自己跑:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent
```

一次装多个:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent,mechanical,matlab
```

install.ps1 通过 `uv tool list` 反推之前装了什么 —— 不维护 state file,重跑就
保留状态。Tier 2 装包失败(如本机没 MATLAB → sim-plugin-matlab 装不上)会软
fail,Tier 1 依然能用。

## 试用

装完重启 WorkBuddy / CodeBuddy,可以说:

> 帮我看看这个 .mph 文件用了什么物理场、参数和 mesh 设置

> 用 OpenFOAM 跑稳态 cavity 教程,报一下 residuals

> 这个 LTspice 原理图扫 R1 从 1k 到 100k,画输出

Agent 会加载对应 plugin 的 SKILL,检查本地 sim 环境,跑类似命令:

```powershell
sim --version
sim plugin list
sim plugin doctor <solver>
sim check <solver>
sim connect --solver <solver>
```

## 其他 Solver Plugin(还在路上)

sim-cli 在 [svd-ai-lab](https://github.com/svd-ai-lab) 下有 ~50 个 solver
plugin repo,目前 10 个发到 PyPI(就是上面表里那 10 个)。其他的(CalculiX、
SU2、Elmer、gmsh、LS-DYNA、MAPDL 等)还在 PyPI 队列中,跟踪
[sim-plugin-index](https://github.com/svd-ai-lab/sim-plugin-index) 看进度。

## 排查问题

如果助手找不到 `sim`,可以重新运行安装脚本,或直接运行:

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --with sim-plugin-openfoam --with sim-plugin-ltspice --upgrade --force
```

如果某个 solver 没被检测到,plugin 仍可能离线工作(比如 COMSOL `.mph`
inspection);live solve 需要本机软件:

```powershell
sim check <solver>
sim plugin doctor <solver>
```

## License

Apache-2.0. See [LICENSE](LICENSE).

## 反馈

请在 [svd-ai-lab/sim-buddy](https://github.com/svd-ai-lab/sim-buddy/issues)
提交 issue。
