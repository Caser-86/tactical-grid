## Chapter One production-art catalog.
## Gameplay code asks for stable IDs instead of owning generated asset paths.
extends Node

const ROOT := "res://assets/generated/chapter1/runtime/"
const ENVIRONMENT_ROOT := ROOT + "environment/"
const ENVIRONMENT_COMPONENTS := {
	&"echo_yard": {
		&"floor": [
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_00.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_01.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_02.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_03.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_04.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_05.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_06.png",
			ENVIRONMENT_ROOT + "echo_yard/floor/floor_07.png",
		],
		&"edge": [
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_north.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_east.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_south.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_west.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_corner_nw.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_corner_ne.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_corner_se.png",
			ENVIRONMENT_ROOT + "echo_yard/edge/edge_corner_sw.png",
		],
		&"prop": [
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_00.png",
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_01.png",
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_02.png",
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_03.png",
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_04.png",
			ENVIRONMENT_ROOT + "echo_yard/prop/prop_05.png",
		],
		&"decal": [
			ENVIRONMENT_ROOT + "echo_yard/decal/decal_00.png",
			ENVIRONMENT_ROOT + "echo_yard/decal/decal_01.png",
			ENVIRONMENT_ROOT + "echo_yard/decal/decal_02.png",
		],
		&"landmark": [
			ENVIRONMENT_ROOT + "echo_yard/landmark/gantry_crane_192x128.png",
			ENVIRONMENT_ROOT + "echo_yard/landmark/floodlight_tower_128.png",
		],
	},
	&"cooling_works": {
		&"floor": [
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_00.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_01.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_02.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_03.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_04.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_05.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_06.png",
			ENVIRONMENT_ROOT + "cooling_works/floor/floor_07.png",
		],
		&"edge": [
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_north.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_east.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_south.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_west.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_corner_nw.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_corner_ne.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_corner_se.png",
			ENVIRONMENT_ROOT + "cooling_works/edge/edge_corner_sw.png",
		],
		&"prop": [
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_00.png",
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_01.png",
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_02.png",
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_03.png",
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_04.png",
			ENVIRONMENT_ROOT + "cooling_works/prop/prop_05.png",
		],
		&"decal": [
			ENVIRONMENT_ROOT + "cooling_works/decal/decal_00.png",
			ENVIRONMENT_ROOT + "cooling_works/decal/decal_01.png",
			ENVIRONMENT_ROOT + "cooling_works/decal/decal_02.png",
		],
		&"landmark": [
			ENVIRONMENT_ROOT + "cooling_works/landmark/cooling_tower_base_192x128.png",
			ENVIRONMENT_ROOT + "cooling_works/landmark/turbine_manifold_128.png",
		],
	},
	&"transit_hub": {
		&"floor": [
			ENVIRONMENT_ROOT + "transit_hub/floor/floor_00.png", ENVIRONMENT_ROOT + "transit_hub/floor/floor_01.png",
			ENVIRONMENT_ROOT + "transit_hub/floor/floor_02.png", ENVIRONMENT_ROOT + "transit_hub/floor/floor_03.png",
			ENVIRONMENT_ROOT + "transit_hub/floor/floor_04.png", ENVIRONMENT_ROOT + "transit_hub/floor/floor_05.png",
			ENVIRONMENT_ROOT + "transit_hub/floor/floor_06.png", ENVIRONMENT_ROOT + "transit_hub/floor/floor_07.png",
		],
		&"edge": [
			ENVIRONMENT_ROOT + "transit_hub/edge/edge_north.png", ENVIRONMENT_ROOT + "transit_hub/edge/edge_east.png",
			ENVIRONMENT_ROOT + "transit_hub/edge/edge_south.png", ENVIRONMENT_ROOT + "transit_hub/edge/edge_west.png",
			ENVIRONMENT_ROOT + "transit_hub/edge/edge_corner_nw.png", ENVIRONMENT_ROOT + "transit_hub/edge/edge_corner_ne.png",
			ENVIRONMENT_ROOT + "transit_hub/edge/edge_corner_se.png", ENVIRONMENT_ROOT + "transit_hub/edge/edge_corner_sw.png",
		],
		&"prop": [
			ENVIRONMENT_ROOT + "transit_hub/prop/prop_00.png", ENVIRONMENT_ROOT + "transit_hub/prop/prop_01.png",
			ENVIRONMENT_ROOT + "transit_hub/prop/prop_02.png", ENVIRONMENT_ROOT + "transit_hub/prop/prop_03.png",
			ENVIRONMENT_ROOT + "transit_hub/prop/prop_04.png", ENVIRONMENT_ROOT + "transit_hub/prop/prop_05.png",
		],
		&"decal": [
			ENVIRONMENT_ROOT + "transit_hub/decal/decal_00.png", ENVIRONMENT_ROOT + "transit_hub/decal/decal_01.png", ENVIRONMENT_ROOT + "transit_hub/decal/decal_02.png",
		],
		&"landmark": [
			ENVIRONMENT_ROOT + "transit_hub/landmark/suspended_train_nose_192x128.png", ENVIRONMENT_ROOT + "transit_hub/landmark/signal_gantry_128.png",
		],
	},
	&"sentinel_core": {
		&"floor": [ENVIRONMENT_ROOT + "sentinel_core/floor/floor_00.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_01.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_02.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_03.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_04.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_05.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_06.png",ENVIRONMENT_ROOT + "sentinel_core/floor/floor_07.png"],
		&"edge": [ENVIRONMENT_ROOT + "sentinel_core/edge/edge_north.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_east.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_south.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_west.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_corner_nw.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_corner_ne.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_corner_se.png",ENVIRONMENT_ROOT + "sentinel_core/edge/edge_corner_sw.png"],
		&"prop": [ENVIRONMENT_ROOT + "sentinel_core/prop/prop_00.png",ENVIRONMENT_ROOT + "sentinel_core/prop/prop_01.png",ENVIRONMENT_ROOT + "sentinel_core/prop/prop_02.png",ENVIRONMENT_ROOT + "sentinel_core/prop/prop_03.png",ENVIRONMENT_ROOT + "sentinel_core/prop/prop_04.png",ENVIRONMENT_ROOT + "sentinel_core/prop/prop_05.png"],
		&"decal": [ENVIRONMENT_ROOT + "sentinel_core/decal/decal_00.png",ENVIRONMENT_ROOT + "sentinel_core/decal/decal_01.png",ENVIRONMENT_ROOT + "sentinel_core/decal/decal_02.png"],
		&"landmark": [ENVIRONMENT_ROOT + "sentinel_core/landmark/sentinel_aperture_192x128.png",ENVIRONMENT_ROOT + "sentinel_core/landmark/phase_pylons_128.png"],
	},
}
const PATHS := {
	&"background": {
		&"mission_debrief": "res://assets/generated/chapter1/backgrounds/mission_debrief_data_city_v1.png",
		&"boot_command_network": "res://assets/generated/chapter1/backgrounds/boot_command_network_v1.png",
	},
	&"item": {
		&"assault_rifle": ROOT + "icons/assault_rifle_128.png",
		&"sniper_rifle": ROOT + "icons/sniper_rifle_128.png",
		&"machine_gun": ROOT + "icons/machine_gun_128.png",
		&"grenade_launcher": ROOT + "icons/grenade_launcher_128.png",
		&"shotgun": ROOT + "icons/shotgun_128.png",
		&"suppressed_pistol": ROOT + "icons/suppressed_pistol_128.png",
		&"tactical_knife": ROOT + "icons/tactical_knife_128.png",
		&"medical_gun": ROOT + "icons/medical_gun_128.png",
		&"med_kit": ROOT + "icons/med_kit_128.png",
		&"injector": ROOT + "icons/injector_128.png",
		&"frag_grenade": ROOT + "icons/frag_grenade_128.png",
		&"emp_grenade": ROOT + "icons/emp_grenade_128.png",
		&"smoke_grenade": ROOT + "icons/smoke_grenade_128.png",
		&"incendiary": ROOT + "icons/incendiary_128.png",
		&"shield_generator": ROOT + "icons/shield_generator_128.png",
		&"proximity_mine": ROOT + "icons/proximity_mine_128.png",
	},
	&"hud": {
		&"move": ROOT + "hud_icons/move_128.png",
		&"attack": ROOT + "hud_icons/attack_128.png",
		&"skill": ROOT + "hud_icons/skill_128.png",
		&"item": ROOT + "hud_icons/item_128.png",
		&"overwatch": ROOT + "hud_icons/overwatch_128.png",
		&"end_turn": ROOT + "hud_icons/end_turn_128.png",
	},
	&"status": {
		&"marked": ROOT + "status_icons/marked_64.png",
		&"barrier": ROOT + "status_icons/barrier_64.png",
		&"stealth": ROOT + "status_icons/stealth_64.png",
		&"overwatch": ROOT + "status_icons/overwatch_64.png",
		&"bleed": ROOT + "status_icons/bleed_64.png",
		&"burn": ROOT + "status_icons/burn_64.png",
		&"poison": ROOT + "status_icons/poison_64.png",
		&"blind": ROOT + "status_icons/blind_64.png",
		&"suppress": ROOT + "status_icons/suppress_64.png",
		&"jammed": ROOT + "status_icons/jammed_64.png",
		&"rooted": ROOT + "status_icons/rooted_64.png",
		&"silenced": ROOT + "status_icons/silenced_64.png",
	},
	&"terrain": {
		&"data_floor": ROOT + "tiles/data_floor_64.png",
		&"road": ROOT + "tiles/road_64.png",
		&"forest": ROOT + "tiles/forest_64.png",
		&"sand": ROOT + "tiles/sand_64.png",
		&"highland": ROOT + "tiles/highland_64.png",
		&"water": ROOT + "tiles/water_64.png",
		&"toxic": ROOT + "tiles/toxic_64.png",
	},
	&"unit": {
		&"assault": ROOT + "units/assault_96.png",
		&"sniper": ROOT + "units/sniper_96.png",
		&"heavy": ROOT + "units/heavy_96.png",
		&"medic": ROOT + "units/medic_topdown_64.png",
		&"scout": ROOT + "units/scout_96.png",
		&"attack_drone": ROOT + "units/attack_drone_topdown_64.png",
		&"drone_scout": ROOT + "units/drone_scout_96.png",
		&"drone_assault": ROOT + "units/drone_assault_96.png",
		&"protocol_engineer": ROOT + "units/protocol_engineer_96.png",
		&"hunter": ROOT + "units/hunter_96.png",
		&"drone_bomber": ROOT + "units/attack_drone_topdown_64.png",
		&"cyber_guard": ROOT + "units/cyber_guard_64.png",
		&"sentry_basic": ROOT + "units/sentry_basic_96.png",
		&"sentry_elite": ROOT + "units/cyber_guard_64.png",
		&"sentry_sniper": ROOT + "units/sentry_sniper_96.png",
		&"sniper_elite": ROOT + "units/cyber_guard_64.png",
		&"shield_bot": ROOT + "units/shield_bot_64.png",
		&"shield_maestro": ROOT + "units/shield_bot_64.png",
		&"heavy_gunner": ROOT + "units/heavy_gunner_64.png",
		&"assault_mech": ROOT + "units/heavy_gunner_64.png",
		&"rocket_trooper": ROOT + "units/rocket_trooper_64.png",
		&"siege_mech": ROOT + "units/rocket_trooper_64.png",
		&"stealth_assassin": ROOT + "units/stealth_assassin_64.png",
		&"stealth_drone": ROOT + "units/attack_drone_topdown_64.png",
		&"matrix_collider": ROOT + "units/cyber_guard_64.png",
		&"boss_data_sentinel": ROOT + "units/boss_data_sentinel_96.png",
		&"boss_heavy_judge": ROOT + "units/boss_heavy_judge_96.png",
		&"boss_shadow_mercenary": ROOT + "units/boss_shadow_mercenary_96.png",
		&"boss_matrix_general": ROOT + "units/boss_matrix_general_96.png",
		&"boss_architect": ROOT + "units/boss_architect_96.png",
		&"flame_trooper": ROOT + "units/flame_trooper_64.png",
		&"poison_spitter": ROOT + "units/poison_spitter_64.png",
		&"combat_medic": ROOT + "units/combat_medic_64.png",
		&"jammer": ROOT + "units/jammer_64.png",
	},
	&"blocker": {
		&"metal_barricade": ROOT + "blockers/metal_barricade_64.png",
		&"steel_wall": ROOT + "blockers/steel_wall_64.png",
		&"supply_crate": ROOT + "blockers/supply_crate_64.png",
	},
	&"objective": {
		&"terminal": ROOT + "objectives/terminal_64.png",
		&"evac": ROOT + "objectives/evac_64.png",
		&"reactor_target": ROOT + "objectives/reactor_target_64.png",
	},
	&"network_node": {
		&"camera": ROOT + "network_icons/camera_64.png",
		&"door": ROOT + "network_icons/door_64.png",
		&"turret": ROOT + "network_icons/turret_64.png",
		&"power_conduit": ROOT + "network_icons/power_conduit_64.png",
		&"reinforcement_beacon": ROOT + "network_icons/reinforcement_beacon_64.png",
	},
	&"effect": {
		&"muzzle": ROOT + "effects/muzzle_128.png",
		&"hit": ROOT + "effects/hit_128.png",
		&"explosion": ROOT + "effects/explosion_128.png",
		&"heal": ROOT + "effects/heal_128.png",
		&"terminal": ROOT + "effects/terminal_128.png",
		&"crit": ROOT + "effects/crit_128.png",
		&"miss": ROOT + "effects/miss_128.png",
	},
	&"portrait": {
		&"alpha": ROOT + "portraits/alpha_portrait_512_v2.png",
		&"commander": ROOT + "portraits/commander_portrait_512_v4.png",
		&"lila": ROOT + "portraits/lila_portrait_512.png",
		&"doctor": ROOT + "portraits/doctor_portrait_512_v5.png",
		&"sentinel": ROOT + "portraits/sentinel_portrait_512.png",
		&"shadow": ROOT + "portraits/shadow_portrait_512.png",
		&"architect": ROOT + "portraits/architect_portrait_512.png",
	},
}

