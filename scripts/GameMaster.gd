extends Node2D

@onready var script_name_label: Label = $CanvasLayer/MainLayout/Header/ScriptName
@onready var difficulty_label: Label = $CanvasLayer/MainLayout/Header/Difficulty
@onready var terror_value_label: Label = $CanvasLayer/MainLayout/Header/TerrorValue
@onready var status_label: Label = $CanvasLayer/MainLayout/Header/Status
@onready var sense_box: RichTextLabel = $CanvasLayer/MainLayout/SenseBox
@onready var story_log: RichTextLabel = $CanvasLayer/MainLayout/StoryLog
@onready var command_input: LineEdit = $CanvasLayer/MainLayout/InputArea/CommandInput
@onready var prefix_label: Label = $CanvasLayer/MainLayout/InputArea/Prefix
@onready var crt_overlay: ColorRect = $CanvasLayer/CRT_Overlay

@onready var logic_manager: Node = $LogicManager
@onready var audio_manager: Node = $AudioManager

var terror_value: int = 0
var sanity_state: String = "理智"
var difficulty: String = "普通"
var story_title: String = "平田的世界"

var typewriter_active: bool = false
var typewriter_speed: float = 0.02
var typewriter_pause: float = 0.18
var typewriter_timer: Timer
var typewriter_callback: Callable = Callable()
var typewriter_segment_text: String = ""
var typewriter_segment_index: int = 0
var typewriter_target_visible: int = 0
var current_visible_characters: int = 0

var story_buffer: String = ""

const GLITCH_CHARS: Array[String] = ["#", "%", "&", "?", "/", "\\", "*", "+", "~"]


func _ready() -> void:
	_create_typewriter_timer()
	_setup_ui_style()
	call_deferred("_initialize_game")


func _create_typewriter_timer() -> void:
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(typewriter_timer)


func _setup_ui_style() -> void:
	$CanvasLayer/Background.color = Color.BLACK

	var ui_font = SystemFont.new()
	ui_font.font_names = ["JetBrains Mono", "Consolas", "SimSun", "Microsoft YaHei UI"]

	for label in [script_name_label, difficulty_label, terror_value_label, status_label]:
		label.add_theme_font_override("font", ui_font)
		label.add_theme_font_size_override("font_size", 18)
		label.modulate = Color.WHITE

	sense_box.bbcode_enabled = true
	sense_box.add_theme_font_override("normal_font", ui_font)
	sense_box.add_theme_font_size_override("normal_font_size", 20)
	sense_box.add_theme_constant_override("line_separation", 8)
	sense_box.modulate = Color.WHITE

	story_log.bbcode_enabled = true
	story_log.add_theme_font_override("normal_font", ui_font)
	story_log.add_theme_font_size_override("normal_font_size", 20)
	story_log.add_theme_constant_override("line_separation", 10)
	story_log.scroll_following = true
	story_log.modulate = Color.WHITE

	command_input.add_theme_font_override("font", ui_font)
	command_input.add_theme_font_size_override("font_size", 18)
	command_input.flat = true
	command_input.modulate = Color.WHITE

	prefix_label.add_theme_font_override("font", ui_font)
	prefix_label.add_theme_font_size_override("font_size", 16)
	prefix_label.modulate = Color.WHITE


func _initialize_game() -> void:
	story_title = logic_manager.get_story_title()
	_update_header()

	var subtitle = logic_manager.get_story_subtitle().strip_edges()
	if subtitle != "":
		_append_system_message("欢迎来到%s。%s" % [story_title, subtitle])
	else:
		_append_system_message("欢迎来到%s。输入 help 查看可用指令。" % story_title)

	var start_node = logic_manager.get_start_node()
	_present_scene(logic_manager.load_scene(start_node))


