## 游戏管理器（单例）
## 管理全局流程状态、当前存档和场景切换，不持有战斗单位
extends Node

const ProgressionManagerScript = preload("res://scripts/game/progression_manager.gd")
const DialogueScene = preload("res://scenes/dialogue.tscn")

signal save_loaded(slot: int)
signal save_created(slot: int)
signal inventory_changed()
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)
signal dialogue_finished(dialogue_id: String)

enum GameState {
	BOOT,
	MAIN_MENU,
	BASE,
	BATTLE,
	MISSION_RESULT,
	SETTINGS,
}

var current_state: GameState = GameState.BOOT
var current_save: Dictionary = {}
var current_slot: int = 0
var current_level_id: String = ""
var current_map_data: Dictionary = {}

## 流程状态：仅用于记录，不持有战斗单位
var battle_result: Dictionary = {}
var pending_level_id: String = ""

## 待展示的成就通知队列（场景切换间保留）
var pending_achievement_notifications: Array[Dictionary] = []

## 进度管理器实例
var progression = null

func _ready() -> void:
	current_save = SaveManager.create_default_save()
	progression = ProgressionManagerScript.new()
	add_child(progression)

## 开始新游戏（槽位 0 为自动存档）
func new_game(slot: int = 0) -> void:
	current_slot = slot
	current_save = SaveManager.create_default_save()
	# 初始化角色队伍
	current_save.characters = progression.create_starter_roster()
	# 初始资源
	current_save.resources.credit = 500
	SaveManager.save_game(current_save, current_slot)
	save_created.emit(current_slot)
	go_to_base()

## 测试专用：初始化新游戏存档但不切换场景
## 供无头测试验证流程状态交接，不复制生产逻辑
func begin_new_game_for_test(slot: int) -> Dictionary:
	current_slot = slot
	current_save = SaveManager.create_default_save()
	current_save.characters = progression.create_starter_roster()
	current_save.resources.credit = 500
	current_state = GameState.BASE
	SaveManager.save_game(current_save, current_slot)
	return current_save

## 继续游戏（读取最新有效存档）
func continue_game() -> bool:
	for slot in range(SaveManager.MAX_LOCAL_SAVES):
		var data = SaveManager.load_game(slot)
		if not data.is_empty():
			current_slot = slot
			current_save = data
			save_loaded.emit(current_slot)
			go_to_base()
			return true
	return false

## 加载指定存档槽位
func load_slot(slot: int) -> bool:
	var data = SaveManager.load_game(slot)
	if data.is_empty():
		return false
	current_slot = slot
	current_save = data
	save_loaded.emit(current_slot)
	return true

## 保存当前游戏
func save_current() -> bool:
	if current_save.is_empty():
		return false
	return SaveManager.save_game(current_save, current_slot)

