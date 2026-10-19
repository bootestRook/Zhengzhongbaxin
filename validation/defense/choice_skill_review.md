# 选择卡圆形技能入口

用户图1标出的圆形技能区域应查看当前候选的说明，不应招募英雄或应用强化；图2的白底黑框气泡为视觉依据。

固定入口在 `scenes/defense/choice_card.tscn`，实际命中为圆形。英雄、强化、雕像和宝箱单卡均读取当前卡片的 option 描述；宝箱中间槽映射到候选索引 0。其他卡面区域仍可确认，i 保留资料入口。查看说明不修改候选、英雄、选择历史、游戏时钟或玩法 RNG。

实际输入回归包含入场锁定、各候选切换、同图标关闭、纸面关闭并阻断穿透、空白和 Esc 关闭、刷新/候选替换/退出清理、i 资料与普通区域确认。底栏技能入口沿用已有位置和战斗继续规则。

截图由 `capture_choice_skill.gd` 通过真实鼠标输入生成，共七组乘三档：hero_0、hero_1、hero_2、upgrade、statue、chest、reference_fixture；尺寸为 960×1920、720×1440、540×1080。最后一组仅组合用户图2对应的真实英雄定义作为表现布局夹具，不提交为生产选择。总览为 `choice_skill_contact.png`。

独立视觉复核给出的 M1 为正文贴近下边框。修复仅将 choice 模式的纸高留白从 80 增为 112，气泡向上增长 32，正文区域采用实际文本高度；body 下沿、指针锚点及 roster 模式保持原值。同矩阵重拍后，复核将 M1 判为 resolved、disposition 为 ship；字形下净空在 960 档约 30–31 px、720 档约 23 px、540 档约 18 px。此 verdict 仅确认 M1，不构成整个游戏或原客户端逐帧认证。

气泡正文纹理通过语义名称 `map:tips2_paper` 绑定；裁切由源元数据的归一化派生规则生成。完整图集重排回归覆盖 26 个状态的三档截图：15 页全部反序，实际像素补边 8 px，所有精灵区域移动，页尺寸改变。78 组比较均通过，最大平均 RGB 通道误差为 0.007532；报告位于 `atlas_audit/report.json`。

最终 `python tools/project.py check` 退出 0，见 `choice_skill_project_check.log`：2678 项 Godot 断言、34 项 Python 测试，以及数据、资源、架构、导入、manifest 和运行烟测全部通过，日志无 `SCRIPT ERROR` 或 `ERROR`。该源快照的 manifest 为 575 files、90191442 bytes。
