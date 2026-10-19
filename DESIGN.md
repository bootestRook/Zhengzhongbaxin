---
name: 正中靶心战斗复刻初版
description: 使用原始热更资源的竖屏自动守城界面
colors:
  primary: "rgb(100% 82% 25%)"
  primary-pressed: "rgb(87% 64% 13%)"
  disabled: "rgb(64% 63% 52%)"
  paper: "rgb(98% 96.5% 89%)"
  ink: "rgb(14% 16% 10%)"
  health: "rgb(39% 76% 23%)"
  battle-shield: "#bfc3c7"
  battle-shield-edge: "#eceef0"
  track: "rgb(18% 21% 14%)"
  home-focus: "rgb(100% 83% 24%)"
  home-experience: "rgb(0% 91% 94%)"
  home-status: "rgb(48% 76% 26%)"
  home-muted: "rgb(61% 61% 60%)"
  hud-progress: "rgb(29% 89% 96%)"
  hud-health: "rgb(63% 84% 34%)"
  hud-track: "rgb(36% 36% 36%)"
  choice-shade: "rgba(0, 0, 0, 0.63)"
  choice-roster-shade: "rgba(0, 0, 0, 0.04)"
  battle-text: "rgb(100% 100% 100%)"
  battle-ink: "rgb(0% 0% 0%)"
  report-fill: "rgb(80% 28% 28%)"
  result-progress-fill: "#fff36c"
  result-progress-track: "#ba2825"
  result-damage: "#ce4d42"
  result-taken: "#59b8e9"
  result-heal: "#70cc62"
  result-statue: "#73cbe2"
  hero-attribute-highlight: "#23812b"
typography:
  default:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "34px"
  home-level:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "78px"
  home-start:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "70px"
  home-navigation:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "48px"
  home-detail:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "31px"
  choice-title:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "46px"
  choice-skill:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "40px"
  roster-skill-level:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "32px"
  choice-tag:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "32px"
  hud-wave:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "54px"
  hud-level:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "60px"
  hud-wall:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "40px"
  battle-action:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "52px"
  battle-label:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "40px"
  battle-list-title:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "56px"
  result-title:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "100px"
  result-level:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "57px"
  result-stat:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "23px"
  result-confirm:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "90px"
  hero-detail-title:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "68px"
  hero-detail-tip-title:
    fontFamily: "AlibabaPuHuiTi-2-85-Bold_plus_dragonball_unique"
    fontSize: "48px"
rounded:
  control: "12px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
  button-pressed:
    backgroundColor: "{colors.primary-pressed}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
  panel:
    backgroundColor: "{colors.paper}"
    rounded: "{rounded.control}"
  choice-card:
    width: "292px"
    height: "860px"
  choice-skill-button:
    width: "192px"
    height: "192px"
  roster-skill-button:
    width: "78px"
    height: "78px"
  skill-tooltip:
    width: "680px"
    textColor: "{colors.battle-ink}"
  roster-card:
    width: "172px"
    height: "330px"
  monster-row:
    width: "840px"
    height: "218px"
  result-card:
    width: "203px"
    height: "303px"
  result-statue:
    width: "80px"
    height: "80px"
  result-item:
    width: "100px"
    height: "100px"
  result-confirm:
    width: "420px"
    height: "194px"
  hero-detail-panel:
    width: "852px"
    height: "1280px"
  hero-detail-portrait:
    width: "172px"
    height: "204px"
  hero-detail-skill:
    width: "84px"
    height: "84px"
  hero-detail-tooltip:
    width: "680px"
    textColor: "{colors.battle-ink}"
---

# Design System: 正中靶心战斗复刻初版

## Overview

保留用户指定的原游戏资源身份：橄榄绿色地图、白色黑描边角色、破边纸片和黄黑按钮。关卡主页以用户提供的图 2 为 1:1 复刻目标，保持顶部玩家与资源、四个侧边入口、中央首领与关卡纸片、三宝箱、下方操作和五格导航的构图；这是目标约束，不是逐像素一致的验收结论。战斗界面把主要面积留给单位和弹体。

主页保留首充礼包、排行榜、商店等参考入口；未接入的功能打开明确的本地说明。当前是离线可玩初版，未宣称所有动画或原界面逐帧一致。

英雄页与选关主页共用原有顶部玩家信息、三种资源和底部导航，只切换中间内容。上方以完整角色动作和名称展示当前选择，下方以四列纸墨卡片浏览英雄；选中与锁定属于展示状态，等级和碎片栏不代表已接入局外养成。

局外英雄二级界面沿用同一纸墨体系和用户参考结构：顶部玩家资料保持可见，灰色标题纸面中左侧为淡大头像、真实动作角色与职业／种族，右侧为基础属性及初始技能；下部为待配置升级效果和消耗，底部横向头像栏切换英雄。技能与属性说明继续使用白纸、黑框和墨线图标，不建立新的视觉身份。

局内三选一延续用户所附选择界面图 2 的破边白纸、黑边灰底角色图、灰色名条和右上角详情入口，下方使用灰白刷新纸框。按最新简化要求，强化卡移除中央圆形技能图，词条名上移到卡内 y=375，说明从 y=460 起直接显示；说明区高365、字号28、行距5，超长内容保留卡内滚动。招募卡也使用同一文字布局，正文仅显示“招募”紧接英雄名（如“招募勇者”），不展开技能效果说明；强化正文保留词条原文。种族与职业在英雄名下以24逻辑像素小字显示，技能名条与右上 i 详情保持既有行为。选卡中央没有技能图标或描述气泡。画像、名称和其他普通卡面区域确认选择，右上 i 打开顶部半透明英雄属性条。出现动效为本工程独立实现，静态参考不能证明原客户端的动效时序。

局内战场及资料浮层延续同一资源身份：中央裁切的森林、薄城墙生命条、四格纸框英雄栏，以及暂停页画像、首领白纸说明和透明深色属性/统计层。底栏画像打开“已选词条”二级面板，按英雄实例展示本局后续获得的强化词条，排除初始技能，保持名称与说明原文；相同词条合并一行，重复选取超过一次时，在名称行末显示右对齐的X数量，单次不显示。右侧头像只包含当前入队英雄，可直接切换；查看、切换与关闭均不改变暂停状态，战斗原本运行时继续运行。三选一和结算的属性入口保持原有用途；其下圆形技能在原背景上显示对应的初始技能说明，查看技能也不改变当前暂停状态。英雄等级及局外装备、宝石、符文输入保持固定基线；生命、伤害、技能等级、冷却和英雄属性来自所展示的真实状态，空槽保持空。

局内自动奖励只由精英或首领的实际击杀必定触发，排队进入转盘并暂停战斗：全屏暗遮罩保留冻结战场，上方纸色结果列表保留获得词条的原名和原文，下方十二格周边转盘只显示填充格内的既有黑白墨线技能图标，以金色标示选中奖励。中央固定显示真实来源“精英掉落”或“首领掉落”：第8、14波固定登场为精英，第20波为首领；数量滚动移至顶部状态。空库仍显示来源与“词条已全部获得”，等待关闭；三次固定登场均清理且最终首领的奖励处理完成后才胜利。该局部扩展保留森林、角色、HUD 和底栏的既有身份。

退出及胜负结算以用户所附结算截图和模拟器退出记录为依据：蓝色结束或金色胜利武器横幅覆盖模糊暗化的冻结战场，下方依次为真实进度与两精英一首领的固定登场节点、关卡与本进程最好记录、零至四名实际英雄的统计、已选雕像、已有普通奖励配置及黄色确认纸按钮。沿用既有图集、捆绑中文字体和属性层；参考中的四英雄、54%及五奖励格只是布局夹具，当前生产奖励为空时显示“未获得奖励”。

**Key Characteristics:**
- 原图集墨线、纸纹和角色轮廓决定视觉身份。
- 固定竖屏场景按同一逻辑画布等比缩放，主要面积留给战斗。
- 资料层保留所查看的战斗或选择背景，数值与当前状态一致。

## Colors

通用 token 来自 `scenes/main.tscn` 的 StyleBoxFlat；`home-*` 颜色来自 `scenes/defense/home.tscn` 的焦点、经验条和文字覆盖值。地图底色、角色、技能特效和主界面破边纸片来自原图集，不用纯色重绘替换；`paper` 只描述原生弹窗底板。绿色用于生命和通关状态，遮罩用于暂停及选择。

主页的经验条使用亮青色，排名文字使用灰色。底部导航使用原图集 `home:bg4` 纸纹并乘以 `Color(0.52, 0.53, 0.52, 1)`，保留破边纸面，避免放射线纹理。英雄或战斗页签选中时向上突出，显示白色纸片、对应原图集图标和黑字；未选时恢复白字黑描边。不要把整条导航替换为无纹理的纯色块。

战斗 HUD 的进度、城墙生命和底槽分别使用 `hud-progress`、`hud-health` 和 `hud-track`。三选一的上部战场与底部英雄栏使用 `choice-shade` 和 `choice-roster-shade` 分层遮罩，英雄栏保留更清晰的纸片轮廓。卡纸与名条沿用图集纹理并作小幅颜色调制；`paper` 不是三选一卡纸的替代底色。

战斗资料层的白字和墨线使用 `battle-text` 与 `battle-ink`，首领纸面、底栏及候选技能气泡内部使用无描边黑字。贡献条使用 `report-fill`，只表示本局英雄输出的相对长度；它不是通用主操作色。各浮层按用途使用深色透明底，不能用通用 `paper` 替代森林、画像、空符文槽或首领的既有纹理。

自动宝箱奖励沿用黑白墨线技能图标、纸色结果行与金色选中边框。转盘未选格为深色墨绿底与灰边，移动高亮为浅金底与亮边，已获格为既有纸色与金边；结果行保持深色无描边正文。颜色来自 `reward_row.tscn` 与 `reward_slot.tscn` 的实际样式，只用于该奖励组件，不扩展为通用品质配色。

结算横幅的青蓝结束、金色胜利和武器轮廓来自 `battle:bg1/bg2`；转动光晕来自 `battle:smallLight`。结算进度采用 `result-progress-fill` 与 `result-progress-track`，英雄三行统计依次使用 `result-damage`、`result-taken`、`result-heal`；这些条长分别是该英雄在本队对应统计总量中的占比，与贡献浮层的最高输出比例分开。雕像的青色圆底使用 `result-statue`，黑边和内部图标保留现有资源身份，不把这组结算颜色推广成全局战斗配色。

局外英雄属性说明的数值强调使用 `hero-attribute-highlight`。在本批实际截图白纸采样色 `#f9f9f7` 上对比度约4.69:1；白纸采样值是资源验证依据，不替代图集纹理或建立通用背景 token。

闪电刺客的刺杀与刀扇使用偏紫电光（#bf6cff）、深紫外缘和淡白亮芯；感电受击染色使用较浅的紫色（#cb9be8）。保留原图集的黑色墨线与技能轮廓，电弧只强化落点和范围伤害反馈。烟幕保留既有金黄（#ffe45b）烟团，置于角色和电光下层，轻微扩散并在后段平滑淡出。表现节奏读取战斗时间，暂停时冻结，倍速时同步；透明度在绘制时应用，相同帧与颜色共用缓存。

