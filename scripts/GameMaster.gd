extends Node2D

# ==================== 游戏主控脚本 ====================
# 负责: UI管理、输入处理、打字机效果、惊吓值系统、与LogicManager通信

# UI 节点引用
@onready var header_container: HBoxContainer = $CanvasLayer/MainLayout/Header
@onready var script_name_label: Label = $CanvasLayer/MainLayout/Header/ScriptName
@onready var difficulty_label: Label = $CanvasLayer/MainLayout/Header/Difficulty
@onready var terror_value_label: Label = $CanvasLayer/MainLayout/Header/TerrorValue
@onready var status_label: Label = $CanvasLayer/MainLayout/Header/Status
@onready var sense_box: RichTextLabel = $CanvasLayer/MainLayout/SenseBox
@onready var story_log: RichTextLabel = $CanvasLayer/MainLayout/StoryLog
@onready var command_input: LineEdit = $CanvasLayer/MainLayout/InputArea/CommandInput
# @onready var crt_overlay: ColorRect = $CanvasLayer/CRT_Overlay

# 逻辑管理器
@onready var logic_manager: Node = $LogicManager
@onready var audio_manager: Node = $AudioManager

# 游戏状态
var terror_value: int = 0        # 惊吓值 0-100
var sanity_state: String = "理智" # 理智状态
var difficulty: String = "普通"   # 难度
var story_title: String = "平田的世界" # 当前剧本

# 打字机效果
var typewriter_active: bool = false
var typewriter_speed: float = 0.015  # 文字打印速度（秒/字符），可调小以加快
var typewriter_pause: float = 0.15  # 标点符号停顿
var current_text: String = ""
var visible_char_index: int = 0
var typewriter_timer: Timer
var typewriter_callback: Callable = Callable()  # 打字机完成后执行的回调

# 乱码字符集 (惊吓值高时使用)
const GLITCH_CHARS: Array[String] = ["§", "¶", "†", "‡", "▓", "▒", "░", "■", "□", "◆", "◇", "●", "○", "★", "☆", "◈", "◉"]

func _ready():
	print("=== 惊悚乐园 初始化 ===")
	
	# 创建打字机计时器
	_create_typewriter_timer()
	
	# 设置UI样式
	_setup_ui_style()
	
	# 延迟初始化游戏，确保 LogicManager 已加载数据
	call_deferred("_initialize_game")

func _create_typewriter_timer():
	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = true
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(typewriter_timer)

func _setup_ui_style():
	# 设置纯黑背景
	$CanvasLayer/Background.color = Color.BLACK
	
	# 设置等宽字体
	var mono_font = load("res://assets/fonts/JetBrainsMono-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/JetBrainsMono-Regular.ttf") else null
	
	# 加载宋体
	var simsun_font = SystemFont.new()
	simsun_font.font_names = ["SimSun", "宋体"]
	
	# Header 样式 - 白色宋体
	script_name_label.add_theme_font_size_override("font_size", 20)
	script_name_label.add_theme_font_override("font", simsun_font)
	script_name_label.modulate = Color.WHITE
	difficulty_label.add_theme_font_size_override("font_size", 20)
	difficulty_label.add_theme_font_override("font", simsun_font)
	difficulty_label.modulate = Color.WHITE
	terror_value_label.add_theme_font_size_override("font_size", 20)
	terror_value_label.add_theme_font_override("font", simsun_font)
	terror_value_label.modulate = Color.WHITE
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_font_override("font", simsun_font)
	status_label.modulate = Color.WHITE
	
	# SenseBox 样式 - 白色宋体
	sense_box.bbcode_enabled = true
	sense_box.add_theme_font_size_override("normal_font_size", 20)
	sense_box.add_theme_font_override("normal_font", simsun_font)
	sense_box.add_theme_constant_override("line_separation", 8)
	sense_box.modulate = Color.WHITE
	sense_box.custom_minimum_size = Vector2(0, 80)
	
	# StoryLog 样式 - 白色宋体
	story_log.bbcode_enabled = true
	story_log.add_theme_font_size_override("normal_font_size", 20)
	story_log.add_theme_font_override("normal_font", simsun_font)
	story_log.add_theme_constant_override("line_separation", 10)
	story_log.scroll_following = true
	story_log.modulate = Color.WHITE
	
	# 输入框样式 - 白色宋体
	command_input.add_theme_font_size_override("font_size", 20)
	command_input.add_theme_font_override("font", simsun_font)
	command_input.flat = true
	command_input.modulate = Color.WHITE
	
	# 输入前缀样式
	var prefix_label = $CanvasLayer/MainLayout/InputArea/Prefix
	prefix_label.add_theme_font_size_override("font_size", 16)
	prefix_label.add_theme_font_override("font", simsun_font)
	prefix_label.modulate = Color.WHITE

func _initialize_game():
	_update_header()
	_append_system_message("欢迎来到平田的世界。输入 'help' 查看可用指令。")
	
	# 更新感官区
	_update_sense_box()
	
	# 加载初始场景并显示描述（选项在打字机完成后显示）
	var scene_desc = logic_manager.load_scene("living_room")
	append_story_text(scene_desc, true, _show_current_options)
	
	# 输入框自动获取焦点
	command_input.grab_focus()

func _show_current_options():
	# 显示当前场景的选项
	var options = logic_manager.get_current_options()
	if options.size() > 0:
		var options_text = "\n\n"
		for i in range(options.size()):
			options_text += "> %d. %s\n" % [i + 1, options[i]]
		story_log.text += options_text

func _update_header():
	script_name_label.text = "[ 剧本：%s ]" % story_title
	difficulty_label.text = "[ 难度：%s ]" % difficulty
	terror_value_label.text = "[ 惊吓值：%d%% ]" % terror_value
	status_label.text = "[ 状态：%s ]" % sanity_state

