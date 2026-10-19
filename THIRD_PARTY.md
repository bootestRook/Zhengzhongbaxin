# 第三方内容清单

原脚手架、自行编写的 GDScript/Python 实现和示例 SVG 属于项目代码。根目录 MIT 许可证不授予下列第三方游戏内容的权利。

| 内容 | 来源与版本 | 本地文件 | 使用边界 |
|---|---|---|---|
| 游戏配置、中文名称及文本 | 用户提供的《正中靶心2》当前客户端与合并热更，2026-10-13 冻结 | `data/source/defense/` | 本地复刻研究；无公开发行授权声明 |
| 人物、怪物、地图、UI、特效帧 | 同一当前热更资源 | `art_source/defense/original_pngs.zip`、`assets/runtime/defense/atlas_*.png` | 保留来源与 SHA-256；未声称项目原创 |
| 主界面补充图标与头像 | 用户提供的图 2，2026-10-13 | `art_source/defense/home_reference.png`、`assets/runtime/defense/home_reference_icons.png` | 提取已有图集中缺少的六个图标与头像；本地复刻研究 |
| 结算晶石与装备图标 | 用户提供的结算截图，2026-10-14 | `art_source/defense/result_reference.png`、同一独立参考图标图集 | 按名称登记缺少的晶石与装备格；保留来源、裁切与SHA-256；用于布局验证，不补造生产掉落 |
| 音效与音乐 | 当前客户端音频，93 源文件合并为 89 个运行文件 | `art_source/defense/original_audio.zip`、`assets/runtime/defense/audio/` | 按原资源名索引，指纹在 audio_provenance.json |
| 阿里巴巴普惠体文件 | 同一用户提供的客户端资源 | `assets/runtime/defense/chinese.ttf` | 当前研究用途；不计入项目 MIT 授权 |
| Godot 4.7.1 | 本机外部 Godot 引擎安装 | 不随本工程附带引擎二进制 | 引擎使用其自身许可证 |

上述资源负责人为 `project_research`，资产台账登记 `third_party`。资源仅在明确更新拆解快照时重新导入，日常生成不联网、不自动追随服务器。实现代码重新编写，没有复制原商业 JavaScript。后续若公开发行，须先取得或替换所有相关第三方内容；本次未进行该项交付。

2026-10-17 雕像页新增六部位默认装备与浅蓝测试宝石图标，由内置图像生成工具按项目墨线风格生成，再经透明处理与独立切图。它们不使用用户操作参考图中的科幻装备或彩虹宝石；资产台账归属 `project_team`、`project_owned`。生成原图、实际提示词、切图参数与 QC 记录保存在 `art_source/statue_equipment/`、`art_source/statue_gem/`，运行资源位于 `assets/runtime/statue_equipment/`。雕像、背景、字体及公共导航仍沿用上表既有资源。
