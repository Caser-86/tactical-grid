## 音频管理器（单例）
## 管理所有 BGM 和音效的播放
extends Node

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

var bgm_volume: float = 0.7
var sfx_volume: float = 0.8
var ambient_volume: float = 0.5

var current_bgm: String = ""
var audio_cache: Dictionary = {}

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	add_child(ambient_player)

	_load_settings()

func _load_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if file:
		var settings = JSON.parse_string(file.get_as_text()) or {}
		bgm_volume = settings.get("bgm_volume", 70) / 100.0
		sfx_volume = settings.get("sfx_volume", 80) / 100.0
		file.close()

	_apply_volumes()

func _apply_volumes() -> void:
	bgm_player.volume_db = linear_to_db(bgm_volume)
	sfx_player.volume_db = linear_to_db(sfx_volume)
	ambient_player.volume_db = linear_to_db(ambient_volume)

## 播放 BGM
func play_bgm(bgm_id: String) -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	if not bgm_player:
		return
	if bgm_id == current_bgm:
		return
	current_bgm = bgm_id

	var stream = _load_audio("bgm", bgm_id)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()

## 停止 BGM
func stop_bgm() -> void:
	if bgm_player:
		bgm_player.stop()
		bgm_player.stream = null
	current_bgm = ""
	audio_cache.clear()

## 播放音效
func play_sfx(sfx_id: String) -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	if not sfx_player:
		return
	var stream = _load_audio("sfx", sfx_id)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

## 播放环境音
func play_ambient(ambient_id: String) -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return
	if not ambient_player:
		return
	var stream = _load_audio("ambient", ambient_id)
	if stream:
		ambient_player.stream = stream
		ambient_player.play()

## 停止环境音
func stop_ambient() -> void:
	if ambient_player:
		ambient_player.stop()
		ambient_player.stream = null
	audio_cache.clear()

func _exit_tree() -> void:
	stop_bgm()
	if sfx_player:
		sfx_player.stop()
		sfx_player.stream = null
	stop_ambient()
	audio_cache.clear()

## 检查音频文件是否存在（不加载）
func _audio_exists(category: String, audio_id: String) -> bool:
	var path_ogg = "res://assets/audio/" + category + "/" + audio_id + ".ogg"
	var path_wav = "res://assets/audio/" + category + "/" + audio_id + ".wav"
	return FileAccess.file_exists(path_ogg) or FileAccess.file_exists(path_wav)

## 加载音频文件
func _load_audio(category: String, audio_id: String) -> AudioStream:
	var cache_key = category + "_" + audio_id
	if audio_cache.has(cache_key):
		return audio_cache[cache_key]

	var path = "res://assets/audio/" + category + "/" + audio_id + ".ogg"
	if not FileAccess.file_exists(path):
		path = "res://assets/audio/" + category + "/" + audio_id + ".wav"
		if not FileAccess.file_exists(path):
			return null

	var stream = load(path)
	if stream:
		audio_cache[cache_key] = stream
	return stream

