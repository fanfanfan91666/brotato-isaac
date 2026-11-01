extends "res://global/entity_spawner.gd"

const RULES = preload("res://mods-unpacked/Local-Isaac/bomb_rules.gd")

func spawn_entity(scene: PackedScene, args: SpawnEntityArgs, data: Resource = null, source = null, charmed_by: int = -1) -> KinematicBody2D:
    var entity = .spawn_entity(scene, args, data, source, charmed_by)
    if entity != null and args.type == EntityType.PET and data != null and data.has_meta("isaac_gemini_temporary"):
        entity.set_meta("isaac_gemini_temporary", true)
        entity.set_meta("isaac_gemini_phase", data.get_meta("isaac_gemini_phase"))
    if entity != null and args.type == EntityType.ENEMY and charmed_by >= 0 and is_instance_valid(source) and source is Enemy:
        var inherited = source.effect_behaviors.get_node_or_null("IsaacEyeshadowCharm")
        if inherited != null and inherited.charmed:
            load("res://mods-unpacked/Local-Isaac/world/attack_utility.gd").apply_charm(entity, charmed_by, max(0.01, inherited._charm_timer.time_left))
    return entity

func on_entity_birth_timeout(birth: EntityBirth) -> void:
    if birth.data != null and birth.data.has_meta("isaac_gemini_temporary"):
        var component = _main.get("isaac_gemini")
        if not _main.is_inside_tree() or not is_instance_valid(component) or component.finished:
            active_births = int(max(0, active_births - 1))
            if _main.is_inside_tree():
                _main.add_node_to_pool(birth, _entity_birth_pool_id)
            else:
                birth.queue_free()
            return
    .on_entity_birth_timeout(birth)

func isaac_is_tree(unit_data: WaveUnitData) -> bool:
    return load("res://mods-unpacked/Local-Isaac/scenery_rules_032.gd").is_tree_unit(unit_data)

func isaac_scenery_group(group_data: WaveGroupData) -> WaveGroupData:
    var adjusted = group_data.duplicate()
    adjusted.wave_units_data = []
    for data in group_data.wave_units_data:
        var copy = data.duplicate()
        if isaac_is_tree(data):
            copy.spawn_chance *= RULES.SCENERY_RATE
        adjusted.wave_units_data.append(copy)
    return adjusted

func on_group_spawn_timing_reached(group_data: WaveGroupData) -> void:
    if _cleaning_up:
        return
    var has_trees = false
    for data in group_data.wave_units_data:
        has_trees = has_trees or isaac_is_tree(data)
    if not has_trees:
        .on_group_spawn_timing_reached(group_data)
        return
    var adjusted = isaac_scenery_group(group_data)
    # Keep native enemy generation and the original Tree item's additive bonus.
    .on_group_spawn_timing_reached(adjusted)
    for data in group_data.wave_units_data:
        if not isaac_is_tree(data):
            continue
        var number = Utils.randi_range(data.min_number, data.max_number) * DebugService.nb_enemies_mult
        number += RunData.sum_all_player_effects(Keys.generate_hash(RULES.ROCKS))
        var expected = max(0.0, number * data.spawn_chance * RULES.SCENERY_RATE)
        var count = int(expected) + (1 if Utils.get_chance_success(expected - int(expected)) else 0)
        var group_pos = get_group_pos_away_from_players(get_group_pos(group_data), group_data)
        for _i in range(count):
            var pos = get_spawn_pos_in_area(group_pos, group_data.area, group_data.spawn_dist_away_from_edges, group_data.spawn_edge_of_map)
            pos = get_spawn_pos_away_from_players(pos, group_pos, group_data, data)
            _main.isaac_spawn_rock(pos)
