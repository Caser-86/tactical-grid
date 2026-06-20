## 程序化关卡生成器
## 根据 levels.json 中的关卡元数据自动生成可玩的地图布局
extends RefCounted
class_name ProceduralGenerator

const THEMES := {
	"warehouse": {
		"base_terrain": [0],
		"blocker_chance": 0.05,
		"cover_chance": 0.10,
		"highland_chance": 0.0,
		"water_chance": 0.0,
		"forest_chance": 0.0,
		"enemy_archetypes": ["sentry_basic", "sentry_elite", "heavy_gunner"],
		"primary_path": "road",
		"lighting": "indoor",
	},
	"city_ruins": {
		"base_terrain": [0, 1, 3],
		"blocker_chance": 0.08,
		"cover_chance": 0.08,
		"highland_chance": 0.05,
		"water_chance": 0.0,
		"forest_chance": 0.0,
		"enemy_archetypes": ["drone_scout", "drone_assault", "sentry_elite", "sentry_sniper", "heavy_gunner"],
		"primary_path": "road",
		"lighting": "outdoor",
	},
	"underground": {
		"base_terrain": [0, 0, 0],
		"blocker_chance": 0.07,
		"cover_chance": 0.05,
		"highland_chance": 0.0,
		"water_chance": 0.03,
		"forest_chance": 0.0,
		"poison_chance": 0.02,
		"enemy_archetypes": ["sentry_basic", "sentry_elite", "stealth_assassin", "poison_spitter", "jammer"],
		"primary_path": "narrow",
		"lighting": "dark",
	},
	"mountain_fort": {
		"base_terrain": [0, 3, 4],
		"blocker_chance": 0.10,
		"cover_chance": 0.04,
		"highland_chance": 0.12,
		"water_chance": 0.0,
		"forest_chance": 0.05,
		"enemy_archetypes": ["sentry_elite", "sentry_sniper", "heavy_gunner", "rocket_trooper", "assault_mech", "shield_maestro"],
		"primary_path": "elevated",
		"lighting": "outdoor",
	},
	"forest": {
		"base_terrain": [0, 0, 2],
		"blocker_chance": 0.02,
		"cover_chance": 0.04,
		"highland_chance": 0.05,
		"water_chance": 0.02,
		"forest_chance": 0.30,
		"enemy_archetypes": ["drone_scout", "stealth_assassin", "sentry_sniper", "flame_trooper"],
		"primary_path": "natural",
		"lighting": "outdoor",
	},
}

const SIZE_PRESETS := {
	"small":  {"width": 10, "height": 8},
	"medium": {"width": 14, "height": 10},
	"large":  {"width": 18, "height": 12},
}

## 程序化生成关卡数据
## 接受 levels.json 中的关卡字典，输出 map_data 字典
static func generate_level(level_meta: Dictionary) -> Dictionary:
	if level_meta.is_empty():
		return {}

	var seed_val = int(level_meta.get("seed", 0))
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val

	var size_key = String(level_meta.get("size", "small"))
	var size = SIZE_PRESETS.get(size_key, SIZE_PRESETS["small"])
	var width = int(size.get("width", 10))
	var height = int(size.get("height", 8))

	var theme_key = String(level_meta.get("theme", "warehouse"))
	var theme = THEMES.get(theme_key, THEMES["warehouse"])

	var mission_type = String(level_meta.get("mission_type", "extract"))
	var difficulty = int(level_meta.get("difficulty", 1))
	var chapter = int(level_meta.get("chapter", 1))
	var enemy_count = int(level_meta.get("enemy_count", 4))
	var player_count = int(level_meta.get("player_units", 4))

	var base_terrain = _generate_terrain(width, height, theme, rng)
	var blocker = _generate_blockers(width, height, theme, base_terrain, rng)
	var spawns = _generate_spawns(width, height, player_count, enemy_count, mission_type, theme, chapter, rng)
	var objects = _generate_objects(width, height, mission_type, theme, level_meta, rng)

	var result = {
		"map_id": level_meta.get("id", "generated"),
		"id": level_meta.get("id", "generated"),
		"name": level_meta.get("name", "未命名关卡"),
		"seed": seed_val,
		"size": {"width": width, "height": height},
		"theme": theme_key,
		"mission_type": mission_type,
		"difficulty": difficulty,
		"chapter": chapter,
		"layers": {
			"base_terrain": base_terrain,
			"blocker": blocker,
			"height_level": [],
		},
		"spawns": spawns,
		"objects": objects,
		"scripts": [],
		"victory": _generate_victory(mission_type, width, height, spawns),
		"intro_dialogue": level_meta.get("intro_dialogue", ""),
		"outro_dialogue": level_meta.get("outro_dialogue", ""),
		"rewards": level_meta.get("rewards", {}),
		"is_boss": level_meta.get("is_boss", false),
		"boss_id": level_meta.get("boss_id", ""),
		"tutorial_flags": level_meta.get("tutorial_flags", []),
		"special_rules": level_meta.get("special_rules", []),
		"weather": level_meta.get("weather", ""),
		"time": level_meta.get("time", "day"),
	}

	return result

