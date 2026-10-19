# Combat Framework Scaffold — AI 接入指南

这是一个可复用的 Godot 4.7.1 Combat Framework 脚手架。解压后，先在项目根目录打开本文件，再让 AI 按以下顺序工作。

## 快速开始

```powershell
python tools/project.py doctor
python tools/project.py graphs
python tools/project.py check
```

Godot 不在 PATH 时使用：

```powershell
python tools/project.py check --godot <Godot 控制台可执行文件>
```

## 先读什么

1. `README.md`：项目入口和日常命令。
2. `AGENTS.md`：编码、模块边界、生成物和交付规则。
3. `docs/combat-framework/00_goals.md`：框架目标。
4. `docs/combat-framework/02_architecture.md`：总体架构。
5. `docs/combat-framework/05_data_model.md`：Definition/Spec/Instance 数据模型。
6. `docs/combat-framework/08_editor_architecture.md`：可视化技能编辑器。

## 新建技能

技能行为图的 canonical source 位于：

```text
authoring/combat/ability_graphs/<graph_id>.tres
```

用 Godot Editor 打开 `.tres`，通过 Ability Graph Editor 添加 Event、Target、Action、Logic 和 Cue 节点。不要直接编辑 `data/generated/ability_plans.json`；它由以下命令生成：

```powershell
python tools/project.py graphs
```

当前技能 Definition 通过稳定 `ability_id → graph_id` 注册。新项目可以在自己的 `src/features/<project>/domain/` 中注册 AbilityDefinition，不要把项目 ID 分支写进 `src/runtime/`。

## 扩展规则

- 普通技能优先使用 Core + Trigger + Condition + Formula + Effect + Module Action 组合。
- Projectile 必须先注册 ProjectileDefinition；不能运行时隐式创建。
- 多目标 Damage 必须由 Target/Action 层按稳定顺序展开为多个单目标 Spec。
- Presentation 只消费 committed Domain Event/Cue，不决定规则结果。
- 只有现有组合无法表达时，才新增 Project Extension，并为它定义 owner、Save、lifecycle、error code 和测试。

## 交付前

```powershell
python tools/project.py data
python tools/project.py assets
python tools/project.py graphs
python tools/project.py check
```

不要提交 `.godot/`、`.import/`、`build/`、`validation/` 或手工修改的 generated 文件。
