# Combat Framework 数据模型

## 建模原则

1. Definition、Spec、Instance 分离。
2. 静态 Definition 运行时不可变，可变值进入明确 owner 的 State/Instance。
3. 引用使用稳定 ID，不使用显示名、数组下标、NodePath 或资源路径。
4. 组合数据使用有类型、可校验的结构，不使用任意代码字符串或开放 Dictionary。
5. 所有时间、数值、百分比和计数显式声明单位。
6. 所有动态授予使用 handle/token；remove/revoke 必须指定来源。
7. Save 只保存运行状态 DTO 和 Definition fingerprint，不复制静态 Definition。

## 通用身份与序列

| 字段 | 作用 | 规则 |
|---|---|---|
| `definition_id` | 静态内容身份 | 小写 `a-z0-9_.-`；构建内唯一 |
| `instance_id` | 会话内运行实例身份 | 由 CombatState 分配，不从 Node/ObjectID 派生 |
| `instance_sequence` | 确定性排序 | 单调递增；进入 Save/restore |
| `transaction_id` | 顶层 Action 身份 | 用于 trace/事件关联，不作为内容引用 |
| `event_id` | committed fact 身份 | 在 transaction 内单调分配 |
| `grant_handle` | 某个来源授予内容的所有权 | 只能由创建它的 owner/revoker 使用 |

显示名、图标、说明和本地化 key 不参与规则身份。

## CombatSessionDefinition 与 CombatState

### CombatSessionDefinition

描述一个战斗运行环境的静态选择：启用模块、逻辑时间单位、初始规则包、relationship policy、事件预算设置 ID 和项目 Extension profile。它不包含参战 Entity 的可变值。

### CombatState

保存 session ID、当前 tick/turn、sequence counters、Entity instances、active module state、等待中的 AbilityRun、Effect schedule 和必要的队列状态。正常 Action 边界外 reaction queue 必须为空；若 stepwise Ability 允许等待，保存的是明确 wait token，而不是调用栈或 Callable。

## Entity

### EntityDefinition

| 组成 | 含义 |
|---|---|
| base tags | 实体天然拥有、不可由运行时误删的 tag grants |
| attribute set references | 初始 AttributeDefinition/值集合 |
| grant bundles | 初始 Ability、Effect、Trigger 或模块能力 |
| capability declarations | targetable、can_receive_effect 等通用 capability；不等同项目内容类型 |
| presentation profile ID | 可选逻辑表现绑定，不含 NodePath |

EntityDefinition 不存队伍、当前血量、位置或正在播放的动画。

### CombatEntityState

| 状态 | Owner |
|---|---|
| lifecycle (`active/defeated/removed`) | Entity lifecycle Command |
| attributes | AttributeStore |
| tag grant tokens/counts | TagStore |
| active effects | EffectStore |
| ability grants/runs | AbilityStore |
| module-owned state | 对应 Gameplay Module 子状态 |

“死亡”不是 Core 硬编码 ID；Damage/项目模块可根据配置的 Attribute/Condition 提交通用 lifecycle transition。

## Attribute

### AttributeDefinition

定义 attribute ID、数值类型、默认 base value、最小/最大 Formula、精度/舍入规则、聚合层和是否进入 Save。第一版只支持明确需要的整数或定点语义；若使用 float，必须定义有限值检查和确定性容差，不让平台差异悄悄进入回放。

### AttributeState

保存 `base_value` 与 active modifier handles。`current_value` 是按确定性聚合规则计算的结果，可以缓存，但缓存不是 source of truth，restore 后必须可重建。

内容应把“当前生命”和“生命上限”建成不同 Attribute ID，而不是假设所有 Attribute 的 `current_value` 都是可消耗资源。永久伤害修改 `health.current` 的 base value；持续最大生命 buff 修改 `health.max` 的 derived value。如何处理最大值降低后的当前生命由 Damage/Buff/Project policy 明确决定。

### ModifierDefinition

| 字段 | 含义 |
|---|---|
| target attribute | 被聚合的 Attribute ID |
| layer | `base_add`、`multiply`、`final_add`、`override` 等受控阶段 |
| magnitude formula | 纯 FormulaDefinition |
| capture policy | live/on_request/on_apply/on_activation |
| priority | 同层排序；高值先 |
| condition | 可选纯 Condition |