## 完成关卡并更新存档
func complete_mission(result: Dictionary) -> void:
	var level_id = result.get("level_id", current_level_id)
	var rating = result.get("rating", 0)

	var progress = current_save.get("campaign_progress", {})
	var completed_missions: Array = progress.get("completed_missions", []).duplicate()
	var is_first_clear: bool = not (level_id in completed_missions)
	if is_first_clear:
		completed_missions.append(level_id)
	progress["completed_missions"] = completed_missions

	progress["mission_ratings"][level_id] = rating

	var next_id = CampaignRepository.get_next_level(level_id)
	if next_id != "":
		var next_level = CampaignRepository.get_level(next_id)
		progress["current_mission"] = next_id
		progress["current_chapter"] = next_level.get("chapter", progress.get("current_chapter", 1))
	else:
		progress["current_mission"] = level_id

	# 战斗层只传基础奖励。首通奖励必须在这里按存档进度判定，避免重玩重复发放。
	var rewards: Dictionary = result.get("rewards", {}).duplicate(true)
	if is_first_clear:
		var level_data := CampaignRepository.get_level(level_id)
		var first_clear_rewards: Dictionary = level_data.get("rewards", {}).get("first_clear", {})
		rewards["credit"] = rewards.get("credit", 0) + first_clear_rewards.get("credit", 0)
		rewards["intel"] = rewards.get("intel", 0) + first_clear_rewards.get("intel", 0)
		var loot_id := str(first_clear_rewards.get("loot", ""))
		if not loot_id.is_empty():
			var loot_data := GameData.get_weapon(loot_id)
			if loot_data.is_empty():
				loot_data = GameData.get_item(loot_id)
			if not loot_data.is_empty():
				var inventory = current_save.get("inventory", {})
				inventory[loot_id] = inventory.get(loot_id, 0) + 1
				current_save["inventory"] = inventory
				result["loot"] = [{"id": loot_id, "name": loot_data.get("name", loot_id)}]
			else:
				push_warning("First-clear loot is not defined: %s" % loot_id)
		# 结算界面消费这一字段，避免玩家在基地列表中才发现新机制已可用。
		result["new_unlocks"] = level_data.get("new_unlocks", []).duplicate()
		result["first_clear"] = true
	else:
		result["first_clear"] = false
		result["new_unlocks"] = []
	result["rewards"] = rewards

	# 累计资源
	var resources = current_save.get("resources", {})
	resources["credit"] = resources.get("credit", 0) + rewards.get("credit", 0)
	resources["intel"] = resources.get("intel", 0) + rewards.get("intel", 0)

	# 角色经验
	var xp_reward = rewards.get("exp", rewards.get("xp", 50 + rating * 25))
	var characters = current_save.get("characters", [])
	for i in range(characters.size()):
		# 只给参战角色（存活的）加经验
		if i < result.get("survivor_count", characters.size()):
			characters[i] = progression.add_xp(characters[i], xp_reward)
	current_save["characters"] = characters

	# 统计
	var stats = current_save.get("stats_tracking", {})
	stats["total_missions"] = stats.get("total_missions", 0) + 1

	current_save["campaign_progress"] = progress
	current_save["resources"] = resources
	current_save["stats_tracking"] = stats
	if is_first_clear and not result.get("loot", []).is_empty():
		inventory_changed.emit()

	# 成就检查
	var survived_count = result.get("survivor_count", result.get("units_survived", 0))
	_check_achievements(result, rating, survived_count)

	# 章节完成检查：首通章节最后一关时设置 chapter_N_completed 旗标并安排通知
	if is_first_clear and victory_result_is_win(result):
		_check_chapter_completion(level_id, progress)

	# 持久化战斗遥测（胜利场次）
	_record_battle_telemetry(stats, result)

	SaveManager.save_game(current_save, current_slot)

## 判断 battle result 是否为胜利（complete_mission 仅在胜利时调用，但保持防御性）
func victory_result_is_win(result: Dictionary) -> bool:
	return result.get("result", "victory") == "victory"

## 检查关卡是否为其所在章节的最后一关，若是则标记章节完成并安排通知
## chapter_N_completed 旗标只在首通章节末关时设置一次，重复通关不重复触发通知
func _check_chapter_completion(level_id: String, progress: Dictionary) -> void:
	var level = CampaignRepository.get_level(level_id)
	if level.is_empty():
		return
	# 使用与 _check_achievements 相同的类型（不强制 int 转换，避免字典键类型不匹配）
	var chapter = level.get("chapter", 1)
	# 该章节是否还有未完成的后续关卡
	var chapter_missions = CampaignRepository.get_chapter_levels(chapter)
	if chapter_missions.is_empty():
		return
	# 若当前关不是该章节最后一关，则不触发章节完成
	if chapter_missions[chapter_missions.size() - 1] != level_id:
		return
	var completed: Array = progress.get("completed_missions", [])
	var flag_key = "chapter_%d_completed" % int(chapter)
	# 已标记过则不重复触发
	if progress.get("story_flags", {}).get(flag_key, false):
		return
	# 验证该章节所有关卡均已完成（防御性检查）
	for mid in chapter_missions:
		if not mid in completed:
			return
	# 设置章节完成旗标
	var flags = progress.get("story_flags", {})
	flags[flag_key] = true
	# 同时设置 chapter_N_clear 别名旗标，便于对话系统查询
	flags["chapter_%d_clear" % int(chapter)] = true
	progress["story_flags"] = flags
	# 章节完成通知由 _check_achievements 的 chapter_N_clear 成就处理，此处不重复入队
	print("章节完成：第%d章 - %s" % [int(chapter), CampaignRepository.get_chapter_name(int(chapter))])

