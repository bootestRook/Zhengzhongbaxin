"""Build the supplied reference's missing UI icon sheet and editable home scene.

The existing atlas owns paper, map, boss, buttons, chests and navigation art.
Only the six icons and avatar absent from that atlas use the user's image.
"""
from pathlib import Path
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from defense_reference_icons import register_icons

source = ROOT / "art_source/defense/home_reference.png"
if not source.exists():
    shutil.copyfile("C:/Users/Arche/AppData/Local/Temp/codex-clipboard-a5d719a6-dadd-4244-99f7-bf31aa92fb18.png", source)
art_path = ROOT / "data/source/defense/art.json"
art = json.loads(art_path.read_text(encoding="utf-8"))
register_icons(art)
art_path.write_text(json.dumps(art, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")

resources = ['[gd_scene format=3]',
             '[ext_resource type="Shader" path="res://src/features/defense/presentation/home_light.gdshader" id="light_shader"]',
             '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_home.gd" id="home"]',
             '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_home_boss.gd" id="boss"]',
             '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_atlas_sprite.gd" id="sprite"]']

nodes = ['[node name="Home" type="Control"]\nlayout_mode = 0\noffset_right = 960.0\noffset_bottom = 1920.0\nmouse_filter = 2\nscript = ExtResource("home")']
def node(name, kind, rect, parent='.', extra=''):
    x,y,w,h = rect
    nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\nlayout_mode = 0\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+h)}\n{extra}')
def image(name,key,rect,parent='.',tint=None):
    extra = 'mouse_filter = 2\nexpand_mode = 1\nstretch_mode = 0'
    extra += '\nscript = ExtResource("sprite")\nresource_key = ' + json.dumps(key)
    if tint:
        extra += '\nmodulate = Color(' + tint + ')'
    node(name,'TextureRect',rect,parent,extra)
def label(name,text,rect,font=34,color='0, 0, 0, 1',outline=0,parent='.',align=1,outline_color='0, 0, 0, 1'):
    text=json.dumps(text,ensure_ascii=False)
    node(name,'Label',rect,parent,f'mouse_filter = 2\ntheme_override_colors/font_color = Color({color})\ntheme_override_colors/font_outline_color = Color({outline_color})\ntheme_override_constants/outline_size = {outline}\ntheme_override_font_sizes/font_size = {font}\ntext = {text}\nhorizontal_alignment = {align}\nvertical_alignment = 1')
def button(name,rect,tip='',disabled=False):
    node(name,'Button',rect,extra=f'tooltip_text = {json.dumps(tip,ensure_ascii=False)}\nmouse_default_cursor_shape = 2\ntheme_override_styles/normal = SubResource("Empty")\ntheme_override_styles/hover = SubResource("Empty")\ntheme_override_styles/pressed = SubResource("Empty")\ntheme_override_styles/disabled = SubResource("Empty")\ntheme_override_styles/focus = SubResource("Focus")\ndisabled = {str(disabled).lower()}')
def color(name,rect,color,parent='.'):
    node(name,'ColorRect',rect,parent,f'mouse_filter = 2\ncolor = Color({color})')

resources.append('[sub_resource type="StyleBoxEmpty" id="Empty"]')
resources.append('[sub_resource type="ShaderMaterial" id="LightMaterial"]\nresource_local_to_scene = true\nshader = ExtResource("light_shader")')
resources.append('[sub_resource type="StyleBoxFlat" id="Focus"]\nbg_color = Color(0, 0, 0, 0)\nborder_width_left = 3\nborder_width_top = 3\nborder_width_right = 3\nborder_width_bottom = 3\nborder_color = Color(1, 0.83, 0.24, 1)')
image('Map','home:home_level_bg_1',(0,0,960,1920))
image('MapShade','home:home_level_bg_mask',(0,0,960,1920))
image('MapLight','home:home_level_bg_light',(35,180,880,1230),tint='1, 1, 1, 0.84')
nodes[-1]+='\nmaterial = SubResource("LightMaterial")'
image('PlayerPaper','home:bg4',(12,12,452,126))
image('AvatarFrame','home:frame',(16,20,114,108))
image('Avatar','homeReference:avatar',(27,30,91,91))
label('PlayerName','玩家45703703',(142,24,320,41),39,'1, 1, 1, 1',6,align=0)
label('PlayerId','编号:57519',(143,66,270,31),31,'1, 1, 1, 1',5,align=0)
label('PlayerLevel','等级: 0',(143,96,135,33),30,'1, 1, 1, 1',5,align=0)
color('ExperienceBorder',(260,106,197,25),'0, 0, 0, 1')
color('Experience',(264,109,156,19),'0, 0.91, 0.94, 1')
label('ExperienceText','8/10',(270,102,176,30),30,'1, 1, 1, 1',5)
for i,(text,key) in enumerate([('1368/30','homeReference:energy'),('1150','homeReference:diamond'),('1893','homeReference:coin')]):
    color('ResourceTrack%d'%i,(766,24+i*52,172,36),'0, 0, 0, 1')
    image('ResourceIcon%d'%i,key,(760,20+i*52,42,42))
    label('ResourceValue%d'%i,text,(805,24+i*52,131,36),31,'1, 1, 1, 1',2)