## Typography

界面文本使用中文，共用 `assets/runtime/defense/chinese.ttf`。Theme 默认 34 逻辑像素，各节点在场景中覆盖字号。字族文件名含 Bold，字体内部样式标签为 Regular，不额外推断 CSS 字重。不得用系统字体冒充已捆绑字体。

主页关卡标题和开始按钮使用黑字，侧边标签使用白字黑描边。开始按钮的字形由固定 `LetteringEdge` 与 `Label` 两层叠加：底层黑字带 8 逻辑像素黑描边，上层黑字带 4 逻辑像素白描边，形成黑字、白色内轮廓和黑色外轮廓。主页关卡、开始、导航和细节字号分别由前置 token 记录；玩家昵称为 39、通关状态为 40、系统提示为 29 逻辑像素。其他描边保持区分：导航标签为 7、玩家昵称为 6、资源数字为 2；纸片内部黑字不加描边。

三选一英雄名、技能名、种族/职业标签使用 `choice-title`、`choice-skill`、`choice-tag`；英雄名与技能名为白字、10 逻辑像素黑描边，标签为黑字。技能名字号以上限 token 为起点，按捆绑字体的实际字宽收缩到 224 逻辑像素内，长名保持完整。英雄等级为 32 逻辑像素黄字、5 逻辑像素黑描边，当前真实基线均为等级 1。刷新标题为 44，剩余次数为 28；强化卡的内嵌说明为 28。招募候选与底栏技能描述气泡都使用同一捆绑字体，默认 36 逻辑像素，只有实际换行高度超过各自可用高度时逐点缩小，最低 28；正文宽 598，保持无描边黑字。

HUD 波次、关卡与城墙数值字号分别使用 `hud-wave`、`hud-level` 和 `hud-wall`。前两者采用白字与 6 逻辑像素黑描边，城墙数值采用白字与 5 逻辑像素黑描边。

暂停的退出/继续和首领纸面标题使用 `battle-action`；前者为白字、7 逻辑像素黑描边，后者为无描边黑字。`battle-label` 用于伤害显示、英雄名称、展开属性数值、技能等级与宝石数值；英雄主属性数值为 44，等级为 38，输出/治疗/承伤摘要为 28。怪物列表标题使用 `battle-list-title` 与 7 逻辑像素黑描边，说明沿用默认字号与 5 逻辑像素黑描边。贡献标题为 38、英雄名称为 32，均有 4 逻辑像素黑描边，输出数字为 21。精英/首领说明为 40 逻辑像素无描边黑字，按纸面内宽自动换行；其 -8 行间距仅属于此说明组件，不建立通用排版尺度。

结算标题、关卡、统计及确认分别使用 `result-title`、`result-level`、`result-stat`、`result-confirm`，实际黑描边分别为 4、5、2、7 逻辑像素，不增加人工加粗字体层。历史记录为 29 逻辑像素、5 像素黑描边；统计右对齐，达到 1000 时用两位小数的 `k` 简写。奖励标题沿用 `battle-label`，数量为 29、4 像素黑描边；参考夹具中经验角标为 15，不能据此宣称生产有经验发放。

自动奖励继续使用捆绑中文字体：标题64逻辑像素、8像素黑描边，状态及底部操作提示32，中央来源“精英掉落”或“首领掉落”为48。纸色结果行的名称32、正文24、行距4，为深色无描边字；转盘格只显示技能图标，不显示词条名。这些是奖励组件的局部排版值，不替换全局字号尺度。结算固定登场节点的分类标签使用24逻辑像素白字、4像素黑描边；暂停画像的精英/首领标签保持38号、3像素黑描边，怪物列表标签保持40号、5像素黑描边，均沿用原紫色旗标。

**The State-backed Numbers Rule.** 招募候选英雄读取定义基线和零统计；强化的 i 按 offer.owner 匹配已入队英雄的运行时 id，读取该英雄当前属性、已学技能和统计，不预先应用候选；英雄等级统一读取基线。不得为静态参考伪造等级、160 攻击、48 防御、装备或符文角标。

局外英雄二级界面主标题使用 `hero-detail-title` 与10逻辑像素黑描边，等级60、主属性值52；基础属性、初始技能及升级效果标题40，职业／种族36，碎片30。两类纸面说明标题使用 `hero-detail-tip-title`；技能正文37、属性正文36，均为无描边黑字。升级列表使用灰色文字，等级待配置29、效果待配置34；消耗32。以上均沿用捆绑中文字体，是本组件实值。

## Layout

逻辑画布 960×1920，桌面初始窗口 720×1440，canvas_items + keep 保持纵横比。没有响应式断点或移动平台导出验收；缩放后的逻辑像素不等于屏幕物理像素。

主页骨架在 `scenes/defense/home.tscn`，由 `scenes/main.tscn` 实例化。顶部左侧放玩家纸片与头像，右侧纵向排列体力、钻石、金币；活动和首充礼包在左侧，更多和排行榜在右侧。首充礼包的黑色标签底片宽 164，覆盖完整四字标签。中央关卡纸片为 680×830，首领站在纸片上缘的石台上；首领显示区域为 240×200，左上角为 (375, 415)，水平中心 495 与石台一致，脚底基线为 615。关卡标题下依次为通关状态、排名、人数栏和三只宝箱。左右箭头切换前 50 关，点击关卡标题打开关卡列表。

开始按钮为 461×215，位于扫荡和领地之间。其下为三行系统提示，底部五格依次是商店、英雄、战斗、雕像和锁定项；英雄与战斗按当前页切换向上突出的选中态。所有尺寸与坐标为逻辑像素，不通过运行脚本拼装或重排固定结构。主页已留存 720×1440 和 540×1080 原生截图；这两种缩放不建立新的断点规则。

固定布局在 `.tscn`。战斗上方为暂停、倍速、波次与关卡，下面是进度条、统计和宝石属性入口；中部战场；下方城墙与四英雄栏。关卡列表和英雄页的英雄卡使用动态条目，其容器骨架固定。

英雄页由 `home.tscn` 的 `HeroPage` 实例承载，顶部位于全局 y=180；`home_heroes.tscn` 固定角色区、名称、滚动容器和锁定提示，顶部头像、昵称、编号、玩家等级、经验及三种资源继续使用共用节点。角色区为局部 (30, 0, 900, 630)，名称位于 y=635；没有石盘或动作选择按钮。四列滚动区为局部 (24, 756)..(950, 1484)，列距18、行距20，动态 `home_hero_card.tscn` 最小尺寸210×352。视口底边全局 y=1664，保留至选中导航图标顶边 y=1671 的间隔；滚到末尾时最后一行完整卡片及种族栏位于导航之上。720×1440 和540×1080仍为同一逻辑画布等比缩放。

**The Named Atlas Binding Rule.** 所有界面按名称绑定当前图集索引。主页 TextureRect 在 `.tscn` 中保存 `resource_key`，由 `DefenseAtlasSprite` 在启动时绑定纹理和光纹 UV；头像和六个补充图标也纳入同一索引。战斗、选择及资料层通过 `DefenseAtlas` 按名称绘制；内部纸框和按钮表面使用管线按当前尺寸生成的命名子区域。场景及表现脚本不得保存图集页路径、切图坐标或旧 UV 范围，图集重排不需要重建场景。规则与回归见 ADR-0006。

战场森林绘制区域为 (0, -446, 960, 2368)，蒙版为 (0, -10, 960, 1940)，底栏纹理从 y=1534 开始。中央雕像位于 (451, 1400)，以 1.6 倍显示。领域坐标统一平移 (-320, -97) 后绘制单位、弹体和战斗文字；表现投影不改变领域坐标。城墙生命条覆盖全宽，位于 y=1537、高 28。四个 `roster_card.tscn` 固定实例的左上角为 (30, 1590)、(258, 1590)、(486, 1590)、(714, 1590)，尺寸由 `components.roster-card` 记录。

战斗资料的固定容器与点击区在 `scenes/defense/battle_panels.tscn`。暂停画像为 200×200 的三列两行，x=130/380/630，y=436/666；上排普通怪，下排按第8、14、20波的固定登场顺序显示两名精英和一名首领，不足三个的配置隐藏对应画像。退出与继续纸按钮各为 280×100，y=910；伤害显示开关位于 (330, 1125)。首领说明白纸绘制区域为 (108, 758, 744, 369)，纸内交互区域为 (110, 760, 740, 365)；标题、分隔线和正文均收在纸内，正文区域为纸内 (34, 202, 641, 143)，保留右侧内边距。

英雄属性层在画布顶部，折叠/展开高度分别为 391/735；九个空槽从 (37, 94) 开始，槽宽 94、横向步进 98。展开属性分四列，行数为 5/5/5/4，列步进 212、行步进 56；右侧 80×80 的箭头随状态移到 y=292/632。贡献浮层为 (143, 208, 349, 395)，内部使用动态 324×79 条目；怪物列表的滚动区域为 (70, 190, 840, 1300)，条目尺寸由 `components.monster-row` 记录，关闭横向滚动。宝石属性保留雕像与三项主属性，下方七条固定基线说明从 (65, 630) 开始，每条 840×87、纵向步进 92。固定控件不由代码创建，贡献与怪物列表的真实动态条目可由代码实例化。

三选一的固定骨架在 `scenes/main.tscn`，三张卡片实例化同一 `scenes/defense/choice_card.tscn`。在逻辑画布上，三卡左上角分别为 (22, 328)、(332, 328)、(642, 328)，宽高由 `components.choice-card` 记录；刷新纸框为 230×156，左上角 (365, 1237)。选择时领域战斗停止，纸卡保持并列。每张 `choice_card.tscn` 内固定 `Skill` Button 的矩形为 (50, 371, 192, 192)，实际鼠标命中由 `_has_point` 限定为该矩形内接圆；圆外区域仍由普通卡面处理。已留存 960×1920、720×1440 和 540×1080 的原生截图；这些等比缩放不是自适应断点或移动平台验收。

自动奖励固定骨架在 `scenes/defense/reward_panel.tscn`，结果行由 `reward_row.tscn` 动态实例化，十二个 `reward_slot.tscn` 为固定实例。结果滚动区位于 (80, 304, 800, 706)，关闭横向滚动；行间距18、最小行高126，正文按实际换行撑高。下方转盘位于 (80, 1080, 800, 472)，144×144 的十二格沿五列三行的周边排列，步进164；中间固定 `Source` 文本框从 (280, 1244) 到 (680, 1396)，按快照显示真实来源；数量滚动与已定数量放在顶部 `Status`，底部提示位于 y=1644。960×1920、720×1440 和540×1080沿用同一画布等比缩放，不建立新断点。

