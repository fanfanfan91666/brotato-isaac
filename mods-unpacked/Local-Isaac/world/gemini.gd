extends Node

var game: Main
var chosen = {}
var extra_counts = {}
var extra_orbitals = []
var finished = false
var started = false

func _ready() -> void:
    if started:
        return
    started = true
    game = get_parent()
    game.connect("end_of_the_wave", self, "finish")
    for p in RunData.get_player_count():
        if RunData.get_nb_item(Keys.generate_hash("item_local_isaac_gemini"), p) <= 0:
            continue
        var pool = candidates(p)
        if pool.empty():
            chosen[p] = null
            continue
        var selected = pool[Utils.randi_range(0, pool.size() - 1)]
        chosen[p] = selected[0]
        var count = int(load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("gemini", p, "copies", 1.0))
        var pair_size = 2 if selected[0].my_id == "item_local_isaac_sin_twins" else 1
        extra_counts[p] = count * pair_size
        Utils.reset_stat_cache(p)
        RunData._are_player_stats_dirty[p] = true
        for _i in count * pair_size:
            if selected[1] == null:
                var guardian = load("res://mods-unpacked/Local-Isaac/world/guardian_angel_0413.gd").spawn_copy(game._players[p], _i, count)
                extra_orbitals.append([game._players[p], guardian])
                continue
            var effect = selected[1].duplicate(false)
            effect.scene = selected[1].scene
            effect.is_cursed = selected[1].is_cursed
            effect.value = 1
            effect.curse_factor = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").effect_factor(selected[1], p, selected[0].my_id)
            effect.set_meta("isaac_gemini_temporary", true)
            effect.set_meta("isaac_gemini_phase", TAU * float(_i + 1) / float(count + 1))
            if pair_size == 2:
                effect.set_meta("isaac_gemini_phase", PI * float(int(_i / 2) + 1) / float(count + 1))
            var pos = game._players[p].global_position + Vector2(120, 0).rotated(Utils._rng.randf_range(-PI, PI))
            var request = SpawnRequest.new(EntityType.PET, effect.scene, pos)
            request.data = effect
            game._entity_spawner.queues_to_spawn_pets[p].append(request)

func candidates(p: int) -> Array:
    var result = []
    for item in RunData.get_player_items(p):
        if not item.my_id.begins_with("item_local_isaac_"):
            continue
        if item.my_id == "item_local_isaac_guardian_angel":
            result.append([item, null])
            continue
        for effect in item.effects:
            if effect is PetEffect and not effect.is_structure and effect.scene != null and effect.scene.resource_path.begins_with("res://mods-unpacked/Local-Isaac/world/"):
                result.append([item, effect])
    return result

func count(p: int) -> int:
    return int(extra_counts.get(p, 0)) if not finished and RunData.wave_in_progress else 0

func description(p: int) -> String:
    if finished or not RunData.wave_in_progress or not chosen.has(p):
        return ""
    var source = chosen[p]
    if source == null:
        return Text.text("LOCAL_ISAAC_GEMINI_EMPTY")
    return Text.text("LOCAL_ISAAC_GEMINI_CURRENT", [tr(source.name)]) + "\n" + source.get_effects_text(p)

func finish() -> void:
    if finished:
        return
    finished = true
    for p in extra_counts:
        if p < RunData.get_player_count():
            Utils.reset_stat_cache(p)
            RunData._are_player_stats_dirty[p] = true
    extra_counts.clear()
    chosen.clear()
    for row in extra_orbitals:
        if is_instance_valid(row[0]):
            row[0].jellyshields.erase(row[1])
        if is_instance_valid(row[1]):
            row[1].end_of_wave_callback()
            row[1].queue_free()
    extra_orbitals.clear()
    if not is_instance_valid(game) or not is_instance_valid(game._entity_spawner):
        return
    for queue in game._entity_spawner.queues_to_spawn_pets:
        for request in queue.duplicate():
            if request.data != null and request.data.has_meta("isaac_gemini_temporary"):
                queue.erase(request)
    for pet in game._entity_spawner.pets.duplicate():
        if is_instance_valid(pet) and pet.has_meta("isaac_gemini_temporary"):
            game._entity_spawner.pets.erase(pet)
            game._entity_spawner.targetable_pets.erase(pet)
            pet.end_of_wave_callback()
            pet.queue_free()

func _exit_tree() -> void:
    finish()