func _present_scene(scene_text: String, with_typewriter: bool = true) -> void:
	if logic_manager.consume_clear_screen():
		_clear_story_log()

	_update_sense_box()

	var sections: Array[String] = []
	var pending_messages = logic_manager.consume_pending_messages()
	for pending_message in pending_messages:
		sections.append(pending_message)

	var trimmed_scene_text = scene_text.strip_edges()
	if trimmed_scene_text != "":
		sections.append(trimmed_scene_text)

	if sections.is_empty():
		_show_current_options()
		return

	append_story_text("\n\n".join(sections), with_typewriter, _show_current_options)


func _show_current_options() -> void:
	if logic_manager.has_auto_transition():
		_schedule_auto_transition()
		return

	var options = logic_manager.get_current_options()
	if options.is_empty():
		return

	var option_lines: Array[String] = []
	for i in range(options.size()):
		option_lines.append("> %d. %s" % [i + 1, options[i]])

	append_story_text("\n".join(option_lines), false)


func _schedule_auto_transition() -> void:
	command_input.editable = false
	var timer = get_tree().create_timer(logic_manager.get_auto_delay())
	timer.timeout.connect(func():
		var next_scene = logic_manager.get_auto_next_scene()
		_present_scene(logic_manager.load_scene(next_scene))
	)


func _update_header() -> void:
	script_name_label.text = "[ 剧本：%s ]" % story_title
	difficulty_label.text = "[ 难度：%s ]" % difficulty
	terror_value_label.text = "[ 惊吓值：%d%% ]" % terror_value
	status_label.text = "[ 状态：%s ]" % sanity_state


func append_story_text(text: String, with_typewriter: bool = true, on_complete: Callable = Callable()) -> void:
	var processed_text = _apply_terror_effects(text)
	var segment_bbcode = processed_text if story_buffer == "" else "\n\n" + processed_text
	var segment_plain = _strip_supported_bbcode(segment_bbcode)

	var previous_total = story_log.get_total_character_count()
	story_buffer += segment_bbcode
	story_log.text = story_buffer

	if with_typewriter:
		command_input.editable = false
		typewriter_active = true
		typewriter_callback = on_complete
		typewriter_segment_text = segment_plain
		typewriter_segment_index = 0
		typewriter_target_visible = story_log.get_total_character_count()
		current_visible_characters = previous_total
		story_log.visible_characters = current_visible_characters
		_on_typewriter_tick()
		return

	story_log.visible_characters = -1
	if on_complete.is_valid():
		on_complete.call()


func _on_typewriter_tick() -> void:
	if current_visible_characters >= typewriter_target_visible:
		typewriter_active = false
		story_log.visible_characters = -1
		command_input.editable = true
		command_input.grab_focus()
		if typewriter_callback.is_valid():
			typewriter_callback.call()
			typewriter_callback = Callable()
		return

	current_visible_characters += 1
	story_log.visible_characters = current_visible_characters

	var current_char = ""
	if typewriter_segment_index < typewriter_segment_text.length():
		current_char = typewriter_segment_text[typewriter_segment_index]
		typewriter_segment_index += 1

	var delay = typewriter_speed
	if current_char in [",", ".", "!", "?", "，", "。", "！", "？", "：", "；"]:
		delay = typewriter_pause
	elif terror_value >= 90:
		delay = randf_range(0.01, 0.08)
	elif terror_value >= 60:
		delay = randf_range(0.015, 0.05)

	typewriter_timer.start(delay)


func _apply_terror_effects(text: String) -> String:
	var result = text

	if terror_value >= 80 and result.begins_with("(系统提示：") and randf() < 0.3:
		var lies = [
			"快跑。",
			"它已经发现你了。",
			"不要回头。",
			"这里根本没有出口。"
		]
		result = "(系统提示：%s)" % lies[randi() % lies.size()]

	if terror_value >= 60 and not _contains_bbcode_markup(result):
		var glitch_chance = clamp((terror_value - 50) / 100.0 * 0.1, 0.0, 0.08)
		var chars = result.split("")
		for i in range(chars.size()):
			if chars[i] in [" ", "\n", "\t"]:
				continue
			if randf() < glitch_chance:
				chars[i] = GLITCH_CHARS[randi() % GLITCH_CHARS.size()]
		result = "".join(chars)

	return result


