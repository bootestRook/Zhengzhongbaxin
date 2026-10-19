extends DefenseSpace

# Reproduce the old slot replacement only for the comparison fixture.
func bind(enemy: Dictionary, blocker: Dictionary) -> void:
	if enemy.blocked_by > 0:
		occupied.get(enemy.blocked_by, []).erase(enemy)
	enemy.blocked_by = blocker.get("id", 0)
	if enemy.blocked_by > 0:
		if not occupied.has(enemy.blocked_by):
			occupied[enemy.blocked_by] = []
		occupied[enemy.blocked_by].append(enemy)