聚合顺序固定为 schema 声明的层顺序；同层使用 priority、来源 instance sequence、modifier ID。`override` 冲突不取“最后注册者”，必须按同一排序选首个并在 trace 中记录被遮蔽项。

Instant Effect 若要永久改值，生成 Attribute Command 修改 base value，不创建“永久 Modifier 假装基础值”。

### AttributeModifier 与 FormulaPlan 运行 DTO

Runtime modifier 以稳定 handle、operation、priority、source 和 sequence 保存，并提供 aggregation trace；聚合顺序固定为 `base_add → multiply → final_add → override`，而不是依赖注册顺序。`FormulaPlan` 是可序列化的纯表达式树，节点声明 operation、value type、unit 和 entity scope；它只读取 EvaluationContext，不能访问 Node、墙钟或随机流。

## Tag

### TagDefinition

Tag 是注册过的层级语义 ID，例如 `state.control.stunned`。授予叶 tag 时，查询可以匹配其祖先；父 tag 的存在来自查询展开，不自动创建多个可撤销 grant。

TagDefinition 可包含说明、owner module 和弃用状态，不包含运行时 bool。

### TagStore

每次 grant 创建 token，保存 tag ID、source instance/definition、grant sequence 和可选到期 owner。查询只看有效 token 计数。撤销 token 只减少该来源；多个 Effect 同时授予同一 tag 时，一个 Effect 移除不会清掉另一个来源。

base tag 也以不可撤销的 definition-source grant 表示，避免另建一套查询路径。

### TagQueryDefinition

第一版支持有类型的 `all`、`any`、`none` 和嵌套组合。Query 必须在生成阶段验证 tag 存在、树深上限和空集合语义。它只回答标签匹配，不携带副作用。

## Condition

ConditionDefinition 是纯布尔表达式树。第一批内建类型只覆盖已有真实消费者：

- tag query。
- attribute compare（明确 source/target、operator、Formula）。
- entity lifecycle/relationship compare。
- active effect/ability state 查询。
- event/cause field compare。
- `all/any/not` 组合。

每个类型都有稳定 evaluator type ID 和有类型参数。未知类型、循环引用、过深嵌套、单位不兼容在构建阶段失败。项目专属判断通过 Extension evaluator 注册，不把表达式脚本塞进数据。

Condition 返回 `true/false` 与可选诊断 reason；它不消费 RNG、不写状态、不创建事件。

## Formula

FormulaDefinition 是纯值表达式。最小内建集合：

- constant。
- attribute read。
- event/spec/captured field read。
- level/tuning lookup。
- add、subtract、multiply、divide。
- min、max、clamp、abs 和显式 rounding。

每个 Formula 声明输出类型和单位。除零、未知输入、溢出、NaN/Infinity 是稳定错误，不静默归零。复杂项目公式通过注册新的纯 evaluator 扩展；不得引用 Node、时间墙钟、随机函数或任意脚本文本。

Curve 若用于调参，Definition 只引用经过生成管线验证的 curve/tuning ID。Godot Curve Resource 可以作为编辑器输入或表现资产，但运行时规则值必须进入可指纹化、可回放的生成数据。

## Effect

### EffectDefinition

| 组成 | 含义 |
|---|---|
| effect tags | 对 Effect 自身分类，不自动授予 Entity |
| application conditions | 是否允许创建 Spec/应用 |
| duration policy | instant、timed、infinite；timed 使用 Formula + 单位 |
| period policy | 可选周期、首 tick/末 tick 语义 |
| stacking policy | reject、refresh、add_stack、replace、independent |
| stacking key | definition/source/target/group 的明确组合 |
| modifiers | active instance 持有的 Attribute Modifier |
| executions | apply/period/remove 时执行的 ActionDefinition 列表 |
| grants | tags、abilities、triggers 的来源化 grant |
| ongoing/removal conditions | 继续存在或自动移除的纯条件 |
| cue keys | applied/executed/updated/removed 等表现提示 |

EffectDefinition 不存当前 stack、剩余时间、来源实体或 captured value。

