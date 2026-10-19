# 本地 Godot 官方文档使用规范

这份指南只在任务涉及 Godot API、节点/资源行为、导入导出、平台能力或引擎版本差异时阅读。普通 Feature、策划表和美术内容修改不需要加载官方文档。

## 目标引擎 API 索引

第一次为某个 Godot 版本编写引擎调用前，导出该可执行文件的完整脚本 API：

```powershell
python tools/godot_api.py export --godot <Godot 控制台可执行文件>
```

工具调用 Godot 官方 `--doctool`，把 Class Reference XML 生成到 `.godot/api_reference/<版本>/`。该目录已被忽略，不随脚手架交付；每个类对应一个 XML 文件，因此类名就是第一层索引，不再生成数据库。

按类、类成员或全局成员名查询：

```powershell
python tools/godot_api.py query Node --version 4.7.1
python tools/godot_api.py query Node.add_child --version 4.7.1
python tools/godot_api.py query request_particles_process --version 4.7.1
```

查询结果只输出签名和少量匹配项。它用于确认类、方法、属性、信号、常量、参数和返回类型是否真实存在；需要语义说明和示例时，再进入下方本地官方文档。

## 文档位置与性质

本地知识库根目录：

```text
G:\Slay the Spire2 Research\Godot 4.7 Dooc
```

从本脚手架根目录访问时可使用 `..\Godot 4.7 Dooc`。它位于脚手架外部，不进入游戏制品，也不复制到仓库中。

该副本页面标题为 `Godot Docs – master branch` / `latest`，并包含 Godot 4.7 迁移内容，应视为 4.7 开发线的官方文档快照。脚手架基线为 Godot 4.7.1；以该版本导出的 API 和自动测试结果为准。

## 渐进式查询顺序

1. 先用本项目 README 和相关 `docs/` 指南确定项目约束。
2. 引擎调用先查询目标版本导出的 API，确认签名，不凭记忆写代码。
3. 只有缺少行为解释或示例时，才在 Markdown 文档中用 2–5 个精确关键词找候选文件。
4. 候选限制在少量文件内，再读取命中附近的段落；不要批量加载全部 1,593 篇文档。
5. 涉及 4.7 新增或变更 API 时，同时检查迁移文档，并在项目支持的最低 Godot 版本上验证。
6. 结论只记录 API 版本、来源文件和项目决策，不把大段官方文档复制进项目规范。

## 选择正确的副本

| 用途 | 使用位置 |
|---|---|
| 代理关键词检索 | `Godot Engine 4.7 documentation in English MD\Godot Engine 4.7 documentation in English MD\` |
| Markdown 标题索引 | 上述目录中的 `README.md` |
| 人工按官方目录浏览 | `godot-docs-html-master\index.html` |
| API 类参考 | HTML 副本的 `classes\` |
| 最佳实践 | HTML 副本的 `tutorials\best_practices\` |
| GDScript | HTML 副本的 `tutorials\scripting\gdscript\` |
| 资源导入 | HTML 副本的 `tutorials\assets_pipeline\` |
| 导出与平台 | HTML 副本的 `tutorials\export\`、`tutorials\platform\` |
| 版本迁移 | HTML 副本的 `tutorials\migrating\` |

EPUB、ZIP、7z、图片、字体和整套 HTML 静态资源不用于代理全文检索。

## 检索示例

先查标题索引，不直接扫描或输出全文：

```powershell
$mdRoot = '..\Godot 4.7 Dooc\Godot Engine 4.7 documentation in English MD\Godot Engine 4.7 documentation in English MD'
rg -n -i 'project organization|autoload|import process' (Join-Path $mdRoot 'README.md')
```

选定文件后，再定位精确段落：

```powershell
rg -n -i 'gdignore|snake_case|version control' <选中的文档路径>
```

读取时只取命中附近的必要行。若关键词过宽，先增加类名、方法名、节点名或具体系统名，不要扩大到整个知识库。

## 与本框架的关系

本框架已有多项设计与官方建议一致：固定节点层级保存在 Scene、共享状态优先显式所有者而非滥用 Autoload、目录使用 `snake_case`、源文件目录用 `.gdignore` 隔离、提交相邻 `.import` 但不提交 `.godot/` 缓存、GDScript 使用明确类型。

官方文档解释引擎事实并提供通用建议；本项目的架构契约、ADR 和测试决定具体采用方式。若两者冲突，先确认版本差异，再通过 ADR 修改项目契约，不能因看到 4.7 文档而静默提升最低版本。
