extends Node

var current_scene_id: String = ""
var current_scene_data: Dictionary = {}
var scene_history: Array[String] = []

var story_data: Dictionary = {}
var nodes: Dictionary = {}
var start_node: String = "act1_intro"
var story_title: String = "Thriller Paradise"
var story_subtitle: String = ""

var player_inventory: Array[String] = []
var discovered_clues: Array[String] = []
var story_flags: Dictionary = {}
var reality_integrity: int = 100
var reasoning_points: int = 0

var pending_messages: Array[String] = []
var pending_clear_screen: bool = false

@onready var game_master: Node = get_parent()


func _ready() -> void:
	_load_story_data()


func _load_story_data() -> void:
	var file_path = "res://data/hirata_world.json"
	if not FileAccess.file_exists(file_path):
		push_error("Story file not found: %s" % file_path)
		_create_default_story()
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("JSON parse error: %s" % json.get_error_message())
		_create_default_story()
		return

	story_data = json.get_data()
	story_title = str(story_data.get("title", "Thriller Paradise"))
	story_subtitle = str(story_data.get("subtitle", ""))
	start_node = str(story_data.get("start_node", "act1_intro"))
	nodes = story_data.get("nodes", {})


func _create_default_story() -> void:
	story_data = {
		"title": "Thriller Paradise",
		"subtitle": "",
		"start_node": "fallback_intro",
		"nodes": {
			"fallback_intro": {
				"sense": "空气里只有空白。",
				"description": "剧情文件加载失败。请检查 data/hirata_world.json。",
				"options": {}
			}
		}
	}
	story_title = "Thriller Paradise"
	story_subtitle = ""
	start_node = "fallback_intro"
	nodes = story_data["nodes"]


func get_start_node() -> String:
	return start_node


func get_story_title() -> String:
	return story_title


func get_story_subtitle() -> String:
	return story_subtitle


func get_reasoning_points() -> int:
	return reasoning_points


func load_scene(scene_id: String) -> String:
	if not nodes.has(scene_id):
		return "[系统错误] 场景不存在：%s" % scene_id

	current_scene_id = scene_id
	current_scene_data = nodes[scene_id]
	scene_history.append(scene_id)

	_apply_scene_effects(current_scene_data)

	if current_scene_data.has("is_ending"):
		var ending_title = str(current_scene_data.get("ending_title", "")).strip_edges()
		if ending_title != "":
			_queue_message("[color=red]%s[/color]" % ending_title)

	var parts: Array[String] = []
	var narration = str(current_scene_data.get("narration", "")).strip_edges()
	var description = str(current_scene_data.get("description", "")).strip_edges()

	if narration != "":
		parts.append(narration)
	if description != "":
		parts.append(description)

	return "\n\n".join(parts)


func _apply_scene_effects(scene_data: Dictionary) -> void:
	if bool(scene_data.get("clear_screen", false)):
		pending_clear_screen = true

	_apply_task_update(scene_data.get("task_update", {}))
	_apply_add_item(str(scene_data.get("add_item", "")))
	_add_flag(str(scene_data.get("add_flag", "")))
	_execute_enter_events(scene_data.get("on_enter", null))


func _apply_task_update(task_update: Variant) -> void:
	if not (task_update is Dictionary):
		return

	var text = str(task_update.get("text", "")).strip_edges()
	if text == "":
		return

	var color = "yellow"
	match str(task_update.get("type", "")).to_lower():
		"complete":
			color = "lime"
		"update":
			color = "aqua"

	_queue_message("[color=%s]%s[/color]" % [color, text])


func _apply_add_item(item_name: String) -> void:
	var normalized_item = item_name.strip_edges()
	if normalized_item == "":
		return

	if normalized_item not in player_inventory:
		player_inventory.append(normalized_item)
		_queue_message("[color=khaki]获得物品：%s[/color]" % normalized_item)


func _execute_enter_events(event_value: Variant) -> void:
	if event_value == null:
		return

	if event_value is Array:
		for event_item in event_value:
			_apply_enter_event(event_item)
		return

	_apply_enter_event(event_value)


