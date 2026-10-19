extends VBoxContainer

var option_id: int = 0
var count: int = 0

func configure(option: Dictionary, selected_count: int) -> void:
	option_id = int(option.id)
	count = selected_count
	$Heading/Line/Name.text = option.title
	$Heading/Line/Count.text = "X%d" % count if count > 1 else ""
	$Heading/Line/Count.visible = count > 1
	# Add literal text so status brackets remain the exact source wording.
	var description: String = option.description
	var numbers = RegEx.new()
	assert(numbers.compile("[-+]?\\d+(?:\\.\\d+)?%?") == OK)
	$Description.clear()
	var offset: int = 0
	for match_value in numbers.search_all(description):
		$Description.add_text(description.substr(offset, match_value.get_start() - offset))
		$Description.push_color(Color("28712c"))
		$Description.add_text(match_value.get_string())
		$Description.pop()
		offset = match_value.get_end()
	$Description.add_text(description.substr(offset))
