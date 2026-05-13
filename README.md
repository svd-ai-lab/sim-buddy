# sim-buddy

**用自然语言驱动本地 CAE / CFD / FEA 仿真。** WorkBuddy / CodeBuddy
marketplace,每个仿真器一个独立 plugin,底层调用
[`sim`](https://github.com/svd-ai-lab/sim-cli) 统一驱动 30+ 主流仿真器
(COMSOL / OpenFOAM / Fluent / Ansys Mechanical / LTspice / Abaqus / 等)。

> 跟 CodeBuddy / WorkBuddy 的关系: WorkBuddy 是腾讯云的桌面 AI Agent。
> 本 marketplace 让它从"会写文档 / 做 PPT"升级到"会跑仿真"。一句话:
> **"用 COMSOL 算一下这块铜板 100 W 加热的稳态温度分布"** —— AI 自己
> connect / build / solve / 出结果。

## 工作原理

```
 你 (自然语言)
    │
    ▼
 WorkBuddy (腾讯)               ◄── 加载本 marketplace 里对应 solver 的 plugin
    │ 选用 sim-comsol / sim-openfoam / ...
    │ shell 出 sim CLI
    ▼
 sim CLI (本地)                 ◄── 单一入口,统一管理所有仿真器
    │ 路由到具体 driver
    ▼
 COMSOL / OpenFOAM / ...        ◄── 真正干活的仿真器
```

## 当前 plugin 列表

| Plugin | Solver | 覆盖 |
|---|---|---|
| `sim-comsol` | COMSOL Multiphysics | JPype Java API / shared-desktop GUI / 离线 `.mph` 检查 / Desktop attach 回退 |

后续会按优先级补 OpenFOAM / Fluent / Mechanical / LTspice 等。

## 安装 — 一句话

**前提**: 已装 [WorkBuddy](https://copilot.tencent.com/work/) (Windows 10/11) +
git + COMSOL Multiphysics (要 solve 才用得上)。WorkBuddy 至少启动过一次。

在 WorkBuddy 聊天框直接说:

> 帮我跑这个 PowerShell:
> `irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex`

AI 会 shell 出来跑 [`install.ps1`](install.ps1), 5 分钟之内自动完成:

1. 装 [uv](https://docs.astral.sh/uv/) (Astral Python toolchain)
2. `uv tool install sim-cli-core` + `sim plugin install sim-plugin-comsol`
3. clone 本仓库到 `~/.workbuddy/plugins/marketplaces/sim-buddy/`
4. 注册到 `~/.workbuddy/plugins/known_marketplaces.json` (`type=local`)
5. 重启 WorkBuddy, 然后你说 "用 sim 跑 COMSOL 仿真" 就能用

或者你想绕过 AI 直接手跑:

```powershell
irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
```

## 装其他 solver driver (可选)

只是 COMSOL skill 默认就装好了。要别的 solver 加一句:

```powershell
sim plugin install sim-plugin-openfoam   # OpenFOAM
sim plugin install sim-plugin-fluent     # Ansys Fluent
# ... 见 sim plugin list --available
```

## 一句话用法

打开 WorkBuddy,直接说:

> "把 `block.mph` 算一下 100 W 加热下的稳态温度,出一张温度云图"

或者:

> "我有一个 .mph 文件,你帮我看看里面用了什么物理场和参数"

WorkBuddy 会自动加载 `sim-comsol` plugin,通过 sim CLI 在本地跑,结果文件路径
直接回给你.

## 仓库布局

```
sim-buddy/
├── .codebuddy-plugin/
│   └── marketplace.json          ← marketplace 总清单
├── plugins/
│   └── sim-comsol/
│       ├── .codebuddy-plugin/
│       │   └── plugin.json       ← plugin 元信息
│       ├── SKILL.md              ← skill 主文件 (WorkBuddy 加载)
│       └── README.md             ← 给开发者看
├── README.md
└── LICENSE
```

每个 plugin 是一个独立目录,自带 `SKILL.md` + `.codebuddy-plugin/plugin.json`。
新加 solver 就是在 `plugins/` 下加一个新目录 + 在 marketplace.json 里加一条。

## 跟 sim-studio 的关系

| | sim-buddy (本仓库) | sim-studio |
|---|---|---|
| 形态 | WorkBuddy plugin marketplace | 独立桌面应用 |
| UI 谁做 | 腾讯 | 我们 |
| 认证 | WorkBuddy 账号 | 我们的 gateway |
| 跑 sim CLI | 是 | 是 |
| **共享什么** | **sim CLI runtime + sim-skills 知识** | |

两条路并行:中国用户偏好腾讯生态用 sim-buddy;需要完全独立体验的用
sim-studio.底层都是同一个 sim CLI.

## License

Apache 2.0 — 见 [LICENSE](LICENSE).

## 反馈

issue → [svd-ai-lab/sim-buddy](https://github.com/svd-ai-lab/sim-buddy/issues)