### EffectSpec

EffectSpec 是一次应用请求，包含 definition ID、source/instigator/target、level、created tick、set-by-caller typed values、captured values 和 cause chain。Set-by-caller key 必须在 Definition 中预声明类型、单位、必填和范围，不能成为任意变量袋。

### EffectInstance

仅 timed/infinite Effect 创建 instance，保存 instance/sequence、definition、source/target、start/end/next period tick、stack count、captured values、grant handle set 和 lifecycle state。

EffectInstance 还保存它创建的 tag/modifier grant handles。Restore 必须先恢复 owner stores，再复用这些 handles；不能因为重建 instance 而重复授予同一效果。周期到期只产生 due instance 列表，实际 periodic Action 仍通过普通 Event Pipeline 提交。

移除顺序固定：标记 removing → 执行允许的 remove plan → 撤销本 instance 的 modifiers/triggers/tags/abilities → 从索引和 schedule 移除 → 产生 `effect.removed`。任何异常按所属 Action 原子性处理。

### Stacking

StackingPolicy 必须回答：如何找同组 instance、是否增加 stack、是否刷新 duration、magnitude 是否重捕获、达到上限如何处理、overflow 是否排队附加 Effect。不得由内容脚本临时猜测。

第一版只实现有真实用例的策略。项目独特叠层通过 policy extension 接入；若扩展直接需要写 EffectStore 私有状态，说明 SPI 不完整，应先设计窄 Command，而不是开放容器。

## Trigger

TriggerDefinition 描述：

- 监听的 committed event type 或允许的 request phase。
- owner scope（source/target/session/effect instance）。
- event/cause/tag/attribute Condition。
- priority。
- once/per-event/cooldown 等明确触发限制。
- reaction ActionDefinition 列表。
- 防自反 cause tags。

普通反应默认监听 AFTER 的 committed DomainEvent 并 enqueue Action。需要修改候选值的规则使用 ModifierDefinition；需要拒绝应用的规则使用 application Condition/GATE handler。不要用一个万能 Trigger 同时承担所有阶段。

Trigger runtime state（剩余次数、上次触发 tick）归授予它的 Effect/Ability/Entity 或模块 State 所有，并进入对应 Save DTO。

## Damage、Hit 与 Outcome

`DamageSpec` 描述一次单目标请求：source/instigator、target、attribute、typed damage components、capture policy、flags 和 cause chain。Component 至少声明 damage type、amount 和可选 duration；Spec 校验通过后才能创建 `damage.request`。

`HitResult` 只描述命中解析是否接受、source/target 与 reason。`DamageOutcome` 描述 requested、mitigated、absorbed、applied、remaining、flags 和逐组件结果。`damage.applied` 的 payload 必须携带 Outcome，供反伤、击杀、Cue 和 replay 使用；不能让下游重新猜测实际扣除值。

## Projectile 与 Target Query

`ProjectileDefinition` 是不可变内容，声明 lifetime、movement/collision policy、max hits、pierce/bounce budgets、impact/expire action IDs 和 cue keys。`max_hits` 是本实例允许提交的总命中数；pierce/bounce 是移动/碰撞 adapter 的策略预算，不能让实例绕过命中上限。`ProjectileInstance` 只保存运行中的 source/target、spawn/current/expire tick、observation sequence、hit count 和 lifecycle。未注册 Definition 的 projectile 不允许运行时隐式创建。

`TargetQueryDefinition` 声明 relationship、lifecycle、tag include/exclude、stable order 和 limit。Resolver 只返回稳定 entity ID；它可以消费 Definition，也可以接受已展开参数，但不能查询 SceneTree。多目标 Action 必须按 query 结果的稳定顺序展开独立 Spec。

## Event

### EventTypeDefinition

每个 event/request type 声明：

- 稳定 type ID、owner module 和版本。
- request relay schema 与单位。
- 可用 source/target/cause 字段。
- 允许的 handler phase 和 `REPLACE` 字段。
- resolver type ID。
- 可能产生的 DomainEvent schema 与 error codes。

项目不能临时向事件 Dictionary 塞字段。事件 schema 变化会影响回放、Save 中等待事件的 AbilityRun 和 Extension，必须版本化。