const ITEM_ICON_KEYS := {
	&"shotgun": &"shotgun", &"shotgun_mk2": &"shotgun",
	&"smg": &"assault_rifle", &"smg_x7": &"assault_rifle",
	&"knife": &"tactical_knife", &"plasma_blade": &"tactical_knife", &"nano_blade": &"tactical_knife",
	&"sniper_rifle": &"sniper_rifle", &"marksman_rifle": &"sniper_rifle", &"em_sniper": &"sniper_rifle", &"orbital_strike_rifle": &"sniper_rifle",
	&"mg": &"machine_gun", &"gatling": &"machine_gun", &"railgun": &"machine_gun",
	&"grenade_launcher": &"grenade_launcher",
	&"med_gun": &"medical_gun", &"nano_med_gun": &"medical_gun", &"life_drain_gun": &"medical_gun",
	&"silenced_pistol": &"suppressed_pistol", &"silenced_pistol_mk2": &"suppressed_pistol",
	&"phantom_dual_blade": &"tactical_knife", &"legendary_weapon_shadow_blade": &"tactical_knife",
	&"med_kit": &"med_kit", &"advanced_med_kit": &"med_kit", &"painkiller": &"med_kit", &"heal_mist": &"med_kit",
	&"adrenaline_shot": &"injector", &"energy_drink": &"injector", &"revival_needle": &"injector",
	&"grenade": &"frag_grenade", &"flashbang": &"emp_grenade", &"emp_grenade": &"emp_grenade",
	&"smoke_grenade": &"smoke_grenade", &"molotov": &"incendiary",
	&"shield_generator": &"shield_generator", &"cloak_invisibility": &"shield_generator",
	&"mine": &"proximity_mine", &"wire_trap": &"proximity_mine",
	&"legendary_armor": &"shield_generator", &"legendary_full_set": &"shield_generator",
}

