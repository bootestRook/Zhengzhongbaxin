# WebApp / EXE 打包与分辨率适配

这份指南只在准备导出可交付包时阅读。`project.py check` 证明工程可运行；它不证明界面已经适配目标窗口，也不代替制品验收。

## 先确认显示契约

编辑根目录的 `package_profiles.json`，确认以下内容：

1. 默认 `resolution.mode=project`，打包工具直接读取 `project.godot` 的 viewport 分辨率，不维护第二份数字。只有明确的交付要求才能改为 `special`；必须填写 `override` 和 `reason`，并先把同一分辨率应用到 `project.godot`。
2. `stretch_mode`、`stretch_aspect` 与项目实际布局策略一致。
3. 目标 profile 的输出路径、初始窗口或浏览器 Canvas 策略正确。
4. `test_resolutions` 覆盖实际支持的最小、常用、最大尺寸和全部支持方向。
5. 确认显示方案后先把 `resolution_and_mode_confirmed` 改为 `true`；在候选包中完成下方验收后，再确认布局、颜色、字体和编辑器/候选包一致性。

默认值故意为 `false`。通用脚手架不知道具体项目的目标设备，不能替用户虚构“已经适配”。

## WebApp 契约

WebApp 默认使用 `Adaptive` Canvas：画布跟随浏览器可用区域，`960×540` 只是设计基准，不是最终浏览器分辨率。固定 UI 使用 anchors 与 Containers；背景或世界内容按项目选择扩展、裁切或留边。

最终 Web 交付物固定为 `build/webapp.zip`：解压后根目录必须直接包含 `index.html`，压缩包不得超过 `100,000,000` 字节（十进制 100 MB）。工具会自动生成并检查，不接受手工挑文件压缩或外包一层 `web/` 目录。

至少验证：

- 目标桌面浏览器与移动浏览器，横屏和竖屏，以及运行中连续改变窗口尺寸。
- 最窄/最矮尺寸下无控件重叠、裁切、不可点击或文字溢出；输入、焦点、虚拟键盘和音频启动正常。
- 高 DPI、浏览器缩放、全屏切换、页面失焦/恢复、加载进度和失败提示正常。
- 性能与内存以目标移动设备为准；需要 Web threads 时另行确认安全上下文和 COOP/COEP 部署条件。
- 在 Compatibility 编辑器运行画面与候选包之间完成颜色对比；逐个 `required_locales` 验证随包字体、缺字和编码。

导出入口必须命名为 `index.html`，并与生成的 `.js`、`.wasm`、`.pck` 等文件一起部署；不得双击 HTML 代替 HTTP 环境验收。

颜色偏差、方框、缺字和乱码的固定生产链与最短排查路径见 [WEB_EXPORT_PARITY.md](WEB_EXPORT_PARITY.md)。这些项目通过后，才能确认 `color_parity_reviewed` 与 `text_and_font_reviewed`。

## Windows EXE 契约

`initial_window_resolution` 是首次启动窗口尺寸；设计基准仍由 `design.resolution` 决定。若 `resizable=true`，必须检查测试矩阵中的不同比例、拖动缩放和全屏切换；若产品只支持固定窗口，则显式改为 `false` 并同步 `project.godot`。

至少验证：

- 初始窗口、最小可接受窗口、16:9、4:3、目标最大尺寸以及目标显示器 DPI。
- 窗口缩放和全屏往返后布局、鼠标/手柄坐标、弹窗、文字和画面比例正确。
- 在干净机器或等价环境运行 EXE；检查资源加载、存档目录、权限、缺失运行库和退出流程。
- 最终签名、安装器、商店 depot、版本信息和回滚记录属于发布流水线，不由 Godot 导出成功自动保证。

## 打包门禁

先确认分辨率与显示模式并生成候选包；用候选包完成视觉/交互验收后，确认适配状态并生成最终包：

```powershell
python tools/package.py candidate webapp --godot <Godot 控制台可执行文件>
python tools/package.py check webapp
python tools/package.py export webapp --godot <Godot 控制台可执行文件>

python tools/package.py candidate exe --godot <Godot 控制台可执行文件>
python tools/package.py check exe
python tools/package.py export exe --godot <Godot 控制台可执行文件>
```

`candidate` 只要求分辨率/模式已确认；`export` 还要求候选包的布局、颜色、文字/字体和编辑器对照验收已完成。两者都会删除 `.godot/.import` 旧缓存，重新生成策划数据与资产清单，重建 release 输入指纹，用指定的同一个 Godot 可执行文件完成干净导入、完整工程检查和空目录导出。直接使用这些入口时，无需在外面先重复执行一次 `project.py check`；每次导出内部的门禁仍保留。日常修改的验证范围见 [测试方案](TESTING_AND_RELEASE.md)。导出前后源指纹不同会判废，旧 `build/`、缓存、工具和源素材目录由 preset 硬排除。

Web 会额外生成根目录含 `index.html` 的 ZIP，严格检查 HTML UTF-8、压缩包结构与 100 MB 上限；`package-manifest.json` 记录 Godot 版本、源指纹和制品逐文件哈希。缺少 export templates 时直接失败，不跳过。

导出后仍要用最终制品复跑 profile 的 `test_resolutions`，并在同一机器、同一分辨率、Compatibility renderer 下与 Godot 编辑器运行画面对照，确认内容、布局、颜色、字体、动画和交互一致。浏览器/GPU/显示器差异使跨设备逐像素相等不可保证；发布标准是不存在可感知或功能性差异，任何已知容差必须写入项目验收记录。只有制品验收通过并设置 `editor_candidate_parity_reviewed=true`，才能进入签名和上传阶段。

涉及 Godot 伸缩行为、Web Canvas 或导出参数的版本差异时，按 [OFFICIAL_GODOT_DOCS.md](OFFICIAL_GODOT_DOCS.md) 渐进查询本地官方文档；优先检索 `Multiple resolutions`、`Size and anchors`、`Using Containers` 与 `Exporting for the Web`。