### DomainEvent

DomainEvent 至少含 event ID/type、transaction ID、tick、source/targets、cause chain、关联 definition/instance IDs 和有类型 payload。它是已发生事实，不持有 Callable、Node、Resource 或可写对象。

Presentation 所需参数可以出现在事实 payload 或由 Cue binding 从 snapshot 推导；不得为了某个粒子特效把渲染对象塞入领域事件。

## Ability

### AbilityDefinition

| 组成 | 含义 |
|---|---|
| ability tags | 分类、block/cancel/query |
| activation policy | manual、on_granted、on_event；输入策略由 adapter 映射为 manual Intent |
| activation conditions | owner/target/cause 条件 |
| concurrency policy | independent、exclusive_replaceable、exclusive_blocking 或项目策略 |
| target definition | 领域选择或需要的 TargetObservation contract |
| costs | 一组 CostDefinition |
| cooldown | CooldownDefinition |
| behavior graph | `ability_graph_id`，编译后解析为不可变 `AbilityExecutionPlanDefinition` |
| owned grants | run 期间的 tags/triggers/effects |
| cue keys | activated/committed/ended/cancelled |

AbilityDefinition 不直接引用 InputEvent、AnimationPlayer、PackedScene 或具体 Damage 类。

### AbilityGrant

保存 grant handle、ability definition ID、owner entity、source definition/instance、level、grant sequence 和 enabled state。撤销来源时：未运行的 grant 立即删除；运行中的 run 按定义的 revoke policy cancel/end，然后删除。

### AbilityRun

保存 run ID/sequence、grant handle、owner、targets、activation context、lifecycle state、active execution tokens、wait tokens、scoped variable frame、cancel scopes、captured values、cost/cooldown commit state 和 run-owned grant handles。

生命周期为：`activating → active/waiting → ending → ended`，取消走 `cancelling → cancelled`。所有出口都必须撤销 run-owned grants 和 wait subscriptions。运行结束与 grant 移除是不同概念。

## Cost

CostDefinition 声明 payment type、amount Formula、payer selector、precheck 和 commit policy。内建 Attribute cost 只生成 Attribute Command；物品、卡牌、弹药等由对应模块/Project Extension 提供 payment resolver。

所有 cost 先 prepare，全部可支付后在 ability commit point 一次提交。默认取消不退款；需要退款时必须是显式 refund policy/Command，并说明外部副作用与 Save 行为。

## Cooldown

CooldownDefinition 声明 cooldown group/tag、duration Formula、开始时机（commit 或 end）和 source policy。默认实现应用一个 timed cooldown Effect 并授予 `cooldown.*` tag，Ability activation condition 查询该 tag。

共享冷却通过相同 group/tag 表达，不需要 Ability manager 针对技能 ID 分支。没有持续时间的回合次数等语义仍由注入 CombatClock 解释。

## Target

TargetDefinition 支持：self、explicit entity IDs、event source/target、relationship filter、tag/attribute filter、stable sort、limit。需要空间查询时，它声明 observation type 和校验策略，由 Area/Projectile/项目 adapter 提供 TargetObservation。

Target result 是稳定 entity ID 列表和可选几何 value，不保存 Node 引用。多目标默认按 entity sequence 排序；随机选取必须使用声明的 target RNG stream 和稳定候选顺序。

## Ability Graph 与 Execution Plan

Ability Graph 是受限、可编译的战斗领域图，不是通用可视化脚本。Authoring、编译产物和运行状态严格分开。

### AbilityGraphDefinition

逻辑图定义包含：

| 字段 | 含义 |
|---|---|
| `graph_id` / version | 稳定图身份和 schema 版本 |
| `nodes` | 稳定 node ID、node type ID、有类型参数 |
| `connections` | from/to node ID 与 semantic pin ID；不保存 GraphNode slot index |
| `entry_points` | `OnCast` 及声明允许的 committed event entry |
| `variables` | graph/run-local 的有类型声明、默认值与 scope |
| `subgraph_refs` | 有类型输入/输出 contract 与显式版本引用 |
| `editor_layout` | 位置、尺寸、折叠、注释和视图状态；不参与规则执行 |