结算固定骨架在 `scenes/defense/result_panel.tscn`。横幅为 (45, 119, 870, 429)，进度容器为 (125, 574, 740, 127)；三个固定登场节点按第8、14、20波放置，下方在组件内以24逻辑像素白字、4像素黑描边依次显示“精英、精英、首领”；击杀盖章逐波查询冻结的 `encounters_cleared`，乱序击杀也只标记对应波次，不按击败数量顺序推断。关卡居中于 y=728，历史记录位于右侧 (742, 705, 168, 86)。英雄排从 y=815 开始，按实际人数整体居中，卡间距 17；零英雄显示“未招募英雄”，不补空卡。雕像排在 y=1119，间距 10；奖励标题在 y=1248、条目在 y=1353，间距 12。确认点击区左上角为 (270, 1606)，各组件宽高由前置 token 记录。只有真实英雄、雕像和奖励条目动态实例化，场景不按屏幕宽度另行重排；三档渲染继续是同一逻辑画布的等比缩放。

局外英雄二级界面的固定骨架在 `home_hero_details.tscn`，覆盖同一960×1920画布；遮罩从 y=180 开始，保留共用顶部HUD。主纸面左上角为(54,188)，尺寸由 `components.hero-detail-panel` 记录；横向头像滚动区为(54,1490,852,220)，头像间距16。无关闭X；点击主纸面和头像栏以外区域返回，点击纸面或头像栏内部不关闭。展开属性纸面为(16,402,928,526)，上排三项基础属性，下排四列、行数5/5/5/4，列步进210。技能说明位于(234,807)，宽度由 `components.hero-detail-tooltip` 记录，高度取 `max(320, 正文最小高度 + 220)`，不裁断长文。属性说明为680×420，定位在所点图标下方24逻辑像素，X限制在20..260，三角指向该图标。720×1440与540×1080仍为同一画布等比缩放。

## Elevation & Depth

原生面板依靠深色边框、色块和遮罩建立层级，没有通用模糊阴影系统。地图和原始纸片自身的绘制阴影属于图片内容，不应额外套用投影效果。候选技能气泡另有固定场景序列化的局部阴影：透明 StyleBoxFlat、黑色 0.35 alpha、shadow_size 16、偏移 (8, 12)，仅用于这一说明纸面。

主页使用地图、地图暗纹和局部光纹三层图集内容。光纹使用 0.84 的 alpha 调制；`home_light.gdshader` 先通过 `shader_parameter/atlas_region` 将整页图集 UV 转换为光纹区域的局部 UV，该参数由光纹矩形除以图集页面实际尺寸得到，再由 `local_uv.x` 驱动横向衰减：中部与左侧乘以 0.40，向右经 smoothstep(0.52, 0.80) 过渡到原强度。中部与左侧的组合 alpha 系数为 0.336，保持橄榄地图，右侧保留更亮光纹。关卡纸片、首领石台和开始按钮依靠已有墨线与图片中的阴影形成前后关系；底部导航的黑色上沿和白色战斗纸片形成选中层级。

三选一在遮罩上方放置三束白色光束，纸卡再覆盖其上；光束由 `choice_beam.gdshader` 形成柔和边缘和上下渐隐，入场时渐显。角色脚下使用扁椭圆阴影，纸边与名条保留图片自身的墨线，不添加通用模糊卡片投影。

暂停以 `battle_blur.gdshader` 采样背景的 2.4 级 mip，并将 RGB 乘以 0.24；这是保留底层战场和三选一卡片的全屏模糊暗化，不是卡片投影。战斗资料层位于 HUD 与三选一之上。英雄属性顶部使用 0.57 alpha 的黑底，三项主属性块使用 0.6；贡献底为 0.66，怪物行底为 0.64，宝石全屏遮罩为 0.58、说明行底为 0.63。它们是各组件的实值，不合并成未实现的统一阴影或遮罩 token。

自动奖励层为 `z_index = 60` 的全屏覆盖，背板使用 `Color(0.025, 0.03, 0.02, 0.86)` 暗化冻结战场并拦截输入。纸色结果行与金色转盘选中态建立前后关系，结果按序淡入；没有地面品质光柱或中间纸卡光束。

结算使用 `result_blur.gdshader` 采样冻结战场的 2.5 级 mip，并将 RGB 乘以 0.16。结算层 `z_index = 4`，英雄资料层位于其上；场景同级节点顺序也按这个视觉层级排列，保证资料层空白关闭区接收输入。进入结算时关闭暂停及其他资料，重复快照不能再覆盖结算；这只是结算背板与资料层的契约，不建立通用阴影系统。

局外英雄二级界面使用0.68 alpha黑色遮罩，只遮暗顶部HUD以下区域；主纸面沿用 `common:heroInfo2Bg`，展开属性与两类说明沿用 `common:textBg_Box`。大头像为0.12 alpha水印，其上显示独立角色动作；不使用角色全身图替代淡头像。纸面墨线和层叠顺序建立深度，不新增模糊卡片投影。

## Shapes

原生弹窗面板描边 5、Theme 默认按钮描边 4、默认进度底槽描边 3 逻辑像素；这些默认 StyleBoxFlat 的圆角均为 12。原图集的破边纸片保持原轮廓，不用统一圆角卡片代替。

主页按钮使用透明 StyleBoxEmpty 承载图集图像，不能沿用弹窗按钮的圆角和边框。主页键盘焦点另用 3 逻辑像素的黄色矩形描边，不改变图片轮廓。

三选一卡片同样使用透明 StyleBoxEmpty，破边白纸与灰底黑框来自原图集。圆形技能区域使用黑色轮廓，英雄卡下方两行白底黑框标签分别承载种族与职业图标；强化和雕像卡在该区域展示可滚动的技能说明。暂停、倍速和刷新图集先按实色边界裁去透明留白，再填入固定目标矩形，不能把精灵原始尺寸当成可见轮廓尺寸。

四英雄栏沿用 `map:choice3` 的 214×246 纸框与 `map:skillBg3` 的圆形技能底，空英雄格保留底栏纹理并禁用。英雄详情九槽使用冻结的 `gem:mpt` 和 `gem:5_0` 空槽资源，保留切角、渐变和旗形；该形状不代表已装备符文。首领说明使用冻结的 `common:panel2_variant2` 白纸纹理，普通怪及精英画像使用既有浅色森林底，首领使用深色山洞底；精英和首领共用既有紫色旗标背景，并按真实身份显示标签。不得以纯色圆角卡片替换这些轮廓。

转盘格为直角方框，以未选、移动高亮和已获三种边框区分状态；格内不显示词条名，既有技能图标填充边框内的 `Rect2((6, 6), size - (12, 12))` 区域；结果行使用直角纸色底板与金色描边，左侧保留现有墨线技能图标，右侧显示名称和原文。它们是 `reward_slot.tscn` 与 `reward_row.tscn` 的独立组件，不复用三选一的画像、名条、圆技能入口或中间纸卡映射。

结算英雄卡沿用 `battle:DPSBG` 的黑白矩形统计框与 `map:choice3_inner` 的灰色放射纹画像底，右上角 `i` 为独立 37×37 点击区。MVP 冠标来自 `battle:icon_mvp`，仅挂在本局最高输出英雄左上角。雕像为青底黑边圆形；普通奖励沿用 `common:iconBg`，参考装备格保留原截图裁切的完整边框。确认按钮使用 `common:btnYello_Shadow` 破边黄纸，不套用通用圆角面板。

局外英雄二级主纸面的九切片边距为左66、右66、上132、下66，灰色标题区必须保持在纸面顶部，不能延伸覆盖等级与基础属性。初始技能按钮与技能说明头部均叠加 `gameIcon:skillbg` 圆形底板；横向头像采用黑框、灰底和金色选中边，不显示选中勾。

## Components

原生弹窗按钮普通与 hover 同色，pressed 变深，disabled 降低色彩明度。此类按钮未定义按压位移或 Tween；静态截图不证明完整键盘焦点流。

主页图像按钮普通与 hover 保持原图；按下时整体乘以 `Color(0.76, 0.76, 0.76)`，松开或移出恢复白色调制，无按压位移或缓动。主页按钮使用上述黄色 focus 描边。首关的上一关与第 50 关的下一关禁用并变暗，底部锁定项禁用；不要把这组局部状态描述推广成所有战斗控件的交互契约。

主页首领读取当前关卡 `encounters` 中 `kind = boss` 且波次最大的条目，以对应资源的 idle 动画置于石台；切换资源时汇总该动画所有裁切帧的最大可见宽高，使用统一缩放比例，每帧水平居中并贴住同一脚底基线，避免随帧改变体量。放大镜展示同一最终首领资料，说明第8、14波为精英、第20波为首领。三宝箱读取关卡的首通奖励配置，点击展示内容并说明尚未接入局外发放。开始按钮进入实际英雄选择和战斗；英雄页签显示英雄页，战斗页签返回选关主页，关卡标题打开关卡列表。英雄页无其他浮层时 Esc 返回选关主页。旧整页 `GalleryPanel` 与 `hero_item.tscn` 已移除。

玩家昵称、编号、等级、经验和资源数值当前是图 2 的静态参考值。通关状态、宝箱勾记与人数栏由本次运行的最近结果及 `result_level` 驱动：当前关卡与成功结果一致时显示已通关，城墙满血且无英雄死亡时显示完美通关，否则为等待挑战。人数栏目前仅为 0 或 1，不代表在线通关人数；排名显示暂无。不能据此推导永久存档、玩家经济或全服统计。首充、商店、扫荡和排行榜入口分别说明当前未接入的服务。

点击底栏已入队英雄画像打开已选词条面板，保留运行中的战场；右侧头像切换英雄，长列表支持滚动，点击外侧空白或Esc关闭。重复项合并并在名称右侧显示X数量，属性仅从三选一卡片和结算的既有入口查看；点击画像下的圆形技能只查看对应说明，不主动暂停。Esc 优先关闭当前资料或技能气泡，没有浮层时可暂停/继续。暂停及结算始终有退出入口；自动宝箱奖励层的点击只跳过动画或关闭当前展示。表现读取快照，不修改领域状态。

### 局外英雄展示与四列卡片（2026-10-17）

英雄列表读取当前目录的18名英雄，先按 `available_heroes()` 顺序列出已开放的五名（1、2、4、13、17），再按 ID 升序列出其余英雄。初始选中第一名可用英雄；点击可用卡片更新选择并打开局外英雄二级界面，关闭后保留当前角色、名称及金色边框。未开放卡片的画像与种族图标置灰，叠加暗层和锁图标，仍可点击并显示1.6秒“还未解锁”，不改变当前选择。卡片按下变暗，松开或移出恢复；键盘焦点使用3逻辑像素白色描边，与主页其他按钮的黄色焦点区分。

卡片固定包含职业图标、画像、黄色 `Lv:1`、碎片进度条及 `0/14`、描边英雄名、种族图标与名称，不含九宫格。卡片文字沿用捆绑中文字体，等级44、英雄名34、种族32、碎片数量27逻辑像素；上方英雄名60。全部英雄等级显示1，`0/14` 仅为初始展示，碎片来源、获取、升级与局外存档尚未接入；这一显示不改写等级、属性或领域状态。

