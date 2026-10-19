"""Build the editable settlement skeleton; artwork is bound only by name."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]


def build():
    resources = ['[gd_scene format=3]',
        '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_result_panel.gd" id="panel"]',
        '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_atlas_sprite.gd" id="sprite"]',
        '[ext_resource type="Script" path="res://src/features/defense/presentation/defense_result_progress.gd" id="progress"]',
        '[ext_resource type="Shader" path="res://src/features/defense/presentation/result_blur.gdshader" id="blur"]',
        '[sub_resource type="ShaderMaterial" id="Blur"]\nresource_local_to_scene = true\nshader = ExtResource("blur")',
        '[sub_resource type="StyleBoxEmpty" id="Empty"]',
        '[sub_resource type="StyleBoxFlat" id="Focus"]\nbg_color = Color(0,0,0,0)\nborder_width_left = 3\nborder_width_right = 3\nborder_width_top = 3\nborder_width_bottom = 3\nborder_color = Color(1,0.85,0.25,1)']
    nodes = ['[node name="ResultPanel" type="Control"]\nvisible = false\nz_index = 4\noffset_right = 960.0\noffset_bottom = 1920.0\nscript = ExtResource("panel")']
    def node(name, kind, rect, parent='.', extra=''):
        x,y,w,h=rect
        nodes.append(f'[node name="{name}" type="{kind}" parent="{parent}"]\nlayout_mode = 0\noffset_left = {float(x)}\noffset_top = {float(y)}\noffset_right = {float(x+w)}\noffset_bottom = {float(y+h)}\n{extra}')
    def image(name, key, rect, parent='.', extra=''):
        node(name,'TextureRect',rect,parent,'mouse_filter = 2\nexpand_mode = 1\nstretch_mode = 0\nscript = ExtResource("sprite")\nresource_key = '+json.dumps(key)+'\n'+extra)
    def label(name, text, rect, font, parent='.', extra=''):
        node(name,'Label',rect,parent,'mouse_filter = 2\ntheme_override_colors/font_color = Color(1,1,1,1)\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 5\ntheme_override_font_sizes/font_size = '+str(font)+'\ntext = '+json.dumps(text,ensure_ascii=False)+'\nhorizontal_alignment = 1\nvertical_alignment = 1\n'+extra)
    node('Shade','ColorRect',(0,0,960,1920),extra='material = SubResource("Blur")\ncolor = Color(1,1,1,1)')
    image('Glow','battle:smallLight',(150,-75,660,660),extra='pivot_offset = Vector2(330,330)\nmodulate = Color(0.08,0.85,1,0.4)')
    node('Header','Control',(45,119,870,429),extra='mouse_filter = 2')
    image('Paper','battle:bg1',(0,0,870,429),'Header')
    label('Title','关卡结束',(165,226,540,132),100,'Header','theme_override_constants/outline_size = 4')
    node('Progress','Control',(125,574,740,127),extra='mouse_filter = 2\nscript = ExtResource("progress")')
    label('History','0%\n历史记录',(742,705,168,86),29)
    label('Level','第1关',(270,728,420,70),57)
    node('Heroes','Control',(0,815,960,303),extra='mouse_filter = 2')
    label('EmptyTeam','未招募英雄',(240,856,480,78),38)
    node('Statues','Control',(0,1119,960,80),extra='mouse_filter = 2')
    node('Rewards','Control',(0,1248,960,235),extra='mouse_filter = 2')
    label('Title','未获得奖励',(240,0,480,75),40,'Rewards')
    node('Items','Control',(0,105,960,100),'Rewards','mouse_filter = 2')
    node('Confirm','Button',(270,1606,420,194),extra='mouse_default_cursor_shape = 2\ntheme_override_styles/normal = SubResource("Empty")\ntheme_override_styles/hover = SubResource("Empty")\ntheme_override_styles/pressed = SubResource("Empty")\ntheme_override_styles/disabled = SubResource("Empty")\ntheme_override_styles/focus = SubResource("Focus")')
    image('Paper','common:btnYello_Shadow',(17,10,420,194),'Confirm')
    label('Label','确认',(7.5,2,405,171),90,'Confirm','theme_override_constants/outline_size = 7')
    (ROOT/'scenes/defense/result_panel.tscn').write_text('\n\n'.join(resources+nodes)+'\n',encoding='utf-8',newline='\n')
    card = '''[gd_scene format=3]

[ext_resource type="Script" path="res://src/features/defense/presentation/defense_result_card.gd" id="card"]
[ext_resource type="Script" path="res://src/features/defense/presentation/defense_atlas_sprite.gd" id="sprite"]
[sub_resource type="StyleBoxEmpty" id="Empty"]

[node name="ResultCard" type="Control"]
offset_right = 203.0
offset_bottom = 303.0
mouse_filter = 2
script = ExtResource("card")

[node name="MVP" type="TextureRect" parent="."]
offset_left = -8.0
offset_top = -13.0
offset_right = 51.0
offset_bottom = 45.0
mouse_filter = 2
expand_mode = 1
script = ExtResource("sprite")
resource_key = "battle:icon_mvp"

[node name="Info" type="Button" parent="."]
offset_left = 153.0
offset_top = 10.0
offset_right = 190.0
offset_bottom = 47.0
mouse_default_cursor_shape = 2
theme_override_styles/normal = SubResource("Empty")
theme_override_styles/hover = SubResource("Empty")
theme_override_styles/pressed = SubResource("Empty")

[node name="Icon" type="TextureRect" parent="Info"]
offset_right = 37.0
offset_bottom = 37.0
mouse_filter = 2
expand_mode = 1
script = ExtResource("sprite")
resource_key = "map:buffCard_hero_Info_face"
'''
    for i,name in enumerate(['Damage','Taken','Heal']):
        card+=f'\n[node name="{name}" type="Label" parent="."]\noffset_left = 34.0\noffset_top = {191.0+i*33}\noffset_right = 194.0\noffset_bottom = {224.0+i*33}\nmouse_filter = 2\ntheme_override_colors/font_color = Color(1,1,1,1)\ntheme_override_colors/font_outline_color = Color(0,0,0,1)\ntheme_override_constants/outline_size = 2\ntheme_override_font_sizes/font_size = 23\ntext = "0"\nhorizontal_alignment = 2\nvertical_alignment = 1\n'
    (ROOT/'scenes/defense/result_card.tscn').write_text(card,encoding='utf-8',newline='\n')
    item='''[gd_scene format=3]

[ext_resource type="Script" path="res://src/features/defense/presentation/defense_result_item.gd" id="item"]

[node name="ResultItem" type="Control"]
offset_right = 100.0
offset_bottom = 100.0
script = ExtResource("item")

[node name="Count" type="Label" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_colors/font_color = Color(1,1,1,1)
theme_override_colors/font_outline_color = Color(0,0,0,1)
theme_override_constants/outline_size = 4
theme_override_font_sizes/font_size = 29
horizontal_alignment = 2
vertical_alignment = 2

[node name="Experience" type="Label" parent="."]
offset_left = 3.0
offset_top = 3.0
offset_right = 42.0
offset_bottom = 25.0
mouse_filter = 2
theme_override_colors/font_color = Color(0.48,1,0.55,1)
theme_override_colors/font_outline_color = Color(0,0.3,0,1)
theme_override_constants/outline_size = 3
theme_override_font_sizes/font_size = 15
text = "经验"
'''
    (ROOT/'scenes/defense/result_item.tscn').write_text(item,encoding='utf-8',newline='\n')
    path=ROOT/'scenes/main.tscn';main=path.read_text(encoding='utf-8')
    ext='[ext_resource type="PackedScene" path="res://scenes/defense/result_panel.tscn" id="result_panel"]\n\n'
    if 'id="result_panel"' not in main:
        at=main.index('[sub_resource');main=main[:at]+ext+main[at:]
        start=main.index('[node name="ResultPanel"');end=main.index('[node name="LevelPanel"',start)
        main=main[:start]+'[node name="ResultPanel" parent="DefenseView" instance=ExtResource("result_panel")]\nunique_name_in_owner = true\n\n'+main[end:]
        path.write_text(main,encoding='utf-8',newline='\n')
    print('Built editable named-atlas result scenes')


if __name__=='__main__':
    build()