节点参数不使用开放 Dictionary。每个 node type descriptor 决定字段 schema、pin、cardinality、required capability、允许的 control cycle 和编译器。布局数据不进入 gameplay fingerprint；节点、参数、连接、变量 schema 和 subgraph contract 必须进入。

### Pin 与连接类型

第一版区分三种语义边：

- **Control**：传递确定性的 execution token；一个 output 若允许多目标，顺序由 descriptor/plan 显式声明。
- **Value**：把有类型、带单位和 scope 的值连接到输入；不允许只凭 Godot Variant 可转换就接线。
- **Owned control scope**：下游 wait/state 生命周期归当前 scope；父 scope 结束或取消时自动释放其 wait subscriptions 和 run-owned handles。这吸收 Statescript subgraph 的所有权思想，但不复制其端口实现。

连接校验至少检查方向、语义类型、单位、scope、cardinality、模块 capability、数据环和控制环。端口显示顺序可以变化，semantic pin ID 不得变化；破坏性 pin 改名需要 graph schema 版本变更。

### 节点类别

公共节点库按领域职责组织：

| 类别 | 第一批节点 | 边界 |
|---|---|---|
| Event | `OnCast`、`OnHit`、`OnKill`、`OnExpire` | committed event entry 必须声明订阅、filter、scope 和取消清理 |
| Target | `SelectTarget`、`FilterTarget`；启用 Area 后增加 `AreaQuery` | 只产生稳定 entity IDs/typed observation，不查询 SceneTree |
| Action | `CommitAbility`、`DealDamage`、`ApplyEffect`、`SpawnProjectile`、`Move`、`Summon` | 节点由对应 Module 注册，编译为标准 Action/Resolver 调用 |
| Logic | `Branch`、`Sequence`、`Delay`、`WaitEvent`、bounded `Repeat`、`End` | 不允许隐式无界循环；并行/Join 只在语义和取消策略完整后加入 |
| Data | context/Attribute/Tag/Formula/Condition/typed variable read-write | 纯值求解不写 CombatState；变量只属于当前 Run/scope |
| Presentation | `Animation`、`VFX`、`SFX`/统一 `EmitCue` | 只编译为 presentation cue fact/request，不直接操作 Node，也不决定规则结果 |

节点名称是编辑器展示词汇，不要求 Runtime 为每个节点保留一个对象类。多个展示节点可以编译为同一少量 plan opcode/ActionDefinition。

### Graph Compiler

Compiler 在生成阶段完成：

1. 解析所有 node/semantic pin/type IDs 与 module capability。
2. 检查必需 entry、不可达节点、缺失出口、坏引用、value/data cycle、无界 control cycle 和非法 scope escape。
3. 将 bounded Repeat 展开或编译为带明确上限的 opcode；不接受数据驱动的无限循环。
4. 固定同一节点多输出、同 tick resume、event subscriber 和 branch merge 的确定性顺序。
5. 把 Formula/Condition/Action 引用解析为稳定 registry handles，生成不可变 `AbilityExecutionPlanDefinition`。
6. 输出 node ID ↔ plan operation 的 debug map 和结构化诊断。

Editor 的即时校验可以更早提示，但只有同一 headless Compiler 的结果具有权威性。Runtime 不对坏图“尽量执行”。

### AbilityExecutionPlanDefinition

Execution Plan 保存已解析 operations、entry table、typed constants、variable schema、adjacency、scope/cancel table、wait descriptors、capability fingerprint 和 debug source map。它不包含节点位置、图标、Control、Resource 的可写引用或 Callable。

同一 plan 可由多个 AbilityGrant/Run 共享。Plan 运行时不可变，Save 只记录其 fingerprint/version，不复制完整 plan。

### AbilityRun 执行状态

Runtime 不扫描整张图，也不让每个节点 `_process()`。一次外部 activation/event/tick 唤醒按稳定 sequence 排序的 token；即时 operations 在当前 Action 预算内推进，遇到 wait 时持久化 token并退出。

Wait token 保存 owner run/scope、resume operation、event type/filter 或 deadline、注册 sequence 和取消策略。Run 结束、取消、grant revoke 或 scope exit 必须注销全部 wait token并撤销 owned handles。动画通知可以生成 adapter Intent，但不能成为唯一规则时钟；权威命中窗口来自 CombatClock、committed event 或经过验证的 observation。

