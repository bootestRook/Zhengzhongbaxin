# 编码代理项目规则

## 目标

保持这是一个小型、可运行的 Godot 研发底座。具体游戏规则属于 Feature，不属于框架核心。

## 开始工作

1. 阅读 `README.md`。
2. 只阅读 `docs/` 中与当前任务有关的指南。
3. 只有 Godot API、引擎行为或版本差异影响任务时，才按 `docs/OFFICIAL_GODOT_DOCS.md` 查询本地官方文档。
4. 修改或验证前必读 [测试方案](docs/TESTING_AND_RELEASE.md)，按影响范围选择验证、停止条件与发布门禁。

## 模块边界

- `src/foundation/`：只放轻引擎依赖的基础原语；不得依赖 Feature、UI 或项目数据。
- `src/runtime/`：Action/Hook 执行契约；不得依赖 Node 或具体 Feature。
- `src/features/<name>/domain/`：持有该 Feature 的状态和规则；不得访问 Node、查询场景或操作 UI。
- `src/features/<name>/presentation/`：读取快照和事件并提交 Intent；不得写入领域状态。
- `src/app/`：只负责组合根和生命周期。
- `data/source/` 与 `art_source/`：人工编辑的源文件。
- `data/generated/` 与 `assets/generated/`：自动生成，禁止手工修改。

## 硬性规则

- 静态 Definition 数据在运行时不可变；可变值必须存放在有明确所有者的 Instance/State 中。
- 状态变更必须通过 Command 或状态所属 Feature 的公开接口完成。
- 玩法随机必须使用注入的命名 `RngSet` 流；表现随机必须使用独立随机流。
- 领域事件只描述已经发生的事实，表现提示负责响应；动画和特效不得决定规则结果。
- 固定 UI 结构必须保存在 `.tscn` 中；代码只能创建真正动态的列表项。
- 共享代码不得根据具体 Definition 或内容 ID 进行分支。
- 调用 Godot API 前必须按 `docs/OFFICIAL_GODOT_DOCS.md` 查询目标引擎导出的签名；不得凭记忆假设类、方法或参数存在。
- 最终打包前必须按 `docs/PACKAGING.md` 确认目标、分辨率、伸缩策略和适配矩阵；`tools/package.py check` 未通过不得发布导出。
- WebApp 必须交付根目录含 `index.html` 且不超过 100,000,000 字节的 ZIP；颜色和字体问题按 `docs/WEB_EXPORT_PARITY.md` 验收。
- 打包分辨率默认读取 `project.godot`；特殊值必须说明并同步项目。导出前须清缓存、重建生成物和源指纹，禁止复用旧输出。
- 未编写 ADR 前，不得新增 Autoload、全局 EventBus、第三方依赖、数据格式、Save/RNG 契约变更或跨 Feature 依赖。
- 所有文本保持 UTF-8 无 BOM、LF 换行。不得复制商业源码、名称、数据或资产。

## 常用命令

```text
python tools/project.py data     # 校验 CSV/schema 并重新生成运行时 JSON
python tools/project.py assets   # 校验源资产和运行时资产并重新生成清单
python tools/project.py run      # 运行项目
python tools/project.py check    # 全量工程检查；仅按测试方案触发
```

## 完成标准

- 本次变更涉及的最小真实路径可以正常工作。
- 按测试方案完成适用验证，如实报告通过项、未执行范围及阻塞。
- 只有契约或工作流发生变化时才修改文档。