## 任务失败恢复：仅记录失败统计，不修改关卡进度、资源或角色
## 玩家可在 MissionResult 界面选择重试或返回基地，主线不会被锁定
func fail_mission(result: Dictionary) -> void:
	var level_id = result.get("level_id", current_level_id)

	# 仅更新失败统计，不修改 campaign_progress / resources / characters
	var stats = current_save.get("stats_tracking", {})
	stats["total_failures"] = stats.get("total_failures", 0) + 1
	# 记录该关卡的失败次数（不覆盖 rating，rating 仅在胜利时写入）
	var fail_count_map = stats.get("failure_counts", {})
	fail_count_map[level_id] = fail_count_map.get(level_id, 0) + 1
	stats["failure_counts"] = fail_count_map
	# 记录最近失败关卡，便于调试和后续分析
	stats["last_failed_mission"] = level_id
	# 持久化战斗遥测（含失败场次，便于分析卡点）
	_record_battle_telemetry(stats, result)
	current_save["stats_tracking"] = stats

	# 失败时也持久化一次存档，但只写统计字段；这不会破坏已完成的关卡进度
	# 也不会从 completed_missions 中移除任何条目，因此不会产生死档
	SaveManager.save_game(current_save, current_slot)

## 把战斗遥测写入 stats_tracking.battle_history（限定最大条数避免无限增长）
func _record_battle_telemetry(stats: Dictionary, result: Dictionary) -> void:
	if not result.has("telemetry"):
		return
	var history = stats.get("battle_history", [])
	history.append(result["telemetry"])
	# 仅保留最近 50 场战斗的遥测，避免存档膨胀
	while history.size() > 50:
		history.pop_front()
	stats["battle_history"] = history

## 获取当前队伍角色列表
func get_roster() -> Array:
	return current_save.get("characters", [])

## 检查并解锁成就
func _check_achievements(result: Dictionary, rating: int, survived: int) -> void:
	var unlocked = current_save.get("achievements_unlocked", {})
	var stats = current_save.get("stats_tracking", {})
	var new_unlocks = []

	# first_blood: 完成第一场战斗
	if not unlocked.has("first_blood"):
		unlocked["first_blood"] = true
		new_unlocks.append("first_blood")

	# first_clear: 首次通关
	if not unlocked.has("first_clear"):
		unlocked["first_clear"] = true
		new_unlocks.append("first_clear")

	# zero_casualty: 零阵亡
	if survived == result.get("units_total", 0) and not unlocked.has("zero_casualty"):
		unlocked["zero_casualty"] = true
		new_unlocks.append("zero_casualty")

	# 速通成就：5回合内通关
	if result.get("turns", 99) <= 5 and not unlocked.has("speedrun_ch1"):
		unlocked["speedrun_ch1"] = true
		new_unlocks.append("speedrun_ch1")

	# 章节通关成就
	var level_id = result.get("level_id", "")
	var chapter = CampaignRepository.get_level(level_id).get("chapter", 0)
	var chapter_key = "chapter_%d_clear" % chapter
	if not unlocked.has(chapter_key):
		# 检查该章节是否全部完成
		var chapter_levels = CampaignRepository.get_chapter_levels(chapter)
		var completed = current_save.get("campaign_progress", {}).get("completed_missions", [])
		var all_done = true
		for cl in chapter_levels:
			if not cl in completed:
				all_done = false
				break
		if all_done:
			unlocked[chapter_key] = true
			new_unlocks.append(chapter_key)

	# 满级角色成就
	var characters = current_save.get("characters", [])
	for character in characters:
		if character.get("level", 1) >= 20 and not unlocked.has("max_level_char"):
			unlocked["max_level_char"] = true
			new_unlocks.append("max_level_char")
			break

	current_save["achievements_unlocked"] = unlocked

	# 通知UI逐个显示新解锁的成就；同时加入待展示队列供场景切换后回看
	for ach_id in new_unlocks:
		var ach_data = GameData.get_achievement(ach_id)
		pending_achievement_notifications.append({
			"id": ach_id,
			"name": ach_data.get("name", ach_id),
			"description": ach_data.get("description", ""),
		})
		achievement_unlocked.emit(ach_id, ach_data)
		print("成就解锁: ", ach_id, " - ", ach_data.get("name", ""))

