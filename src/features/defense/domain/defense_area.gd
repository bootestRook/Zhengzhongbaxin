class_name DefenseArea
extends RefCounted

## Converts a cumulative circular-area increase into its radius.
## Percentages are area changes, so they are summed before this conversion.
static func radius(base_radius: float, area_percent: float) -> float:
	return maxf(0.0, base_radius) * sqrt(maxf(0.0, 1.0 + area_percent / 100.0))