func _apply_enter_event(event_value: Variant) -> void:
	if not (event_value is String):
		return

	var event_name = str(event_value)
	if event_name.begins_with("add_terror_"):
		game_master.add_terror(_parse_suffix_int(event_name, "add_terror_"))
	elif event_name.begins_with("reduce_reality_"):
		var amount = _parse_suffix_int(event_name, "reduce_reality_")
		reality_integrity = max(0, reality_integrity - amount)
		game_master.add_terror(amount)
	elif event_name.begins_with("reasoning_"):
		reasoning_points += _parse_suffix_int(event_name, "reasoning_")
	elif event_name.begins_with("add_flag_"):
		_add_flag(event_name.trim_prefix("add_flag_"))


func _parse_suffix_int(event_name: String, prefix: String) -> int:
	return int(event_name.trim_prefix(prefix))


func get_current_sense() -> String:
	return str(current_scene_data.get("sense", ""))


func get_current_options() -> Array[String]:
	var options: Array[String] = []
	for option_text in _get_available_options().keys():
		options.append(option_text)
	return options


func _get_available_options() -> Dictionary:
	var available: Dictionary = {}
	var options_dict: Dictionary = current_scene_data.get("options", {})
	var conditions_dict: Dictionary = current_scene_data.get("conditions", {})

	for option_text in options_dict.keys():
		var condition = conditions_dict.get(option_text, {})
		if _conditions_met(condition):
			available[option_text] = options_dict[option_text]

	return available


func _conditions_met(condition: Variant) -> bool:
	if not (condition is Dictionary):
		return true

	var requires_item = str(condition.get("requires_item", "")).strip_edges()
	if requires_item != "" and not has_item(requires_item):
		return false

	var requires_flag = str(condition.get("requires_flag", "")).strip_edges()
	if requires_flag != "" and not has_flag(requires_flag):
		return false

	var forbid_flag = str(condition.get("forbid_flag", condition.get("lacks_flag", ""))).strip_edges()
	if forbid_flag != "" and has_flag(forbid_flag):
		return false

	var requires_flags = condition.get("requires_flags", [])
	if requires_flags is Array:
		for flag_name in requires_flags:
			if not has_flag(str(flag_name)):
				return false

	return true


func process_command(command: String) -> String:
	var trimmed = command.strip_edges()
	if trimmed == "":
		return ""

	var hidden_break_result = _try_hidden_break(trimmed)
	if hidden_break_result != "":
		return hidden_break_result

	if trimmed.is_valid_int():
		var option_index = trimmed.to_int() - 1
		var options = get_current_options()
		if option_index >= 0 and option_index < options.size():
			return _execute_option(options[option_index])
		return "无效的选项编号。"

	var available_options = _get_available_options()

	for option_text in available_options.keys():
		if _normalize_input(option_text) == _normalize_input(trimmed):
			return _execute_option(option_text)

	for option_text in available_options.keys():
		if _option_matches(trimmed, option_text):
			return _execute_option(option_text)

	var reasoning_result = _check_builtin_reasoning(trimmed)
	if reasoning_result != "":
		return reasoning_result

	game_master.add_terror(3)
	return _unknown_response()


func _try_hidden_break(command: String) -> String:
	var hidden_breaks = current_scene_data.get("hidden_breaks", [])
	if not (hidden_breaks is Array):
		return ""

	for hidden_break in hidden_breaks:
		if not (hidden_break is Dictionary):
			continue

		var requires_flag = str(hidden_break.get("requires_flag", "")).strip_edges()
		if requires_flag != "" and not has_flag(requires_flag):
			continue

		var forbid_flag = str(hidden_break.get("forbid_flag", hidden_break.get("lacks_flag", ""))).strip_edges()
		if forbid_flag != "" and has_flag(forbid_flag):
			continue

		var intent = str(hidden_break.get("intent", "")).strip_edges()
		var once_flag = "hidden_break_%s_done" % intent if intent != "" else ""
		if once_flag != "" and has_flag(once_flag):
			continue

		var keywords = hidden_break.get("keywords", [])
		if not _keywords_match(command, keywords):
			continue

		if once_flag != "":
			_add_flag(once_flag)

		var terror_change = int(hidden_break.get("terror_change", 0))
		if terror_change != 0:
			game_master.add_terror(terror_change)

		var reasoning_change = int(hidden_break.get("reasoning_change", 0))
		if reasoning_change != 0:
			reasoning_points += reasoning_change

		var break_text = str(hidden_break.get("break_text", "")).strip_edges()
		var next_node = str(hidden_break.get("next_node", "")).strip_edges()
		if next_node == "":
			return break_text

		var next_scene_text = load_scene(next_node)
		if break_text == "":
			return next_scene_text
		if next_scene_text == "":
			return break_text
		return "%s\n\n%s" % [break_text, next_scene_text]

	return ""


