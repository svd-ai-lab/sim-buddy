# sim-comsol

`sim-comsol` 是本 marketplace 里的 WorkBuddy / CodeBuddy skill，用来通过
[`sim` CLI](https://github.com/svd-ai-lab/sim-cli) 驱动 **COMSOL
Multiphysics**。

它会帮助 Agent 选择合适的 COMSOL 控制路径：

- 通过 `sim connect --solver comsol` 启动或连接 live COMSOL session
- 用户希望看着 Model Builder 更新时，使用 shared-desktop 协作模式
- 不启动 COMSOL 的情况下检查已保存 `.mph` 文件
- 只有在明确需要时，才参考旧的 Desktop attach / Java Shell 回退路径

## 安装后怎么用

WorkBuddy / CodeBuddy 会读取同目录的 [`SKILL.md`](./SKILL.md)，并在任务和
COMSOL 相关时调用这个 skill。你可以直接说：

> Inspect this `.mph` file and summarize its physics, parameters, studies, and
> mesh state.

如果本机已安装并授权 COMSOL，也可以说：

> Use COMSOL to solve `block.mph` for steady-state temperature under 100 W of
> heating, then report the result files.

Agent 应先检查本地 runtime：

```powershell
sim --version
sim plugin list
sim plugin info comsol
sim plugin doctor comsol
sim check comsol
```

## Runtime 安装方式

顶层 sim-buddy 安装脚本会配置带 COMSOL plugin 的全局 `sim` 命令：

```powershell
uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force
```

如果是在普通 agent project 里使用，而不是安装本 marketplace，请用项目环境：

```powershell
uv add sim-cli-core sim-plugin-comsol
uv run sim plugin sync-skills --target .agents/skills --copy
uv run sim check comsol
```

COMSOL Multiphysics 本体和 license 不随本 plugin 分发。实时建模 / 求解需要本机
安装并授权 COMSOL；没有 live COMSOL session 时，已保存 `.mph` 文件检查仍然可用。

## Skill 内容

详见 [`SKILL.md`](./SKILL.md)。WorkBuddy / CodeBuddy 加载该文件作为 COMSOL
工作流指南。
