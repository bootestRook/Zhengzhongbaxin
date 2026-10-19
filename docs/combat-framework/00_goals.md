# Combat Framework：目标与设计准则

## 文档状态

本目录描述 Combat Framework 的目标架构，并作为已实现纵向切片的契约基线。实现代码位于共享 runtime 与 editor-only addon；任何实现若改变这里的状态所有权、事件顺序、Save/RNG 契约或模块依赖，必须先更新设计并按项目规则补充 ADR。

## 一句话目标

建立一套可在多个 Godot 项目长期复用的轻量战斗领域框架：普通内容通过 `Trigger + Condition + Action/Effect + Modifier` 组合完成，项目特例通过明确的 Project Extension 接入，Core 不因某个技能、角色或内容 ID 而修改。

这里的“通用”指稳定的职责和协议，不指把所有玩法塞进一个万能系统。框架提供 Entity、Attribute、Tag、Effect、Event、Trigger、Condition、Formula 和 Ability 生命周期；伤害、投射物、移动等可选 Gameplay Module 建立在这些原语之上；具体游戏决定启用哪些模块以及规则语义。

## 目标

1. **长期稳定的 Core**：Core 只包含跨项目反复出现且语义稳定的原语，不知道火球、宝可梦、卡牌、武器或任何具体 Definition ID。
2. **组合优先**：数据可以在有类型的 Ability Graph 中组合事件、目标、条件、公式、Action、Effect、Modifier 与表现 Cue。新增普通技能不新增脚本，不修改共享代码。
3. **项目扩展而非核心膨胀**：无法由现有原语表达的规则，由项目自己的 Extension 实现并经组合根注入；出现第二个真实消费者后，才评估上移为公共机制。
4. **确定性与可追踪**：同一输入、状态、命名 RNG 流和时钟序列产生同一结果。每次 Action 都能输出事件顺序、处理器顺序、数值变化和拒绝原因。
5. **明确状态所有权**：静态 Definition 不可变；Entity、Attribute、Tag grant、Effect instance、Ability run 和时钟都有唯一运行时所有者；表现层不持有玩法事实。
6. **规则与表现分离**：领域事件只描述已经发生的事实。Animation、VFX、SFX 和 Cue 可以响应结果，但不能决定命中、伤害、持续时间或资源消耗。
7. **适配不同战斗形态**：Core 不依赖回合制、即时制、2D、3D 或物理节点。项目通过注入时钟、目标观察和世界操作端口选择形态。
8. **Godot 原生但不 Node 化一切**：Scene/Node 承担引擎生命周期、世界观察和表现；Resource 承担可共享的引擎数据与编辑器配置；高频可变战斗状态使用轻量领域对象。
9. **与当前底座一致**：沿用 `Intent → Action → Command → Feature State → Domain Event`、原子回滚、命名 `RngSet`、不可变 `DataRegistry`、唯一 Composition Root 和 Feature save namespace。
10. **可分层交付**：先完成最小但真实的端到端路径，再逐层增加持续效果、Ability、模块和编辑器体验。

## 非目标

- 不复制 Forge、Unreal GAS、Lyra、Pokémon Showdown 或 OpenRA 的类型体系、API 和实现。
- 不在第一版建设 ECS、网络预测、回滚网络码、Mod 沙箱或服务器权威同步。
- 不提供全局 EventBus；Combat Event Pipeline 是单个 Combat Feature/Session 内的受控规则管线。
- 不把每个 Entity、Effect、Trigger 或 AbilityTask 建成 Node，也不依赖每帧 `_process()` 驱动领域状态。
- 不以共享可变 Resource 保存 Entity/Effect/Ability 的运行时状态。
- 不提供可执行任意代码的公式字符串、脚本字段或通用可视化脚本语言。Ability Graph 是受限的战斗领域语言，只能使用注册、校验并可确定性执行的节点类型。
- 不要求所有项目采用同一伤害、护甲、阵营、暴击、命中、元素或死亡规则。
- 不用兼容层维持尚未发布的旧 Combat API；架构演进时删除被取代的路径。
- 不让编辑器插件成为运行时正确性的前提；没有插件时，CLI 管线和运行时仍然完整工作。

## 首要架构判据

评审任何新需求时，依次回答：

1. 能否只新增或修改 Definition？
2. 能否组合已有 Trigger、Condition、Action/Effect、Modifier、Formula 或 Target？
3. 能否通过已有 Gameplay Module 的公开扩展点完成？
4. 是否确实需要项目专属 Extension？
5. 是否已有至少两个项目需要完全相同且语义稳定的能力，足以上移为公共模块或 Core？

如果问题 1–3 任一为“能”，不得修改 Core。如果只有问题 4 为“是”，实现必须留在项目 Extension。只有问题 5 有真实证据时，才启动公共化设计评审。