角色使用既有图集，按待机2秒 → 完整普攻一次 → 待机2秒 → 完整技能一次循环。动作采用源帧时长，跨动作所有帧共用可见范围和缩放；切换英雄重置循环，页面隐藏后停止角色处理。浏览选择仅保存在表现层，不决定局内招募，不修改战斗快照、规则时钟或玩法 RNG。固定骨架保留在 `.tscn`，代码仅实例化真实英雄卡列表。

### 局外英雄二级界面（2026-10-17）

从已解锁英雄卡进入，点击主纸面和头像栏外空白，或无说明浮层时按 Esc 返回英雄页；只有英雄页没有覆盖层时 Esc 才返回选关主页。横向栏沿用18名目录英雄、先五名可用再按ID排列的顺序，选中仅显示金框并滚动到可见位置；锁定头像置灰、暗层与锁保留，点击显示1.6秒“还未解锁”，不切换英雄。头像和技能按钮按下调制0.76，松开或移出恢复；固定按钮焦点为3逻辑像素白框，不宣称完整键盘焦点流已验收。打开详情时暂停底下英雄页的角色处理，关闭后按页面可见性恢复；详情角色复用既有待机、普攻、待机、技能循环。

主纸面左侧淡底使用对应 `gameIcon:heroHead{id}_new` 大头像，其上显示真实动画本体，下方为职业／种族。右侧三项基础值和展开面板读取 `hero.base`；信息按钮切换属性纸面，基础与展开属性图标均可打开名称、当前值、说明和“基础”来源。当前生命恢复按实际每1秒说明，未参与战斗计算的属性明确说明现状。初始技能按钮按 `initial_options` 动态实例化，五名可用英雄目前各一项；图标、标题和描述来自同一实际 option，不补造第二技能。参考中的装备格、雷达和下方页签改为升级效果列表及消耗；本二级页不出现装备九宫格、石盘或动作选择器。

技能说明、展开属性与单属性说明按顶部优先收起：单属性说明打开时，外部点击／Esc只关闭它；下一次再关闭展开属性。技能说明打开时关闭属性层，信息按钮切换属性时关闭说明；外部点击用于收起后必须消费输入，不能同时选择背后的英雄、技能或底栏。切换英雄和关闭详情清除所有说明。

**The Home Hero Definition Rule.** 局外英雄二级界面只读所选英雄的定义基础值和 initial_options 原文，不推算截图中的升级收益、雕像或玩家等级加成。等级保持1，碎片保持0/14；升级等级、效果及金币／碎片消耗显示待配置，升级按钮禁用。浏览、切换和说明开关不修改领域状态、规则时钟或玩法 RNG。

### 战场与四英雄栏

英雄纸框内角色以 idle 动作显示；生命条读真实 hp/max_hp，初始技能图标下的数字读同技能组强化等级，扇形暗面读真实 cooldown/total。暂停和三选一不推进领域冷却。死亡英雄变暗，并显示复活秒数；空队伍格不画画像、生命或技能，不提供无效按钮。

死亡动作结束后的墓碑在单位上方、HUD下方绘制，保留原墨线素材并增加金色描边、脚下光环和半透明光柱。墓碑上的倒计时数字移除，底栏画像中的复活秒数保留。现有灵魂素材作为“复活之源”从光柱上方匀速下降至墓碑；位置使用死亡后已过时间占完整复活时长的比例，包含死亡动作，直接跟随10秒或20秒战斗时钟。领域复活时，灵魂收缩融入墓碑并闪光，光圈向外散开，墓碑轻微下沉并与光柱在600毫秒内淡出；余光留在原死亡位置。复活与底栏倒计时仍在原截止时刻完成，出生点的既有复活特效继续播放。所有等待和淡出效果均在暂停时冻结、倍速时同步加速，退出或重新开局清除。

英雄卡根节点为 Control，固定 `Portrait` 与 `Skill` 两个 Button 分别负责画像资料和圆形技能说明：画像点击区为 (0, 0, 214, 246)，技能点击区为 (68, 236, 78, 78)。技能旁的空白不触发画像资料。按下画像时在画像矩形、按下技能时在对应圆形叠加 0.15 alpha 黑底；两个入口的 focus 均为 4 逻辑像素黄色描边，不推广为所有控件的键盘验收。

普通怪满血时隐藏生命条，受伤后显示；英雄生命条持续显示，护盾环仅在领域 shield 大于零时出现。动作、弹体与事件表现读取真实快照，中央裁切或 UI 动画不能决定规则结果。

护盾在原生命条内接在生命值段后方，以银灰填充、浅灰上沿和深色分隔线区分；头顶和底栏共用同一表现。获得或增加护盾时闪亮并扫光260毫秒，吸收伤害导致护盾减少时轻闪140毫秒，稳定后不循环。动效读取战斗时钟，暂停时冻结；护盾耗尽或目标死亡立即清除，条长始终读取真实剩余量。参考英雄联盟血条提示护盾生效的设计原则，具体色值和时长属于本项目实现。

成功确认强化卡后，从所选词条名条中心释放该词条的黑白图标及灰色圆底，400毫秒内沿向上拱起的弧线缩小并飞向所属英雄，落点随英雄当前站位移动。抵达时复用既有金色召唤光圈并散开8颗星屑，500毫秒后清除。已阵亡英雄的词条飞往其底栏画像；查看资料、招募和被拒绝的选择不触发。飞行是独立表现，不延迟词条生效，不消耗玩法随机；手动暂停时冻结，退出、结算或新局时清除。依据为当前雷电原游戏中血族亲王“血狂”的选择录像及只读资源、时长参数核对，详见`validation/defense/choice_transfer/findings.md`。

### 两名精英与一名首领的固定登场

每局三次固定登场为第8波精英、第14波精英、第20波首领，读取显式 `encounters` 记录；原单位资源、技能及生命攻击配置保留。固定精英使用原固定登场成长，普通波内精英保留原额外成长。真实身份传递至奖励、暂停资料、怪物列表和结算节点，固定精英死亡不增加普通波击杀经验。清理状态用 `encounters_cleared` 按实际固定波次记录，三个节点均清理且奖励处理完毕后才能胜利；不再使用 `boss_waves`、`level.bosses` 或 `bosses_dead` 旧路径。该分类仅更新既有界面的标签及状态，不更换角色资源、布局或视觉世界。

### 局内自动宝箱与转盘奖励

只有精英和首领的实际击杀必定触发一份奖励，普通怪不触发，也不消耗掉落随机流。每份队列票据及快照保留真实 source，中央据此显示“精英掉落”或“首领掉落”。掉落自动排队，升级、指定英雄奖励及手动暂停期间延后打开；进入 reward 阶段冻结战斗时钟。最终首领同样发奖，三次固定登场均按真实波次清理且全部排队奖励关闭后才生成胜利结算；雕像归零仍优先失败并清空队列。有合法词条时先按50∶30∶15∶5的权重确定获得1、2、3、4项，再从已招募英雄当前合法、未达次数上限的词条中逐项抽取；同次不重复，每应用一项后重新检查前置。没有0项档位，候选不足给完剩余合法不同项。空库仍暂停显示来源及“词条已全部获得”，不抽数量、不伪造奖励，等待点击关闭。固定登场为第8波精英、第14波精英、第20波首领，奖励来源依次为“精英掉落、精英掉落、首领掉落”；普通波内原有精英仍真实参与精英掉落规则。具体规则以 `docs/DEFENSE_CHEST_FIDELITY.md`、ADR-0024 及 ADR-0025 为准；normal_chance 已移除，源规则严格 schema5，生成目录严格 schema11。

**The Granted Reward Display Rule.** 有合法词条时，当前奖励开始由领域通过命名 `defense.loot` 随机流完成抽取并一次性入账；空库不抽取。表现只读取这一奖励的编号、真实来源与结果。当前奖励的播放、跳过和关闭均不重新抽取当前奖励；关闭后打开下一份排队奖励时，才按正常规则处理下一份。reward 阶段冻结战斗时钟，关闭必须匹配当前奖励编号，旧编号与重复输入不能关闭后续奖励。旧拾取 Intent、地面箱字段、预抽单项、同品质替换、拆箱和单卡映射已移除。

有奖励词条时，顶部状态先用0.85秒滚动数量，中央来源保持固定，再逐项沿十二格周边转盘移动高亮，每项0.9秒，以 `1 - (1 - progress)^3` 三次曲线减速停靠；对应结果在0.18秒内淡入并从0.96倍恢复原尺寸，最后一项停靠后保留0.3秒结束时间轴。界面以0.15秒渐显，表现位置排列使用独立 `defense.reward.visual` 随机流，不消耗玩法 RNG。顶部结果名称保留英雄名与原始词条名，正文直接读取原始 Definition，不改写用户词条；长文在结果区滚动阅读。

动画期间点击空白或结果区立即展示全部结果，第二次点击关闭；自然播放结束后点击即可关闭。空库提示直接处于展示完成状态，一次点击关闭。Esc、空格、回车遵循同样的跳过/关闭行为。滚动拖动不视为点击，遮罩阻断向暂停和英雄按钮穿透。多个掉落依次处理，各有独立编号；新局、重试和结算清理队列及展示状态。转盘不可刷新、不消耗每局刷新次数，也没有三选一卡面确认或英雄 i 入口。

### 初始技能说明气泡

四个底栏技能入口共用 `scenes/defense/skill_tooltip.tscn` 的固定气泡，按点击英雄定义的 `initial_option` 读取对应 option 的 `description`，只显示该技能说明。`show_skill` 不提交 pause Intent：正常战斗继续推进规则时钟，原有手动暂停和三选一阶段保持原状态。点击另一个技能切换说明，点击同一技能、纸面、纸外空白或 Esc 关闭；这些动作不重建候选。打开画像资料、提交其他 Intent、返回主页或进入结算时关闭气泡。

气泡使用同一捆绑字体的无描边黑字和智能换行，默认字号为 36 逻辑像素，纸宽 680，正文宽 `WIDTH - 82`（598）。纸高按 Label 当前换行后的实际最小高度向上取整再加 80；若高度超过技能按钮顶部减 2 再减 `TOP` 的可用高度，字号逐点缩小到最低 28，并按每次字号重新测量。正文区域从 (28, 22) 起、高为纸高减 68。`TOP = 1584`，纸面 Y 为 `max(TOP, 技能按钮顶部 - 8 - 纸高)`：纸面逻辑顶边不早于 1584，当前可用英雄说明的逻辑底边保持在技能按钮顶部之前，避开城墙生命数值并保持技能圆可达。X 限制在 12 至 `960 - WIDTH - 12`（268）之间。气泡固定 `z_index = 8`，在四英雄栏与选择背景前显示，不增加全屏遮罩。白纸沿用 `map:tips2` 的 StyleBoxTexture 九宫纹理，左/右/上/下边距为 24/48/20/60；黑边浅色几何三角指向当前圆形技能，没有新增位图。上述数值只属于此气泡组件，不扩展为通用字号、间距或断点。