for name,title,key,rect,iconrect,badge in [
    ('Activity','活动','homeReference:activity',(28,188,120,161),(12,10,100,100),True),
    ('FirstGift','首充礼包','homeReference:firstGift',(20,395,130,140),(17,2,99,83),False),
    ('More','更多','common:setBg',(814,199,120,151),(6,4,108,108),True),
    ('Ranking','排行榜','home:ar',(814,395,120,139),(9,0,100,90),False)]:
    button(name,rect,title)
    image('Icon',key,iconrect,name)
    caption_width = 164 if name == 'FirstGift' else 132
    image('Caption','home:blackBG',((120-caption_width)/2,105 if name in ['Activity','More'] else 86,caption_width,50),name)
    label('Label',title,(-6,106 if name in ['Activity','More'] else 87,132,42),31,'1, 1, 1, 1',2,name)
    if badge: image('Badge','common:hint2',(90,2,30,30),name)

image('LevelPaper','home:bg',(164,552,680,830))
image('BossBase','home:icon_boss_base_home',(343,529,304,173))
node('Boss','Control',(375,415,240,200),extra='mouse_filter = 2\nscript = ExtResource("boss")')
button('Monster',(694,623,112,104),'查看本关最终首领')
image('Icon','home:btn_Monster',(0,0,112,104),'Monster')
button('LevelSelect',(255,724,480,106),'选择关卡')
label('LevelTitle','第1关',(0,0,480,106),78,parent='LevelSelect')
label('ClearStatus','等待挑战',(270,841,450,52),40,'0.48, 0.76, 0.26, 1')
image('Rule','home:home_line',(340,900,316,4))
label('Rank','排名:暂无',(300,915,390,45),31,'0.61, 0.61, 0.60, 1')
image('ClearCountPaper','home:common_section',(261,992,442,111),tint='0.90, 0.89, 0.90, 1')
label('ClearCountTitle','通关人数',(270,1002,424,43),31)
label('ClearCount','0',(270,1045,424,44),38)
for i,tint in enumerate(['0.69, 0.81, 0.61, 1','0.52, 0.68, 0.76, 1','0.67, 0.51, 0.76, 1']):
    button('Reward%d'%i,(264+i*150,1122,137,126),'查看本关宝箱奖励')
    image('Tile','home:common_section_w_zhengfangxing',(0,0,137,126),'Reward%d'%i,tint)
    image('Chest','home:t10',(17,19,102,89),'Reward%d'%i)
    image('Claimed','home:yes',(80,73,55,48),'Reward%d'%i)
for name,x,flip in [('Previous',33,True),('Next',829,False)]:
    button(name,(x,830,100,135),'上一关' if flip else '下一关')
    image('Arrow','common:arrow',(0,0,100,135),name)
    if flip: nodes[-1]+='\nflip_h = true'

button('Start',(274,1350,461,215),'开始本关挑战')
image('Paper','home:Start_Btn',(0,0,461,215),'Start')
label('LetteringEdge','开始',(0,20,426,88),70,'0, 0, 0, 1',8,'Start')
label('Label','开始',(0,20,426,88),70,'0, 0, 0, 1',4,'Start',outline_color='1, 1, 1, 1')
image('Energy','homeReference:energy',(155,108,37,37),'Start')
label('Cost','×6',(192,105,80,44),40,'1, 1, 1, 1',5,'Start')
button('Sweep',(19,1350,255,203),'扫荡')
image('Paper','home:btn_Home',(0,0,255,203),'Sweep')
image('Icon','home:icon_Sweep',(52,-74,142,162),'Sweep')
label('Label','扫荡',(26,46,194,55),50,'1, 1, 1, 1',8,'Sweep')
image('Energy','homeReference:energy',(64,105,34,34),'Sweep',tint='0.7, 0.7, 0.7, 1')
label('Cost','×6',(100,101,82,44),40,'1, 1, 1, 1',5,'Sweep')
button('Territory',(715,1355,255,203),'领地')
image('Paper','home:btn_Home',(0,0,255,203),'Territory')
image('Icon','homeReference:territory',(57,-60,120,145),'Territory')
label('Label','领地',(26,93,194,62),50,'1, 1, 1, 1',8,'Territory')
node('Chat','RichTextLabel',(40,1530,882,169),extra='mouse_filter = 2\ntheme_override_colors/default_color = Color(1, 1, 1, 1)\ntheme_override_font_sizes/normal_font_size = 29\nbbcode_enabled = true\ntext = "[color=#ffdf2a]系统:[/color]选择英雄和强化，构筑你的守城队伍！\\n[color=#ffdf2a]系统:[/color]击败本关最后一位首领即可完成挑战。\\n[color=#ffdf2a]系统:[/color]点击关卡名称可选择前 50 关。"\nscroll_active = false')
color('NavigationInk',(0,1735,960,185),'0, 0, 0, 1')
image('NavigationPaper','home:bg4',(0,1745,960,192),tint='0.52, 0.53, 0.52, 1')
for name,title,key,x,badge in [('Shop','商店','home:sc2_up',0,True),('HeroGallery','英雄','home:yx2_up',192,True),('Statue','雕像','home:tz2_up',576,True),('Locked','','home:icon_Lock',768,False)]:
    button(name,(x,1745,192,175),title,disabled=name=='Locked')
    image('Icon',key,(21,6,150,126) if title else (65,47,63,81),name)
    if title: label('Label',title,(0,111,192,53),48,'1, 1, 1, 1',7,name)
    if badge: image('Badge','common:hint2',(166,-5,28,28),name)
    if x: color('Divider%d'%x,(x,1750,3,170),'0.16, 0.17, 0.16, 1')
