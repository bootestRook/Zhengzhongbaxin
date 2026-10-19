# Web 导出颜色与文字一致性

这份排障指南只在 Web 候选包出现颜色偏差、缺字、方框或乱码时阅读。最终发布门禁仍以 [PACKAGING.md](PACKAGING.md) 为入口。

## 先判断是哪一类问题

| 现象 | 优先检查 |
|---|---|
| 整体光照、材质或后处理与编辑器不同 | 编辑器是否正在使用 Compatibility；Web 只能使用 WebGL 2 + Compatibility |
| 单张颜色贴图发白、过暗或过亮 | 着色器 `source_color`、材质 sRGB 设置、HDR/线性纹理处理 |
| UI 出现色块、色带、透明边或噪点 | 是否误用 VRAM 压缩、透明预乘方式是否与材质一致 |
| 桌面浏览器正常、移动浏览器错误 | profile 声明的 VRAM 纹理目标是否与素材和 preset 一致 |
| 中文变成方框或空白 | 字体缺少字形、字体没有随包导出、误用 `SystemFont` |
| 中文变成 `U+00C3`、`U+FFFD` 一类异常字符 | UTF-8 被按其他编码读取；这不是字体问题 |
| 修改后浏览器仍显示旧画面 | 浏览器缓存或旧 Service Worker；先清站点数据再判断 |

## 固定颜色生产链

1. 美术源文件使用明确的工作色彩空间；Web 交付图转换为 SDR、非线性 sRGB 的 8-bit PNG/WebP。不要把 Display-P3/Adobe RGB 数据只“指定”为 sRGB，也不要把 HDR 图当普通 UI 图。
2. UI、图标、像素画和需要精确色块的 2D 图使用 Lossless；Godot 官方文档说明 VRAM Compressed 会在低分辨率 2D 纹理上产生明显失真。相邻 `.import` 必须评审并提交。
3. 项目从开发开始就使用 `gl_compatibility` 预览 Web；不要用 Forward+/Mobile 编辑效果，再期待 Web 导出完全一致。
4. 自定义 shader 中，albedo/UI 等颜色纹理的 `sampler2D` 使用 `: source_color`；normal、roughness、metallic、height 等数据纹理不要误标。错误的线性/sRGB 转换会造成发白、过暗或过亮。
5. `BaseMaterial3D.albedo_texture_force_srgb` 只在输入确实需要强制转换时启用；错误启用会变暗，错误关闭会变亮。启用 HDR 2D 的 ViewportTexture 是线性数据，必须按实际用途转换。
6. Web 不支持 HDR 输出。编辑器对比和浏览器验收统一在 SDR、相同显示器亮度与系统色彩设置下进行；不同显示器/浏览器色彩管理无法承诺逐像素一致。
7. 在 `vram_texture_targets` 中明确声明实际目标并与 preset 保持一致。4.7 文档说明同时启用 Desktop/Mobile 会更大但更兼容；当前 preset 默认只选 Desktop。UI/精确 2D 图继续使用 Lossless；若项目需要移动 Web 的 VRAM 压缩 3D 纹理，应针对 Godot 4.7.1 建立独立 preset 并实机验证，不能只改一个开关。

## 固定文字与字体链

1. `.gd`、`.tscn`、`.tres`、CSV、JSON、HTML 和本地化源统一为 UTF-8 无 BOM、LF；打包前的 `project.py check` 会严格扫描。禁止用系统默认编码读写或用替换字符“修复”。
2. Web 不依赖 `SystemFont` 或操作系统字体 fallback。把有商业授权、覆盖 `required_locales` 的 TTF/OTF/WOFF/WOFF2 放入 `assets/runtime/`，登记 source、license、budget 和 consumer。
3. 在项目 Theme 中设置随包字体为默认字体，并显式配置 CJK、emoji 或其他脚本的 fallback。仅把字体文件复制进目录不算完成；必须存在运行时资源引用。
4. 候选包强制切换到每个 `required_locales`，逐页检查实际文案、数字、标点、换行、截断和输入框。至少包含 `中文，。！？“”《》`；方框是缺字，错误拉丁字符通常是编码损坏。
5. 自定义 HTML shell 必须保留 `<meta charset="utf-8">`。打包工具会对最终 `index.html` 严格 UTF-8 解码并检查该声明。

## 最短排障顺序

1. 清除站点缓存/Service Worker，用候选包目录通过 HTTP 启动，不双击 `index.html`。
2. 在同一台机器、同一分辨率分别截取 Compatibility 编辑器运行画面和 Chromium 候选包画面。
3. 若整体不同，先查 renderer/HDR；若只有个别素材，查源图色彩空间、`.import` 和 shader；若只有文字，先区分缺字与编码损坏。
4. Chromium 通过后再测 Firefox；Safari 只有在产品声明支持时才进入矩阵，并单独记录其 WebGL 2 差异。
5. 修复后重新生成候选 ZIP，不在旧导出目录上覆盖文件。最终确认 `color_parity_reviewed`、`text_and_font_reviewed` 与 `editor_candidate_parity_reviewed` 后才能发布导出。

## 本地官方文档依据

按 [OFFICIAL_GODOT_DOCS.md](OFFICIAL_GODOT_DOCS.md) 的方式查询以下页面，不把全文载入上下文：

- `gdd_0177_Exporting_for_the_Web.md`：WebGL 2、Compatibility、VRAM Desktop/Mobile 格式和静态文件部署。
- `gdd_0295_Overview_of_renderers.md`：切换 renderer 可能需要调整场景、光照和环境。
- `gdd_0148_Importing_images.md`：2D Lossless、VRAM 压缩失真、sRGB/HDR 与透明处理。
- `gdd_0381_Shading_language.md`：颜色纹理的 `source_color` 规则。
- `gdd_0412_Using_Fonts.md`、`gdd_1070_SystemFont.md`：FontFile、fallback、缺字及 SystemFont 平台限制。
- `gdd_0190_Internationalizing_games.md`：中文等字符集需要有对应字形的项目字体。
- `gdd_0301_HDR_output.md`：Web 不支持 HDR 输出。
