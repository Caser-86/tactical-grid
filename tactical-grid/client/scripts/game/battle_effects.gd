## 战斗特效播放器
## 在指定世界坐标创建临时 Sprite2D / AnimatedSprite2D 特效
extends Node

const FADE_DURATION := 0.25
const SEQUENCE_FRAME_RATE := 12.0

func _ready() -> void:
	name = "BattleEffects"

func play_effect(effect_id: String, world_pos: Vector2, parent: Node = null) -> void:
	var texture = ArtAssets.get_effect_texture(effect_id)
	if not texture:
		return

	if parent == null:
		parent = get_tree().current_scene
	if not parent:
		return

	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.position = world_pos
	parent.add_child(sprite)

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_property(sprite, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(sprite.queue_free)

func play_effect_animated(effect_id: String, world_pos: Vector2, parent: Node = null) -> void:
	if parent == null:
		parent = get_tree().current_scene
	if not parent:
		return

	var frames = _load_sequence_frames(effect_id)
	if frames.is_empty():
		# fallback 到单张图
		play_effect(effect_id, world_pos, parent)
		return

	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	var anim_name = "default"
	sprite.sprite_frames.add_animation(anim_name)
	sprite.sprite_frames.set_animation_speed(anim_name, SEQUENCE_FRAME_RATE)
	sprite.sprite_frames.set_animation_loop(anim_name, false)
	for tex in frames:
		sprite.sprite_frames.add_frame(anim_name, tex)

	sprite.position = world_pos
	sprite.animation_finished.connect(sprite.queue_free)
	parent.add_child(sprite)
	sprite.play(anim_name)

func _load_sequence_frames(effect_id: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var base_path = "res://assets/effects/sequences/%s_frames/" % effect_id
	var i = 1
	while true:
		var path = base_path + "frame_%02d.png" % i
		if not FileAccess.file_exists(path):
			break
		var tex = load(path)
		if tex is Texture2D:
			result.append(tex)
		i += 1
		if i > 60:
			break
	return result

func play_hit(world_pos: Vector2, parent: Node = null) -> void:
	play_effect("hit", world_pos, parent)

func play_critical(world_pos: Vector2, parent: Node = null) -> void:
	play_effect("critical", world_pos, parent)

func play_heal(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("heal", world_pos, parent)

func play_explosion(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("explosion", world_pos, parent)

func play_smoke(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("smoke", world_pos, parent)

func play_teleport(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("teleport", world_pos, parent)

func play_buff(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("buff", world_pos, parent)

func play_debuff(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("debuff", world_pos, parent)

func play_electro(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("electro", world_pos, parent)

func play_burn(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("burn", world_pos, parent)

func play_freeze(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("freeze", world_pos, parent)

func play_muzzle_flash(world_pos: Vector2, parent: Node = null) -> void:
	play_effect_animated("muzzle_flash", world_pos, parent)

func play_boss_phase_transition(world_pos: Vector2, parent: Node = null) -> void:
	if parent == null:
		parent = get_tree().current_scene
	if not parent:
		return

	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.7, 0.15)
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)

	var ring = Sprite2D.new()
	ring.position = world_pos
	ring.modulate = Color(1.0, 0.3, 0.1, 0.8)
	var tex = ArtAssets.get_effect_texture("hit")
	if tex:
		ring.texture = tex
	parent.add_child(ring)
	var ring_tween = create_tween()
	ring_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.6).from(Vector2(0.5, 0.5))
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
	ring_tween.tween_callback(ring.queue_free)
