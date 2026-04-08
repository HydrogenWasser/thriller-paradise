extends Node

# ==================== 剧本逻辑管理器 ====================
# 负责: JSON剧本解析、状态机管理、场景切换、指令解析

# 当前场景数据
var current_scene_id: String = ""
var current_scene_data: Dictionary = {}
var scene_history: Array[String] = []

# 剧本数据
var story_data: Dictionary = {}
var nodes: Dictionary = {}
var start_node: String = "living_room"  # 默认起始节点

# 玩家状态
var player_inventory: Array[String] = []
var discovered_clues: Array[String] = []
var reality_integrity: int = 100  # 现实完整度

# 参考 GameMaster
@onready var game_master: Node2D = get_parent()

func _ready():
	_load_story_data()

func _load_story_data():
	var file_path = "res://data/hirata_world.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			story_data = json.get_data()
			nodes = story_data.get("nodes", {})
			start_node = story_data.get("start_node", "living_room")
			print("剧本数据加载成功，共 %d 个场景，起始节点: %s" % [nodes.size(), start_node])
		else:
			push_error("JSON解析错误: " + json.get_error_message())
			# 解析失败时使用默认数据
			_create_default_story()
	else:
		push_error("剧本文件不存在: " + file_path)
		# 使用默认数据
		_create_default_story()

func get_start_node() -> String:
	return start_node

func _create_default_story():
	# 默认剧本数据（备用）
	story_data = {
		"start_node": "living_room",
		"nodes": {
			"living_room": {
				"sense": "空气中弥漫着陈旧的草席味。",
				"description": "这里是一个普通的日式客厅。\n\n四面是略显斑驳的土墙，脚下的榻榻米散发着陈腐的草席味。一台笨重的显像管电视占据了角落，屏幕满是闪烁的灰色雪花。\n\n几张发黄的报纸被随意地丢弃在低矮的茶几上，边缘卷曲，像是被火燎过，又像是被某种液体浸透后干涸的痕迹。\n\n你感觉到一种强烈的违和感，仿佛墙壁后的阴影正在蠕动。",
				"options": {
					"观察报纸": "check_newspaper",
					"走向电视": "tv_static",
					"尝试拉开玄关的大门": "try_door",
					"检查草席": "check_tatami"
				},
				"enter_events": []
			},
			"check_newspaper": {
				"sense": "墨水味道异常刺鼻，像是刚印出来不久。",
				"description": "日期是4月14日。所有的头版头条都在报道同一个人的失踪，但照片被涂黑了。你凑近看，发现涂黑的笔触还没干。\n\n更令人不安的是，报纸下方印着今天的日期。",
				"options": {
					"返回客厅": "living_room"
				},
				"on_enter": "add_terror_10"
			},
			"tv_static": {
				"sense": "静电的噼啪声中夹杂着某种低频的嗡鸣。",
				"description": "雪花的沙沙声在你靠近时突然消失了。屏幕黑了下去，映出了你的脸——\n\n或者说，映出了一个正站在你身后，低头看着你的'东西'。\n\n你猛地回头，身后空无一人。再看屏幕，只有雪花在无声地闪烁。",
				"options": {
					"关闭电视": "tv_off",
					"返回客厅": "living_room"
				},
				"on_enter": "add_terror_15"
			},
			"tv_off": {
				"sense": "安静得能听见自己的心跳。",
				"description": "你按下电源按钮。电视屏幕缓缓暗了下去。\n\n但在完全黑屏前的最后一刻，你似乎看到屏幕里有一只手正在向外伸...\n\n你眨了眨眼，那只是一个幻觉。",
				"options": {
					"返回客厅": "living_room"
				},
				"on_enter": "add_terror_10"
			},
			"try_door": {
				"sense": "把手冰冷得刺骨。",
				"description": "你用力一拉，门缝后面不是走廊，而是无尽的黑色。\n\n你感到一阵眩晕，仿佛有什么东西在黑暗中凝视着你。\n\n系统警告：[现实完整度下降 5%]",
				"options": {
					"关上门": "living_room",
					"踏入黑暗": "void_space"
				},
				"on_enter": "reduce_reality_5"
			},
			"check_tatami": {
				"sense": "草席下似乎藏着什么。",
				"description": "你掀开草席的一角，发现下面压着一张泛黄的照片。\n\n照片上是你自己，站在一个陌生的房间里，脸上带着诡异的微笑。\n\n照片背面用红笔写着：'欢迎回家'。",
				"options": {
					"收好照片": "take_photo",
					"放回原处": "living_room"
				},
				"on_enter": "add_terror_20"
			},
			"take_photo": {
				"sense": "照片摸起来异常冰冷。",
				"description": "你将照片收入口袋。无论走到哪里，你总感觉照片里的自己在看着你。\n\n你获得了物品：[神秘照片]",
				"options": {
					"返回客厅": "living_room"
				},
				"on_enter": "add_item_photo"
			},
			"void_space": {
				"sense": "这里没有上下左右，只有无尽的坠落感。",
				"description": "你踏入了黑暗。\n\n重力消失了。声音消失了。连你自己也逐渐消失了。\n\n这就是故事的终点吗？\n\n还是说，这才是真正的开始...",
				"options": {
					"重新开始": "living_room"
				},
				"on_enter": "add_terror_50"
			}
		}
	}
	nodes = story_data.get("nodes", {})

