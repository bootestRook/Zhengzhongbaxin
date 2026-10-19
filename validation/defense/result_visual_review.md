# 结算视觉复核记录

2026-10-14。独立 Impeccable finish reviewer 对用户结算截图、雷电15秒录屏、游戏区域960×1920原版末帧、工程15张三档状态截图及带实际elapsed_ms的入场采样进行复核。没有运行HTML/CSS detector，原生Godot不适用。

初次 disposition 为 fix，四项 material findings：M1 详情与输入层、M2 背景暗化模糊、M3 几何/画像/字形、M4 奖励方格与图标。第一轮 M1/M2 resolved，M3/M4 partial；第二轮最终 disposition 为 ship，仅评分最后两项，均 resolved。四项列表已关闭；不构成整个游戏或严格逐帧一致认证。

- M1：三档真实窗口在持续渲染下执行暂停→退出→i→详情可见→空白关闭→确认返回主界面，暂停层保持隐藏。证据 `result_capture.log`、`result_hero_details_*`。
- M2：战场暗化模糊退到背景层，顶部及底栏不再竞争。不同冻结战场底纹不同，单点RGB不能当整图亮度契约。
- M3：撤去人工加粗后字腔恢复，960标题纯白覆盖37.1%，参考35.1%；白字范围约1像素差。确认黄面可见框(301,1627)–(672,1769)，参考(302,1627)–(671,1769)。横幅可见框(95,359)–(863,504)，参考(96,359)–(863,504)。卡片高度、画像留白与i比例已修复，三档文字可读。
- M4：灰色方格、盾形雕像、蓝紫晶石与装备格恢复对应素材，图片按语义名称登记。额外晶石/经验/装备奖励只在明确标记的布局夹具中，不生成生产掉落。

工程入口为固定 `result_panel.tscn`；没有保留旧文字结算路径。原图路径为 `result_actual_*`、`result_reference_fixture_*`、`result_empty_*`、`result_victory_*`、`result_hero_details_*`，分别含960、720、540宽。联系表在 `.impeccable/review/result_all_viewports.png`。动效采样时间由 `result_motion_times.json` 记录，不把固定采样序号当作精确播放时间。