### 选择卡统一文字布局

招募和强化共用 `choice_card.tscn` 的 `TermName` 与 `Description/Text`：技能名条保持既有内容，正文读取当前 offer 的 `description`。招募正文为“招募”紧接英雄名（如“招募勇者”），不展开技能效果说明；强化正文继续使用词条原文。词条名位于y=375..440；说明区位于(26, 460)，宽240、高365，字号28、行距5，保留智能换行和超长内容滚动。招募的种族与职业以单行 `Traits` 小字显示在y=343..375。 宝箱奖励使用独立转盘与结果行，不进入此选择卡路径。

已删除选卡专用的圆形技能按钮、重复技能名、双图标标签及候选描述气泡路由；卡片本身不设置原生悬浮提示，避免遮挡旁边的说明。卡片画像与词条名确认选择，右上i读取英雄属性；阅读和滚动说明不提交选择。底栏已入队英雄的技能说明气泡保留，候选变化不会改变其暂停契约。

### 暂停、画像与精英/首领说明

暂停保留并模糊底层选择，不取消候选、不重播选择入场，底层选择输入被锁定。固定六画像按本关冻结怪物配置显示；下排三张依固定登场顺序标记“精英、精英、首领”，MonsterPortrait 及 MonsterRow 读取真实 kind，沿用既有紫色旗标背景、捆绑字体与描边。点击画像打开对应说明，点击纸框外或 Esc 关闭说明并返回暂停。退出/继续使用既有红色纸按钮；伤害显示复选状态即时控制飘字显示，未定义弹窗入场或按压 Tween。

### 宝石属性与英雄属性

宝石入口仅在三选一阶段显示。宝石层的生命读取当前 wall_max，攻击、防御与七项加成为当前固定局外基线的 0/0%；没有动态装备系统，也不将参考图的加成伪装成已接入。点击背景或 Esc 关闭此层，保持当前候选。

选择卡右上 `i` 复用固定 `BattlePanels/Hero` 顶部半透明属性条：招募候选显示英雄定义基线、初始技能和零输出/治疗/承伤；强化及其他有主英雄选项按 `offer.owner` 匹配 `current.heroes.id`，显示该英雄当前属性、已学技能和真实统计，不预先应用候选。没有所属英雄的全队雕像隐藏 i，仍可通过圆形技能入口查看描述。底部已入队英雄的 `Portrait` 画像按钮打开本局属性，并在打开前保存暂停状态，关闭后恢复。其下 `Skill` 圆形按钮使用独立的初始技能说明气泡，不进入英雄属性的暂停路径。顶部依次为种族/职业、名称、基线等级、已有技能、九空槽、生命/攻击/防御和输出/治疗/承伤；展开箭头显示十九项额外属性，图标与数值使用同一属性 ID，收起/展开没有新增 Tween。已入队资料随快照更新，招募候选资料保持定义基线；顶部属性条折叠/展开仍为 391/735 逻辑像素，展开箭头、纸外空白和 Esc 关闭沿用既有交互。选择卡 i 打开前关闭技能气泡，经阶段、暂停、busy 和索引检查；入场及确认期间锁定，查看和关闭不提交选择、不应用候选，不改变候选、历史、玩法 RNG、规则时钟或原暂停状态。旧整页 `SkillPanel/SkillTitle/SkillText/SkillClose` 场景及 `view.close_hero` 路由已删除。卡片的 Info 控件和 i 图像只在存在英雄数据时显示，提示为“查看英雄属性”；不为截图假造外部养成。

### 贡献度与本关怪物列表

左侧柱状图开关贡献度，空队伍只保留标题；有英雄时按实际累计输出降序显示头像、名称、输出数字和红条。红条以当前队伍最高输出为 100%，不能解释为总伤害占比。怪物入口开关本关列表，固定登场的两名精英及一名首领在前、普通怪在后，按资源去重并读取本关冻结名称与说明；它不是当前存活怪物清单。两个浮层都不主动暂停对局，可再次点击入口或 Esc 关闭；条目是动态实例，容器骨架固定。

原始角色动作按图集帧时长播放；部分动作反向循环与击中时序仍待精确校对，不记录未实现的缓动规则。

### 退出与胜负结算

`DefenseResult` 在 finish 时冻结真实进度、固定登场记录及逐波清理状态、英雄和三项统计总量、MVP、已选雕像及普通奖励配置；胜利进度为 100%，退出或失败为当前已完成波次与当前波进度的总比例。历史记录读取 `DefenseSession` 持有的该关最好进度，仅在当前进程内保存。MVP 按最高输出选出；统计条按本队对应总量计算，零总量显示零长度，不借用参考数值。

本工程入场时序为：遮罩 200 毫秒淡入；青色光晕从 100 毫秒起用 600 毫秒渐显至 0.5 alpha；横幅从 120 毫秒起由 0.6 倍以 500 毫秒 `TRANS_BACK / EASE_OUT` 回弹至原尺寸，另用 180 毫秒淡入。进度从 650 毫秒开始用 450 毫秒增长至冻结值，关卡与历史从 800 毫秒渐显。英雄从 1000 毫秒开始逐卡错峰 80 毫秒，透明度 200 毫秒、0.85 倍到原尺寸 250 毫秒，统计在 600 毫秒内计数；MVP 从 1650 毫秒渐显。雕像从 1550 毫秒、奖励从 1800 毫秒渐显，各 250 毫秒。确认从 1000 毫秒渐显，1250 毫秒解锁；按下时乘以 0.78 的颜色调制，松开恢复，focus 为 3 逻辑像素黄框。时长来自本工程代码，实机录屏只支持出现顺序和持续动作，不证明逐帧一致。

结算期间英雄继续使用独立表现时钟播放 idle，青色光晕以每秒 0.35 弧度转动；领域战斗不再推进。重复快照不重播入场，状态退出、确认和节点退出停止 Tween。`i` 打开所点击英雄的本局属性与技能，纸外空白或 Esc 关闭后仍为结算；确认只提交 `home` Intent，返回主页。

**The Frozen Result Receipt Rule.** 结算只呈现 finish 已冻结的事实，不由计数动画、奖励图标或布局夹具生成掉落。生产 50 关普通 reward 数组均为空，因此显示“未获得奖励”；尚未接入的首次奖励、服务器随机掉落、局外库存及跨启动最好记录不能在界面中补造。已支持的普通配置资源按明确名称绑定，未知引用由数据编译拒绝。

三选一普通卡面区域提交选择，圆形技能独立显示当前候选描述，右上角 `i` 独立打开对应资料，不触发选卡；招募候选显示基线属性，强化显示所属英雄的当前属性和统计；全队雕像隐藏 i，圆形技能仍可查看描述。确认时锁定卡片、技能、详情与刷新输入，选中卡短暂放大至 1.035 倍，另外两卡透明度降至 0.28；130 毫秒后只提交一次 `choose` Intent。按下纸卡时 90 毫秒缩至 0.975 倍，松开恢复；卡片与详情入口具有 4 逻辑像素黄色 focus 描边，但未据此宣称全界面键盘焦点流已验收。

入场遮罩淡入 180 毫秒。首卡延迟 80 毫秒，后两卡依次错峰 100 毫秒；每卡从低 64 逻辑像素的位置、0.82 倍缩放和透明状态进入，位移 340 毫秒、回弹缩放 380 毫秒、淡入 180 毫秒。卡后光束从 100 毫秒起渐显 450 毫秒，刷新纸框从 400 毫秒起淡入并恢复缩放，整轮约 660 毫秒后解锁。刷新读取真实剩余次数、耗尽时禁用，并重播入场；刷新纸框的按下图像下移 3 逻辑像素。

暂停或详情返回同一轮候选时不重播入场。退出选择、取消或候选变化会停止旧 Tween，避免旧确认回调提交新一轮选择。英雄、强化和雕像选项均沿用现有领域快照及 Intent，不由动效生成规则结果。源客户端左上白色角标由已装备符文数量大于 0 决定；本工程基线没有装备符文，因此隐藏，不能将其当作首卡或某英雄的固定装饰。

### 新版五英雄单初始技能（2026-10-16）

沿用纸墨界面、现有角色资源、中文字体和960×1920逻辑画布。五个底槽位置保持不变，每名英雄只显示当前的一项初始技能。勇者/火法师/德鲁伊/寒冰射手/闪电刺客的名称、种族和职业标签读取定义；元素与普攻动作后等待时间进入属性摘要；当时的图鉴正文属于旧界面记录，现已由局外英雄页替代。

底栏画像点击区仍为(0,0,172,198)。单技能按钮左上角为(47,206)，78×78，在卡片中水平居中；等级标签位于(90,254)，39×43。真实冷却遮罩、按下反馈和空槽禁用保留，删除第二技能节点。

此前的招募、强化卡共同使用原192×192技能按钮(50,371)及224×53名称区域(34,589)。技能名按40逻辑像素上限适配实际字宽。卡面选择、圆形说明和右上详情入口保持独立，气泡操作不选择、不消耗随机数、不改变暂停状态。 该技能按钮布局属于统一文字布局前的记录，当前选择卡以“选择卡统一文字布局”为准；宝箱已改为独立转盘奖励。

旧图鉴的种族、职业、位置、元素、等待时间及技能长文动态行已随 `GalleryPanel` 移除，当前英雄页使用上述四列卡片。上方战斗属性条在主属性下显示元素、位置、攻击方式和基础等待时间；沿用深色半透明底。

当前规则见 `docs/DEFENSE_HERO_ROSTER.md`，源表为 `data/source/defense/hero_roster.json`；此前双技能审核记录仅属于历史快照。

### 已穿戴装备二级详情

雕像页上方六个已穿戴槽位打开居中单张纸卡，沿用 0.65 黑色遮罩、捆绑中文字体、墨线装备图标和浅蓝宝石。蓝紫渐变标题区显示名称、已装备标记、部位；下方“宝石属性／装备属性”二级页签以黄色标示当前项。宝石页固定五条米色槽位行，已占用行显示绿色“卸下”，空槽保留占位文字且不显示操作；装备页沿用同一卡框，当前显示“暂无附加属性。”。

卸下立即归还同一颗宝石到背包，装备保持穿戴，剩余宝石维持相对顺序，槽位行与计数同步更新。空白或 Esc 关闭，离开雕像页清除浮层。背包装备仍进入左当前、右候选的独立替换卡，不与已穿戴入口混用。固定骨架在 `equipment_worn_dialog.tscn` 和 `equipment_socket_row.tscn`，本次沿用现有资产，不增加锻造、装备卸下、宝石锁定、异能编码或属性效果。

## Do's and Don'ts

- 局外英雄二级界面保留灰标题纸面、淡大头像和动作本体、职业／种族、实际基础属性及初始技能、底部横向头像栏；说明按最上层优先收起并阻止点击穿透。
- 不把局外英雄的0/14、待配置效果或消耗做成已实现养成，不用全身图替代淡头像，不遗漏技能圆底，也不让灰标题覆盖正文。

