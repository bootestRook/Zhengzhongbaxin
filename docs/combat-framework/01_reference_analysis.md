# 参考系统分析与取舍

## 分析方法

本设计只提取职责边界、生命周期、组合方式和扩展机制，不复制命名体系或 API。结论以公开一手文档和源码为依据；参考版本会继续演进，因此本文记录的是可迁移的设计思想，而不是兼容承诺。

评估每项设计时使用四个问题：

1. 它解决了什么长期复杂度？
2. 它是否依赖原框架独有的引擎、网络或语言条件？
3. 放进当前 Godot/GDScript 底座后，最小可用形态是什么？
4. 它会不会让 Core 因内容特例持续增长？

## Forge for Godot

Forge 将 GAS-like 概念接到 Godot，而 Statescript 又把 Ability 行为建成受限状态图。源码中，`StatescriptGraph` Resource 只保存节点、连接、变量和画布位置；`StatescriptGraphBuilder` 将其构造成运行图；`StatescriptAbilityBehavior` 缓存并共享不可变图定义，但每次激活创建独立 `GraphProcessor/GraphContext`。这是本框架可视化 Ability 架构最直接的参考。

### 值得吸收

- **Godot 适配职责清晰**：Resource 适合 Inspector 中可组合的静态配置；Node 适合 Area、RayCast、Cue handler 等必须接 SceneTree/物理/表现的边界。
- **Definition 与运行实例分离**：Effect/Ability 数据资产是配置，应用后的 Effect 和每次 Ability activation 才拥有运行状态。
- **Effect component 组合**：Modifier、tag grant、requirement、chance 等行为以组件组合，而不是为每个 buff 新增总控分支。
- **Cue 独立于规则**：Cue handler 负责 VFX/SFX/UI，规则层只产生 Cue 所需的语义参数。
- **Graph Definition 与 Processor 分离**：同一图可以服务多个 activation；变量、活跃节点和取消状态属于本次执行，不写回 Resource。
- **混合执行模型**：即时 Action/Condition 同步传播，State 节点显式保持活动；这说明技能图既需要控制流，也需要可保存、可取消的 wait/state token。
- **子图需要所有权语义**：Statescript 区分普通事件输出和 owned subgraph；父状态结束时自动清理其拥有的下游状态。这个思想比“从一个节点画出一条线”更重要。
- **编辑器与运行时使用同一节点构造事实**：节点发现获得端口和参数布局，Graph Builder 使用同一路径创建运行节点，避免画布显示与运行端口漂移。
- **节点 UI 可替换**：默认属性渲染与 `CustomNodeEditorRegistry` 分开；复杂节点可以提供专用编辑器而不修改 Graph Dock 总控。
- **搜索目录是一等能力**：Add Node Dialog 提供分类、搜索和说明；节点库扩展不要求手改一个巨型菜单。

### 不直接采用

- Forge 当前以 C#/.NET、Autoload manager、全局/实体 EventBus 和每实体 `_Process()` 更新为主要集成方式；当前项目明确默认无 Autoload、领域不依赖 Node，并已有注入式 `RngSet` 与组合根。
- `SharedVariables` 一类跨 Ability 可写变量袋会弱化状态所有权。本设计要求共享值进入有类型、可快照的 Entity/Feature State。
- 不照搬每帧更新所有 State 节点。AbilityRun 由 CombatClock、committed event 和可信 observation 唤醒，只保存明确 wait token。
- 不照搬反射扫描 loaded assemblies。Core、Module 和 Project Extension 通过组合根显式注册节点描述符、编译器和执行器，确保导出、headless 和排序一致。
- 不照搬端口数组下标作为长期语义身份。连接保存稳定 node ID 与 semantic pin ID；可视端口序号只是 GraphNode 投影。
- 不把图当任意 C#/GDScript 的替代品。节点集合严格受战斗领域、事务、RNG、时间和状态 owner 约束。
- Forge 仍处于活跃开发阶段；它是设计参考，不是本项目的依赖或稳定性来源。

### 本项目中的转化

采用四段式边界：`AbilityGraph authoring document → validated engine-neutral graph → immutable execution plan → AbilityRun`。Godot Resource/GraphEdit 只在 authoring adapter 中；运行时不读取 GraphNode，也不执行未编译 Resource。领域时间由显式 tick/turn 驱动，事件限于 Combat Session。