## 生成空白地图数据（用于Roguelike快速战斗）
static func _generate_empty_map(width: int, height: int, theme_key: String) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var theme = THEMES.get(theme_key, THEMES["warehouse"])
	var base_terrain = _generate_terrain(width, height, theme, rng)
	var blocker = _generate_blockers(width, height, theme, base_terrain, rng)
	var height_level = []
	for y in range(height):
		height_level.append([])
		for x in range(width):
			height_level[y].append(0)

	return {
		"map_id": "rl_" + theme_key,
		"id": "rl_" + theme_key,
		"name": "深渊远征 - " + theme_key,
		"seed": rng.seed,
		"size": {"width": width, "height": height},
		"theme": theme_key,
		"mission_type": "assassinate",
		"difficulty": 1,
		"chapter": 1,
		"layers": {
			"base_terrain": base_terrain,
			"blocker": blocker,
			"height_level": height_level,
		},
		"spawns": {"player": [], "enemy": []},
		"objects": [],
		"scripts": [],
		"victory": {"type": "eliminate_all"},
		"is_boss": false,
		"boss_id": "",
	}

## 根据主题生成基础地形
static func _generate_terrain(width: int, height: int, theme: Dictionary, rng: RandomNumberGenerator) -> Array:
	var grid = []
	var base_options = theme.get("base_terrain", [0])
	var primary_path = String(theme.get("primary_path", "road"))

	# 先生成全平地图
	for y in range(height):
		var row = []
		for x in range(width):
			var idx = rng.randi() % base_options.size()
			row.append(int(base_options[idx]))
		grid.append(row)

	# 主题地形分布
	match primary_path:
		"road":
			# 水平或垂直道路
			var road_y = int(height * 0.5)
			for x in range(width):
				grid[road_y][x] = 1
			# 横向分支
			if rng.randf() < 0.5 and width >= 12:
				var road_x = int(width * 0.5)
				for y in range(height):
					grid[y][road_x] = 1
		"narrow":
			# 走廊
			var corridor_x = int(width * 0.5)
			for y in range(height):
				grid[y][corridor_x] = 1
				if corridor_x + 1 < width:
					grid[y][corridor_x + 1] = 1
		"elevated":
			# 高地走廊
			for x in range(width):
				if rng.randf() < float(theme.get("highland_chance", 0.0)):
					grid[0][x] = 4
		"natural":
			# 自然地形
			pass

	# 森林/水/毒池分布
	var forest_chance = float(theme.get("forest_chance", 0.0))
	var water_chance = float(theme.get("water_chance", 0.0))
	var poison_chance = float(theme.get("poison_chance", 0.0))
	for y in range(height):
		for x in range(width):
			var roll = rng.randf()
			if roll < forest_chance:
				grid[y][x] = 2
			elif roll < forest_chance + water_chance:
				grid[y][x] = 5
			elif roll < forest_chance + water_chance + poison_chance:
				grid[y][x] = 8

	# 边缘保护：玩家侧保持开阔
	for y in range(height):
		grid[y][0] = 0
		grid[y][width - 1] = base_options[0]

	return grid