- 保留原资源的黑白角色、草绿色战场、黄黑操作层级。
- 主页对照图 2 保持纸片、首领石台、头像、资源图标及五格导航的比例和层级。
- 三选一保持固定破边纸卡、灰底角色、圆技能图、种族/职业双标签、独立技能说明与详情入口及灰白刷新纸框。
- 战场对象共用同一投影，英雄栏保留真实生命、技能等级、冷却及空格状态；自动奖励界面使用固定画布坐标。
- 自动宝箱奖励保留全屏暗遮罩、上方可滚动纸色原文结果、下方十二格无名称的填充墨线图标转盘与金色选中态；中央保留真实精英/首领来源，动画只展示当前奖励已发放的结果。
- 底栏画像与技能入口保持独立；底栏技能说明读取对应初始 option，候选技能说明读取当前卡片 option，切换和关闭保留原暂停与候选状态。
- 选择卡 i 只查看所属英雄的顶部属性条；招募候选用定义基线，强化用本局当前值，全队雕像隐藏 i，不预先应用候选。
- 暂停保留当前选择背景；首领说明保持纸内边距，属性图标与数值使用同一属性 ID。
- 通过固定场景调整界面，动态代码只创建列表和战斗对象。
- 记录第三方来源，遵守 `THIRD_PARTY.md` 的内容边界。
- 结算按实际零至四英雄整体居中，进度、固定登场节点、统计、MVP、雕像和奖励均读取同一冻结结果；空奖励保留“未获得奖励”。
- 不把截图验收扩大为全部技能、动画、分辨率或平台验收。
- 不添加没有实际实现的焦点、动效和自适应承诺。
- 不把静态参考资源值、最近一局结果或本地说明入口写成已实现的经济、存档或在线服务。
- 不为模仿选择截图伪造英雄等级、符文角标或广告状态，也不把静态参考写成原客户端动效时序的证据。
- 不将候选技能圆点击当作确认，不将候选词条描述替换为已拥有英雄的初始技能，也不将描述气泡的表现夹具提交为生产选择。
- 不伪造 160 攻击、48 防御或局外宝石/符文加成；参考中的快捷键气泡属于模拟器标记，不纳入游戏。
- 不把结算参考夹具的四英雄、54%、金币、宝石、经验和装备当成生产掉落，也不把本进程最好进度写成永久存档或账户历史。

- 不把历史落地箱及单卡复核当作当前转盘验收，也不把本次转盘截图或专项检查扩大为全游戏、原客户端逐像素或逐帧认证。

2026-10-16两精英一首领分类依据：ADR-0025、`defense_units.gd` 的 `create_encounter`、`defense_spawn.gd`、`defense_damage.gd`、`defense_result.gd`、`defense_battle_panels.gd`、`defense_monster_portrait.gd`、`defense_monster_row.gd` 与 `defense_result_progress.gd`。原生证据为 `validation/defense/two_elites_one_boss/{pause,wave_8,wave_14,wave_20,victory}_{960,720,540}.png`，共15张，并复制至 `.impeccable/review/two_elites_one_boss/`。`tests.log` 记录171项领域/界面专项断言、0失败；`capture.log` 记录16项原生输入/采集断言、0失败。夹具通过公开工厂、真实死亡接口与 Viewport 点击覆盖暂停标签、三次奖励来源和关完奖励后胜利，不代表自然完整对局抽样；完整工程检查以主线程最终源状态日志为准。 独立 finish reviewer 结论见 `validation/defense/two_elites_one_boss/review.md`：disposition 为 ship、无 material fixes，仅覆盖本次固定登场分类及直接相关的标签、奖励来源与逐波结算节点；不扩大为自然整局、整个游戏或原客户端逐帧认证。

**固定登场分类的历史边界。** 以下既有批次中“三位首领”、下排三张首领画像、三个首领节点及其旧计数的截图或验收，只对应 ADR-0025 之前的历史分类。保留全部原截图、断言数和审核结论；当前身份及逐波盖章以第8、14波精英和第20波首领为准，不把旧证据改写为新分类的验收。

主页依据：`scenes/defense/home.tscn`、`defense_home.gd`、`defense_home_boss.gd`、会话快照及 `validation/defense/home_level3_720.png`、`home_reference_540.png`。原始图集沿用既有资源；补充的六个图标与金发头像从 `art_source/defense/home_reference.png` 提取，来源登记在 `THIRD_PARTY.md`。同尺寸对照保存在 `.impeccable/review/hero-repro.png` 与 `reference-game.png`。本节记录当前实现，不宣称 1:1 已验收，也不沿用旧界面的视觉复核结论。

2026-10-17 英雄页依据：`scenes/defense/home.tscn`、`home_heroes.tscn`、`home_hero_card.tscn` 与对应 `defense_home.gd`、`defense_home_heroes.gd`、`defense_home_hero_card.gd`、`defense_home_hero_actor.gd`、`home_hero_locked.gdshader`。当前原生截图位于 `.impeccable/review/hero_page/`，包含 `heroes`、`locked`、`roster_bottom`、`battle_home` 四组的 `_720.png` 与 `_540.png`，共8张；`validation/defense/hero_page/capture.log` 通过329条真实输入、状态、动作顺序及截图断言，`atlas.log` 通过572条共用主页与动态卡片图集重排断言。首次复核的M1末行种族栏遮挡已修复，重拍同批8张后评分 resolved、disposition 为 ship；该结论限于M1及直接视觉回归。完整执行范围与早期失败说明见 [英雄页验收](validation/defense/hero_page/验收.md)。本次未运行全量 `project.py check`、未导出，不把浏览界面或占位进度视为碎片养成、全游戏或原客户端逐像素/逐帧认证。

三选一与 HUD 依据：`scenes/main.tscn`、`scenes/defense/choice_card.tscn`、`defense_choice_panel.gd`、`defense_choice_card.gd`、`defense_choice_refresh.gd`、`defense_hud.gd`、`choice_beam.gdshader`、ADR-0003 及 `validation/defense/choice_reference_findings.md`。当前原生静态构建留存于 `choice_reference_960.png`、`choice_reference_720.png`、`choice_reference_540.png` 和 `choice_statue.png`；动效时长依据本工程代码，截图不能证明原客户端逐像素或逐帧一致，也不能替代最终完整检查。

此前主页与三选一批次的完整 `python tools/project.py check` 通过 980 条断言与 16 项管线测试，日志无 `ERROR`、`SCRIPT ERROR` 或 `FAIL`。该记录属于当时的源状态，不替代后续工程检查。

战场与资料层依据：`scenes/main.tscn`、`scenes/defense/battle_panels.tscn`、`roster_card.tscn`、`monster_portrait.tscn`、`monster_row.tscn`、`contribution_row.tscn`，以及对应 `defense_field.gd`、`defense_hud.gd`、`defense_view.gd`、`defense_roster_card.gd`、`defense_battle_panels.gd` 和行/画像表现脚本、`battle_blur.gdshader`、ADR-0005。资产沿用当前已冻结且有 provenance 的既有资源，本次没有 AI 新图。

本批原生截图位于 `validation/defense/`：战场为 `battle_reference_720.png`、`battle_reference_960.png`、`battle_reference_540.png`；其余九组为 `pause_reference`、`boss_details`、`gem_attributes`、`hero_details_collapsed`、`hero_details_expanded`、`owned_hero_details`、`contribution_empty`、`contribution_live`、`battle_monsters`，每组含默认 720 宽以及 `_960`、`_540` 文件，共 30 张。截图经真实视口鼠标链生成，数值为实际状态；这三档等比渲染不建立响应式断点或移动平台验收。

此前战场与资料层批次修复后的检查快照通过 1088 项 Godot 断言、18 项 Python 测试及资源、架构、manifest、烟测；鼠标链覆盖资料打开/关闭、候选保留、已入队英雄暂停恢复、属性展开、贡献度/怪物开关、伤害显示和退出。该批最终 `python tools/project.py check` 与紧接着的 `python tools/release_manifest.py check` 均退出 0，该批源指纹下的资源、架构、import、manifest 和烟测通过；后续并行源更新可能使该验证失效，不将历史快照写成永久认证。`battle_visual_review.md` 的四项修复及已发现纸框回归全部 resolved，ship 仅覆盖这些修复项及其回归，不代表整套界面全范围重审，也不认证严格逐像素 1:1、原客户端动效时序或全部机制一致。

底栏技能说明修复依据：`scenes/defense/roster_card.tscn`、`scenes/defense/skill_tooltip.tscn`、`defense_roster_card.gd`、`defense_skill_tooltip.gd`、`defense_view.gd`、`tests/test_defense_battle_ui.gd`，以及 `validation/defense/skill_tooltip_review_packet.md` 和 `skill_tooltip_visual_review.md`。原生截图为 `skill_tooltip_battle`、`skill_tooltip_right`、`skill_tooltip_choice` 三组，每组含 `_720.png`、`_960.png`、`_540.png`，共 9 张；纸面采样、高度和生命数值避让修复后的同矩阵重拍已替换旧截图。没有新增产品位图，截图仅为此入口和气泡的验证证据。

本轮行为检查快照曾通过 20136 项 Godot 断言，真实鼠标链覆盖四槽描述、战斗规则时钟继续推进、同槽关闭、跨槽切换、纸面/外部/Esc 关闭、候选保留、已有手动暂停和画像属性行为。上一轮共享工程完整检查见 `validation/defense/effects_fix_final_check.log`：2299 项 Godot 断言、28 项 Python 测试及资源、架构、manifest、烟测均通过；初始大魔导师特效测试的目标夹具已由并行战斗修复纠正。紧接着的 `release_manifest.py check` 通过（该快照 552 files，90102036 bytes）。最新回归修复新增全部 17 个可用英雄初始说明的生命数值避让、技能圆可达及字号不低于 28 的测试。主代理完成的该技能说明回归修复源快照 `python tools/project.py check` 退出 0：2350 项 Godot 断言、28 项 Python 测试及数据、资源、架构、import、manifest、运行烟测全部通过；该快照 manifest 为 552 files、90102376 bytes。第二次视觉 verdict 已确认生命数值 3900 遮挡和位置文档笔误 resolved，remaining clear，disposition 为 ship；该 ship 严格限定所评分的三项修复及其生命数值遮挡回归、文档同步和本批直接回归。各次工程通过仅对应各自源快照，不把本批限定 ship 扩大为整套界面认证、全部描述的逐图视觉认证、严格逐像素 1:1 或原客户端机制认证。