## 消费并返回下一个待展示的成就通知
func pop_pending_achievement() -> Dictionary:
	if pending_achievement_notifications.is_empty():
		return {}
	return pending_achievement_notifications.pop_front()

## 是否有未展示的成就通知
func has_pending_achievements() -> bool:
	return not pending_achievement_notifications.is_empty()

## 清空待展示队列
func clear_pending_achievements() -> void:
	pending_achievement_notifications.clear()

## 获取当前信用点
func get_credit() -> int:
	return current_save.get("resources", {}).get("credit", 0)

## 购买物品（从商店）
func purchase_item(item_id: String, price: int) -> bool:
	var resources = current_save.get("resources", {})
	if resources.get("credit", 0) < price:
		return false
	resources["credit"] = resources.get("credit", 0) - price
	# 添加到库存
	var inventory = current_save.get("inventory", {})
	var current_count = inventory.get(item_id, 0)
	inventory[item_id] = current_count + 1
	current_save["resources"] = resources
	current_save["inventory"] = inventory
	SaveManager.save_game(current_save, current_slot)
	inventory_changed.emit()
	return true

## 获取库存
func get_inventory() -> Dictionary:
	return current_save.get("inventory", {})

## 装备物品到角色
func equip_to_character(char_index: int, slot: String, item_id: String) -> bool:
	var characters = current_save.get("characters", [])
	if char_index < 0 or char_index >= characters.size():
		return false
	# 检查库存
	var inventory = current_save.get("inventory", {})
	if inventory.get(item_id, 0) <= 0:
		return false
	# 如果槽位已有装备，先放回库存
	var old_item = characters[char_index].get("equipment", {}).get(slot, "")
	if old_item != "":
		inventory[old_item] = inventory.get(old_item, 0) + 1
	# 装备（ProgressionManager 会校验职业限制）
	var new_char = progression.equip_item(characters[char_index], slot, item_id)
	if new_char == characters[char_index]:
		# 装备失败（职业限制），回滚库存
		if old_item != "":
			inventory[old_item] = inventory.get(old_item, 0) - 1
			if inventory[old_item] <= 0:
				inventory.erase(old_item)
		return false
	characters[char_index] = new_char
	# 从库存移除
	inventory[item_id] = inventory.get(item_id, 0) - 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	current_save["characters"] = characters
	current_save["inventory"] = inventory
	SaveManager.save_game(current_save, current_slot)
	inventory_changed.emit()
	return true

## 卸下装备，返回到库存
func unequip_from_character(char_index: int, slot: String) -> bool:
	var characters = current_save.get("characters", [])
	if char_index < 0 or char_index >= characters.size():
		return false
	var current_item = characters[char_index].get("equipment", {}).get(slot, "")
	if current_item == "":
		return false
	characters[char_index] = progression.unequip_item(characters[char_index], slot)
	var inventory = current_save.get("inventory", {})
	inventory[current_item] = inventory.get(current_item, 0) + 1
	current_save["characters"] = characters
	current_save["inventory"] = inventory
	SaveManager.save_game(current_save, current_slot)
	inventory_changed.emit()
	return true