## 设置音量
func set_bgm_volume(volume: float) -> void:
	bgm_volume = clamp(volume, 0.0, 1.0)
	bgm_player.volume_db = linear_to_db(bgm_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	sfx_player.volume_db = linear_to_db(sfx_volume)

## === 战斗音效快捷方法 ===

func sfx_ui_click() -> void:
	play_sfx("sfx_ui_click")

func sfx_ui_hover() -> void:
	play_sfx("sfx_ui_hover")

func sfx_ui_error() -> void:
	play_sfx("sfx_ui_error")

func sfx_select_unit() -> void:
	play_sfx("sfx_select_unit")

func sfx_move(terrain = "ground") -> void:
	var terrain_name = _terrain_to_name(terrain)
	var map := {
		"road": "sfx_step_road", "asphalt": "sfx_step_road",
		"grass": "sfx_step_grass", "forest": "sfx_step_grass",
		"sand": "sfx_step_sand", "dirt": "sfx_step_sand",
		"water": "sfx_step_water", "river": "sfx_step_water",
		"snow": "sfx_step_snow", "ice": "sfx_step_snow",
		"metal": "sfx_step_metal", "floor": "sfx_step_metal",
		"highland": "sfx_step_rock", "rock": "sfx_step_rock",
	}
	var sfx_id = map.get(terrain_name, "sfx_step_ground")
	if not _audio_exists("sfx", sfx_id):
		sfx_id = "sfx_unit_land"
	play_sfx(sfx_id)

func sfx_attack(weapon_type: String = "pistol") -> void:
	var map := {
		"shotgun": "sfx_combat_shotgun", "shotgun_mk2": "sfx_combat_shotgun", "double_barrel_shotgun": "sfx_combat_shotgun",
		"smg": "sfx_combat_rifle", "smg_x7": "sfx_combat_rifle",
		"rifle": "sfx_combat_rifle",
		"sniper_rifle": "sfx_combat_sniper", "marksman_rifle": "sfx_combat_sniper", "em_sniper": "sfx_combat_sniper",
		"heavy_anti_materiel": "sfx_combat_sniper", "orbital_strike_rifle": "sfx_combat_sniper",
		"mg": "sfx_combat_rifle", "gatling": "sfx_combat_rifle", "railgun": "sfx_combat_sniper",
		"pistol": "sfx_combat_pistol", "silenced_pistol": "sfx_combat_pistol", "silenced_pistol_mk2": "sfx_combat_pistol",
		"knife": "sfx_combat_pistol", "plasma_blade": "sfx_combat_pistol", "nano_blade": "sfx_combat_pistol",
		"phantom_dual_blade": "sfx_combat_pistol", "energy_dagger": "sfx_combat_pistol",
		"grenade_launcher": "sfx_explosion", "plasma_grenade_cannon": "sfx_explosion",
		"flamethrower_mk2": "sfx_explosion",
		"med_gun": "sfx_combat_pistol", "nano_med_gun": "sfx_combat_pistol",
		"bio_toxin_gun": "sfx_combat_pistol", "life_drain_gun": "sfx_combat_pistol",
		"bomb": "sfx_explosion", "laser_light": "sfx_combat_rifle", "dual_laser": "sfx_combat_rifle",
		"precision_rifle": "sfx_combat_sniper", "rocket_launcher": "sfx_explosion",
		"energy_blade": "sfx_combat_pistol", "poison_gun": "sfx_combat_pistol", "flamethrower": "sfx_explosion",
	}
	var sfx_id = map.get(weapon_type, "sfx_combat_pistol")
	play_sfx(sfx_id)

func sfx_hit(terrain = "ground") -> void:
	var terrain_name = _terrain_to_name(terrain)
	var map := {
		"water": "sfx_hit_water", "river": "sfx_hit_water",
		"metal": "sfx_hit_metal", "floor": "sfx_hit_metal",
		"wall": "sfx_hit_metal", "crate": "sfx_hit_wood",
		"rock": "sfx_hit_rock", "highland": "sfx_hit_rock",
	}
	var sfx_id = map.get(terrain_name, "sfx_hit_flesh")
	if not _audio_exists("sfx", sfx_id):
		sfx_id = "sfx_hit_flesh"
	play_sfx(sfx_id)

func _terrain_to_name(terrain) -> String:
	if terrain is String:
		return terrain.to_lower()
	if terrain is int:
		var map := {
			0: "plain", 1: "road", 2: "forest", 3: "sand",
			4: "highland", 5: "water", 6: "wall", 7: "crate",
			8: "poison", 9: "bridge",
		}
		return map.get(terrain, "ground")
	return "ground"

func sfx_critical() -> void:
	play_sfx("sfx_critical_hit")

func sfx_unit_down() -> void:
	play_sfx("sfx_unit_down")

func sfx_explosion() -> void:
	play_sfx("sfx_explosion")

func sfx_cover_destroy() -> void:
	play_sfx("sfx_cover_destroy")

func sfx_skill() -> void:
	play_sfx("sfx_skill_cast")

func sfx_heal() -> void:
	play_sfx("sfx_heal_effect")

func sfx_overwatch() -> void:
	play_sfx("sfx_overwatch_trigger")

func sfx_turn_start(player: bool) -> void:
	if player:
		play_sfx("sfx_turn_player_start")
	else:
		play_sfx("sfx_turn_enemy_start")

func sfx_victory() -> void:
	play_sfx("sfx_mission_victory")

func sfx_defeat() -> void:
	play_sfx("sfx_mission_defeat")

func sfx_level_up() -> void:
	play_sfx("sfx_level_up")

func sfx_item_pickup() -> void:
	play_sfx("sfx_item_pickup")

## === BGM 快捷方法 ===

func bgm_menu() -> void:
	play_bgm("bgm_menu")

func bgm_battle(size: String = "small") -> void:
	play_bgm("bgm_battle_" + size)

func bgm_boss() -> void:
	play_bgm("bgm_boss")

func bgm_base() -> void:
	play_bgm("bgm_base")

func bgm_victory() -> void:
	play_bgm("bgm_victory")

func bgm_defeat() -> void:
	play_bgm("bgm_defeat")
