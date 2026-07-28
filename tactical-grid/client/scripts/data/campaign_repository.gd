## 战役仓库
## 从 levels.json 计算章节、任务列表、解锁状态和下一关
extends Node

const LEVEL_ORDER_KEY = "levels"

var _levels: Dictionary = {}
var _chapters: Dictionary = {}

func _ready() -> void:
	_rebuild()
	GameData.ready.connect(_rebuild)

func _rebuild() -> void:
	_levels = GameData.level_data.get(LEVEL_ORDER_KEY, {})
	_chapters.clear()
	for level_id in _levels:
		var level = _levels[level_id]
		# 强制 int 键，避免 JSON 解析的 float/int 类型不一致导致字典查找失败
		var chapter = int(level.get("chapter", 1))
		if not _chapters.has(chapter):
			_chapters[chapter] = []
		_chapters[chapter].append({"id": level_id, "data": level})

	for chapter in _chapters:
		_chapters[chapter].sort_custom(func(a, b): return int(a.data.get("mission", 0)) < int(b.data.get("mission", 0)))

## 获取所有章节号（已排序）
func get_chapters() -> Array:
	var result = _chapters.keys()
	result.sort()
	return result

## 获取某章所有任务
func get_missions(chapter: int) -> Array:
	return _chapters.get(chapter, []).duplicate()

## 获取某章所有关卡 ID 列表
func get_chapter_levels(chapter: int) -> Array:
	var result = []
	for m in _chapters.get(chapter, []):
		result.append(m.id)
	return result

## 获取关卡数据
func get_level(level_id: String) -> Dictionary:
	return _levels.get(level_id, {})

## 获取首个关卡
func get_first_level() -> String:
	var chapters = get_chapters()
	if chapters.is_empty():
		return ""
	var missions = get_missions(chapters[0])
	if missions.is_empty():
		return ""
	return missions[0].id

## 计算某关是否解锁
func is_unlocked(level_id: String, completed_missions: Array) -> bool:
	var level = get_level(level_id)
	if level.is_empty():
		return false
	var chapter = level.get("chapter", 1)
	var mission = level.get("mission", 1)

	# 每章第一关默认解锁
	if mission == 1:
		return true

	# 同一章中，前一关完成后解锁
	var prev_mission_id = _find_level_id(chapter, mission - 1)
	if prev_mission_id != "" and prev_mission_id in completed_missions:
		return true
	return false

## 查找关卡 ID
func _find_level_id(chapter: int, mission: int) -> String:
	var missions = get_missions(chapter)
	for m in missions:
		if m.data.get("mission", 0) == mission:
			return m.id
	return ""

## 获取下一关 ID
func get_next_level(level_id: String) -> String:
	var level = get_level(level_id)
	if level.is_empty():
		return ""
	var chapter = level.get("chapter", 1)
	var mission = level.get("mission", 1)

	var next_id = _find_level_id(chapter, mission + 1)
	if next_id != "":
		return next_id

	# 下一章第一关
	var next_chapter_missions = get_missions(chapter + 1)
	if not next_chapter_missions.is_empty():
		return next_chapter_missions[0].id
	return ""

## 获取章节显示名
func get_chapter_name(chapter: int) -> String:
	var missions = get_missions(chapter)
	if missions.is_empty():
		return "第%d章" % chapter
	# 使用第一关的章节名（如果数据中有）
	return missions[0].data.get("chapter_name", "第%d章" % chapter)

## 构建主菜单/基地可用的章节列表
func build_campaign_tree(completed_missions: Array) -> Array:
	var result = []
	for chapter in get_chapters():
		var missions = get_missions(chapter)
		var mission_entries = []
		for m in missions:
			mission_entries.append({
				"level_id": m.id,
				"name": m.data.get("name", m.id),
				"locked": not is_unlocked(m.id, completed_missions),
				"completed": m.id in completed_missions,
				"is_boss": m.data.get("is_boss", false),
			})
		result.append({
			"chapter": chapter,
			"name": get_chapter_name(chapter),
			"missions": mission_entries,
		})
	return result
