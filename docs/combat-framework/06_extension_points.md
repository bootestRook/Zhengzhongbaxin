# 扩展点与稳定 SPI

## 扩展目标

扩展点的作用是让项目表达 Core 未知的语义，而不是开放 Core 内部容器。一个好的扩展点有窄输入、窄输出、明确阶段、唯一状态 owner、稳定失败语义和可独立测试的生命周期。

默认顺序始终是：先数据组合，再内建 Module，再 Project Extension，最后才评估公共层变化。

## 扩展层级

| 层级 | 适用情况 | 交付物 | 是否改 Core |
|---|---|---|---|
| Definition | 数值、Tag、Condition、Formula、Modifier、Trigger、Action 组合足够 | 数据与测试 fixture | 否 |
| Module configuration | 机制已由 Damage/Buff 等模块支持，只需策略参数 | module/profile 数据 | 否 |
| Project evaluator/resolver | 有新语义，但可落在已有阶段和状态 owner | Extension 实现 + type metadata + tests | 否 |
| Project Gameplay Module | 有独立状态、事件、Action 和 ports | 项目模块 + manifest + Save DTO | 否 |
| Shared Module promotion | 至少两个项目有相同、稳定、无内容特例的语义 | 设计评审/ADR + 通用模块 | 否，优先成为模块 |
| Core change | 现有不变量或协议无法正确表达跨项目共同需求 | ADR + 契约/fixture 变更 | 是，极少发生 |

“写起来更方便”不是修改 Core 的充分理由。

## 注册模型

所有扩展由 Composition Root 显式注册，注册项包含：

- 稳定 `extension_id`、版本和 owner。
- 提供/需要的 capability。
- 新增的 type ID 与类型种类。
- 生命周期（session/entity/effect/ability run）。
- State/Save owner；无状态扩展明确声明 stateless。
- 允许读取的 context view 与允许返回的结果。
- 使用的 RNG streams、event types、error codes 和 cue keys。
- Editor metadata 与数据校验器描述。

禁止目录扫描、按类名反射、Autoload 自注册和“第一个找到的实现”。重复 type ID、依赖循环或版本不兼容直接启动失败。

## 公共注册表

| Registry | 注册对象 | 输入 | 输出/副作用边界 |
|---|---|---|---|
| ConditionEvaluatorRegistry | 纯条件 evaluator | ConditionDefinition + read-only EvaluationContext | bool + diagnostic reason |
| FormulaEvaluatorRegistry | 纯公式 evaluator | FormulaDefinition + read-only EvaluationContext | typed finite value |
| ActionResolverRegistry | Action resolver | ActionDefinition + Event/Ability context | prepared EventRequest/Command plan |
| EventTypeRegistry | request/fact schema 与 resolver binding | type metadata | 验证、发现和 trace；不执行项目代码 |
| HandlerProviderRegistry | 有阶段约束的 handler provider | source instance + event metadata | handler descriptors/handles |
| TargetResolverRegistry | 领域目标 resolver | TargetDefinition + snapshot/observation | stable entity IDs/value data |
| CostResolverRegistry | payment resolver | CostDefinition + ability context | precheck + prepared Commands |
| StackingPolicyRegistry | Effect stacking policy | definition/spec + read-only EffectStore view | stacking decision/plan |
| AbilityNodeRegistry | 节点 descriptor/compiler/executor binding | stable node type metadata | graph 校验、plan 编译与运行查找；不持有画布 |
| CueResolverRegistry | 表现映射 | committed event + cue binding | Presentation command；不返回规则值 |

注册表本身只负责唯一性、版本、能力依赖和查找。它不成为可写 service locator。

## EvaluationContext 视图

Condition 和 Formula 获得最小只读视图，按声明可访问：

- source/instigator/target entity snapshots。
- Attribute/Tag/Effect/Ability 的只读 query API。
- EventRequest/DomainEvent 的有类型 payload。
- level、captured values、logical tick 和 relationship query。
- Definition/tuning lookup。

它们拿不到 RngSet、Command API、SceneTree、Node、ResourceCatalog、Presentation 或其他 Feature。需要随机的判断必须拆成显式 Roll Action；需要写入的逻辑必须拆成 Action/Command。

## Action Resolver

Action Resolver 是最常用的行为扩展点。它必须：

1. 验证 ActionDefinition 参数类型、单位、引用和 capability。
2. 从只读 context 创建 EventRequest 或 prepared Command plan。
3. 声明 atomic/stepwise 语义、可能的 error codes 和 facts。
4. 不在 prepare 阶段直接写 State 或调用世界副作用。
5. 对相同输入产生相同计划；需要随机时使用已声明的 Roll service/stream。

共享 Ability Graph 只认稳定 node/action type ID。项目新增“交换位置”“弃牌支付”“复制上一个效果”等行为时，优先新增项目 Action Resolver，并用薄 NodeDescriptor 暴露给图编辑器；不得在 Ability runtime 中按 ability ID 分支。

