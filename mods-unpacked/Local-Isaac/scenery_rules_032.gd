extends Reference

const PATH = "res://mods-unpacked/Local-Isaac/scenery_rules_032.gd"

static func cache() -> Dictionary:
    var script = load(PATH)
    if not script.has_meta("scenery_cache"):
        script.set_meta("scenery_cache", {"scenes": {}, "zone": null, "tree": {}})
    return script.get_meta("scenery_cache")

static func scene_info(scene: PackedScene) -> Dictionary:
    if scene == null:
        return {}
    var scenes = cache().scenes
    var id = scene.get_instance_id()
    if not scenes.has(id):
        # Native trees on both maps inherit Neutral. Resolve the actual scene
        # once, without adding it to a tree or running its ready/loot behavior.
        var neutral = scene.instance()
        var tree = neutral is Neutral
        scenes[id] = {"scene": scene, "tree": tree, "stats": neutral.stats if tree else null}
        neutral.free()
    return scenes[id]

static func is_tree_unit(unit_data: WaveUnitData) -> bool:
    return unit_data != null and unit_data.type == EntityType.NEUTRAL and bool(scene_info(unit_data.unit_scene).get("tree", false))

static func tree_in_groups(groups: Array) -> Dictionary:
    for group in groups:
        for unit_data in group.wave_units_data:
            if is_tree_unit(unit_data):
                return scene_info(unit_data.unit_scene)
    return {}

static func current_tree_info() -> Dictionary:
    var zone = ZoneService.current_zone
    if zone == null or zone.my_id != RunData.current_zone:
        zone = ZoneService.get_zone_data(RunData.current_zone)
    var state = cache()
    if state.zone != zone:
        state.zone = zone
        # ZoneData has no default_tree field: native WaveTree comes from these
        # always-present groups. Keep its scene/stats instead of a map path.
        state.tree = tree_in_groups(zone.groups_data_in_all_waves)
        if state.tree.empty():
            for wave in zone.waves_data:
                state.tree = tree_in_groups(wave.groups_data)
                if not state.tree.empty():
                    break
    return state.tree

static func current_tree_stats() -> Resource:
    return current_tree_info().get("stats", null)

static func is_tree(tree) -> bool:
    return is_instance_valid(tree) and tree is Neutral
