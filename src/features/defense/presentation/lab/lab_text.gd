extends RefCounted

static func roster(row: Dictionary) -> String:
	var kind: String = {"hero": "英雄", "enemy": "普通", "elite": "精英", "boss": "首领", "summon": "召唤"}.get(row.kind, row.kind)
	var mode: String = {"normal": "", "immortal": " · 不死", "invulnerable": " · 无敌"}.get(row.survival, "")
	return "#%d %s · %s%s  %s" % [row.id, row.name, kind, mode, "已死亡" if row.dead else "%d/%d" % [row.hp, row.max_hp]]

static func summary(actor: Dictionary) -> String:
	if actor.is_empty(): return "选择战场单位，或从列表选择"
	return "#%d %s  |  生命 %d/%d  护盾 %d\n%s · 目标 #%d · 击杀 %d · 伤害 %.1f" % [actor.id, actor.name, actor.hp, actor.max_hp, actor.shield,
		"已死亡，复活剩余 %.1fs" % (actor.revive_ms / 1000.0) if actor.dead else actor.action, actor.target, actor.kills, actor.stats.damage]

static func status_name(value: Dictionary) -> String:
	var names: Array = []
	if int(value.get("moveFor", 0)) == 1: names.append("禁移")
	if int(value.get("attackFor", 0)) == 1: names.append("禁攻")
	if int(value.get("skillFor", 0)) == 1: names.append("禁技能")
	if value.has("hurtRev"): names.append("周期效果")
	if value.has("shield"): names.append("护盾")
	if not value.get("attributeRev", []).is_empty(): names.append("属性修正")
	return " / ".join(names) if not names.is_empty() else "状态"

static func details(actor: Dictionary) -> String:
	if actor.is_empty(): return "未选中单位。点击战场中的单位查看真实状态。"
	var lines = PackedStringArray([summary(actor), "", "属性：基础 → 最终"])
	for entry in actor.attributes:
		lines.append("%s：%s → %s" % [entry.name, entry.base, entry.value])
	lines.append("\n状态（来源 / 层数 / 剩余毫秒 / 护盾）")
	for entry in actor.statuses: lines.append(JSON.stringify(entry))
	lines.append("\n技能实例（包含强化后的真实参数）")
	for skill in actor.skills:
		lines.append("技能 #%d · 冷却 %dms · 计数 %d · 追猎就绪 %s" % [skill.id, skill.cooldown_ms, skill.count, skill.hunt_ready])
		lines.append(JSON.stringify(skill.data, "  "))
	lines.append("\n属性修饰来源")
	for entry in actor.attributes:
		if entry.trace.size() > 2: lines.append(entry.name + "\n" + JSON.stringify(entry.trace, "  "))
	return "\n".join(lines)

static func log_text(trace: Array, query: String, id: int) -> String:
	var result = PackedStringArray()
	for entry in trace:
		if id != 0 and entry.get("source", 0) != id and entry.get("target", 0) != id and entry.get("unit", 0) != id: continue
		var text = JSON.stringify(entry)
		if query.is_empty() or text.containsn(query): result.append(text)
	return "\n".join(result.slice(maxi(0, result.size() - 150))) if not result.is_empty() else "暂无符合条件的事件。运行战斗后可按 damage / cast / death / status 或编号筛选。"