func _check_builtin_reasoning(command: String) -> String:
	var builtins: Array[Dictionary] = [
		{
			"id": "newspaper_date_questioned",
			"scene": "check_newspaper",
			"keywords": ["日期", "时间", "今天", "挂历"],
			"text": "你重新盯住了日期。纸张上的油墨像刚印上去，今天这个词也变得格外刺眼。",
			"terror_change": -5,
			"reasoning_change": 5
		}
	]

	for builtin in builtins:
		if current_scene_id != str(builtin.get("scene", "")):
			continue
		if has_flag(str(builtin.get("id", ""))):
			continue
		if not _keywords_match(command, builtin.get("keywords", [])):
			continue

		_add_flag(str(builtin.get("id", "")))
		reasoning_points += int(builtin.get("reasoning_change", 0))
		game_master.add_terror(int(builtin.get("terror_change", 0)))
		return str(builtin.get("text", ""))

	return ""


func _keywords_match(command: String, keywords: Variant) -> bool:
	if not (keywords is Array):
		return false

	var normalized_command = _normalize_input(command)
	for keyword in keywords:
		var normalized_keyword = _normalize_input(str(keyword))
		if normalized_keyword != "" and normalized_command.contains(normalized_keyword):
			return true
	return false


func _option_matches(command: String, option_text: String) -> bool:
	var normalized_command = _normalize_input(command)
	var normalized_option = _normalize_input(option_text)

	if normalized_command.contains(normalized_option) or normalized_option.contains(normalized_command):
		return true

	for keyword in _extract_keywords(option_text):
		var normalized_keyword = _normalize_input(keyword)
		if normalized_keyword != "" and normalized_command.contains(normalized_keyword):
			return true

	return false


func _extract_keywords(option_text: String) -> Array[String]:
	var keywords: Array[String] = []
	var keyword_map = {
		"钥匙": ["钥匙", "key", "钥匙串"],
		"抽屉": ["抽屉", "drawer"],
		"厕所": ["厕所", "洗手间", "bathroom"],
		"报告": ["报告", "文件", "report"],
		"电视": ["电视", "tv", "screen"],
		"报纸": ["报纸", "newspaper"],
		"茶": ["茶", "热茶"],
		"镜子": ["镜子", "mirror"],
		"门": ["门", "door"],
		"观察": ["观察", "查看", "检查"]
	}

	for key in keyword_map.keys():
		if option_text.contains(key):
			keywords.append_array(keyword_map[key])

	return keywords


func _normalize_input(text: String) -> String:
	return text.strip_edges().to_lower()


func _execute_option(option_text: String) -> String:
	var available_options = _get_available_options()
	if not available_options.has(option_text):
		return "这个选项现在不可用。"

	var next_scene = str(available_options[option_text])
	return load_scene(next_scene)


func _unknown_response() -> String:
	var responses = [
		"系统没有理解你的指令。黑暗里只有一阵短促的电流声。",
		"你试着这么做了，但世界没有给出回应。",
		"这个念头没有抓住真正的裂缝，反而让你更不安了。",
		"也许该盯住文本里的矛盾，再试一次。"
	]
	return responses[randi() % responses.size()]


func _queue_message(message: String) -> void:
	if message.strip_edges() != "":
		pending_messages.append(message)


func consume_pending_messages() -> Array[String]:
	var messages = pending_messages.duplicate()
	pending_messages.clear()
	return messages


func consume_clear_screen() -> bool:
	var should_clear = pending_clear_screen
	pending_clear_screen = false
	return should_clear


func get_reality_integrity() -> int:
	return reality_integrity


func has_item(item_name: String) -> bool:
	return item_name in player_inventory


func add_clue(clue: String) -> void:
	if clue not in discovered_clues:
		discovered_clues.append(clue)


func has_flag(flag_name: String) -> bool:
	return bool(story_flags.get(flag_name, false))


func _add_flag(flag_name: String) -> void:
	var normalized_flag = flag_name.strip_edges()
	if normalized_flag != "":
		story_flags[normalized_flag] = true


func has_auto_transition() -> bool:
	return str(current_scene_data.get("auto_next", "")).strip_edges() != ""


func get_auto_next_scene() -> String:
	return str(current_scene_data.get("auto_next", ""))


func get_auto_delay() -> float:
	return float(current_scene_data.get("auto_delay", 2.0))
