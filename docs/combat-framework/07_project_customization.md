# 项目定制与 Project Extension

## 定制原则

每个消费项目拥有自己的 Combat Profile、内容 Definition、Presentation binding 和必要的 Extension。共享 Combat Framework 不导入项目目录，不预设项目的伤害、阵营、时间、输入或场景结构。

Project Extension 不是“特殊技能文件夹”，而是项目级语义适配层。一个技能能用已有组合表达时，它仍然只是数据。

## 接入流程

1. **选定战斗形态**：回合/阶段/固定 tick，单一基础时间单位，2D/3D/无空间。
2. **选择最小模块集**：先 Core；确有技能需求再启用 Ability、Damage、Buff 等模块。
3. **定义项目词汇**：Tag 命名空间、Attribute IDs、relationship、event/cue keys 和错误本地化。
4. **建立 Combat Profile**：模块 manifest、初始 grant bundles、事件预算、priority 使用约定、RNG streams。
5. **建立最小纵向切片**：一个 Entity、一张 `OnCast → Action → End` Ability Graph、一个 Effect/Attribute 变化、一个 committed event、一个 Cue，并能在调试器看到当前节点。
6. **用组合扩展内容**：先写 Definition/关系/测试，不写内容专属脚本。
7. **识别真实缺口**：只有现有 evaluator/resolver/port 无法表达时，新增项目 Extension。
8. **交付验证**：运行数据生成、纯领域 fixture、场景 adapter 测试和完整 `project.py check`。

## 推荐物理边界

共享执行原语位于 `src/runtime/ability/`；消费项目在自己的 Feature 内保留明确的项目拥有目录：

```text
src/runtime/ability/             # 共享 graph/compiler/plan/run

src/features/<project_feature>/
├── domain/ability_extension/    # 当前项目规则与注册贡献
└── presentation/
    └── ability/                 # 当前项目 Cue/world adapter

data/source/combat/              # 当前项目表格 Definition
authoring/combat/ability_graphs/  # 当前项目 canonical graph Resources
tests/combat/project_extension/  # 当前项目规则 fixture
```

共享库不得 preload `project_extension/`。App Composition Root 显式创建当前项目的 extension manifest；manifest 同时声明项目 node descriptors/compiler/executors，使公共 Ability Editor 不按项目 ID 分支。若团队选择独立 addon/package，物理布局可以改变，但依赖方向不变。

## Combat Profile 的决策项

| 决策 | 项目必须明确 | Core 默认 |
|---|---|---|
| clock | tick/turn 单位、推进者、同 tick 顺序 | 只接受整数逻辑时间 |
| relationship | self/ally/enemy/neutral 等查询语义 | 只有稳定 entity identity |
| lifecycle | defeated/removed/respawn 转换 | 不硬编码 health/death |
| modules | 启用哪些 capability 与版本 | Core only |
| numeric | int/定点/float、舍入与上限 | 必须有限且显式舍入 |
| tags | 项目命名空间、owner、弃用策略 | 层级匹配与 token grant |
| RNG | 流名、消费时机、回放 fixture | 注入 RngSet，不提供全局随机 |
| priority | 项目使用的 priority 档位 | `-1000..1000` 稳定排序 |
| cues | event→cue→resource binding、fallback | Cue 不影响规则 |
| save | 哪些 Session/Entity 状态持久化 | 版本化 DTO + fingerprint |

Profile 只选择策略，不包含某个技能 ID 的条件分支。

## 三类项目示例

### 项目 A：即时 3D 动作战斗

- Fixed combat tick，由 `_physics_process` adapter 推进。
- 启用 Ability、Damage、Buff、Projectile、Movement、Area。
- 物理 ray/shape cast 只生成 TargetObservation；Damage 仍在领域提交。
- 方向格挡需要攻击方向和角色朝向 observation。若内建 Condition 无空间方向语义，项目注册 `project_a.facing_arc` Condition evaluator。
- 动画与 VFX 通过 Cue 对齐；动画 notify 不能直接扣血。
- Ability Graph 可以组合 `OnCast → SelectTarget → SpawnProjectile` 与 `OnHit → DealDamage → EmitCue`；Projectile Module 提供节点语义，Graph Runtime 不知道 3D Scene。

项目 A 的方向 evaluator 留在其 Extension。Core 不新增 `facing` 字段，因为回合制卡牌项目没有该概念。

