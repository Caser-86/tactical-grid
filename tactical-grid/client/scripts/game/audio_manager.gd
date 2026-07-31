## 音频管理器（单例）
## 管理所有 BGM 和音效的播放
extends Node

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
## AUDIO-01: Polyphonic SFX player pool (prevents combat sounds from interrupting facility feedback)
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 4
var _sfx_pool_index := 0
var ambient_player: AudioStreamPlayer

var bgm_volume: float = 0.7
var sfx_volume: float = 0.8
var ambient_volume: float = 0.5

var current_bgm: String = ""
var battle_music_layer: int = -1
var audio_cache: Dictionary = {}

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = &"Music"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = &"SFX"
	add_child(sfx_player)

	# AUDIO-01: Initialize polyphonic SFX player pool
	for i in SFX_POOL_SIZE:
		var pool_player := AudioStreamPlayer.new()
		pool_player.name = "SFXPool_%d" % i
		pool_player.bus = &"SFX"
		add_child(pool_player)
		_sfx_pool.append(pool_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = &"SFX"
	add_child(ambient_player)

	_load_settings()
	bgm_player.finished.connect(_restart_bgm)

func _load_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if file:
		var settings = JSON.parse_string(file.get_as_text()) or {}
		bgm_volume = settings.get("bgm_volume", 70) / 100.0
		sfx_volume = settings.get("sfx_volume", 80) / 100.0
		file.close()

	_apply_volumes()

func _apply_volumes() -> void:
	set_bus_volumes(1.0, bgm_volume, sfx_volume)

## 将存档中的线性音量应用到正式的 Master/Music/SFX 总线。
func set_bus_volumes(master: float, music: float, sfx: float) -> void:
	_set_bus_volume(&"Master", master)
	_set_bus_volume(&"Music", music)
	_set_bus_volume(&"SFX", sfx)
	bgm_volume = music
	sfx_volume = sfx
	ambient_volume = sfx

func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume, 0.0, 1.0)))

## 播放 BGM
func play_bgm(bgm_id: String) -> void:
	if bgm_id == current_bgm:
		return
	current_bgm = bgm_id

	var stream = _load_audio("bgm", bgm_id)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()

func _restart_bgm() -> void:
	if current_bgm == "":
		return
	var stream = _load_audio("bgm", current_bgm)
	if stream:
		bgm_player.stream = stream
		bgm_player.play()

## 停止 BGM
func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm = ""
	battle_music_layer = -1

## 播放音效
func play_sfx(sfx_id: String) -> void:
	var stream = _load_audio("sfx", sfx_id)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

## AUDIO-01: Play SFX through the polyphonic pool so concurrent sounds do not interrupt each other.
func play_sfx_pooled(sfx_id: String) -> void:
	var stream = _load_audio("sfx", sfx_id)
	if stream:
		var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
		player.stream = stream
		player.play()
		_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

## AUDIO-01: Network and alert SFX
func sfx_network_scan() -> void:
	play_sfx_pooled("sfx_network_scan")

func sfx_network_takeover() -> void:
	play_sfx_pooled("sfx_network_takeover")

func sfx_network_disable() -> void:
	play_sfx_pooled("sfx_network_disable")

func sfx_network_overload() -> void:
	play_sfx_pooled("sfx_network_overload")

func sfx_alert_rise() -> void:
	play_sfx_pooled("sfx_alert_rise")

func sfx_camera_reveal() -> void:
	play_sfx_pooled("sfx_camera_reveal")

func sfx_turret_reversal() -> void:
	play_sfx_pooled("sfx_turret_reversal")

func sfx_beacon_delay() -> void:
	play_sfx_pooled("sfx_beacon_delay")

## 播放环境音
func play_ambient(ambient_id: String) -> void:
	var stream = _load_audio("ambient", ambient_id)
	if stream:
		ambient_player.stream = stream
		ambient_player.play()

## 停止环境音
func stop_ambient() -> void:
	ambient_player.stop()

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
	_set_bus_volume(&"Music", bgm_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_set_bus_volume(&"SFX", sfx_volume)

## === 战斗音效快捷方法 ===

func sfx_ui_click() -> void:
	play_sfx("sfx_ui_click")

func sfx_ui_hover() -> void:
	play_sfx("sfx_ui_hover")

func sfx_select_unit() -> void:
	play_sfx("sfx_select_unit")

func sfx_move() -> void:
	play_sfx("sfx_unit_land")

func sfx_attack(weapon_type: String = "pistol") -> void:
	play_sfx("sfx_combat_" + weapon_type)

## 将现有武器 special 映射为可审核的听觉轮廓。
func get_weapon_sfx_profile(weapon_special: String) -> String:
	match weapon_special:
		"close_range_bonus_1.3x_at_2_tiles": return "shotgun"
		"double_tap": return "smg"
		"silent": return "blade"
		"setup_bonus_30_hit", "move_and_shoot": return "sniper"
		"suppressing_fire": return "machine_gun"
		"aoe_3x3_destroy_cover": return "launcher"
		"heal_40", "heal_50", "heal_60": return "medical"
		_: return "pistol"

func sfx_hit() -> void:
	play_sfx("sfx_hit_flesh")

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
	if size == "small":
		bgm_battle_layer(1)
	else:
		play_bgm("bgm_battle_" + size)

## CH1-090: Switch battle music by the public alert level.
## The three tracks are separate procedural loops so the transition remains deterministic.
func bgm_battle_layer(alert_level: int) -> void:
	var layer := clampi(alert_level, 0, 3)
	var track := "bgm_battle_stealth"
	if layer == 1:
		track = "bgm_battle_engaged"
	elif layer >= 2:
		track = "bgm_battle_alert"
	if battle_music_layer == layer and current_bgm == track:
		return
	battle_music_layer = layer
	play_bgm(track)

func bgm_boss() -> void:
	play_bgm("bgm_boss")

func bgm_base() -> void:
	play_bgm("bgm_base")

func bgm_victory() -> void:
	play_bgm("bgm_victory")

func bgm_defeat() -> void:
	play_bgm("bgm_defeat")