## 生成掩体（墙体、箱子等）
static func _generate_blockers(width: int, height: int, theme: Dictionary, base_terrain: Array, rng: RandomNumberGenerator) -> Array:
	var grid = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(0)
		grid.append(row)

	var blocker_chance = float(theme.get("blocker_chance", 0.0))
	var cover_chance = float(theme.get("cover_chance", 0.0))
	var highland_chance = float(theme.get("highland_chance", 0.0))

	for y in range(height):
		for x in range(width):
			# 边缘不放掩体（留出玩家侧空间）
			if x < 2 or x >= width - 2:
				continue
			# 道路/水域不放掩体
			if base_terrain[y][x] in [1, 5, 8]:
				continue
			var roll = rng.randf()
			if roll < blocker_chance:
				grid[y][x] = 6  # 墙
			elif roll < blocker_chance + cover_chance:
				grid[y][x] = 7  # 箱子
			elif roll < blocker_chance + cover_chance + highland_chance:
				# 高地用base_terrain记录，这里blocker保持0
				pass

	# 添加一些预设的掩体群（保证玩法）
	var preset_clusters = int(width * height / 80)
	for i in range(preset_clusters):
		var cx = rng.randi_range(3, width - 4)
		var cy = rng.randi_range(1, height - 2)
		var cluster_type = rng.randi() % 3
		match cluster_type:
			0:
				# L形掩体
				if cx + 1 < width - 1 and cy + 1 < height - 1:
					grid[cy][cx] = 7
					grid[cy][cx + 1] = 7
					grid[cy + 1][cx] = 7
			1:
				# 直线掩体
				if cy + 1 < height - 1:
					grid[cy][cx] = 6
					grid[cy + 1][cx] = 6
			2:
				# 双箱体
				grid[cy][cx] = 7
				if cx + 2 < width - 1:
					grid[cy][cx + 2] = 7

	return grid

## 生成玩家与敌人出生点
static func _generate_spawns(width: int, height: int, player_count: int, enemy_count: int, mission_type: String, theme: Dictionary, chapter: int, rng: RandomNumberGenerator) -> Dictionary:
	var player_spawns: Array = []
	var enemy_spawns: Array = []
	var enemy_archetypes = theme.get("enemy_archetypes", ["sentry_basic"])

	# 玩家出生在左侧
	var player_y_positions = []
	var y_step = max(1, height / (player_count + 1))
	for i in range(player_count):
		var py = min(height - 1, int((i + 1) * y_step))
		player_y_positions.append(py)
		player_spawns.append({"x": 0, "y": py})

	# 敌人出生在右侧或基于任务类型
	match mission_type:
		"extract", "infiltrate":
			for i in range(enemy_count):
				var ey = int((i + 0.5) * height / float(max(1, enemy_count)))
				var ex = width - 1
				enemy_spawns.append({
					"x": ex,
					"y": ey,
					"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
				})
		"destroy", "assassinate":
			# 敌人分散在中间
			for i in range(enemy_count):
				var ex = int(width * 0.6) + rng.randi_range(0, max(0, width - int(width * 0.6) - 2))
				var ey = rng.randi_range(1, height - 2)
				enemy_spawns.append({
					"x": ex,
					"y": ey,
					"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
				})
		"defend":
			# 防守任务：敌人在四周
			for i in range(enemy_count):
				var ex = width - 1
				var ey = rng.randi_range(0, height - 1)
				enemy_spawns.append({
					"x": ex,
					"y": ey,
					"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
				})
		"escort":
			# 护送：敌人在前方
			for i in range(enemy_count):
				var ex = int(width * 0.5) + i
				var ey = rng.randi_range(1, height - 2)
				if ex < width - 1:
					enemy_spawns.append({
						"x": ex,
						"y": ey,
						"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
					})
		"steal_data", "infiltrate":
			# 渗透：敌人在中心
			for i in range(enemy_count):
				var ex = int(width * 0.5) + rng.randi_range(-2, 2)
				var ey = int(height * 0.5) + rng.randi_range(-2, 2)
				enemy_spawns.append({
					"x": clampi(ex, 0, width - 1),
					"y": clampi(ey, 0, height - 1),
					"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
				})
		_:
			for i in range(enemy_count):
				enemy_spawns.append({
					"x": width - 1,
					"y": int((i + 0.5) * height / float(max(1, enemy_count))),
					"job": _pick_enemy_for_chapter(enemy_archetypes, chapter, rng),
				})

	return {
		"player": player_spawns,
		"enemies": enemy_spawns,
	}