2026-10-16精英/首领奖励修正依据：ADR-0024、`defense_loot.gd`、`defense_reward_panel.gd`、`defense_reward_slot.gd` 与固定 `reward_panel.tscn`、`reward_slot.tscn`。原生证据为 `validation/defense/elite_boss_rewards/{elite,boss}_{spin,result}_{960,720,540}.png`，共12张，覆盖两种来源与三档窗口。来源来自公开工厂构建夹具后的实际精英/最终首领死亡，并通过真实跳过、关闭输入确认最终奖励结束后才胜利；它们不作为自然完整对局或所有词条效果的证明。`tests.log` 记录236项专项断言、0失败，`capture.log` 记录12张原生截图与最终首领奖励先于胜利；完整工程检查以主线程最终源状态日志为准。沿用既有墨线图标、中文字体、纸色结果和金色选中态，没有新视觉世界或产品位图。

历史2026-10-16自动宝箱转盘初版依据（普通/精英概率、最终首领跳过奖励、中央数量、格子名称和空库不弹约定已被 ADR-0024 替代）：`scenes/defense/reward_panel.tscn`、`reward_row.tscn`、`reward_slot.tscn`、`defense_reward_panel.gd`、领域 `defense_loot.gd`、`PRODUCT.md`、`docs/DEFENSE_CHEST_FIDELITY.md` 及 ADR-0022。原生截图为 `.impeccable/review/roulette_results_960.png`、`roulette_results_720.png`、`roulette_results_540.png`、`roulette_count.png`、`roulette_spinning.png` 与 `roulette_count_1_result.png` 至 `roulette_count_3_result.png`。`validation/defense/reward_roulette/tests.log` 记录209项专项断言、0失败；`capture.log` 记录真实输入跳过再关闭、结果及 RNG 保留，并覆盖1至4项的8张截图。数量覆盖使用显式领域夹具，不作为自然对局连续抽中全部档位的证明；完整工程检查以该次最终源状态的实际日志为准。没有新增产品位图或独立视觉世界。

**历史验收边界。** 以下落地箱批次及后续旧批次中的宝箱技能圆、i 属性、中间槽和单卡确认记录，均只对应当时源快照，已被2026-10-16自动转盘规则替代；保留旧断言数、截图、ship结论及其局限，不作为当前宝箱实现或永久认证。

历史落地宝箱校正依据（已被2026-10-16自动转盘规则替代）：`docs/DEFENSE_CHEST_FIDELITY.md`、`defense_chest_visual.gd`、`defense_field.gd`、`defense_view.gd`、`defense_choice_panel.gd`、`defense_hud.gd` 与领域 `defense_loot.gd`，以及当时客户端的 `equipBox` 组件及掉落/领取脚本。用户提供的蓝色落地宝箱原图是该历史批次的固定视觉依据，未建立新视觉世界、概念图或 seed。三档原生截图为 `.impeccable/review/chest_ground_540.png`、`chest_ground_720.png`、`chest_ground_960.png` 和 `chest_reward_540.png`、`chest_reward_720.png`、`chest_reward_960.png`；归一化原图局部对照为 `validation/defense/chest_source_comparison.png`，实际摇摆帧证据为 `chest_hover.gif` 与 `chest_hover_contact.png`。

历史落地宝箱源快照的专项检查见 `validation/defense/chest_capture.log`，通过 80 条断言；完整 `python tools/project.py check` 见 `validation/defense/chest_project_check.log`，通过 2540 项 Godot 断言、33 项 Python 测试及数据、资源、架构、import、manifest、运行烟测，日志无 `SCRIPT ERROR` 或 `ERROR`。该检查快照的 manifest 为 573 files、90163911 bytes。`chest_visual_review.md` 的 disposition 为 ship、无 material fixes，范围覆盖本次完整落地宝箱大小、品质光柱、待机/悬浮与冻结、预抽奖励、失效替换/拆箱及单卡确认路径。奖励页视觉按既有纸卡体系及源脚本中间槽拓扑判断；宝箱飞入、扬尘和开盖过程尚未逐帧验收。以前的主页、三选一、战场资料和技能说明检查保留为各自源状态的历史，不能将本次 ship 扩大为整个游戏或全部原客户端掉落动画一致。 以上通过数、ship及旧实现文件仅保留当时源快照的证明；落地拾取、品质光柱、预抽/替换/拆箱和中间单卡均已移除，不再是当前规范。

结算依据：`scenes/defense/result_panel.tscn`、`result_card.tscn`、`result_item.tscn`、对应 `defense_result_*.gd`、`result_blur.gdshader`、领域 `defense_result.gd`、`defense_session.gd`、`defense_battle_panels.gd` 和 ADR-0007。用户结算图保存为 `art_source/defense/result_reference.png`；实际退出录屏及末帧为 `validation/defense/result_reference_motion.mp4` 与 `result_native_reference_960.png`，记录第 2 波、6%、两英雄与未获得奖励。金币、属性、雕像等沿用命名图集；`resultReference:crystal/equipment` 为该用户图的精确裁切，由 `tools/defense_reference_icons.py` 登记源图及裁切 SHA，纳入当前 15 页、7586 个命名精灵的索引。本批没有 AI 产品位图。

三档原生证据为 `result_actual_960/720/540.png`、`result_reference_fixture_960/720/540.png`、`result_empty_960/720/540.png`、`result_victory_960/720/540.png`、`result_hero_details_960/720/540.png`，总览为 `.impeccable/review/result_all_viewports.png`。actual 来自真实固定步战斗、真实选项与退出输入；fixture 的四英雄、54%和五奖励格仅复核用户截图布局，额外经验/装备未进入生产奖励。empty 与 victory 分别覆盖零英雄退出和领域胜利接口；三档缩放不代表新增响应式断点或移动平台导出验收。图集重排回归移动全部 15 页中的所有精灵并改变页尺寸，比较 23 个状态的三档截图。

本批独立视觉复核的最终 disposition 为 ship：初轮 M1/M2 与后续 M3/M4 四项列明修复均 resolved。该结论只覆盖这四项修复及所评分回归，不是整个游戏的 1:1、完整结算页全范围重审或原客户端动效逐帧认证。最终工程检查记录在 `validation/defense/result_project_check.log`，其结果以主代理完成日志为准；此前通过的 2611 项 Godot 断言快照不替代最新资源与文档源状态的完整检查。

选择卡技能入口修复依据：`scenes/defense/choice_card.tscn`、`scenes/defense/skill_tooltip.tscn`、`defense_choice_skill_button.gd`、`defense_choice_card.gd`、`defense_choice_panel.gd`、`defense_view.gd`、`defense_skill_tooltip.gd`、`tools/defense_pipeline.py`，专项回归为 `tests/test_defense_choice_skill_ui.gd`、`tests/test_defense_chest_ui.gd` 和 `tests/test_defense_battle_ui.gd`。真实鼠标链由 `validation/defense/capture_choice_skill.gd` 执行，原生截图前缀为 `choice_skill_hero_0/hero_1/hero_2/upgrade/statue/chest/reference_fixture`，每组含 960×1920、720×1440、540×1080，共 21 张，总览为 `choice_skill_contact.png`。reference_fixture 只使用真实英雄定义 9、8、1 校对用户图 2 的布局，不将该组合提交为生产选择；其余截图覆盖实际候选和宝箱路径。专项输入检查覆盖圆形命中、入场锁定、描述来源、切换、同图标/纸面/空白/Esc 关闭、纸面阻断穿透、候选更换与退出清理、i 资料及普通卡面确认，查看过程不修改领域状态。

本批独立视觉复核见 `validation/defense/choice_skill_review.md`：M1 正文贴近下边框已通过增加候选模式留白并重拍同矩阵解决，最终 disposition 为 ship；960 档实际字形下净空约 30–31 px、720 档约 23 px、540 档约 18 px。该结论只确认 M1 及本批所评分回归，不改写此前审核，也不代表整个游戏、严格逐像素 1:1 或原客户端逐帧认证。最新图集重排报告 `validation/defense/atlas_audit/report.json` 在历史 23 状态批次上扩展至 26 状态：15 页全部反序、实际像素补边 8 px、所有精灵区域移动且页尺寸改变，三档共 78 组比较、0 失败，最大平均 RGB 通道误差为 0.007532。

主代理完成的当前选择技能源快照 `python tools/project.py check` 退出 0，记录于 `validation/defense/choice_skill_project_check.log`：2678 项 Godot 断言、34 项 Python 测试及数据、资源、架构、import、manifest、运行烟测全部通过，日志无 `SCRIPT ERROR`、`ERROR` 或 `FAIL` 标记；该快照 manifest 为 575 files、90191442 bytes。此新批记录保留其源快照边界，不替代此前审核结论，也不作为后续源修改的永久认证。

选择卡 i 属性入口修复依据：`defense_view.gd.show_choice`、`defense_choice_card.gd`、固定 `BattlePanels/Hero`、`tests/test_defense_choice_info_ui.gd` 与 `tests/test_defense_chest_ui.gd`。当前热更 `GameLogic.js` 的 `onInfoIconClick` 只在存在英雄数据时打开 AttributeTips，作为界面类型和入口边界的静态证据，本工程未复制其实现。真实鼠标回归覆盖三名招募候选、两名真实所属英雄、真实强化 902 后的当前属性、打开 i 时关闭技能气泡、展开/关闭、候选与历史及规则时钟/暂停/RNG 保留、宝箱中间槽的 owner 映射。专项 `validation/defense/choice_info_tests.log` 通过 2721 项 Godot 断言，无 ERROR 标记。

本批 `validation/defense/capture_choice_info.gd` 通过真实鼠标保存 candidate、upgrade、expanded、chest 四组，每组含 960×1920、720×1440、540×1080，共 12 张 `choice_info_*` 截图，总览为 `choice_info_contact.png`。截图使用真实大魔导师 id 3 的早期状态，不注入参考的 13257/220/475 数值或已学技能组合。独立新复核已逐张查看全部 12 张截图及两张用户图，五节完整、无 material fixes，disposition 为 ship；720 档折叠条下缘为 293 px，与参考一致。该结论仅覆盖 i 入口及直接回归，审核依据见 `validation/defense/choice_info_review.md`，不扩大为整游戏或严格逐像素认证。当前图集回归以 `upgrade_attributes` 替换过时的 `skill_details` 状态，26 状态、三档共 78 组比较均通过，最大平均 RGB 通道误差为 0.007532；历史选择技能批次记录保持原值。

主代理完成的本批 i 属性入口源快照 `python tools/project.py check` 退出 0，记录于 `validation/defense/choice_info_project_check.log`：2721 项 Godot 断言、34 项 Python 测试及数据、资源、架构、import、manifest、运行烟测全部通过，日志无 `SCRIPT ERROR`、`ERROR` 或 `FAIL` 标记；该快照 manifest 为 575 files、90189825 bytes。该记录仅对应本批源快照，保留此前审核与检查的历史值。

2026-10-14 体验优化：保留现有纸卡、图集、字体与配色。HUD采用五个172宽英雄槽，圆形技能按钮保留78宽；等级宝石显示1到20，波次用中文显示当前/20。结算采用五个168宽动态英雄卡，保留统计及MVP，移除雕像词条区域。原生三档验证及当前边界见 docs/DEFENSE_EXPERIENCE.md。

