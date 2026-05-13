# sim-comsol

WorkBuddy / CodeBuddy plugin: 用自然语言驱动 **COMSOL Multiphysics**。
底层调用 [`sim` CLI](https://github.com/svd-ai-lab/sim-cli) 通过 JPype
Java API 跑 COMSOL,支持 shared-desktop GUI 协作 / 离线 `.mph` 检查 /
Desktop attach 回退三条路径。

## 装上之后

WorkBuddy 自己会读 `SKILL.md` 知道在什么时候调这个 skill。你直接说:

> "把 `block.mph` 算一下 100 W 加热下的稳态温度,出一张温度云图"

或者:

> "我有一个 .mph 文件,你帮我看看里面用了什么物理场和参数"

WorkBuddy 会自己 shell 出 `sim --version` → `sim check comsol` →
`sim connect --solver comsol` → 一步步建模 / 求解 / 检查。

## 前置条件

```powershell
pip install sim-cli-core             # 必装
sim plugin install comsol            # 装 COMSOL driver
# 然后系统里要有 COMSOL Multiphysics (商业 license)
```

## 详细技能内容

见同级 [`SKILL.md`](./SKILL.md) — WorkBuddy 加载这个 skill 时自动读全文。