## Ability Graph Node 扩展

Graph 节点扩展必须同时提供可校验的语义和可运行的 binding，不能只画一个 GraphNode：

1. **NodeDescriptor**：稳定 type ID、category、localization key、icon/keywords、参数 schema、semantic pins、单位/scope/cardinality、required capability、cycle/lifetime policy 和文档链接。
2. **NodeCompiler**：把 graph node 数据验证并编译为一个或多个已知 plan operation、ActionDefinition 或 wait descriptor；不得把 Resource/Callable 塞进 plan。
3. **OperationExecutor binding**：若现有通用 opcode/ActionResolver 不足，提供窄输入/输出的 runtime executor，并声明错误、事务、RNG、时间和 Save 行为。
4. **Editor override（可选）**：只有通用 metadata form 无法清晰表达时才注册专用 NodeView/parameter editor；专用 UI 仍通过 graph command 修改 model。

多数项目节点应该只是已有 Action/Condition/Formula 的 authoring facade，不新增 runtime executor。例如 `project_a.swap_positions` 可以编译为项目 Action Resolver；编辑器只需根据 descriptor 生成两个 Entity value pins。只有出现新的控制流或 wait 语义时才需要新 opcode，并先评审取消、Save、循环和预算。

节点注册由 Composition Root/Editor bootstrap 使用同一显式 manifest；禁止反射扫描脚本目录。关闭项目 Module 时，节点目录隐藏相应类型，已有 graph 则产生 unknown-node/capability error，不能保留一个“忽略并继续”的 fallback。

破坏性变更包括删除/重命名 semantic pin、改变 pin type/unit/cardinality、修改 control/lifetime 语义或 executor 结果。它们需要 node schema version、graph fixture 更新和明确重编译，不增加旧 pin 兼容层。

## Condition Evaluator

适用于内建 tag/attribute/relation/event 条件无法表达的新纯谓词，例如项目特有的格子连通性摘要或牌区规则。

扩展 metadata 必须声明参数 schema、可读取 scope、输出 reason keys 和 Editor 展示信息。Evaluator 不能执行物理查询；物理/导航结果先由 adapter 形成可信 observation，再由 Condition 校验 observation 与当前状态。

如果 Condition 需要隐藏状态，状态应归项目 Module 所有并通过只读 query port 暴露，不能放进 evaluator 单例字段。

## Formula Evaluator

适用于新的纯数值算法，例如项目特有的等级曲线或元素矩阵求值。它必须声明输入/输出类型、单位、舍入、capture 支持和错误边界。

不要为一个固定技能新增 Formula evaluator；固定数值或普通算术留在数据。不要提供 `eval(expression)`、脚本路径或 Callable 字段。

## Event Handler Provider

Handler Provider 把 Entity component、Effect instance、Ability grant/run 或 session policy 投影为 EventPipeline handler descriptors。Descriptor 必须包含 event type、phase、priority、scope、owner/registration sequence、Condition 和稳定 handler ID。

Provider 不控制排序器，也不能在分发中偷偷追加匿名 callback。动态来源结束时必须通过 handle 精确注销。项目若需要新的处理阶段，不能自行伪造 phase；新增 phase 是 Event Pipeline 契约变化，需要 Core 评审。

## Stacking Policy

Project StackingPolicy 只返回 stacking decision：使用哪个现有 instance、stack/duration/capture 如何变化、是否 reject/replace/overflow。实际 EffectStore 写入由 Core Command 完成。

Policy 不取得 EffectStore 可写引用，也不直接移除其他 Effect。若需要附加行为，decision 中排队标准 Effect Action。

## Cost Resolver

CostResolver 将项目资源语义转换为统一的 prepare/commit：

- `can_pay` 返回稳定 reason。
- `prepare_payment` 返回由资源 owner 执行的 Commands。
- 所有 payment prepare 成功后才进入 Ability commit point。
- refund 是独立、显式策略。

若资源属于另一个 Feature（例如卡组/物品），默认由 App 协调器完成两阶段 Intent，而不是让 Combat Extension 直接写那个 Feature。真正的跨 Feature 原子事务需要 ADR。

## Target Resolver 与 World Port

TargetResolver 可以处理 snapshot 内可确定的目标。需要碰撞、射线、导航或可视性的项目扩展分成两部分：

1. Presentation/World adapter 通过窄 port 产生 observation。
2. Domain TargetResolver 验证 observation sequence、entity IDs、约束和 current state。

这样项目可以替换 2D/3D/格子世界 adapter，而不修改 Core 或 Ability。Resolver 不存 Node 引用，也不在 Domain 测试中需要 SceneTree。

## 项目 Gameplay Module

当机制有独立可变状态、多个 Action/Event、自己的时钟推进或世界 port 时，应建项目 Gameplay Module，不把所有逻辑堆进一个 resolver。

模块必须：

