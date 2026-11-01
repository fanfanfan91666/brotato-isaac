extends Reference

const PREFIX = "item_local_isaac_"
const RANDOM_STATS = ["stat_max_hp", "stat_armor", "stat_dodge", "stat_hp_regeneration", "stat_lifesteal", "stat_percent_damage", "stat_attack_speed", "stat_range", "stat_speed", "stat_luck", "stat_harvesting"]

static func probability(name: String, p: int) -> float:
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    var base = rules.max_value(name, p, "chance")
    var per_luck = rules.max_value(name, p, "per_luck")
    var cap = rules.max_value(name, p, "cap")
    return clamp(base + Utils.get_stat(Keys.stat_luck_hash, p) * per_luck, 0.0, cap)

static func roll(p: int) -> Dictionary:
    var result = {"charm": false, "clear": false}
    if RunData.get_nb_item(Keys.generate_hash(PREFIX + "moms_eyeshadow"), p) > 0:
        result.charm = Utils._rng.randf() < probability("moms_eyeshadow", p)
    if RunData.get_nb_item(Keys.generate_hash(PREFIX + "lost_contact"), p) > 0:
        result.clear = Utils._rng.randf() < probability("lost_contact", p)
    return result

static func prepare_random(item: ItemData, keep_roll: bool = false) -> ItemData:
    var result = item.duplicate(false)
    result.is_cursed = item.is_cursed
    result.curse_factor = item.curse_factor
    result.isaac_random_points = item.isaac_random_points.duplicate()
    result.effects = []
    for source_effect in item.effects:
        var private_effect = source_effect.duplicate(false)
        private_effect.curse_factor = source_effect.curse_factor
        result.effects.append(private_effect)
    if keep_roll and not result.isaac_random_points.empty():
        return result
    var config = load("res://mods-unpacked/Local-Isaac/curse_rules.gd").params("dressed_boy", load("res://mods-unpacked/Local-Isaac/curse_rules.gd").item_factor(item))
    result.isaac_random_points = []
    result.isaac_random_points.resize(RANDOM_STATS.size())
    for i in RANDOM_STATS.size():
        result.isaac_random_points[i] = 0
    for _point in int(config.points):
        var index = Utils.randi_range(0, RANDOM_STATS.size() - 1)
        result.isaac_random_points[index] += 1
    return result

static func grant_random(item: ItemData, p: int) -> void:
    for i in min(item.isaac_random_points.size(), RANDOM_STATS.size()):
        if int(item.isaac_random_points[i]) > 0:
            RunData.add_stat(Keys.generate_hash(RANDOM_STATS[i]), int(item.isaac_random_points[i]), p)

static func allocation(effect: Resource, p: int) -> Array:
    if p < 0 or p >= RunData.get_player_count():
        return []
    for item in RunData.get_player_items(p):
        if item.my_id == PREFIX + "dressed_boy" and item.effects.has(effect):
            return item.isaac_random_points
    return []

static func allocation_text(points: Array, p: int) -> String:
    var lines = []
    for i in min(points.size(), RANDOM_STATS.size()):
        if int(points[i]) <= 0:
            continue
        var stat = Effect.new()
        stat.key = RANDOM_STATS[i]
        stat.key_hash = Keys.generate_hash(stat.key)
        stat.value = int(points[i])
        lines.append(load("res://mods-unpacked/Local-Isaac/description_rules.gd").icon(stat.key_hash) + " " + stat.get_text(p))
    return PoolStringArray(lines).join("\n")