2026-10-14 招募混抽：开局三张招募卡，升级每卡位25%招募/75%强化，不再绑定波次或等级；满五人后只出强化。每张offer的kind决定卡面、初始技能/候选强化、i属性和确认，外层upgrade不决定整组卡型。复用固定纸卡的Level标签显示“招募/强化”，招募保留种族与职业标签，强化保留正文；未增加固定UI节点或产品位图。刷新重新混抽并排除上一组仍可用的招募候选，宝箱中间槽与指定奖励只出强化。三档真实混合卡片、属性和胜利截图及输入证据见 validation/defense/mixed_recruitment/，详细规则见 docs/DEFENSE_CHOICE_RULES.md。

历史2026-10-15 双初始技能依据（其中图鉴及动态行高已由2026-10-17英雄页替代，以下断言、截图和审核仅对应当时源快照）：`docs/adr/0012-defense-two-initial-skills.md`、ADR-0012、`roster_card.tscn`、`choice_card.tscn`、`defense_roster_card.gd`、`defense_choice_card.gd`、`defense_view.gd`、`defense_skill_tooltip.gd` 与 `defense_battle_panels.gd`。三档原生原图位于 `.impeccable/review/two_skills/`：recruit、recruit_second、battle、attributes、second_1、second_2、second_4、second_13、second_17、gallery 共十组、30 张；总览不替代原图。独立复核记录在 `validation/defense/two_skills/visual_review.md`，结论为 ship、无 material fixes，仅覆盖双技能界面、图鉴双描述行高及直接回归。`capture.log` 通过 92 条鼠标/布局断言；满编战场是公开工厂创建真实实例并执行战斗的视觉夹具，合法完整对局属于独立领域证据。强化/宝箱的单候选分支本轮经代码复核，未在新矩阵重做整页视觉审查。Godot 原生界面没有运行 HTML/CSS detector；该视觉结论不认证整个游戏、原客户端逐像素/逐帧一致或移动平台导出。主代理完成的本批最终运行源快照 `python tools/project.py check` 退出 0，日志为 `validation/defense/two_skills/project_check.log`：5971 项 Godot 断言、44 项 Python 测试及 import、架构、数据、资源、release manifest、运行烟测通过，无 `SCRIPT ERROR` 或 `ERROR` 标记；该记录仅对应本批源快照，不改写历史审核或永久认证后续修改。

2026-10-16 寒冰词条：复用既有纸卡、字体、名称栏、说明滚动及顶部属性入口。招募显示400多重射击，后续强化显示401至409实际文案，底栏同步星辰之箭名称与图标。箭雨以已有箭矢图集和冰青范围表现半径180，动画只读取战斗时钟和快照。验证见`validation/defense/ice_terms/`。

2026-10-16 技能距离预览：底栏圆形技能保留短按说明，按住0.4秒在角色脚下显示淡红透明圆形填充和红色流动虚线，松开、拖出、死亡、失焦或离开战斗即清除。距离读取技能快照，不使用嘲讽、爆炸、箭雨等效果半径。圆形表示距离上限，交战区、冷却及动作规则继续约束实际出手；预览在单位下方绘制，保留既有森林、墨线角色与HUD。

2026-10-17 雕像页：复用现有主页背景、玩家资料、资源条和五项主导航，作为内容页签切换。上部只放雕像、战力占位条与右侧二列三行装备；下部为背包、部位筛选、宝石/装备分类。背包装备详情为左当前、右候选的两张独立卡，右卡底部替换；宝石详情为左详情卡、右侧五条竖排镶嵌行。普通宝石详情不遮暗全屏，满孔点击镶嵌后才显示0.65黑色遮罩与“请选择要替换的宝石”，空白/Esc只取消选择，普通详情再次空白/Esc关闭。装备和宝石图标为新制墨线、白灰盔甲与浅蓝晶石，保留粗黑描边和纸卡体系，原始生成图、提示词与切图记录在 art_source/statue_equipment、art_source/statue_gem。固定结构保存在 home_statue、equipment_item、equipment_detail_card、equipment_dialog 场景，只有背包项动态实例化。实际状态、真实输入及三档窗口截图位于 validation/defense/statue_page；装备无附加属性，宝石无实际效果，战力未接入公式。

2026-10-17 已穿戴装备详情补充：按用户参考在现有纸墨风格内实现单卡二级页签及逐颗卸下，入口区别见上述组件记录。六张原生截图位于 `.impeccable/review/statue_worn/`，副本位于 `validation/defense/statue_page/`，覆盖 720×1440、480×960、960×1920 的宝石、装备属性、部分卸下及全空状态。`worn_visual_review.md` 结论为 ship、零 material fixes，仅覆盖本轮局部扩展和已捕获尺寸；`worn_verify.log` 记录 324 项、0 失败、6.70 秒，包含真实鼠标／键盘卸下路径及原流程回归。未运行 HTML/CSS detector、完整工程检查或平台导出，不扩大为全游戏认证。

2026-10-17 局外英雄二级界面依据：`scenes/defense/home_hero_details.tscn`、`home_hero_portrait.tscn`、`home_hero_skill.tscn` 及 `defense_home_hero_details.gd`、`defense_home.gd`、`defense_home_heroes.gd`。用户指出的大头像、技能圆底及灰标题重叠已修正。原生截图为 `.impeccable/review/hero_details/{detail,attributes,skill_1,skill_2,attribute_hp,attribute_regen}_{720,540}.png`，共12张；两个 skill 文件名覆盖不同英雄的短／长说明，不表示每名英雄有两个技能。[验收](validation/defense/hero_details/验收.md)与[最终日志](validation/defense/hero_details/final.log)记录753条断言、0失败：详情424条（含12张实际图片像素尺寸），既有英雄页真实输入回归329条；架构检查通过。

[独立视觉复核](validation/defense/hero_details/visual_review.md)初次确认12张截图有效，要求提高属性绿色对比度；最终 M1 resolved、remaining clear、disposition ship，仅覆盖该修正和直接回归。共享主页图集套件另有28项 StatuePage 非图集纹理断言失败，定位记录在 `validation/defense/hero_details/atlas_scope.log`；不宣称该套件或全工程通过。本批未运行HTML/CSS detector、全量工程检查或导出。已有雕像页及历史审核记录保留，不由本批结论覆盖。

2026-10-17 英雄二级关闭方式后续调整：删除左下角X，主纸面与头像栏外点击返回；已有说明仍只收起最上层，消费输入避免点击穿透。`validation/defense/hero_details/blank_return.log`记录767条断言、0失败，详情438条及英雄页329条；720和540实机截图已更新。本轮为局部交互验证，不改写此前独立视觉裁定。

2026-10-17 雕像宝石类型与反馈更新：沿用现有墨线晶石，通过局部晶面着色展示灰、绿、蓝、紫、橙、红、彩七档品质，保留黑色轮廓和白色高光，彩色档采用多色晶面。背包按部位与类型堆叠，数量仅表示同类型副本，不显示字母编号；对应详情标题及已镶嵌行显示品质名称。重复镶嵌或替换提示“该部位已镶嵌相同宝石”，位于弹层之上；被拒绝的替换保留原选择状态。已装备详情头部按用户要求删除镶嵌计数行，固定五行和逐颗卸下操作保留。

本次七品质与去重定向验收：`unique_gems_verify.log` 记录 425 项、0 失败、8.69 秒，架构检查通过。真实输入覆盖背包滚动至最后一组、重复镶嵌、重复替换被拒后选择有效槽位、卸下再镶嵌；480/720/960 原生窗口截图已更新。本轮仅局部规则与表现验证，未重跑历史独立视觉裁定、全量工程检查或平台导出。

## 已选词条二级面板

固定骨架位于`scenes/defense/hero_terms_panel.tscn`。深色标题栏、现有纸纹底板、英雄头像与名称、竖向词条列表和右侧英雄切换组成参考图的信息层级；底栏和战场保留在背后。词条名采用浅绿色标记条与38号黑字，正文32号，原文中的数值使用深绿色强调，方括号与换行保持不变。重复数量独立右对齐，与名称共用一行，不把重复倍率改写进原文。动态行和英雄按钮分别使用独立场景，仅在对应英雄或升级记录变化时更新；逐帧战斗快照不重建列表。只持有初始技能时显示“尚未获得强化词条”；初始技能不参与列表或重复数量统计。自动掉落、结算和返回主页会清理该面板，避免遮挡后续操作。

2026-10-17 宝石视觉修订：按用户图示将单形染色晶石替换为七张独立二维卡通卡面，包含三角、菱形、切角方形、五边形、六边形、红色多边形和至尊钝角异形晶体；七档背景、纹理和边框分别绘制，保留墨线轮廓及大晶面。品质名固定为普通、精良、卓越、完美、传说、绝世、至尊。背包左下装备角标使用深色底、浅色2px描边的40×40逻辑像素底框，内部图标32×32；详情头部固定三行显示部位图标/名称、品质、数量。旧染色 shader 和运行单图已移除。原始生成图、最终提示词、色键切分参数及SHA位于 `art_source/statue_gem_quality/`；本次使用内置 image_gen + generate2dsprite 处理。

本轮 `gem_art_verify.log` 为448项、0失败、9.19秒；架构、通用数据及资源校验通过，Godot导入无错误。主页面、至尊详情及480窗口已装备详情经目视核对，显示无裁切。本轮未跑全量工程检查或导出。完整导表入口因未修改的 `defense_term_hero_button.gd` 动态图标字符串被校验器视作精确资源名而失败；本次资源绑定使用其实际所属通用内容管线生成并校验，详情见验收。

### 雕像装备孔位颜色

五个菱形孔位按实际镶嵌顺序显示灰、绿、蓝、紫、橙、红或彩色；空槽维持中空观感。表现层从快照中的宝石实例读取品质，不再只使用镶嵌数量统一填色。替换在原孔更新颜色，卸下后按剩余宝石顺序前移并清空尾孔，至尊移除后同步清除彩色。

2026-10-17：本轮雕像页定向验证609项、0失败；验证了真实镶嵌、同数量替换、卸下、重新镶嵌与六部位清空。720和480窗口实际画面已核对，范围和证据见 `validation/defense/statue_page/验收.md`。

### 简洁墨线宝石画风（当前）

2026-10-17 用户确认七种形状，要求采用新截图中的简洁墨线风格。保留三角、菱形、切角方形、五边形、六边形、八边形、钝角异形晶体；改为黑色轮廓和切面线、大块色面及有限白色高光。七档底色低饱和，去掉强反光、复杂笔刷纹理和发亮品质边框。这一画风取代上文此前亮面卡面方案；角标底框、品质名称、数量、孔位颜色与全部交互规则保持。

内置 image_gen 重绘，源图/提示词/来源及切分参数仍位于 `art_source/statue_gem_quality/`。七张运行纹理原位更新，资源绑定未变。`gem_flat_verify.log` 记录610项、0失败、9.77秒；Godot导入与资源清单生成/校验通过。背包720、至尊详情720及已装备列表480实际显示已核对；未运行全量工程检查或打包。
