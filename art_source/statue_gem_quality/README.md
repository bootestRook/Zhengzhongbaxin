# 宝石品质图标

当前版本按用户 2026-10-17 新参考收回简洁墨线风格：保留七种形状，黑色轮廓及切面分割线、大块平涂、少量白色边缘高光。品质背景保留灰、绿灰、蓝灰、紫灰、暖米灰、粉灰与淡彩差异，去掉原有深色笔刷、强反光和高饱和边框。部位角标及其底框、数量继续由场景叠加。

使用内置 image_gen，以用户截图为画风参考、上一版图板仅作轮廓参考重绘，再经 generate2dsprite 做外部色键清理、切分及缩放。没有复制参考截图像素。最终提示词：[prompt-used.txt](prompt-used.txt)；原始图：[raw-sheet.png](raw-sheet.png)；切分记录：[pipeline-meta.json](pipeline-meta.json)；生成来源及 SHA-256：[provenance.json](provenance.json)。

| 品质 | 形状 | 源图 | 运行资源 |
|---|---|---|---|
| 普通 | 三角 | quality-1.png | assets/runtime/statue_equipment/gem_common.png |
| 精良 | 菱形 | quality-2.png | assets/runtime/statue_equipment/gem_fine.png |
| 卓越 | 切角方形 | quality-3.png | assets/runtime/statue_equipment/gem_excellent.png |
| 完美 | 五边形 | quality-4.png | assets/runtime/statue_equipment/gem_perfect.png |
| 传说 | 六边形 | quality-5.png | assets/runtime/statue_equipment/gem_legendary.png |
| 绝世 | 八边形 | quality-6.png | assets/runtime/statue_equipment/gem_peerless.png |
| 至尊 | 钝角异形晶体 | quality-7.png | assets/runtime/statue_equipment/gem_supreme.png |

第八格为空白，不进入资源绑定和游戏。参数：rows=2、cols=4、cell_size=256、fit_scale=1、align=center、component_mode=largest、threshold=0、edge_threshold=230、edge_clean_depth=0、trim_border=0、reject_edge_touch=true。仅从外部连通背景清除色键，七张纹理中部均无透明孔，没有触碰原网格边界。

七张运行纹理已原位替换并完成 Godot 导入、资产清单生成与校验。背包、宝石详情与已装备列表共用这些资源，玩法及交互代码没有变化。当前实机验收见 `validation/defense/statue_page/验收.md` 的“简洁墨线宝石画风”部分。