## 不可破坏的约束

- Core 和共享模块不得按具体 `definition_id`、技能 ID、角色 ID 或资源路径分支。
- Condition 和 Formula 是纯求值；不得写状态、发 Cue、访问 SceneTree 或隐式消费随机数。
- 所有玩法随机只从注入的语义命名 `RngSet` 流取得；表现随机使用 `presentation.*` 流。
- 状态变更只能由 owning Command 或状态所属 Feature 的公开接口提交。
- 事件处理器只能在声明的阶段做声明允许的事；已提交事实不可被事后处理器改写。
- 同一事件的处理器集合和排序在分发开始时冻结；分发中新增/删除的注册从下一个事件生效。
- Ability、Effect、Tag grant 的取得和释放都使用稳定句柄，确保多个来源不会互相误删。
- 领域时钟使用显式整数 tick/turn；Node Timer、动画帧和墙钟不是玩法时间源。
- 失败必须有稳定错误码；达到事件深度或预算上限时整次原子 Action 拒绝并恢复快照。
- Cue 消费的是已提交 Domain Event；Cue 失败、缺资源或被跳过不影响战斗结果。

## 代表性使用场景

框架至少应能在不修改 Core 的前提下表达：

- 即时伤害、治疗、护盾吸收、持续伤害和持续治疗。
- 基于 Attribute、Tag、关系和事件载荷的技能可用性、目标筛选与效果条件。
- 增伤、减伤、免疫、反伤、吸血、击杀触发、连锁施法和效果驱散。
- 有时限、无限期、周期执行、刷新、叠层、独立实例和互斥组效果。
- 资源成本、共享/独立冷却、主动技能、被动技能以及可取消的多阶段 Ability。
- 回合推进或固定 tick 推进；相同战斗规则可接 2D/3D 表现。
- 项目 A 的护盾优先级、项目 B 的元素反应、项目 C 的卡牌结算等彼此不同的扩展。

## 成功标准

设计进入实现阶段后，以以下标准验收：

| 维度 | 验收标准 |
|---|---|
| Core 稳定性 | 三个差异明显的示例项目机制均不要求按内容 ID 修改 Core |
| 数据驱动 | 普通 Ability/Effect 只新增经过 Schema 校验的源数据和表现绑定 |
| 确定性 | 固定输入、seed、时钟和 Definition 指纹的回放事件序列完全一致 |
| 原子性 | 成本、冷却、效果与后续触发任一步失败时，按声明的提交边界恢复 |
| 可诊断性 | Trace 可定位事件、阶段、处理器、优先级、前后 relay 值、Command 和 RNG 流 |
| 生命周期 | grant/revoke、apply/remove、activate/end/cancel、target invalidation 均有成对测试 |
| 边界 | Domain 测试无需 SceneTree；Presentation 只能通过快照、事件和 Intent 交互 |
| 编辑器 | 非法 ID、坏连线、类型不匹配、无界循环、未知扩展类型和危险优先级在编译/导出前失败；运行时可定位当前 Ability 节点 |
| 性能 | 热路径不为每个 Effect/Trigger 创建 Node，不对所有 Entity 做全局广播扫描 |

## 分层交付顺序

1. **Core 最小纵向切片**：Entity + Attribute + Tag + instant Effect + Event trace，证明 Intent 到 Cue 的完整链路。
2. **持续规则**：Effect instance、Modifier、Condition、Trigger、显式时钟、Save 与确定性重放。
3. **Ability Graph 内核**：grant、activation、cost、cooldown、target、`OnCast → Action → End` 最小执行计划，以及 end/cancel；先用纯领域 fixture 证明编译与运行。
4. **首批 Gameplay Modules**：先 Damage 与 Buff；有真实消费者后再加 Projectile、Movement、Summon、Area，并通过节点描述符接入 Ability Graph。
5. **可视化纵向切片**：用 `GraphEdit + GraphNode` 打通 Graph Resource/Document、节点目录、类型连线、Undo/Redo、编译诊断和保存；图编辑器从第一版就是正式 authoring 方向，不是另一个运行时。
6. **运行时调试**：先做活跃 AbilityRun 列表和当前节点状态，再与 Event Trace、Formula/Condition 诊断联动。
7. **Project Extension 样例**：用至少两个不能仅靠参数化解决的项目规则验证 SPI，包括项目节点如何只扩展注册表而不修改 Core。

后续文档分别说明[参考系统取舍](01_reference_analysis.md)、[总体架构](02_architecture.md)、[模块边界](03_module_boundaries.md)、[事件管线](04_event_pipeline.md)、[数据模型](05_data_model.md)、[扩展点](06_extension_points.md)、[项目定制](07_project_customization.md)和[编辑器架构](08_editor_architecture.md)。