# ==================== 场景管理 ====================

func load_scene(scene_id: String) -> String:
	if not nodes.has(scene_id):
		return "[系统错误] 场景 '%s' 不存在" % scene_id
	
	current_scene_id = scene_id
	current_scene_data = nodes[scene_id]
	scene_history.append(scene_id)
	
	# 执行进入事件
	_execute_enter_events(current_scene_data.get("on_enter", ""))
	
	# 构建场景描述：优先使用 narration（剧情旁白），否则使用 description
	var narration = current_scene_data.get("narration", "")
	var description = current_scene_data.get("description", "")
	
	if narration != "":
		return narration + "\n\n" + description
	else:
		return description

func get_current_sense() -> String:
	return current_scene_data.get("sense", "")

func get_current_options() -> Array[String]:
	var options: Array[String] = []
	var options_dict = current_scene_data.get("options", {})
	for key in options_dict.keys():
		options.append(key)
	return options

func _execute_enter_events(event_string: String):
	if event_string == "":
		return
	
	match event_string:
		"add_terror_10":
			game_master.add_terror(10)
		"add_terror_15":
			game_master.add_terror(15)
		"add_terror_20":
			game_master.add_terror(20)
		"add_terror_50":
			game_master.add_terror(50)
		"reduce_reality_5":
			reality_integrity -= 5
			game_master.add_terror(5)
		"add_item_photo":
			player_inventory.append("神秘照片")
			discovered_clues.append("你的照片")

# ==================== 指令解析 ====================

func process_command(command: String) -> String:
	command = command.strip_edges()
	
	# 检查是否为数字选项
	if command.is_valid_int():
		var index = command.to_int() - 1
		var options = get_current_options()
		if index >= 0 and index < options.size():
			return _execute_option(options[index])
		else:
			return "无效的选择。"
	
	# 关键词匹配
	var options_dict = current_scene_data.get("options", {})
	
	# 首先尝试精确匹配
	if options_dict.has(command):
		return _execute_option(command)
	
	# 模糊匹配
	for option_text in options_dict.keys():
		# 检查指令是否包含在选项中，或选项包含指令
		if command in option_text or option_text in command:
			return _execute_option(option_text)
		
		# 检查关键词匹配
		var keywords = _extract_keywords(option_text)
		for keyword in keywords:
			if command == keyword or command.contains(keyword):
				return _execute_option(option_text)
	
	# 检查推理点（脑补力判定）
	if _check_reasoning(command):
		return "你察觉到了某种异常...\n\n[隐藏剧情触发]"
	
	# 未识别的指令
	var unknown_responses = [
		"你不确定该如何做。",
		"这个指令无效。",
		"你尝试这样做，但什么都没有发生。",
		"也许应该试试其他方法。"
	]
	return unknown_responses[randi() % unknown_responses.size()]

func _extract_keywords(option_text: String) -> Array[String]:
	# 从选项文本中提取关键词
	var keywords: Array[String] = []
	
	# 常见物品/动作关键词映射
	var keyword_map = {
		"报纸": ["报纸", "newspaper", "paper"],
		"电视": ["电视", "tv", "television", "screen"],
		"门": ["门", "door", "大门", "玄关"],
		"草席": ["草席", "榻榻米", "tatami", "席子"],
		"照片": ["照片", "photo", "picture", "相片"]
	}
	
	for key in keyword_map.keys():
		if key in option_text:
			keywords.append_array(keyword_map[key])
	
	return keywords

func _execute_option(option_text: String) -> String:
	var options_dict = current_scene_data.get("options", {})
	if not options_dict.has(option_text):
		return "无效的选项。"
	
	var next_scene = options_dict[option_text]
	return load_scene(next_scene)

# ==================== 脑补力判定 ====================

func _check_reasoning(command: String) -> bool:
	# 检查玩家是否发现了文本中的矛盾
	# 这是一个隐藏系统，用于奖励仔细阅读的玩家
	
	var reasoning_clues = {
		"检查消失的碗": {
			"check": func(): return "碗" in command and current_scene_id == "living_room",
			"reward": "你注意到茶几上应该有三只碗，但现在只看到两只。第三只碗去哪了？"
		},
		"检查日期": {
			"check": func(): return ("日期" in command or "时间" in command) and current_scene_id == "check_newspaper",
			"reward": "你仔细查看报纸，发现日期每天都在变化，就像报纸是实时印刷的一样。"
		}
	}
	
	for clue_name in reasoning_clues.keys():
		var clue = reasoning_clues[clue_name]
		if clue.check.call():
			if clue_name not in discovered_clues:
				discovered_clues.append(clue_name)
				game_master.add_terror(-5)  # 发现真相降低恐惧
				return true
	
	return false

# ==================== 公共接口 ====================

func get_reality_integrity() -> int:
	return reality_integrity

func has_item(item_name: String) -> bool:
	return item_name in player_inventory

func add_clue(clue: String):
	if clue not in discovered_clues:
		discovered_clues.append(clue)

func has_auto_transition() -> bool:
	return current_scene_data.get("auto_next", "") != ""

func get_auto_next_scene() -> String:
	return current_scene_data.get("auto_next", "")

func get_auto_delay() -> float:
	return current_scene_data.get("auto_delay", 2.0)