## 学习技能（消耗技能点）
func learn_skill(char_index: int, skill_id: String) -> bool:
	var characters = current_save.get("characters", [])
	if char_index < 0 or char_index >= characters.size():
		return false
	var new_char = progression.learn_skill(characters[char_index], skill_id)
	if new_char == characters[char_index]:
		return false
	characters[char_index] = new_char
	current_save["characters"] = characters
	SaveManager.save_game(current_save, current_slot)
	return true

## 获取角色可学技能
func get_learnable_skills(char_index: int) -> Array:
	var characters = current_save.get("characters", [])
	if char_index < 0 or char_index >= characters.size():
		return []
	return progression.get_learnable_skills(characters[char_index])

## 成就解锁通知信号
## （已在类顶部声明）

## 分配属性点
func allocate_stat(char_index: int, stat_name: String) -> bool:
	var characters = current_save.get("characters", [])
	if char_index < 0 or char_index >= characters.size():
		return false
	characters[char_index] = progression.allocate_stat(characters[char_index], stat_name)
	current_save["characters"] = characters
	SaveManager.save_game(current_save, current_slot)
	return true

## 获取参战角色对应的战斗单位
func create_battle_units_from_roster() -> Array:
	var characters = current_save.get("characters", [])
	var units = []
	for character in characters:
		var unit = progression.create_battle_unit(character)
		units.append(unit)
	return units

## 获取设置
func get_settings() -> Dictionary:
	return current_save.get("settings", SaveManager.create_default_save().settings)

## 更新设置
func update_settings(settings: Dictionary) -> void:
	InputBindings.apply_settings(settings)
	current_save["settings"] = settings
	SaveManager.save_game(current_save, current_slot)

## 获取当前难度参数
## 故事难度：敌人弱化、奖励加成；标准难度：原值；困难难度：敌人强化、奖励削减
## 注意：不修改玩家命中率，仅调整敌人 HP/伤害和奖励倍率
func get_difficulty_params() -> Dictionary:
	var difficulty = get_settings().get("difficulty", "standard")
	match difficulty:
		"story":
			return {
				"enemy_hp_multiplier": 0.8,
				"enemy_damage_multiplier": 0.8,
				"reward_multiplier": 1.3,
				"turn_limit_bonus": 5,
			}
		"hard":
			return {
				"enemy_hp_multiplier": 1.25,
				"enemy_damage_multiplier": 1.20,
				"reward_multiplier": 0.85,
				"turn_limit_bonus": -3,
			}
		_:  # standard
			return {
				"enemy_hp_multiplier": 1.0,
				"enemy_damage_multiplier": 1.0,
				"reward_multiplier": 1.0,
				"turn_limit_bonus": 0,
			}

## 场景切换
func go_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func go_to_base() -> void:
	current_state = GameState.BASE
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func go_to_battle(level_id: String) -> void:
	current_state = GameState.BATTLE
	pending_level_id = level_id
	current_level_id = level_id
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

## CH1-080: 从遭遇检查点重试战斗（当前实现为重开关卡，完整状态恢复见 CH1-020）
func go_to_battle_from_encounter(level_id: String) -> void:
	go_to_battle(level_id)

func go_to_settings(caller: String = "main_menu") -> void:
	current_state = GameState.SETTINGS
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func go_to_mission_result(result: Dictionary) -> void:
	current_state = GameState.MISSION_RESULT
	battle_result = result
	get_tree().change_scene_to_file("res://scenes/mission_result.tscn")

## 退出游戏
func quit_game() -> void:
	get_tree().quit()

## ===== 对话系统接入 =====

## 当前活跃的对话实例（同时只允许一个）
var _active_dialogue: Node = null