Save 不保存调用栈对象或节点实例，而保存 active token queue、wait tokens、variable frame、scope stack、commit state 和稳定 sequences。Restore 后根据 plan fingerprint 重建索引；不重新触发已经执行过的 Action/Cue。

### Subgraph

Subgraph 只通过声明的 typed inputs/outputs 交换数据，有独立局部 variable frame 和 cancel scope。当前实现提供 owned synchronous/async-return 调用：子图遇到 tick/event wait 时由父 Run 持有并驱动 resume，父 scope cancel 时级联取消；detached reaction 明确禁止。递归引用和运行时动态选择任意 graph 第一版禁止；复用通过明确 graph ID 与无循环依赖完成。

跨 Ability/Entity 的共享值不通过 graph global variable 实现，而使用 Attribute、Tag、Effect 或项目 Module State。这样每个值都有 owner、Save 和事件语义。

## GrantBundle

GrantBundleDefinition 是装配单位，可包含 Attribute initializers、Ability grants、initial Effects、Tags 和 Module capability。应用返回 `GrantHandleSet`，授予方负责保存并撤销。

职业、装备、形态、关卡规则和项目模式通过选择 bundle 组合能力；Core 不知道这些上层概念。Bundle 间引用必须无循环，冲突在生成阶段报告。

## Cue 数据

CueBindingDefinition 将 committed event/cue key 映射到逻辑资源 ID 和参数映射：

- lifecycle：executed/started/updated/ended/cancelled。
- audience/anchor/attachment policy。
- magnitude、color、variant 等有类型参数来源。
- missing-resource fallback policy。

CueDefinition 不进入 CombatState。持续 Cue handle 只在 Presentation 中存在，可由 effect/run instance ID 幂等重建。

## Source、Generated 与 Runtime

建议的逻辑数据分类如下；具体表只在实现对应纵向切片时加入 Schema：

| 数据组 | 典型内容 |
|---|---|
| registry | tags、attributes、event/action/condition/formula types |
| entity | entity definitions、initial attributes、grant bundles |
| effect | effects、modifiers、grants、stack policies、executions |
| ability | abilities、costs、cooldowns、targets、graph references、compiled execution plans |
| trigger | subscriptions、conditions、reactions、priority |
| presentation | cue bindings 与 logical resource IDs |
| module/project | module manifest、extension type declarations、profiles |

表格关系仍使用独立 relation 表，不把逗号列表、JSON blob 或表达式脚本塞进单元格。Ability Graph 拓扑使用独立 authoring document；Godot Resource 是目标载体，但必须先通过数据格式 ADR 并取代旧 timeline rows，不能双写。生成器负责类型、ID、外键、pin、循环、单位、范围、extension type 和 capability 校验，并将图编译进 runtime catalog。

## Save 与重放

Save 保存：CombatState DTO、RngSet snapshot、逻辑时间、sequence counters、active Effect/AbilityRun/module state，以及 Definition/schema/module/extension fingerprint。

Save 不保存：静态 Definition 全量、Node/Resource、Event handler Callable、derived Attribute cache、Presentation Cue handle 或 Event trace。

`AbilityService.snapshot()` 只保存 active run 的稳定 run ID、ability/grant/entity 引用与 `AbilityRun.save_state()`；`restore()` 先验证 Definition/Plan/Grant 引用，再由调用方注入新的 ExecutionContext，绝不序列化 Node、Resource 或 Callable。Event trace 通过独立的有界 `CoreEventTrace` 保存/导出，不进入正式 Save。

Restore 顺序固定：验证版本/fingerprint → 恢复 counters/time/RNG → Entity base state → active Effect/grants → AbilityRun/wait token → 重建 modifier/handler/schedule 索引 → 重新计算 derived values → 校验不变量。不能依靠加载顺序偶然触发 apply Cue 或重复执行 Effect execution。

Definition ID 删除/改名、字段语义变化、clock/RNG/capture/stacking 变化都需要 ADR 和历史 fixture；不保留未发布旧路径的兼容分支。
