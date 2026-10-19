"""Author the fixed Godot laboratory scene. Run only when editing its layout."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
out = ['[gd_scene load_steps=10 format=3]',
       '[ext_resource type="Script" path="res://src/app/lab_app.gd" id="app"]',
       '[ext_resource type="PackedScene" path="res://scenes/main.tscn" id="game"]',
       '[ext_resource type="FontFile" path="res://assets/runtime/defense/chinese.ttf" id="font"]']

def style(name, color, border=None):
    out.extend([f'[sub_resource type="StyleBoxFlat" id="{name}"]', f'bg_color = Color{color}',
                'content_margin_left = 10.0', 'content_margin_right = 10.0',
                'content_margin_top = 7.0', 'content_margin_bottom = 7.0',
                'corner_radius_top_left = 5', 'corner_radius_top_right = 5',
                'corner_radius_bottom_left = 5', 'corner_radius_bottom_right = 5'])
    if border:
        out.extend([f'border_color = Color{border}']+[f'border_width_{edge} = 1' for edge in ['left','top','right','bottom']])

style('paper', '(0.967, 0.966, 0.94, 1)')
style('normal', '(0.9, 0.908, 0.86, 1)', '(0.71, 0.74, 0.65, 1)')
style('hover', '(0.96, 0.94, 0.77, 1)', '(0.55, 0.59, 0.43, 1)')
style('pressed', '(1, 0.83, 0.25, 1)')
style('focus', '(0, 0, 0, 0)', '(0.42, 0.5, 0.18, 1)')
out.extend(['[sub_resource type="Theme" id="theme"]', 'default_font = ExtResource("font")', 'default_font_size = 18'])
for t in ['Button','OptionButton','Label','LineEdit','ItemList','RichTextLabel','TabBar','TabContainer','SpinBox','PopupMenu']:
    for color in ['font_color','font_hover_color','font_hovered_color','font_pressed_color','font_selected_color','font_unselected_color','font_focus_color']:
        out.append(f'{t}/colors/{color} = Color(0.13, 0.18, 0.12, 1)')
    out.append(f'{t}/colors/font_disabled_color = Color(0.46, 0.48, 0.42, 1)')
for t in ['Button','OptionButton','LineEdit','ItemList']:
    for slot, resource in [('normal','normal'),('hover','hover'),('pressed','pressed'),('focus','focus'),('disabled','paper'),('selected','pressed'),('selected_focus','pressed'),('panel','paper')]:
        out.append(f'{t}/styles/{slot} = SubResource("{resource}")')
out.append('RichTextLabel/colors/default_color = Color(0.13, 0.18, 0.12, 1)')
for slot, resource in [('tab_selected','pressed'), ('tab_unselected','normal'), ('tab_hovered','hover'), ('tab_disabled','paper'), ('tab_focus','focus')]:
    out.append(f'TabContainer/styles/{slot} = SubResource("{resource}")')
for direction in ['up', 'down']:
    for state in ['', 'hover_', 'pressed_']:
        out.append(f'SpinBox/colors/{direction}_{state}icon_modulate = Color(0.2, 0.28, 0.15, 1)')
    out.append(f'SpinBox/colors/{direction}_disabled_icon_modulate = Color(0.58, 0.61, 0.53, 1)')
out.extend(['PopupMenu/styles/panel = SubResource("paper")', 'PopupMenu/styles/hover = SubResource("hover")'])
out.extend(['PanelContainer/styles/panel = SubResource("paper")', 'TabContainer/styles/panel = SubResource("paper")',
            'TabBar/styles/tab_selected = SubResource("pressed")', 'TabBar/styles/tab_unselected = SubResource("normal")',
            'TabBar/styles/tab_hovered = SubResource("hover")', 'TabBar/colors/font_unselected_color = Color(0.25, 0.29, 0.22, 1)',
            'LineEdit/colors/caret_color = Color(0.2, 0.3, 0.1, 1)', 'LineEdit/colors/font_placeholder_color = Color(0.4, 0.44, 0.36, 1)'])

def raw(value):
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool): return str(value).lower()
    return str(value)

def node(name, typ, parent='.', **props):
    out.append(f'[node name="{name}" type="{typ}"'+(f' parent="{parent}"' if parent else '')+']')
    out.append('unique_name_in_owner = true')
    if parent and typ not in ['SubViewport','Node','FileDialog']: out.append('layout_mode = 2')
    for key, value in props.items(): out.append(f'{key} = {raw(value)}')
    return name if parent in ['', '.'] else parent+'/'+name

def expression(key, value): out.append(f'{key} = {value}')
def row(name, parent): return node(name, 'HFlowContainer', parent)
def label(name, parent, text, wrap=False):
    p=node(name,'Label',parent,text=text)
    if wrap: expression('autowrap_mode','3')
    return p
def button(name,parent,text,toggle=False,pressed=False): return node(name,'Button',parent,text=text,toggle_mode=toggle,button_pressed=pressed)
def spin(name,parent,value=1,minimum=0,maximum=1000000000,step=1,width=106):
    p=node(name,'SpinBox',parent,min_value=minimum,max_value=maximum,step=step,value=value)
    expression('custom_minimum_size',f'Vector2({width}, 36)')
    return p
def option(name,parent,items):
    p=node(name,'OptionButton',parent,item_count=len(items))
    for i,item in enumerate(items): expression(f'popup/item_{i}/text',raw(item)); expression(f'popup/item_{i}/id',str(i))
    if items: expression('selected','0')
    return p
def line(name,parent,placeholder): return node(name,'LineEdit',parent,placeholder_text=placeholder,size_flags_horizontal=3)
def rich(name,parent,height):
    p=node(name,'RichTextLabel',parent,scroll_active=True,size_flags_horizontal=3,size_flags_vertical=3)
    expression('custom_minimum_size',f'Vector2(0, {height})')
    return p
def tab(name,title,tabs):
    p=node(name,'ScrollContainer',tabs,**{'horizontal_scroll_mode':0})
    expression('metadata/_tab_name',raw(title))
    inner=node(name+'Body','VBoxContainer',p,size_flags_horizontal=3)
    expression('theme_override_constants/separation','10')
    return inner

node('BattleLaboratory','Control','')
expression('layout_mode','3'); expression('anchors_preset','15'); expression('anchor_right','1.0'); expression('anchor_bottom','1.0')
expression('theme','SubResource("theme")'); expression('script','ExtResource("app")')
node('Background','ColorRect','.',mouse_filter=2)
expression('anchors_preset','15'); expression('anchor_right','1.0'); expression('anchor_bottom','1.0'); expression('color','Color(0.82, 0.84, 0.76, 1)')
margin=node('Margin','MarginContainer')
expression('anchors_preset','15'); expression('anchor_right','1.0'); expression('anchor_bottom','1.0')
for side in ['left','top','right','bottom']: expression('theme_override_constants/margin_'+side,'12')
root=node('RootLayout','VBoxContainer',margin)
expression('theme_override_constants/separation','8')
toolbar=row('Toolbar',root)
label('Title',toolbar,'战斗测试场'); expression('theme_override_font_sizes/font_size','24')
button('Play',toolbar,'继续'); button('Step',toolbar,'单步 16ms'); button('Second',toolbar,'推进 1.6s')
option('Event',toolbar,['下次起手','下次伤害','下次死亡']); button('Next',toolbar,'推进至事件')
option('Rate',toolbar,['0.25×','0.5×','1×','2×','3×']); expression('selected','2')
button('Reset',toolbar,'重开'); button('Geometry',toolbar,'判定范围',True); button('Tools',toolbar,'工具面板')
label('Timeline',root,'0.000 秒'); label('Mode',root,'合法构筑')
body=node('Body','HBoxContainer',root,size_flags_vertical=3)
expression('theme_override_constants/separation','12')
frame=node('BattleFrame','Control',body,size_flags_horizontal=3,size_flags_vertical=3)
expression('custom_minimum_size','Vector2(240, 300)')
container=node('ViewportContainer','SubViewportContainer',frame)
expression('layout_mode','0'); expression('offset_right','960.0'); expression('offset_bottom','1920.0')
vp=node('Viewport','SubViewport',container)
expression('size','Vector2i(960, 1920)'); expression('render_target_update_mode','4'); expression('handle_input_locally','false')
out.append(f'[node name="Game" parent="{vp}" instance=ExtResource("game")]'); expression('unique_name_in_owner','true')
tools=node('ToolPanel','PanelContainer',body,size_flags_vertical=3)
expression('custom_minimum_size','Vector2(440, 0)')
toolbox=node('Toolbox','VBoxContainer',tools)
label('Selection',toolbox,'选择战场单位，或从列表选择',True)
node('Units','ItemList',toolbox,size_flags_horizontal=3); expression('custom_minimum_size','Vector2(0, 122)')
tabs=node('Tabs','TabContainer',toolbox,size_flags_vertical=3)

units=tab('单位','单位',tabs)
label('HeroLabel',units,'指定英雄')
r=row('HeroRow',units); option('HeroChoice',r,[]); button('AddHero',r,'召唤英雄')
label('MonsterLabel',units,'怪物模板')
line('MonsterSearch',units,'搜索名称或编号')
option('MonsterChoice',units,[])
r=row('MonsterOptions',units); option('MonsterKind',r,['普通怪物','精英','首领']); label('CountLabel',r,'数量'); spin('Count',r,1,1,300)
r=row('Arrangement',units); option('Layout',r,['单点','横排','纵排','环形','网格','随机区域']); label('SpaceLabel',r,'间距/半径'); spin('Spacing',r,80,0,1000)
r=row('Position',units); label('XLabel',r,'X'); spin('PosX',r,800,-2000,4000); label('YLabel',r,'Y'); spin('PosY',r,700,-2000,4000)
r=row('SpawnRules',units); option('SpawnSurvival',r,['正常生命','不死靶','无敌靶']); button('StaticTarget',r,'静止靶（不移动、不攻击）',True,True)
r=row('SpawnButtons',units); button('AddMonster',r,'添加怪物'); button('Place',r,'点击战场放置',True); button('MoveSelected',r,'移动选中单位')
label('PositionHelp',units,'点击战场选择单位并填写坐标；开启放置后，点击即生成。',True)
r=row('ClearRow',units); button('ClearSelected',r,'清除选中'); button('ClearEnemies',r,'清除怪物'); button('ClearAll',r,'清空战场')
label('ClearHelp',units,'清除不触发死亡、击杀或掉落。击杀验证在“属性”页操作。',True)

terms=tab('词条','词条',tabs)
r=row('LegalRow',terms); button('Legal',r,'遵守前置与次数',True,True); button('ApplyMode',r,'应用模式并重开')
line('TermSearch',terms,'搜索所选英雄的词条')
node('Terms','ItemList',terms); expression('custom_minimum_size','Vector2(0, 190)')
rich('TermDescription',terms,140)
r=row('TermActions',terms); label('TermCountLabel',r,'总次数'); spin('TermCount',r,1,1,20,1,80); button('AddTerm',r,'应用'); button('Prerequisites',r,'补齐前置并应用')
r=row('RemoveTerms',terms); button('RemoveTerm',r,'移除词条'); button('ClearTerms',r,'清空强化')
label('TermHelp',terms,'增删词条会重建整个配置并暂停，初始技能保留。自由模式可越过前置和次数限制。',True)

stats=tab('属性','属性',tabs)
option('Scope',stats,['仅选中单位','全部怪物','与选中怪物同模板'])
r=row('AttributeRow',stats); option('AttributeChoice',r,[]); spin('AttributeValue',r,100); button('ApplyAttribute',r,'设置基础值')
label('AttributeReadback',stats,'基础 → 最终',True)
r=row('HPRow',stats); label('HPLabel',r,'生命%'); spin('HPPercent',r,100,0.1,100,0.1); button('ApplyHP',r,'设置'); button('FullHP',r,'满血')
r=row('SurvivalRow',stats); option('Survival',r,['正常生命','不死：受伤后补满','无敌：拒绝伤害']); button('ApplySurvival',r,'应用生存模式')
label('SurvivalHelp',stats,'不死靶正常结算伤害与受击效果，但不触发死亡。致死、斩杀与击杀测试请用正常生命。',True)
r=row('ShieldRow',stats); label('ShieldLabel',r,'测试护盾'); spin('Shield',r,0); button('ApplyShield',r,'设置护盾')
r=row('BehaviorRow',stats); button('Move',r,'移动',True,True); button('Attack',r,'普攻',True,True); button('Skill',r,'技能',True,True); button('ApplyActions',r,'应用行为')
r=row('ReadyRow',stats); button('Ready',r,'冷却就绪'); button('Weaken',r,'残血至1'); button('Revive',r,'测试复活')
label('KillHelp',stats,'残血后由真实攻击完成击杀，可验证技能专属效果；“人工击杀”仅验证死亡及通用击杀触发。',True)
r=row('KillRow',stats); option('Killer',r,[]); button('Kill',r,'人工击杀')
label('StatusLabel',stats,'状态与持续时间')
option('StatusChoice',stats,[])
r=row('StatusParams',stats); label('DurationLabel',r,'秒'); spin('StatusDuration',r,5,0.1,3600,0.1); label('StacksLabel',r,'次数'); spin('Stacks',r,1,1,100,1,80)
r=row('StatusActions',stats); button('AddStatus',r,'施加状态'); button('ClearStatus',r,'清除状态')
r=row('WallRow',stats); label('WallLabel',r,'雕像生命'); spin('WallHP',r,3900,0,1000000000); button('ApplyWall',r,'应用')

inspect=tab('状态','状态',tabs); rich('Details',inspect,500)
logs=tab('记录','记录',tabs)
line('LogFilter',logs,'筛选事件：damage / cast / death / status 或编号')
button('OnlySelected',logs,'只看选中单位',True)
label('LogInfo',logs,'事件与逻辑步耗时',True); rich('Log',logs,420)

cases=tab('用例','用例',tabs)
label('PresetLabel',cases,'内置测试配置')
option('Preset',cases,[]); button('LoadPreset',cases,'加载预设')
r=row('RunSetup',cases)
g=node('SeedGroup','HBoxContainer',r); label('SeedLabel',g,'种子'); spin('Seed',g,53,1,2147483647)
g=node('LevelGroup','HBoxContainer',r); label('LevelLabel',g,'关卡'); spin('Level',g,1,1,50,1,80)
g=node('WaveGroup','HBoxContainer',r); label('WaveLabel',g,'波'); spin('Wave',g,1,1,20,1,70)
button('AutoSpawn',cases,'自动刷怪',True); button('Progression',cases,'完整关卡流程（选卡、奖励、胜负）',True); button('Respawn',cases,'配置怪物死亡1秒后自动补充',True)
button('ApplyEnvironment',cases,'应用环境并重开')
label('CaseHelp',cases,'保存配置用于重新搭建战场；保存重放包含操作与固定步进记录。代码或数据变化后请加载配置重新验证。',True)
r=row('FileRow1',cases); button('LoadConfig',r,'加载配置'); button('SaveConfig',r,'保存配置')
r=row('FileRow2',cases); button('SaveReplay',r,'保存重放'); button('Replay',r,'重放操作'); button('Report',r,'导出记录')
label('CaseBoundary',cases,'预设可运行不等于技能已通过。自动化断言、规则回归和人工视觉检查分别记录。',True)
label('Notice',root,'点击继续开始战斗；可先配置英雄、怪物和词条。',True)
node('FileDialog','FileDialog','.',access=2,file_mode=4,title='战斗测试配置')
expression('filters','PackedStringArray("*.json ; 测试配置与记录")')
(ROOT/'scenes/defense_lab.tscn').write_text('\n\n'.join(out)+'\n',encoding='utf-8',newline='\n')
print('Authored scenes/defense_lab.tscn')