## 根据章节选择合适的敌人
static func _pick_enemy_for_chapter(archetypes: Array, chapter: int, rng: RandomNumberGenerator) -> String:
	if archetypes.is_empty():
		return "sentry_basic"
	# 章节越高，越可能用更强敌人
	var idx = rng.randi() % archetypes.size()
	return String(archetypes[idx])

## 生成地图对象（撤离点、终端、目标等）
static func _generate_objects(width: int, height: int, mission_type: String, theme: Dictionary, level_meta: Dictionary, rng: RandomNumberGenerator) -> Array:
	var objects: Array = []

	match mission_type:
		"extract":
			objects.append({
				"id": "evac",
				"type": "evac",
				"x": width - 1,
				"y": int(height * 0.5),
				"name": "撤离点",
			})
		"destroy":
			# 多个可破坏目标
			var target_count = int(level_meta.get("enemy_count", 4)) / 3 + 1
			for i in range(int(target_count)):
				objects.append({
					"id": "destructible_" + str(i),
					"type": "destructible_target",
					"x": int(width * 0.7) + rng.randi_range(0, 2),
					"y": int((i + 0.5) * height / float(target_count + 1)),
					"name": "目标设施 " + str(i + 1),
					"hp": 50,
				})
		"assassinate":
			# 敌方Boss/精英
			objects.append({
				"id": "target",
				"type": "target_unit",
				"x": int(width * 0.7),
				"y": int(height * 0.5),
				"name": "高价值目标",
				"is_boss": level_meta.get("is_boss", false),
				"boss_id": level_meta.get("boss_id", ""),
			})
		"defend":
			# 防御点
			objects.append({
				"id": "defend_point",
				"type": "defend_point",
				"x": int(width * 0.5),
				"y": int(height * 0.5),
				"name": "防御区",
			})
		"escort":
			# VIP
			objects.append({
				"id": "vip",
				"type": "npc",
				"x": int(width * 0.3),
				"y": int(height * 0.5),
				"name": "VIP目标",
				"is_vip": true,
			})
			objects.append({
				"id": "evac",
				"type": "evac",
				"x": width - 1,
				"y": int(height * 0.5),
				"name": "撤离点",
			})
		"steal_data":
			objects.append({
				"id": "terminal",
				"type": "terminal",
				"x": int(width * 0.7),
				"y": int(height * 0.5),
				"name": "数据终端",
				"hack_time": 3,
			})
		"infiltrate":
			objects.append({
				"id": "alarm_panel",
				"type": "alarm_panel",
				"x": int(width * 0.6),
				"y": int(height * 0.5),
				"name": "警报面板",
			})

	# 添加部分补给/资源点
	if rng.randf() < 0.5 and not mission_type in ["destroy", "defend"]:
		objects.append({
			"id": "resource_a",
			"type": "resource",
			"x": int(width * 0.3),
			"y": rng.randi_range(1, height - 2),
			"name": "补给箱",
			"loot": "med_kit",
		})

	return objects

## 生成胜利条件
static func _generate_victory(mission_type: String, width: int, height: int, spawns: Dictionary) -> Dictionary:
	match mission_type:
		"extract":
			return {
				"type": "reach_position",
				"target": {"x": width - 1, "y": int(height * 0.5)},
				"description": "所有单位撤离到撤离点",
			}
		"destroy":
			return {
				"type": "destroy_objects",
				"description": "摧毁所有目标设施",
			}
		"assassinate":
			return {
				"type": "kill_target",
				"description": "消灭高价值目标",
			}
		"defend":
			return {
				"type": "survive_turns",
				"turns": 5,
				"description": "坚守5回合",
			}
		"escort":
			return {
				"type": "escort_to_evac",
				"description": "护送VIP到达撤离点",
			}
		"steal_data":
			return {
				"type": "hack_terminal",
				"description": "入侵并下载数据",
			}
		"infiltrate":
			return {
				"type": "reach_position",
				"target": {"x": width - 1, "y": int(height * 0.5)},
				"description": "穿越区域到达撤离点",
			}
		_:
			return {
				"type": "eliminate_all",
				"description": "消灭所有敌人",
			}

## 通过 level_id 在 levels.json 中查找关卡并生成
static func generate_from_id(level_id: String) -> Dictionary:
	var levels = GameData.level_data.get("levels", {})
	var level_meta = levels.get(level_id, {})
	if level_meta.is_empty():
		return {}
	return generate_level(level_meta)