# ==================== 打字机效果 ====================

func append_story_text(text: String, with_typewriter: bool = true, on_complete: Callable = Callable()):
	if with_typewriter and not typewriter_active:
		# 开始打字机效果
		current_text = _apply_terror_effects(text)
		visible_char_index = 0
		typewriter_active = true
		typewriter_callback = on_complete
		story_log.text += "\n\n"
		_on_typewriter_tick()
	else:
		# 直接显示
		story_log.text += "\n\n" + _apply_terror_effects(text)
		if on_complete.is_valid():
			on_complete.call()

func _on_typewriter_tick():
	if visible_char_index < current_text.length():
		var char_to_show = current_text[visible_char_index]
		story_log.text += char_to_show
		visible_char_index += 1
		
		# 检查是否为标点符号，增加停顿
		if char_to_show in "，。！？、；：":
			typewriter_timer.start(typewriter_pause)
		else:
			# 惊吓值高时，打字速度不稳定
			var speed = typewriter_speed
			if terror_value > 90:
				speed = randf_range(0.01, 0.08)
			elif terror_value > 50:
				speed = randf_range(0.02, 0.05)
			typewriter_timer.start(speed)
	else:
		typewriter_active = false
		# 打字机效果完成后执行回调
		if typewriter_callback.is_valid():
			typewriter_callback.call()
			typewriter_callback = Callable()

func _apply_terror_effects(text: String) -> String:
	var result = text
	
	# 根据惊吓值添加乱码效果
	if terror_value >= 60:
		var glitch_chance = (terror_value - 50) / 100.0 * 0.1  # 最高约5%乱码率
		var chars = result.split("")
		for i in range(chars.size()):
			if randf() < glitch_chance and not chars[i] in " \n[]/":
				chars[i] = GLITCH_CHARS[randi() % GLITCH_CHARS.size()]
		result = "".join(chars)
	
	# 80% 惊吓值时系统开始"撒谎"
	if terror_value >= 80:
		if "(系统提示：" in result and randf() < 0.3:
			var lies = ["快跑快跑快跑", "它在看着你", "不要回头", "你出不去了"]
			result = "(系统提示：" + lies[randi() % lies.size()] + ")"
	
	return result

# ==================== 输入处理 ====================

func _on_command_input_text_submitted(new_text: String):
	if new_text.strip_edges() == "":
		return
	
	# 显示玩家输入
	story_log.text += "\n\n[ 指令输入 ] > " + new_text
	
	# 清空输入框
	command_input.clear()
	
	# 处理指令
	_process_command(new_text.strip_edges())
	
	# 保持焦点
	command_input.grab_focus()

func _process_command(command: String):
	command = command.to_lower()
	
	# 系统指令
	match command:
		"help", "帮助":
			_show_help()
			return
		"clear", "清屏":
			story_log.clear()
			return
		"quit", "退出":
			get_tree().quit()
			return
		"stats", "状态":
			_show_stats()
			return
	
	# 将指令传递给 LogicManager 处理
	var result = logic_manager.process_command(command)
	if result != "":
		_update_sense_box()
		append_story_text(result, true, _show_current_options)

func _show_help():
	var help_text = """
═══════════════════════════════════════════════
                     可用指令
═══════════════════════════════════════════════
  help / 帮助       - 显示此帮助信息
  clear / 清屏      - 清空叙事区域
  stats / 状态      - 显示当前状态
  quit / 退出       - 退出游戏

  场景指令:
  使用数字 (1, 2, 3...) 或关键词选择选项
  例如: "报纸", "电视", "门"
═══════════════════════════════════════════════"""
	append_story_text(help_text, false)

func _show_stats():
	var stats_text = """
═══════════════════════════════════════════════
  剧本：%s
  难度：%s
  惊吓值：%d%%
  状态：%s
═══════════════════════════════════════════════""" % [story_title, difficulty, terror_value, sanity_state]
	append_story_text(stats_text, false)

# ==================== 更新UI ====================

func _update_sense_box():
	var sense_text = logic_manager.get_current_sense()
	if sense_text != "":
		sense_box.text = "[ 感官捕捉 ]\n>> " + sense_text

func _update_options_display():
	# 已废弃，现在使用 _show_current_options 在打字机完成后显示
	pass

func _append_system_message(message: String):
	append_story_text("(系统提示：%s)" % message, false)

# ==================== 惊吓值操作 ====================

func add_terror(value: int):
	var old_terror = terror_value
	terror_value = clamp(terror_value + value, 0, 100)
	_update_header()
	
	# 惊吓值变化时触发屏幕抖动 (CRT效果已禁用)
	# if value > 0 and crt_overlay.material:
	# 	_trigger_crt_shake()
	
	# 检查状态变化
	if old_terror < 50 and terror_value >= 50:
		sanity_state = "不安"
		_update_header()
	elif old_terror < 80 and terror_value >= 80:
		sanity_state = "恐惧"
		_update_header()
	elif old_terror < 95 and terror_value >= 95:
		sanity_state = "崩溃"
		_update_header()

func _trigger_crt_shake():
	pass
	# 触发CRT抖动效果 (已禁用)
	# var material = crt_overlay.material
	# if material and material is ShaderMaterial:
	# 	material.set_shader_parameter("shake_intensity", 0.02)
	# 	var tween = create_tween()
	# 	tween.tween_method(func(v): material.set_shader_parameter("shake_intensity", v), 0.02, 0.0, 0.5)

# ==================== 公共接口 ====================

func set_story_title(title: String):
	story_title = title
	_update_header()

func set_difficulty(diff: String):
	difficulty = diff
	_update_header()
