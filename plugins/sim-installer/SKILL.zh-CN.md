---
name: sim-installer
description: 当用户在 WorkBuddy / CodeBuddy 里想用一个 sim-buddy 默认没装的 solver(MATLAB / Abaqus / Fluent / HFSS / Mechanical / Simscale / Workbench)时使用。给用户一条 PowerShell 一句话装好对应 sim-plugin-*、junction skill bundle、注册到 marketplace,然后让他重启 WorkBuddy。不要尝试手动一步一步装 driver/skill,本 skill 的 magic 命令一条搞定。
---

# sim-installer — 一句话装更多 sim plugin

## 何时使用本 skill

用户说 / 暗示要用某个 solver,但你跑 `sim plugin list` 发现没有那个 plugin,
并且 sim-buddy 当前 marketplace 也没加载该 plugin 的 skill。例如:

- "帮我用 Fluent 算一下风扇" → 当前 `sim plugin list` 没 fluent
- "我想用 MATLAB 跑这段代码" → 没 matlab plugin
- "Abaqus 怎么调用?" / "我要 HFSS 仿天线" / "用 Mechanical 算应力"

## 当前可装清单(都在 PyPI 上)

| Solver | sim-plugin 包 | 本机需要什么 |
|---|---|---|
| MATLAB / Simulink | `sim-plugin-matlab` | 本机装 MATLAB (matlabengine 装包阶段会 link MATLAB lib;没装会失败) |
| Abaqus | `sim-plugin-abaqus` | 本机装 Abaqus (driver 适配器轻,运行需 Abaqus) |
| Ansys Fluent | `sim-plugin-fluent` | 本机装 Ansys + Fluent license (driver 拉 `ansys-fluent-core` ~100MB) |
| Ansys HFSS | `sim-plugin-hfss` | 本机装 Ansys AEDT (driver 拉 `pyaedt` ~100MB) |
| Ansys Mechanical | `sim-plugin-mechanical` | 本机装 Ansys Mechanical (driver 拉 `ansys-mechanical-core`) |
| SimScale | `sim-plugin-simscale` | SimScale 云端账号 + API key,不需要本机 CAE 软件 |
| Ansys Workbench | `sim-plugin-workbench` | 本机装 Ansys Workbench (driver 拉 `ansys-workbench-core`) |

(默认已经装了 COMSOL / OpenFOAM / LTspice 三件套 + 本 sim-installer skill。)

## 一句话装(给用户复制运行)

把下面这条 PowerShell 给用户运行(可以一次装多个,逗号分隔):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent
```

多个例子:

```powershell
# 装 MATLAB
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers matlab

# 装 Fluent + Mechanical (Ansys 套件)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent,mechanical
```

脚本内部干 3 件事:
1. `uv tool install sim-cli-core --with sim-plugin-<X> --upgrade` 装那个 plugin
2. mklink /J 把 `plugins/sim-<X>/skill/` 链接到包里的 `_skills/<X>/`
3. 重写 `marketplace.json` 加入新 plugin entry + 更新 known_marketplaces.json

跑完后**用户必须重启 WorkBuddy / CodeBuddy**(marketplace 是启动时扫的),不然
新 plugin 的 SKILL 不会被 host 加载。

## 安装失败怎么办

- `sim-plugin-matlab` 装包阶段 `matlabengine` 编译 fail → 用户本机没装 MATLAB。
  让用户先装 MATLAB,再重跑命令。或者跟用户讲清楚:matlabengine 装不上 = 没 MATLAB
  = 这个 plugin 用不了。
- 其他 plugin (ansys-*-core 那几个) 装包通常成功(只是 Python 适配器),失败一般
  是网络;让用户重试。
- 装包成功但 `sim check <solver>` fail → driver 在,但本机商业软件没装/没 license。
  agent 不要尝试解决这个,告诉用户先把本机软件装好。

## 不要做的事

- **不要自己手动一步步装 driver/skill**(`sim plugin install` / mklink 自己拼)。
  脚本已经处理好所有边界情况,你重写的版本一定不全。
- **不要装 sim-buddy 这次没列的 plugin** (`sim-plugin-cfx` / `sim-plugin-mapdl` /
  其他 GitHub-only 的 30+ plugin)。这些还没发到 PyPI,装不上。如果用户问,
  告诉他们这个 plugin 还在 sim CLI 团队的发布队列里,可以在
  https://github.com/svd-ai-lab/sim-plugin-index 关注进度。
- **不要在脚本失败后跑 destructive 操作**(`uv tool uninstall` / 删 plugins/
  目录 / 删 marketplaces/ 整个 sim-buddy)。失败就把错误贴回来让用户人工判断。

## 跟用户的对话节奏

1. 用户说"我要用 X" → 你回复"X 当前默认没装,需要装 sim-plugin-X。请运行以下
   PowerShell,跑完重启 WorkBuddy:" + 给出上面那条命令
2. 用户跑完命令,贴出 success 输出 → 你提示"装好了,请重启 WorkBuddy"
3. 用户重启后,sim plugin list 应该出现新 plugin → 你切换到对应 solver 的 SKILL 继续