## 播放对话；若 dialogue_id 为空或数据不存在则立即 emit dialogue_finished
## on_finished 回调在对话结束时被调用
func play_dialogue(dialogue_id: String, on_finished: Callable = Callable()) -> void:
	if dialogue_id == "":
		dialogue_finished.emit(dialogue_id)
		if on_finished.is_valid():
			on_finished.call()
		return

	# 同时只允许一个对话实例
	if _active_dialogue != null and is_instance_valid(_active_dialogue):
		_active_dialogue.queue_free()
		_active_dialogue = null

	var scene_tree = get_tree()
	if scene_tree == null:
		dialogue_finished.emit(dialogue_id)
		if on_finished.is_valid():
			on_finished.call()
		return

	var current_scene = scene_tree.current_scene
	if current_scene == null:
		dialogue_finished.emit(dialogue_id)
		if on_finished.is_valid():
			on_finished.call()
		return

	var dialogue = DialogueScene.instantiate()
	var dialogue_parent: Node = current_scene
	var scene_hud: Node = current_scene.get_node_or_null("HUD")
	if not scene_hud is CanvasLayer:
		scene_hud = scene_tree.get_first_node_in_group("dialogue_layer")
	if scene_hud is CanvasLayer:
		dialogue_parent = scene_hud
	dialogue_parent.add_child(dialogue)
	_active_dialogue = dialogue

	# 对话结束回调
	var end_cb = func():
		_active_dialogue = null
		dialogue_finished.emit(dialogue_id)
		if on_finished.is_valid():
			on_finished.call()

	if dialogue.has_signal("dialogue_finished"):
		dialogue.dialogue_finished.connect(end_cb)
	else:
		# 兜底：若对话实例没有信号，直接调用回调
		_active_dialogue = null
		dialogue.queue_free()
		dialogue_finished.emit(dialogue_id)
		if on_finished.is_valid():
			on_finished.call()
		return

	dialogue.start_dialogue(dialogue_id)
	# 若 start_dialogue 因数据为空直接 emit dialogue_finished，则实例会被 hide 但未 free
	# 由 dialogue_finished 信号回调统一处理

## 触发关卡 intro/outro 对话（基于 levels.json 中的字段）
func play_level_dialogue(level_id: String, kind: String, on_finished: Callable = Callable()) -> void:
	var level = CampaignRepository.get_level(level_id)
	var key = "intro_dialogue" if kind == "intro" else "outro_dialogue"
	var dialogue_id = level.get(key, "")
	play_dialogue(dialogue_id, on_finished)

## 触发章节完成对话（基于 dialogues.json 中的 base_after_chX 约定）
func play_chapter_complete_dialogue(chapter: int, on_finished: Callable = Callable()) -> void:
	var dialogue_id = "base_after_ch%d" % chapter
	# 检查对话是否存在，不存在则直接回调
	if GameData.get_dialogue(dialogue_id).is_empty():
		dialogue_finished.emit("")
		if on_finished.is_valid():
			on_finished.call()
		return
	play_dialogue(dialogue_id, on_finished)

## ===== 剧情旗标与结局 =====

## 设置剧情旗标并立即保存
func set_story_flag(flag: String, value: Variant = true) -> void:
	var progress = current_save.get("campaign_progress", {})
	var flags = progress.get("story_flags", {})
	flags[flag] = value
	progress["story_flags"] = flags
	current_save["campaign_progress"] = progress
	SaveManager.save_game(current_save, current_slot)

## 获取剧情旗标
func get_story_flag(flag: String, default: Variant = false) -> Variant:
	var progress = current_save.get("campaign_progress", {})
	return progress.get("story_flags", {}).get(flag, default)

## 检查是否已通关最终 Boss（用于解锁新游戏+）
func is_game_cleared() -> bool:
	var completed = current_save.get("campaign_progress", {}).get("completed_missions", [])
	return "ch5_m5" in completed

## 获取已达成结局列表
func get_unlocked_endings() -> Array:
	return current_save.get("stats_tracking", {}).get("unlocked_endings", [])