func _contains_bbcode_markup(text: String) -> bool:
	return text.contains("[color=") or text.contains("[/color]") or text.contains("[s]") or text.contains("[/s]")


func _strip_supported_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[(?:/?s|/?color(?:=[^\\]]+)?)\\]")
	return regex.sub(text, "", true)


func _on_command_input_text_submitted(new_text: String) -> void:
	var trimmed = new_text.strip_edges()
	if trimmed == "" or typewriter_active:
		return

	append_story_text("[ 指令输入 ] > %s" % trimmed, false)
	command_input.clear()
	_process_command(trimmed)


func _process_command(command: String) -> void:
	var normalized = command.to_lower()

	match normalized:
		"help", "帮助":
			_show_help()
			return
		"clear", "清屏":
			_clear_story_log()
			_update_sense_box()
			return
		"quit", "exit", "退出":
			get_tree().quit()
			return
		"stats", "状态":
			_show_stats()
			return

	var result = logic_manager.process_command(command)
	if result != "":
		_present_scene(result)


func _show_help() -> void:
	var help_text = """
[ 可用指令 ]
help / 帮助  : 显示帮助
clear / 清屏 : 清空叙事区
stats / 状态 : 查看当前状态
quit / 退出  : 退出游戏

[ 场景交互 ]
1. 输入数字选择选项，如 `1`
2. 也可以直接输入关键词，如 `钥匙`、`抽屉`、`观察`
3. 某些矛盾需要主动质问，系统不会把答案放进选项里
"""
	append_story_text(help_text, false)


func _show_stats() -> void:
	var stats_text = """
[ 当前状态 ]
剧本：%s
难度：%s
惊吓值：%d%%
状态：%s
现实完整度：%d%%
推理进度：%d
""" % [
		story_title,
		difficulty,
		terror_value,
		sanity_state,
		logic_manager.get_reality_integrity(),
		logic_manager.get_reasoning_points()
	]
	append_story_text(stats_text, false)


func _update_sense_box() -> void:
	var sense_text = logic_manager.get_current_sense().strip_edges()
	if sense_text == "":
		sense_box.text = ""
		return

	sense_box.text = "[ 感官捕捉 ]\n>> %s" % sense_text


func _append_system_message(message: String) -> void:
	append_story_text("(系统提示：%s)" % message, false)


func _clear_story_log() -> void:
	story_buffer = ""
	story_log.text = ""
	story_log.visible_characters = -1


func add_terror(value: int) -> void:
	var previous_terror = terror_value
	terror_value = clamp(terror_value + value, 0, 100)

	if terror_value >= 95:
		sanity_state = "崩溃"
	elif terror_value >= 80:
		sanity_state = "恐惧"
	elif terror_value >= 50:
		sanity_state = "不安"
	else:
		sanity_state = "理智"

	_update_header()
	audio_manager.update_heartbeat(terror_value / 100.0)

	if terror_value != previous_terror:
		_trigger_crt_shake(abs(value))


func _trigger_crt_shake(amount: int = 10) -> void:
	var material = crt_overlay.material
	if material == null or not (material is ShaderMaterial):
		return

	var intensity = clamp(0.005 + float(amount) / 1000.0, 0.005, 0.03)
	material.set_shader_parameter("shake_intensity", intensity)

	var tween = create_tween()
	tween.tween_method(
		func(v: float) -> void:
			material.set_shader_parameter("shake_intensity", v),
		intensity,
		0.0,
		0.35
	)


func set_story_title(title: String) -> void:
	story_title = title
	_update_header()


func set_difficulty(diff: String) -> void:
	difficulty = diff
	_update_header()
