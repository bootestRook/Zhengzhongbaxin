class_name DefenseEquipment
extends RefCounted

const PARTS = ["head", "chest", "boots", "arms", "pants", "gloves"]
const PART_NAMES = {"head": "头部", "chest": "胸甲", "boots": "鞋子", "arms": "手臂", "pants": "裤子", "gloves": "手套"}
const SOCKET_LIMIT = 5
const GEM_TYPES = {"a": "普通", "b": "精良", "c": "卓越", "d": "完美", "e": "传说", "f": "绝世", "g": "至尊"}
const QUALITY_KEYS = {"普通": "a", "精良": "b", "卓越": "c", "完美": "d", "传说": "e", "绝世": "f", "至尊": "g"}
const DEFAULT_GEM_COPIES = 2

var catalog
var _revision: int = 0
var _worn: Dictionary = {}
var _spares: Dictionary = {}
var _sockets: Dictionary = {}
var _inventory: Array = []
var _gem_defs: Dictionary = {}
var _gem_types: Dictionary = {}
var _equipped: Dictionary = {}

func _init(definitions = null) -> void:
	catalog = definitions
	for part in PARTS:
		_worn[part] = part + "_equipment_1"
		_spares[part] = [part + "_equipment_2"]
		_sockets[part] = []
	if catalog != null:
		for definition: Dictionary in catalog.records("gems").values():
			for copy in range(DEFAULT_GEM_COPIES):
				var item = "gem_%d_%d" % [int(definition.id), copy + 1]
				_inventory.append(item)
				_gem_defs[item] = int(definition.id)
				_gem_types[item] = QUALITY_KEYS.get(str(definition.quality), "a")
	_refresh_equipment_views()

func snapshot() -> Dictionary:
	var available: Dictionary = {}
	for part in PARTS:
		available[part] = _available_for_part(part)
	return {"revision": _revision, "worn": _worn.duplicate(true), "spares": _spares.duplicate(true),
		"gems": available, "sockets": _sockets.duplicate(true), "gem_types": _gem_types.duplicate(),
		"gem_defs": _gem_defs.duplicate(), "definitions": catalog.records("gems") if catalog != null else {}}

func submit(intent: String, payload: Dictionary) -> String:
	var part = str(payload.get("part", ""))
	var item = str(payload.get("item", ""))
	if not PARTS.has(part):
		return "无效装备部位"
	match intent:
		"equipment_replace":
			if not _spares[part].has(item):
				return "该装备不在此部位的背包中"
			_spares[part].erase(item)
			_spares[part].append(_worn[part])
			_worn[part] = item
		"gem_inlay":
			if not _inventory.has(item) or _equipped.has(item):
				return "该宝石不在背包中"
			if not gem_allowed(item, part):
				return "该宝石不能镶嵌到此部位"
			var same_slot = same_family_slot(part, item)
			if same_slot >= 0:
				return "请选择要替换的宝石" if quality_rank(item) > quality_rank(_sockets[part][same_slot]) else "该部位已有相同效果的宝石"
			if _sockets[part].size() >= SOCKET_LIMIT:
				return "请选择要替换的宝石"
			_sockets[part].append(item)
			_equipped[item] = {"part": part, "slot": _sockets[part].size() - 1}
		"gem_replace":
			if not _inventory.has(item) or _equipped.has(item):
				return "该宝石不在背包中"
			if not gem_allowed(item, part):
				return "该宝石不能镶嵌到此部位"
			var slot = payload.get("slot", -1)
			if not slot is int or slot < 0 or slot >= _sockets[part].size():
				return "无效宝石替换位置"
			var previous: String = _sockets[part][slot]
			if same_family_slot(part, item, slot) >= 0:
				return "该部位已有相同效果的宝石"
			if same_family(previous, item) and quality_rank(item) <= quality_rank(previous):
				return "只能用更高品质的相同效果宝石替换"
			_sockets[part][slot] = item
			_equipped.erase(previous)
			_equipped[item] = {"part": part, "slot": slot}
		"gem_remove":
			var slot = payload.get("slot", -1)
			if not slot is int or slot < 0 or slot >= _sockets[part].size():
				return "无效宝石位置"
			if _sockets[part][slot] != item:
				return "该宝石已不在此位置"
			_sockets[part].remove_at(slot)
			_equipped.erase(item)
			for index in range(_sockets[part].size()):
				_equipped[_sockets[part][index]] = {"part": part, "slot": index}
		_:
			return "未知装备操作"
	_revision += 1
	_refresh_equipment_views()
	return ""

func active_gems() -> Array:
	var result: Array = []
	for part in PARTS:
		for item in _sockets[part]:
			result.append(gem_definition(item))
	return result

func gem_definition(item: String) -> Dictionary:
	return catalog.record("gems", int(_gem_defs.get(item, 0))) if catalog != null else {}

func gem_allowed(item: String, part: String) -> bool:
	var definition = gem_definition(item)
	return not definition.is_empty() and part in definition.get("parts", [])

func quality_rank(item: String) -> int:
	return int(gem_definition(item).get("quality_rank", 0))

func same_family(first: String, second: String) -> bool:
	return int(gem_definition(first).get("effect_family_id", -1)) == int(gem_definition(second).get("effect_family_id", -2))

func same_family_slot(part: String, item: String, ignored_slot: int = -1) -> int:
	for index in range(_sockets[part].size()):
		if index != ignored_slot and same_family(_sockets[part][index], item):
			return index
	return -1

func _available_for_part(part: String) -> Array:
	var result: Array = []
	for item in _inventory:
		if not _equipped.has(item) and gem_allowed(item, part):
			result.append(item)
	return result

func _refresh_equipment_views() -> void:
	for part in PARTS:
		for index in range(_sockets[part].size()):
			_equipped[_sockets[part][index]] = {"part": part, "slot": index}
