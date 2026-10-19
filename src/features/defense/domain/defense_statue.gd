class_name DefenseStatue
extends RefCounted

# World coordinates. The body covers the stone figure and base, excluding the flag.
const POSITION = Vector2(771, 1497)
const BODY_CENTER = POSITION + Vector2(25, -110)
const TARGET = {"id": 0, "kind": "statue", "side": 1, "wall": true,
	"dead": false, "pos": POSITION, "facing": 1.0,
	"motion": {"body_offset": [25, -110], "body_size": [150, 200], "attack_offset": [25, -110]}}