来源：[Forge Statescript 概览](https://github.com/gamesmiths-guild/forge/blob/main/docs/statescript/README.md)、[Ability 集成](https://github.com/gamesmiths-guild/forge/blob/main/docs/statescript/ability-integration.md)、[StatescriptGraph Resource](https://github.com/gamesmiths-guild/forge-godot/blob/main/addons/forge/resources/statescript/StatescriptGraph.cs)、[Graph Builder](https://github.com/gamesmiths-guild/forge-godot/blob/main/addons/forge/core/StatescriptGraphBuilder.cs)、[节点发现](https://github.com/gamesmiths-guild/forge-godot/blob/main/addons/forge/editor/statescript/StatescriptNodeDiscovery.cs)、[图操作与 Undo/Redo](https://github.com/gamesmiths-guild/forge-godot/blob/main/addons/forge/editor/statescript/StatescriptGraphEditorDock.GraphOperations.cs)。

## Godot Orchestrator

Orchestrator 是通用可视化脚本系统，不是 Combat Runtime。它最值得研究的是节点编辑器基础设施：Action Registry、上下文搜索、Pin Model、Pin Widget Factory、Graph Model、复制粘贴和 Resource 序列化。

### 值得吸收

- **目录、过滤和 UI 分层**：Action Registry 汇总候选，Filter Engine 按搜索文本、端口和图上下文筛选，Menu 只负责渐进呈现。这比在右键菜单里硬编码节点列表可扩展。
- **执行端口与数据端口分离**：Pin Model 决定方向、类型、对象继承与允许的 coercion；GraphEdit hover 只询问模型是否兼容。
- **模型不是画布**：其 `OScriptGraph` 明确标注为 UI 逻辑分组，运行实例不得依赖它。节点、连接、变量和函数由 Orchestration Resource 持有。
- **Pin Widget Factory**：bool、number、enum、object、file、struct 等输入用不同控件呈现，节点模型不负责绘制 Inspector 控件。
- **复制粘贴是模型操作**：先复制选中节点和内部连接，再校验函数/变量/Signal 依赖，粘贴时重映射节点 ID，最后恢复连接和动态 pin 类型。
- **大节点库搜索要分帧**：Action Menu 对搜索构建设置时间片并复用 TreeItem，说明节点数量上来后“搜索流畅度”本身就是架构问题。

### 不直接采用

- 不把 Orchestrator 当 Ability 系统或项目依赖。它的通用脚本、函数、Signal、Scene 成员和隐式类型转换远超战斗图所需边界。
- 不复制其自定义脚本格式、编译器或 GDExtension 运行时。当前项目已有 Action/Command/DataRegistry 契约。
- 源码审计显示当前 GraphPanel 的连接、粘贴等编辑路径直接改模型，未完整接入 Godot `EditorUndoRedoManager`。本设计把所有 graph mutation 的 Undo/Redo 作为硬性要求，而不是照单全收。
- Ability 数据端口默认不做宽松 coercion；单位、scope 或数值语义不一致必须显式转换，不能因为 Godot Variant 可转换就自动接线。

### 本项目中的转化

建立显式 `AbilityNodeCatalog + ConnectionPolicy + NodeViewFactory + GraphCommand/UndoRedo + ClipboardService`。节点目录从 Core/Module/Project Extension 的 descriptor 生成；GraphEdit 只发交互请求，所有写入都先修改 graph document model，再刷新 view。

来源：[Orchestrator 仓库](https://github.com/CraterCrash/godot-orchestrator)、[Action Registry](https://github.com/CraterCrash/godot-orchestrator/blob/main/src/editor/actions/registry.cpp)、[Action Filter](https://github.com/CraterCrash/godot-orchestrator/blob/main/src/editor/actions/filter_engine.cpp)、[Pin Compatibility](https://github.com/CraterCrash/godot-orchestrator/blob/main/src/orchestration/node_pin.cpp)、[Graph Clipboard](https://github.com/CraterCrash/godot-orchestrator/blob/main/src/editor/graph/graph_clipboard.cpp)、[Graph UI/Runtime 边界](https://github.com/CraterCrash/godot-orchestrator/blob/main/src/orchestration/graph.h)。

## LimboAI

LimboAI 的 BehaviorTree 是 Resource，`BTInstance` 持有每次运行状态，自定义任务继承少量稳定基类；它的 Visual Debugger 通过 Godot 调试会话观察运行实例。这部分比其树算法本身更适合作为 Ability Graph 参考。

### 值得吸收

- **Definition/Instance 再次分离**：BehaviorTree Resource 可复用，实例持有 root、last status、agent/blackboard 和性能统计。
- **扩展基类少而稳定**：Action、Condition、Decorator、Composite 形成可发现的任务目录；项目脚本任务不用修改编辑器总控。
- **调试只传轻量快照**：`BehaviorTreeData` 将树按深度优先顺序扁平化，只传 instance ID、owner、资源路径、task ID、状态、耗时、类型等显示数据。
- **按需跟踪**：运行时先报告活跃实例；用户选择一个实例后才订阅其 update 并传快照，避免每帧广播所有树。
- **视图保存用户上下文**：更新状态时保留选择和折叠状态；拓扑不变时只更新状态与耗时，而不是每帧重建整棵树。

### 不直接采用

- Ability Graph 不是行为树，不采用 tick-every-frame 的 Success/Failure 传播语义。
- 不采用任意 Blackboard 作为跨技能共享状态；AbilityRun 只拥有有类型局部变量，跨 Run 数据进入明确的 Attribute/Tag/Module State。
- 调试状态不能成为规则输入，也不能把 Remote Object 引用写入 CombatState。

### 本项目中的转化

运行时 Debug Registry 只登记活跃 `AbilityRun`。EditorDebuggerPlugin 选择某个 Run 后接收 `AbilityExecutionSnapshot`：稳定 node ID、状态、进入次数、等待原因、最近错误和活动边。GraphNode 使用 `inactive/queued/running/waiting/succeeded/failed/cancelled` 着色，并可跳转到 Event Trace。

来源：[LimboAI README](https://github.com/limbonaut/limboai)、[BehaviorTreeData](https://github.com/limbonaut/limboai/blob/master/editor/debugger/behavior_tree_data.cpp)、[BehaviorTreeView](https://github.com/limbonaut/limboai/blob/master/editor/debugger/behavior_tree_view.cpp)、[运行时 Debugger](https://github.com/limbonaut/limboai/blob/master/editor/debugger/limbo_debugger.cpp)、[Editor Debugger Plugin](https://github.com/limbonaut/limboai/blob/master/editor/debugger/limbo_debugger_plugin.cpp)。

## Godot GraphEdit / GraphNode

`GraphEdit` 是无限画布、连接显示和交互请求控件，`GraphNode` 是带 slot/port 的可视节点。官方 API 明确把模型职责留给调用者：连接、断开、删除、复制、粘贴和重复主要通过 Signal 请求；调用方必须验证并真正修改数据。

本设计使用 GraphEdit/GraphNode 作为视图底座，并使用 `EditorUndoRedoManager` 管理 graph document mutation。端口 type integer 只映射 UI 色彩和基础 hover；真实兼容性仍由 `ConnectionPolicy` 依据 semantic pin type、单位、scope、cardinality、cycle policy 和 module capability 判断。`set_connection_activity()` 可用于运行时连线高亮，EditorDebuggerPlugin 用于接收运行会话数据。

来源：[GraphEdit](https://docs.godotengine.org/en/stable/classes/class_graphedit.html)、[GraphNode](https://docs.godotengine.org/en/stable/classes/class_graphnode.html)、[EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html)、[EditorDebuggerPlugin](https://docs.godotengine.org/en/stable/classes/class_editordebuggerplugin.html)。

## SkillEditor

技能树编辑器主要解决节点解锁、依赖和布局，不解决一次技能行为的控制流、数据流、wait/cancel、事务和运行时调试。它可以参考树状内容管理与易用性，但不作为 Ability Behavior Editor 的架构来源。

## Unreal Gameplay Ability System

GAS 围绕 Ability System Component 聚合 Ability、Attribute、Effect、Tag、Event 与 Cue。Gameplay Effect 是不可变资产，Gameplay Effect Spec 是携带 level、captured values 等上下文的运行时规格；持续 Effect 再形成 active instance。Ability 有 grant、can activate、activate、commit、cancel、end 生命周期，并以 AbilityTask 承担异步步骤。

### 值得吸收

- **Definition / Spec / Instance 三分法**：静态定义、一次执行上下文和持续运行状态不可混为一个对象。
- **显式生命周期**：Ability 不只是一个函数；grant、activation、commit、waiting、cancel、end、remove 都需要成对清理。
- **Cost 与 Cooldown 是策略**：它们属于 Ability 激活协议，而不是散落在具体技能代码里的扣数值和 Timer。
- **Tag query 统一门禁**：required、blocked、cancel、granted 等规则以层级 Tag 和查询表达，减少系统间硬引用。
- **Effect 管理持续修改**：临时 Modifier 随 Effect instance 移除，永久变化由 instant execution/Command 提交。
- **Cue 只做表现**：官方明确警告不要把需要可靠同步的玩法逻辑放进 Cue。

### 需要减重

- GAS 同时解决 Unreal Actor/Component、反射、Blueprint、复制、客户端预测和服务器校验，复杂度远超当前离线单机底座。
- 不复制 ASC 的巨型职责。Combat Feature 持有领域状态；Node 只是可选 facade；网络权威将来单独做架构阶段。
- 不复制所有 instancing/net execution/replication policy。第一版只保留能被当前项目验证的生命周期与并发策略。
- 不让 Ability 任意操作动画、粒子和 Actor。Ability 只提交领域 Action、等待领域 token、产生事实事件；表现通过 Cue adapter 响应。
- 不照搬浮点捕获和反射式 Attribute 查找。属性、公式输入和捕获时机必须在 Definition 中显式声明并经过 Schema 校验。

### 本项目中的转化

Effect 使用 `Definition → Spec → optional Instance`；Ability 使用 `Definition → Grant → Run`。Cost 在原子 Action 的 commit point 提交，Cooldown 默认复用带 tag 的 timed Effect；Ability Graph 的 wait 节点编译为少量有界、可取消的领域 wait token，而不是复制完整 GameplayTask 子系统。

来源：[GAS 总览](https://dev.epicgames.com/documentation/en-us/unreal-engine/understanding-the-unreal-engine-gameplay-ability-system)、[Gameplay Ability 生命周期](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-gameplay-abilities-in-unreal-engine)、[Gameplay Effect](https://dev.epicgames.com/documentation/unreal-engine/gameplay-effects-for-the-gameplay-ability-system-in-unreal-engine)、[Attribute 与 Attribute Set](https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-attributes-and-attribute-sets-for-the-gameplay-ability-system-in-unreal-engine)、[Gameplay Tag](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-gameplay-tags-in-unreal-engine)。

## Lyra

Lyra 展示了如何在大型样例项目中约束 GAS：AbilitySet 数据资产成组授予 Ability、Effect 和 Attribute Set；授予方保存 handles 并负责撤销；PlayerState 与 Pawn 生命周期分离；Activation Policy/Group 统一被动激活、输入激活和并发；Game Feature/Equipment/Experience 负责装配而非修改 GAS Core。

### 值得吸收

- **授予方负责回收**：grant 返回 handle 集，装备、形态或项目模块卸载时可以精确撤销自己授予的内容。
- **状态所有者不等于场景载体**：战斗状态可比 Pawn/Node 活得更久，避免换场景或换载体时误丢状态。
- **能力包用于装配**：AbilitySet 是组合单位，不把某种职业、武器或模式写进 Core。
- **激活策略和并发组标准化**：手动、on granted/on available、输入触发和保持输入等入口应映射为少量策略；互斥、可替换和独立运行有统一协议。
- **项目功能从外部注入**：Experience、Equipment、Game Feature 负责选择内容，Core 不反向知道它们。

### 不直接采用

- 不复制 PlayerState/Pawn、GameFeaturePlugin、Enhanced Input 或 Unreal 复制模型。
- AbilitySet 不成为新的资源格式；它在当前项目中是经过 Schema 校验的 Definition 关系数据。
- 不建立全局 AbilitySystem 子系统。跨 Entity 效果由当前 Combat Session 或 App 协调器显式提交。

### 本项目中的转化

引入 `GrantBundleDefinition` 和 `GrantHandleSet`；Entity Node 销毁与 CombatEntity 生命周期解耦；Project Extension/Composition Root 选择能力包和模块。Ability run 使用明确 activation policy、concurrency group 与 cancel policy。

来源：[Lyra 中的 Ability](https://dev.epicgames.com/documentation/unreal-engine/abilities-in-lyra-in-unreal-engine)、[Lyra Sample Game](https://dev.epicgames.com/documentation/unreal-engine/lyra-sample-game-in-unreal-engine)。

## Pokémon Showdown

Showdown 的 `runEvent` 是复杂战斗规则管线：它从目标、来源及其相关状态收集 handler，按 order、priority、speed、subOrder、effectOrder 排序；relay value 在 handler 间传递，返回值可以修改或中断事件；嵌套事件维护 parent event/effect 上下文，并有深度与日志上限。

### 值得吸收

- **事件是规则求值管线，不只是通知**：before/modify 阶段允许有序改变候选值或拒绝请求。
- **处理顺序是契约**：priority 必须有稳定 tie-break，不依赖 Dictionary 顺序或 Signal 连接先后。
- **事件上下文显式传播**：source、target、cause/effect、当前 relay、父事件和深度均可追踪。
- **局部作用域发现**：只收集与目标、来源、场地或状态相关的 handler，而不是向全局所有对象广播。
- **中断和“不修改”不同**：continue、replace、reject/stop 必须是显式结果，不用含混的 `null`/真假值约定。
- **防循环是框架职责**：深度、总事件数和 trace 数量需要硬上限。

### 需要重新设计

- Showdown 的回调名、动态对象和特殊返回值约定非常适合其 TypeScript 数据生态，但不适合作为 Godot 通用公开 API。
- 本设计不用 `false/null/undefined` 承载多个语义，而使用明确的 HandlerResult。
- 事件处理器不能直接任意改战斗状态；它只能在允许阶段修改 relay、拒绝，或排队新的 Action/Effect。实际写入仍由 Command 完成。
- 不把所有战斗事实都变成可拦截事件。已提交 Domain Event 是不可变事实，只能触发后续反应。

### 本项目中的转化

Combat Event Pipeline 分为 gate、modify、resolve、commit、after。分发前冻结 handler 集；排序使用 phase、priority、scope、owner sequence、registration sequence 和稳定 ID；reaction 使用有界队列而非无界递归。详见 [04_event_pipeline.md](04_event_pipeline.md)。

来源：[Pokémon Showdown `battle.ts` 的 `runEvent`、排序和深度保护](https://github.com/smogon/pokemon-showdown/blob/master/sim/battle.ts)。

## OpenRA

OpenRA 的 Actor 由 YAML 中的 TraitInfo 组合，TraitInfo 创建运行时 Trait；接口描述 Trait 提供或消费的能力，`Requires<T>`/`NotBefore<T>` 形成构造依赖并在加载时校验。Condition 以 token 计数授予/撤销，多个来源可以安全叠加。Actor 缓存常用接口以控制高频查询成本。

### 值得吸收

- **组合胜过内容子类树**：实体能力来自一组小 Trait/组件，而不是为每个单位或技能新增继承层。
- **静态配置与运行对象分离**：Info 是可加载定义，Trait 是实体实例上的状态与行为。
- **依赖是可验证数据**：组件所需能力与初始化顺序在加载时检查，不等运行时报空引用。
- **Condition 使用来源 token**：撤销某个来源不会错误删除其他来源授予的相同 Condition。
- **多个同类 Trait 可命名实例**：组合可以复用同一机制而不依赖内容 ID 分支。

### 不直接采用

- 不把整个 CombatEntity 做成无约束 Trait 容器。Core 的 Attribute、Tag、Effect、Ability 状态仍有明确 owner 和固定不变量。
- 不复制 OpenRA 的 YAML 继承/删除语法或反射式类型创建；当前项目已有版本化 Schema 与确定性 JSON 生成链路。
- 不让任意组件订阅所有生命周期接口。扩展只能实现公开、窄而有阶段约束的 SPI。

### 本项目中的转化

Gameplay Module 和 Project Extension 通过 capability/requirement manifest 声明依赖；装配时拓扑校验。Tag grant、Effect grant 和 Ability grant 使用来源 handle。高频事件按 event type 和 scope 建索引，而不是遍历所有扩展。

来源：[OpenRA Actor 运行时组合](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Game/Actor.cs)、[ActorInfo/Trait 构造依赖](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Game/GameRules/ActorInfo.cs)、[自动生成的 Trait 参考](https://docs.openra.net/en/release/traits/)。

## Godot 官方设计约束

Godot 官方文档将 Node 定位为绘制、物理、UI 和 SceneTree 生命周期等功能载体，将 Resource 定位为可序列化、Inspector 可编辑、路径缓存的数据容器；Signals 用于对象间低耦合响应；Scene 适合声明 Node 组合，并建议子场景尽量自足或由上层注入依赖。

### 本项目采用的职责边界

| Godot 概念 | Combat 中的职责 | 明确禁止 |
|---|---|---|
| `RefCounted` | CombatState、Entity instance、Effect instance、Ability run、EventContext、纯 evaluator | 访问 SceneTree、持有 UI、隐式每帧更新 |
| `Resource` | 表现绑定、Curve/PackedScene 等引擎资产，以及经 ADR 选定的 Ability Graph authoring document | 保存共享可变战斗状态；与另一格式长期双写同一图语义；被运行时直接当执行实例 |
| `Node` | Entity/world adapter、物理观察、输入、时钟推进、Cue 播放和场景生命周期桥接 | 成为 Attribute/Tag/Effect 的 source of truth；直接写 Domain State |
| `Signal` | Node/Presentation 边界的已发生通知和 Intent 转发 | 代替有序、可取消、可回滚的 Combat Event Pipeline |
| `.tscn` | 固定 adapter、表现、VFX/SFX 和 UI 结构 | 编码不可见的战斗规则或依赖 NodePath 的领域状态 |
| `EditorPlugin` | 校验、选择器、预览、trace 和 authoring UX | 参与导出后的规则执行 |

Resource 按路径缓存，多个加载方可能得到同一实例，因此静态 Combat Definition 必须按不可变对象使用；可变 Spec/Instance 不放进共享 Resource。Signal 的订阅顺序也不是战斗优先级协议，因此规则事件使用领域管线，Signal 只发布提交后的结果。

来源：[Godot Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)、[避免所有对象都使用 Node](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html)、[Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)、[Using signals](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)、[Scenes versus scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html)。

## 综合结论

| 需要解决的问题 | 采用的核心思想 | 本设计的轻量化形态 |
|---|---|---|
| 静态配置与运行状态 | GAS/Forge Definition-Spec-Instance | DataRegistry Definition + RefCounted Spec/Instance |
| 复杂规则传播 | Showdown ordered relay | Combat Session 内分阶段、有界、可追踪的 Event Pipeline |
| 内容组合 | OpenRA Trait、GAS Effect Component | 有类型的 Condition/Formula/Modifier/Action 组合 |
| 技能生命周期 | GAS Ability/Task、Lyra policy、Forge Statescript | Grant/Run + 编译后的 execution plan + 显式 wait/cancel/end |
| 能力装配与撤销 | Lyra AbilitySet handles | GrantBundle + 来源 HandleSet |
| Godot 集成 | Forge + Godot 官方职责 | 纯领域 Core，Node/Resource/Editor adapter |
| 可视化创作 | Forge Statescript、Orchestrator、GraphEdit | 受限 Ability Graph、显式节点目录、类型 pin、model-first Undo/Redo |
| 运行状态观察 | LimboAI Visual Debugger | 按需订阅 AbilityRun，传轻量 snapshot，节点/连线增量高亮 |
| 项目差异 | Lyra Game Feature、OpenRA mod | Composition Root 注入 Project Extension |
| 表现反馈 | Gameplay Cue/Forge Cue | 已提交 Domain Event → Cue router → Presentation Node |

最终原则不是“做一个较小的 GAS”，而是让当前项目拥有一条稳定、可验证的战斗规则路径，同时保留 Godot 的场景与编辑器优势。