button('Battle',(381,1706,198,214),'战斗 / 选择关卡')
image('Paper','home:frame',(0,0,198,214),'Battle')
image('Icon','home:equip',(5,-35,188,188),'Battle')
label('Label','战斗',(0,123,198,60),48,'0, 0, 0, 1',0,'Battle')
(ROOT/'scenes/defense/home.tscn').write_text('\n\n'.join(resources+nodes)+'\n',encoding='utf-8',newline='\n')

binding=ROOT/'data/source/resource_bindings.csv'
text=binding.read_text(encoding='utf-8')
if 'defense.home_reference' not in text:
    text+='defense.home_reference,texture_2d,art_source/defense/home_reference.png,res://assets/runtime/defense/home_reference_icons.png,defense_atlas,defense_art,project_research,third_party,true,defense\n'
    binding.write_text(text,encoding='utf-8',newline='\n')
print('Built supplied-reference icons/avatar and scenes/defense/home.tscn')

main = ROOT / 'scenes/main.tscn'
scene = main.read_text(encoding='utf-8')
if 'id="home"' not in scene:
    at = scene.index('[sub_resource')
    scene = scene[:at] + '[ext_resource type="PackedScene" path="res://scenes/defense/home.tscn" id="home"]\n\n' + scene[at:]
    start = scene.index('[node name="Home"')
    end = scene.index('[node name="HUD"')
    scene = scene[:start] + '[node name="Home" parent="DefenseView" instance=ExtResource("home")]\nunique_name_in_owner = true\n\n' + scene[end:]
    scene += '''
[node name="HomeInfoPanel" type="Control" parent="DefenseView"]
unique_name_in_owner = true
visible = false
layout_mode = 0
offset_right = 960.0
offset_bottom = 1920.0

[node name="Shade" type="ColorRect" parent="DefenseView/HomeInfoPanel"]
layout_mode = 0
offset_right = 960.0
offset_bottom = 1920.0
mouse_filter = 2
color = Color(0, 0, 0, 0.65)

[node name="Paper" type="Panel" parent="DefenseView/HomeInfoPanel"]
layout_mode = 0
offset_left = 90.0
offset_top = 510.0
offset_right = 870.0
offset_bottom = 1390.0
theme_override_styles/panel = SubResource("Paper")

[node name="HomeInfoTitle" type="Label" parent="DefenseView/HomeInfoPanel"]
unique_name_in_owner = true
layout_mode = 0
offset_left = 130.0
offset_top = 560.0
offset_right = 830.0
offset_bottom = 650.0
theme_override_font_sizes/font_size = 48
horizontal_alignment = 1
vertical_alignment = 1

[node name="HomeInfoText" type="Label" parent="DefenseView/HomeInfoPanel"]
unique_name_in_owner = true
layout_mode = 0
offset_left = 145.0
offset_top = 710.0
offset_right = 815.0
offset_bottom = 1210.0
theme_override_font_sizes/font_size = 32
autowrap_mode = 2

[node name="HomeInfoClose" type="Button" parent="DefenseView/HomeInfoPanel"]
unique_name_in_owner = true
layout_mode = 0
offset_left = 330.0
offset_top = 1240.0
offset_right = 630.0
offset_bottom = 1340.0
text = "返回"
'''
    main.write_text(scene, encoding='utf-8', newline='\n')