## 生成 Roguelike 战斗关卡
static func generate_roguelike_battle(theme: String, enemy_count: int, enemy_tier: String, boss_id: String = "", is_boss: bool = false) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var width = rng.randi_range(10, 14)
	var height = rng.randi_range(8, 10)
	var map_data = _generate_empty_map(width, height, theme)

	# 玩家出生点
	var player_spawns = [{"x": 1, "y": height / 2}]
	# 敌人出生点
	var enemy_spawns = []
	for i in range(enemy_count):
		var ex = rng.randi_range(width - 4, width - 2)
		var ey = rng.randi_range(1, height - 2)
		enemy_spawns.append({"x": ex, "y": ey, "job": _pick_enemy_job(enemy_tier, rng)})

	if is_boss and boss_id != "":
		enemy_spawns[0].job = boss_id

	map_data["spawns"] = {
		"player": player_spawns,
		"enemy": enemy_spawns,
	}
	map_data["mission_type"] = "assassinate"
	map_data["theme"] = theme
	map_data["is_boss"] = is_boss
	map_data["boss_id"] = boss_id
	return map_data

static func _pick_enemy_job(tier: String, rng: RandomNumberGenerator) -> String:
	match tier:
		"elite":
			var jobs = ["sentry_elite", "sniper", "heavy", "drone_bomber"]
			return jobs[rng.randi_range(0, jobs.size() - 1)]
		"boss":
			return "rogue_commander"
		_:
			var jobs = ["sentry_basic", "sentry_scout", "drone_spotter"]
			return jobs[rng.randi_range(0, jobs.size() - 1)]

## 生成所有关卡（包括主线和支线）
static func generate_all() -> Array:
	var results: Array = []
	var levels = GameData.level_data.get("levels", {})
	for level_id in levels:
		var generated = generate_from_id(level_id)
		if not generated.is_empty():
			results.append(generated)

	var sidequests = GameData.level_data.get("sidequests", {})
	for sq_id in sidequests:
		var sq = sidequests[sq_id]
		var sq_meta = {
			"id": sq_id,
			"name": sq.get("name", "支线任务"),
			"chapter": 99,
			"mission": 0,
			"size": sq.get("size", "small"),
			"theme": "warehouse",
			"mission_type": "extract",
			"difficulty": sq.get("difficulty", 3),
			"seed": sq.get("seed", 9000),
			"player_units": 4,
			"enemy_count": 5,
			"rewards": {"credit": 500, "exp": 400},
		}
		# 根据支线类型调整任务类型
		match String(sq.get("type", "")):
			"survival":
				sq_meta["mission_type"] = "defend"
			"escort":
				sq_meta["mission_type"] = "escort"
			"timed":
				sq_meta["mission_type"] = "extract"
				sq_meta["special_rules"] = ["turn_limit_8"]
			"sniper":
				sq_meta["theme"] = "city_ruins"
				sq_meta["mission_type"] = "destroy"
			"stealth":
				sq_meta["theme"] = "underground"
				sq_meta["mission_type"] = "infiltrate"
			"boss":
				sq_meta["is_boss"] = true
				sq_meta["boss_id"] = "elite_composite"
				sq_meta["mission_type"] = "assassinate"
			"flawless":
				sq_meta["mission_type"] = "extract"
				sq_meta["special_rules"] = ["no_unit_lost"]
			"speedrun":
				sq_meta["mission_type"] = "destroy"
				sq_meta["special_rules"] = ["turn_limit_6"]
			"ultimate":
				sq_meta["theme"] = "city_ruins"
				sq_meta["is_boss"] = true
				sq_meta["mission_type"] = "assassinate"
				sq_meta["boss_id"] = "matrix_general"
		results.append(generate_level(sq_meta))

	return results

## 通过 level_id 获取关卡（优先使用procedural，回退到LocalMapData）
static func get_level_data(level_id: String) -> Dictionary:
	var generated = generate_from_id(level_id)
	if not generated.is_empty():
		return generated

	# 回退到LocalMapData
	var levels = LocalMapData.get_all_levels()
	for level in levels:
		if level.get("id", "") == level_id:
			return level

	# 最后回退到第一个测试关卡
	return LocalMapData.get_test_level()
