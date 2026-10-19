# 扩展指南

## 新增普通配置定义

只改相应 Feature 的源表，复用已有机制和 presentation cue，运行 `project.py data`，再按 [测试方案](TESTING_AND_RELEASE.md) 验证配置实际生效及相关行为。普通内容不应默认新增专属脚本，也不默认触发全量检查。

## 新增一个 Feature

1. 创建 `src/features/<name>/domain/` 与 `presentation/`。
2. 在 `feature_catalog.csv` 登记 owner、save namespace、两个 root 和状态。
3. Domain 定义 immutable Definition、mutable Instance/State、唯一 owner 和 snapshot/restore。
4. 用 Intent 进入；Action 校验/声明 atomicity；Command 是状态写入口；Domain Event 输出结果。
5. 固定 UI 在 `.tscn`，View 只读取 snapshot/event 并提交 intent。
6. 按 [测试方案](TESTING_AND_RELEASE.md) 覆盖正常、相关边界和必要失败路径；涉及随机、Save 或 Scene 交互时增加对应验证。
7. Composition Root 只负责装配，不把业务规则搬进 `src/app/`。

内置 `sample_interaction` 是最短参考。复制它的结构，不复制其示例语义。

## 新增通用机制

只有多个真实消费者或核心语义需要它时，才把机制放 `src/runtime/`。提交必须包含：稳定语义、输入输出、状态写入、失败/取消/原子性、数据表示、Hook 顺序、RNG 流、Save 影响和测试。一次性特例留在 Feature 内。

## 受控特殊实现

确实无法泛化时允许 Feature 专属脚本，但它不得直接写其他 Feature 状态、访问固定 UI Node、依赖具体资源路径或跳过统一验证。记录原因和测试；出现第二个相似实现时重新评估公共机制。

## UI 和表现

- 固定页面骨架、按钮、容器、锚点和样式放 `.tscn`/Theme。
- 数量不定的列表项、世界标记、状态图标和飘字可以动态创建。
- View 读取 snapshot/ViewModel，向 Feature 提交 Intent。
- 表现通过逻辑资源 ID 与 cue 绑定；缺资源显示可诊断 fallback。

## 第三方和平台

FMOD、Spine、Sentry、Steam、主机 SDK 等实现 Platform/Presentation port，不进入 Domain。引入前记录许可证、版本矩阵、替代方案、隐私、符号/崩溃、构建和最小 smoke suite。

## 必须写 ADR 的变化

新增 Autoload/全局服务/跨 Feature 依赖、数据格式、第三方依赖、Save/RNG/protocol、状态 owner、全局 EventBus、ECS/DSL、导出流程、绕过校验或提高预算/脚本阈值。模板见 `docs/adr/0000-template.md`。