- 拥有唯一 State 与 Save DTO。
- 注册自己的 public types/capabilities。
- 用 Core Command/Event 协议与其他模块协作。
- 提供正常、非法、边界、生命周期、回放和 restore 测试。
- 可以关闭；关闭后数据引用在生成阶段报错。
- 不把项目内容 ID 写入通用模块代码。

## Presentation 扩展

Cue resolver/handler 可以按项目替换动画、VFX、SFX、镜头和 UI。它接收 committed event 与逻辑 resource IDs，可以持有 Node/Resource/Tween 和表现 RNG。

表现扩展不得：

- 提交 Attribute/Effect 写入。
- 通过“动画结束”自动把未完成 Ability 标为成功。
- 因缺少 Cue handler 拒绝 Combat Action。
- 使用 gameplay RNG stream 选择粒子或音效变体。

如果玩法需要玩家在表现过程中输入，adapter 将输入转为新的 typed Intent，领域 AbilityRun 自己判断是否仍处于可接受窗口。

## Editor 扩展 metadata

每个新 type 必须提供编辑器可读 metadata：显示名 localization key、category、icon/keywords、字段 schema、semantic pins、默认值、单位、允许 scope、引用种类、连接/循环/生命周期规则、文档链接和弃用状态。Editor 读取 metadata 生成目录、GraphNode、选择器和表单，但运行时不依赖 EditorPlugin。

Metadata 不是执行入口。Editor 预览使用同一公开 evaluator/resolver 和 fixture context，不能维护一套不同算法。

## 示例判断

| 需求 | 正确路径 | 原因 |
|---|---|---|
| 火焰技能对潮湿目标增伤 | Tag Condition + Damage Modifier | 已有原语足够 |
| 受到伤害后反弹实际伤害的 30% | `damage.applied` Trigger + Formula + Damage Action | 标准 after reaction |
| 同名毒每次刷新持续时间并叠层 | Effect stacking policy 数据 | 内建策略即可 |
| 项目独有六边形连锁目标 | 项目 TargetResolver，输入格子 observation | 新目标语义，不属于 Core |
| 卡牌作为技能成本 | 项目 CostResolver/Feature 协调器 | 资源 owner 不在 Combat Attribute |
| 一种技能需要新动画 | Cue binding/Presentation handler | 纯表现，不触碰 Domain |
| 两个项目都需要相同的格挡方向规则 | 先各自 Extension 验证语义；一致后提炼 Gameplay Module | 尚不足以进入 Core |

## Extension 生命周期

### Session

Composition Root 注册 stateless evaluator/resolver 和 session policy；CombatFeature 销毁时注销 session handles。Extension 不通过 static/global 字段跨 Session 泄漏状态。

### Entity/Effect/Ability

动态来源由对应 owner 创建 handle，按生命周期回收。Project Extension 只能通过公开 grant API 获取 handles，不能把 handle 塞进未版本化 Dictionary。

### Reload/Restore

运行时不热重载规则代码。Restore 前 Extension manifest/version/fingerprint 必须匹配 Save 支持范围；不兼容直接拒绝或走显式迁移，不用 fallback type。

## 稳定性与版本

- Public type ID 一旦进入数据或 Save，不静默复用。
- Extension SPI 使用语义版本，破坏性变化删除旧接口并同步所有当前消费者；不留长期兼容层。
- Definition schema version、module/extension version 和生成源 fingerprint 一起进入 replay/save metadata。
- 扩展只能使用 public API；Core 私有目录不承诺稳定。
- 变更 handler ordering、capture、clock、RNG 或 commit semantics 必须有 ADR 和历史 fixture。

## 扩展测试合同

每个扩展至少提供：

- 注册成功、重复 ID、缺 capability、版本不兼容。
- 参数正常、坏类型、坏引用、边界和单位错误。
- graph 节点坏 pin、非法连接、capability 缺失、无界循环、不可达出口和 compiler/runtime binding 漂移。
- evaluator 纯度：相同输入相同输出，状态/RNG 不变化。
- resolver prepare 失败不写状态；commit 失败能回滚。
- grant/revoke、apply/remove、activate/cancel/end 的清理。
- 固定 seed/time/input 的 trace 与 event fixture。
- Save/restore 后 handler、modifier、schedule 和 sequence 等价。
- 无 SceneTree 的 Domain 测试；有 port 的模块另加真实场景 adapter 测试。
- debug snapshot 只含稳定 DTO；启用/禁用调试不改变 execution plan、事件顺序或 RNG 消费。

## 公共化门槛

项目 Extension 上移为共享 Module 前必须同时满足：

1. 至少两个真实项目已使用，而不是预测未来可能使用。
2. 输入、输出、生命周期、错误和状态 owner 一致。
3. 不包含具体内容 ID、项目数据格式或表现假设。
4. 可选关闭，不迫使 Core 知道该模块。
5. 有跨项目 fixture 证明相同行为。

上移为 Core 还要额外证明：没有它将破坏所有模块共有的不变量，或所有模块都必须重新实现同一协议。否则保持为共享 Gameplay Module。