### 项目 B：回合制元素战斗

- 以 phase/turn 为逻辑时间，无 Physics port。
- 启用 Ability、Damage、Buff、Summon。
- 元素附着用 Tag/Effect；反应关系使用独立 relation data；`effect.applied` Trigger 根据关系选择 reaction bundle。
- 若反应只需表驱动映射、移除/添加 Effect 和 Damage Action，无需项目脚本。
- 只有当“多元素同时存在时的唯一选择算法”无法由稳定排序和关系表表达，才新增项目 Stacking/Reaction resolver。

元素名称和反应 ID 都属于项目数据；Damage Core 不知道火、水或冻结。

### 项目 C：卡牌驱动战斗

- 以 action/turn 为逻辑时间，Ability 由出牌 Intent 激活。
- 卡牌手牌、弃牌、消耗区由独立 Card Feature 拥有，不伪装成 Combat Attribute。
- App 协调器先让 Card Feature prepare 消耗，再向 Combat 提交 Ability Intent；需要跨 Feature 原子性时另做 ADR。
- 卡牌效果使用标准 Action/Effect；抽牌、弃牌等注册项目 Action Resolver 并由 Card Feature owner Command 执行。
- 卡面动画是 Presentation，不能作为效果是否结算的依据。

Core 不新增“card”概念，Ability 也不直接依赖 Card Feature。

## 常见特殊规则的组合方式

| 特殊规则 | 推荐组合 | 不应做 |
|---|---|---|
| 满血时伤害翻倍 | source Attribute Condition + Damage Modifier | 在 Damage resolver 判断某技能 ID |
| 首次受击免疫 | Effect grant Trigger + runtime remaining count + GATE reject | 在 Entity Node 写一次性 bool |
| 反伤 | `damage.applied` Trigger + actual value Formula + Damage Action + cause exclusion | 在 Attribute changed Signal 中直接扣攻击者血 |
| 吸血 | damage fact Trigger + source target selector + Heal/Damage Action | 把治疗塞进 Cue handler |
| 斩杀 | target Attribute ratio Condition + lifecycle/damage Action | Core 硬编码 health ID |
| 共享冷却 | 多 Ability 引用同 cooldown group/tag | 为每个技能创建 Timer |
| 光环 Buff | Area membership observation + enter/exit Effect grant handles | Area2D 直接改目标 Attribute |
| 形态切换 | revoke old GrantHandleSet + apply new GrantBundle | 替换 Node 时靠 `_ready` 重建且丢状态 |
| 复活 | 项目 lifecycle Action + Attribute/Tag/Effect plan | 修改 Core `defeated` 特判 |
| 复制上一个技能 | 项目 Action Resolver读取有类型 action history snapshot | 保存 Callable 或脚本路径 |

## 何时必须写 Extension

满足以下任一情况且无法拆成已有组合时，才建 Extension：

- 新的纯判断语义，需要读取项目 Module 的只读状态。
- 新的数值算法，现有 Formula 原语无法表达且会被多个项目内容复用。
- 新的 Action 语义，有明确 prepare/commit/fact 契约。
- 新的资源 owner/cost 类型。
- 新的目标观察或世界操作 port。
- 新机制有独立 State、Save 和 lifecycle，需要项目 Gameplay Module。

以下情况不构成理由：字段太多、想少写几行数据、只有一个技能使用、可以用现有 Trigger/Effect 组合、只是更换表现。

## Extension 设计模板

每个项目扩展在实现前记录：

1. **语义**：它表达什么，为什么现有组合不能表达。
2. **边界**：输入、输出、执行阶段、state owner、允许读取的 context。
3. **确定性**：排序、RNG stream、时间单位、capture、舍入。
4. **失败**：稳定 error code、atomic/stepwise、补偿。
5. **生命周期**：register/unregister、grant/revoke、save/restore。
6. **数据**：type ID、字段 schema、单位、引用和 Editor metadata。
7. **表现**：可能的 DomainEvent/Cue；确认不参与规则。
8. **测试**：正常、非法、边界、循环、重放和恢复 fixture。

若扩展改变 Save/RNG/clock/data format、引入跨 Feature 依赖或全局服务，必须使用项目 ADR 模板。

## Tag 与 ID 命名空间