## 记录结局并解锁对应成就；返回新解锁的结局ID（首次达成时）
func unlock_ending(ending_id: String) -> String:
	if ending_id not in ["ending_a", "ending_b", "ending_c"]:
		push_warning("Unknown ending id: " + ending_id)
		return ""
	var stats = current_save.get("stats_tracking", {})
	var endings = stats.get("unlocked_endings", [])
	if ending_id in endings:
		return ""  # 已记录
	endings.append(ending_id)
	stats["unlocked_endings"] = endings
	# 标记通关
	stats["game_cleared"] = true
	current_save["stats_tracking"] = stats

	# 解锁对应成就
	var unlocked = current_save.get("achievements_unlocked", {})
	if not unlocked.has(ending_id):
		unlocked[ending_id] = true
		current_save["achievements_unlocked"] = unlocked
		var ach_data = GameData.get_achievement(ending_id)
		pending_achievement_notifications.append({
			"id": ending_id,
			"name": ach_data.get("name", ending_id),
			"description": ach_data.get("description", ""),
		})
		achievement_unlocked.emit(ending_id, ach_data)

	# 全结局成就
	if endings.size() >= 3 and not unlocked.has("all_endings"):
		unlocked["all_endings"] = true
		current_save["achievements_unlocked"] = unlocked
		var ach_data = GameData.get_achievement("all_endings")
		pending_achievement_notifications.append({
			"id": "all_endings",
			"name": ach_data.get("name", "all_endings"),
			"description": ach_data.get("description", ""),
		})
		achievement_unlocked.emit("all_endings", ach_data)

	SaveManager.save_game(current_save, current_slot)
	return ending_id

## 启动新游戏+：保留部分进度（角色等级、装备、信用点）但重置战役进度
## 返回 true 表示数据已重置，调用方负责切换到基地场景
func start_new_game_plus(slot: int = 0) -> bool:
	var retained_characters = current_save.get("characters", []).duplicate(true)
	var retained_inventory = current_save.get("inventory", {}).duplicate(true)
	var retained_credit = current_save.get("resources", {}).get("credit", 0)

	# 增加新游戏+周目数
	var stats = current_save.get("stats_tracking", {})
	var ng_count = int(stats.get("ng_plus_count", 0)) + 1
	var retained_endings = stats.get("unlocked_endings", [])

	current_slot = slot
	current_save = SaveManager.create_default_save()

	# 保留角色和资源
	current_save.characters = retained_characters
	current_save.inventory = retained_inventory
	current_save.resources.credit = retained_credit + 1000  # 新游戏+奖励

	# 标记新游戏+状态
	var new_stats = current_save.get("stats_tracking", {})
	new_stats["ng_plus_count"] = ng_count
	new_stats["unlocked_endings"] = retained_endings
	new_stats["game_cleared"] = false  # 重置通关状态
	current_save["stats_tracking"] = new_stats

	# 剧情旗标：保留已达成结局记录，但重置其他旗标
	var progress = current_save.get("campaign_progress", {})
	progress["story_flags"] = {"ng_plus_unlocked": true}
	current_save["campaign_progress"] = progress

	# 解锁新游戏+成就
	var ach = current_save.get("achievements_unlocked", {})
	if ng_count == 1 and not ach.has("ng_plus"):
		ach["ng_plus"] = true
		current_save["achievements_unlocked"] = ach
		var ach_data = GameData.get_achievement("ng_plus")
		pending_achievement_notifications.append({
			"id": "ng_plus",
			"name": ach_data.get("name", "ng_plus"),
			"description": ach_data.get("description", ""),
		})
		achievement_unlocked.emit("ng_plus", ach_data)
	elif ng_count >= 9 and not ach.has("ng_plus_9"):
		ach["ng_plus_9"] = true
		current_save["achievements_unlocked"] = ach
		var ach_data = GameData.get_achievement("ng_plus_9")
		pending_achievement_notifications.append({
			"id": "ng_plus_9",
			"name": ach_data.get("name", "ng_plus_9"),
			"description": ach_data.get("description", ""),
		})
		achievement_unlocked.emit("ng_plus_9", ach_data)

	SaveManager.save_game(current_save, current_slot)
	save_created.emit(current_slot)
	return true

## 获取当前周目数（0=首次，1=新游戏+1，依次递增）
func get_ng_plus_count() -> int:
	return int(current_save.get("stats_tracking", {}).get("ng_plus_count", 0))
