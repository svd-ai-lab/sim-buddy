# sim-buddy

**用桌面 AI 助手驱动本地 CAE / CFD / FEA 仿真工具。**

sim-buddy 是一个 WorkBuddy / CodeBuddy plugin marketplace。它让 AI Agent
可以调用本地 [`sim` CLI](https://github.com/svd-ai-lab/sim-cli)，并在你的电脑
上操作工程仿真软件。

本仓库当前提供一个 marketplace plugin：

| Plugin | Solver | 覆盖内容 |
|---|---|---|
| `sim-comsol` | COMSOL Multiphysics | 通过 sim CLI 使用 COMSOL live session、shared-desktop 协作、已保存 `.mph` 文件检查，以及 COMSOL 工作流指导 |

English docs: [README.md](README.md)

## 工作方式

```text
你描述一个工程任务
    |
    v
WorkBuddy / CodeBuddy 加载 sim-buddy marketplace
    |
    v
sim-comsol skill 调用本地 sim CLI
    |
    v
sim CLI 加载已安装的 COMSOL driver plugin
    |
    v
COMSOL Multiphysics 在本机运行并返回结果文件
```

## 安装

前提条件：

- Windows 10/11
- 已安装 [WorkBuddy](https://copilot.tencent.com/work/) 或兼容的 CodeBuddy marketplace host，并至少启动过一次
- Git for Windows
- 如果要实时求解或修改 COMSOL 模型，需要本机安装并授权 COMSOL Multiphysics

在 WorkBuddy / CodeBuddy 聊天框里，让助手运行这个 PowerShell 命令：

```powershell
irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
```

你也可以直接在 PowerShell 中运行同一条命令。

安装脚本会：

1. 如果 `PATH` 上没有 `uv`，先安装 `uv`。
2. 安装带 COMSOL plugin 支持的全局 `sim` 命令：
   `uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force`
3. clone 或刷新本 marketplace 到
   `~/.workbuddy/plugins/marketplaces/sim-buddy/`。
4. junction `plugins/sim-comsol/skill/` 到装好的
   `sim_plugin_comsol/_skills/comsol/` bundle。SKILL.md 跟着 driver release 走，
   sim-buddy 只是 manifest 壳，skill 和 driver 永远不会 drift。
5. 注册到 `~/.workbuddy/plugins/known_marketplaces.json`。
6. 提示你重启 WorkBuddy / CodeBuddy。

## 试用

安装后，重启 WorkBuddy / CodeBuddy，然后可以说：

> Inspect this `.mph` file and summarize its physics, parameters, studies, and
> mesh state.

如果本机已安装并授权 COMSOL，也可以说：

> Use COMSOL to solve `block.mph` for steady-state temperature under 100 W of
> heating, then report the result files.

Agent 会加载 `sim-comsol`，检查本地 `sim` 环境，并使用类似命令：

```powershell
sim --version
sim plugin list
sim plugin info comsol
sim plugin doctor comsol
sim check comsol
sim connect --solver comsol
```

## 其他 Solver Plugin

sim-cli 的 solver plugin 是普通 Python package。本 marketplace 当前只打包
COMSOL 的 WorkBuddy / CodeBuddy skill。

当前公开 plugin 列表和安装 package spec 请查看
[sim-plugin-index](https://github.com/svd-ai-lab/sim-plugin-index)。在普通
agent project 中，用 `uv` 安装 solver package，例如：

```powershell
uv add sim-cli-core sim-plugin-comsol
uv run sim plugin sync-skills --target .agents/skills --copy
uv run sim check comsol
```

## 排查问题

如果助手找不到 `sim`，可以重新运行安装脚本，或直接运行：

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force
```

如果没有检测到 COMSOL，plugin 仍然可以检查已保存的 `.mph` 文件，但实时求解需要
本机 COMSOL 安装和 license：

```powershell
sim check comsol
sim plugin doctor comsol
```

## License

Apache-2.0. See [LICENSE](LICENSE).

## 反馈

请在 [svd-ai-lab/sim-buddy](https://github.com/svd-ai-lab/sim-buddy/issues)
提交 issue。