共享库拥有 `combat.*` 下经过文档化的框架类型；共享模块拥有自己的命名空间，例如 `damage.*`。项目内容和扩展使用稳定项目 namespace，例如 `project_a.*`，不得冒用 `combat.*` 让项目概念伪装成 Core。

建议区分：

- `state.*`：Entity 当前状态。
- `ability.*`：Ability 分类/运行状态。
- `effect.*`：Effect 自身分类。
- `cause.*`：因果链标记。
- `cooldown.*`：冷却组。
- `cue.*`：表现提示。

这是组织约定，不把任意文本都变成 Tag。数值、计数、ID 引用和显示文本仍使用正确的数据类型。

## Priority 治理

项目在 Combat Profile 中登记使用的 priority 档位和含义，例如：

- `500`：早期免疫/重定向。
- `100`：项目先置修正。
- `0`：普通内容。
- `-100`：项目后置修正。
- `-500`：统计/收尾 reaction。

Core 不变量在 priority 系统之外。内容作者不得用连续整数猜顺序；语义依赖必须有 fixture 显示完整 handler order。项目 Extension 不得通过极端 priority 绕过 owner、类型或事务校验。

## RNG 定制

每个项目维护 RNG stream 清单：owner module、语义、消费事件、是否保存、fixture。候选目标先稳定排序再随机选择。新增流不会消耗其他流，但重命名流会改变结果，属于 RNG 契约变化。

表现变体统一使用 `presentation.*`，不得读取 gameplay roll 以外的内部随机状态。

## 时间定制

- 回合项目把 duration 定义为 turn/phase tick，推进点由战斗规则 Action 控制。
- 即时项目选择固定逻辑 tick，不把浮点 delta 累积细节散落在 Effect/Ability。
- 暂停、加速、慢动作由推进 adapter 决定提交多少逻辑 tick；领域不读 Engine time scale。
- 项目若需要多时间域，先通过真实用例设计独立 Clock capability；第一版不允许一个 Effect 任意选择墙钟/物理帧/回合。

## 内容生产流程

1. 在 `data/source/combat/` 增加/修改表格型 Definition；在 Ability Editor 中修改 `authoring/combat/ability_graphs/` Resource。图语义不得与 timeline rows 双写，规则见 ADR-0001。
2. 运行同一 headless 生成/Graph Compiler；所有引用、semantic pins、单位、query、capability、生命周期出口和循环必须通过。
3. 为新组合增加领域 fixture；确认 compiled plan、handler order、数值、facts、wait/cancel cleanup 和固定 seed 结果。
4. 在 `presentation_cues`/resource binding 中绑定表现；Animation/VFX/SFX 节点只能生成 Cue。
5. 用真实 Scene adapter 测试 Intent、snapshot、events 和 Cue；运行时调试器确认当前 node/wait/error，不在场景测试中绕开 Feature API。
6. 交付前运行完整检查。

普通内容不创建脚本。Extension type 的实现、数据声明和 Editor metadata 必须在同一变更中交付。

## 升级共享框架

消费项目升级 Combat Framework 时：

1. 读取公共 type/schema/module 变更清单。
2. 在隔离分支运行当前项目所有 replay/save fixtures。
3. 删除被替代的项目兼容代码；不同时保留旧新两条路径。
4. 更新 Extension manifest 与数据生成物。
5. 核对 handler ordering、capture、clock、RNG fingerprint 和 Cue event schema。
6. 完成 Domain、Scene 和完整项目检查后再合入。

若公共更新迫使一个项目把专属语义放进 Core，应拒绝升级方案并重新设计扩展边界。

## 项目验收清单

- Core/共享模块没有项目内容 ID 分支。
- Project Extension 通过 Composition Root 注入，公共库不反向 preload。
- 所有状态有 owner、Save DTO 和 lifecycle cleanup。
- 所有随机有命名流，所有时间来自显式 CombatClock。
- 复杂规则 trace 能显示事件阶段、priority、relay 和 cause chain。
- Cue/Node/Signal 失败不改变规则。
- 普通技能只改数据；Extension 有明确“为何不能组合”的记录。
- Project Node 通过 descriptor/compiler/executor manifest 接入；公共 Graph Editor 和 Runtime 没有项目 ID 分支。
- Ability Graph 可在 headless 编译，所有 end/cancel/wait 路径可验证，调试 overlay 不影响规则。
- 数据、replay、restore、场景 adapter 和 `project.py check` 全部通过。