func has_texture(kind: StringName, key: StringName) -> bool:
	var path := _get_path(kind, key)
	return not path.is_empty() and FileAccess.file_exists(path)

func get_texture(kind: StringName, key: StringName) -> Texture2D:
	var path := _get_path(kind, key)
	if path.is_empty():
		return null
	return load(path) as Texture2D

func get_item_icon_key(item_id: StringName) -> StringName:
	return ITEM_ICON_KEYS.get(item_id, &"assault_rifle")

func get_environment_component_paths(kit: StringName, component_type: StringName) -> Array:
	if not ENVIRONMENT_COMPONENTS.has(kit):
		return []
	return ENVIRONMENT_COMPONENTS[kit].get(component_type, []).duplicate()

func get_environment_component_texture(kit: StringName, component_type: StringName, variant: int = 0) -> Texture2D:
	var paths := get_environment_component_paths(kit, component_type)
	if paths.is_empty():
		return null
	var path: String = paths[posmod(variant, paths.size())]
	return load(path) as Texture2D

func missing_keys() -> PackedStringArray:
	var missing := PackedStringArray()
	for kind in PATHS:
		for key in PATHS[kind]:
			if not has_texture(kind, key):
				missing.append("%s/%s" % [kind, key])
	return missing

func _get_path(kind: StringName, key: StringName) -> String:
	if not PATHS.has(kind):
		return ""
	return PATHS[kind].get(key, "")
