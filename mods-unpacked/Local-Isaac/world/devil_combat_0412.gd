extends Node

const PREFIX = "item_local_isaac_"
var game: Node
var nightmare = {}
var blood = {}
var cooldowns = {}
var kills = {}
var gust = {}
var hits = {}
var finished = false

static func needed() -> bool:
    for p in RunData.get_player_count():
        if RunData.get_nb_item(Keys.generate_hash(PREFIX + "nightmare"), p) > 0 or RunData.get_nb_item(Keys.generate_hash(PREFIX + "lusty_blood"), p) > 0 or RunData.get_nb_item(Keys.generate_hash(PREFIX + "bloody_gust"), p) > 0:
            return true
    return false

func _ready() -> void:
    game = get_parent()
    game.connect("end_of_the_wave", self, "finish")
    var rules = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    for p in RunData.get_player_count():
        if RunData.get_nb_item(Keys.generate_hash(PREFIX + "nightmare"), p) > 0:
            nightmare[p] = {"radius": rules.max_value("nightmare", p, "radius", 200.0), "duration": rules.max_value("nightmare", p, "duration", 2.0), "cooldown": rules.min_value("nightmare", p, "cooldown", 8.0)}
            cooldowns[p] = 0.0
        if RunData.get_nb_item(Keys.generate_hash(PREFIX + "lusty_blood"), p) > 0:
            blood[p] = {"kills": int(rules.min_value("lusty_blood", p, "kills", 50.0)), "damage": int(rules.sum_value("lusty_blood", p, "damage"))}
            kills[p] = 0
        if RunData.get_nb_item(Keys.generate_hash(PREFIX + "bloody_gust"), p) > 0:
            gust[p] = {"speed": int(rules.sum_value("bloody_gust", p, "speed")), "attack_speed": int(rules.sum_value("bloody_gust", p, "attack_speed")), "stacks": 10}
            hits[p] = 0

func active() -> bool:
    return not finished and RunData.wave_in_progress and is_instance_valid(game) and game == Utils.get_scene_node() and game.get("_cleaning_up") == false

func _physics_process(delta: float) -> void:
    if not active() or (is_inside_tree() and get_tree().paused):
        return
    for p in cooldowns:
        cooldowns[p] = max(0.0, float(cooldowns[p]) - max(0.0, delta))

func on_player_damaged(player: Node, actual_damage: int) -> void:
    if actual_damage <= 0 or not active() or not is_instance_valid(player):
        return
    var p = player.player_index
    if gust.has(p) and int(hits[p]) < int(gust[p].stacks):
        hits[p] = int(hits[p]) + 1
        TempStats.add_stat(Keys.stat_speed_hash, int(gust[p].speed), p)
        TempStats.add_stat(Keys.stat_attack_speed_hash, int(gust[p].attack_speed), p)
    if not nightmare.has(p) or float(cooldowns[p]) > 0.0:
        return
    var values = nightmare[p]
    cooldowns[p] = float(values.cooldown)
    var radius_squared = float(values.radius) * float(values.radius)
    var fear = load("res://mods-unpacked/Local-Isaac/world/fear_041.gd")
    # Only the actual, cooldown-gated damage event visits nearby enemies.
    # The native Lantern's aura radius is 200; no pulse node or visual is made.
    for enemy in game._entity_spawner.enemies.duplicate():
        if not is_instance_valid(enemy) or not enemy is Enemy or enemy.dead or enemy._pending_die or enemy.sleeping or enemy.cleaning_up or enemy.get_charmed_by_player_index() >= 0:
            continue
        if enemy.global_position.distance_squared_to(player.global_position) <= radius_squared:
            fear.apply(enemy, float(values.duration))

func on_enemy_died(enemy: Enemy, args: Entity.DieArgs) -> void:
    if not active() or not is_instance_valid(enemy) or enemy.get("isaac_was_charmed_on_death") == true or enemy.get_charmed_by_player_index() >= 0 or args.cleaning_up or not args.enemy_killed_by_player:
        return
    var p = int(args.killed_by_player_index)
    if p < 0 or p >= RunData.get_player_count() or not blood.has(p):
        return
    # Native DieArgs carries attribution for weapons, pets and DOT alike.
    # Main's Enemy-only callback excludes trees, rocks and other Neutrals.
    kills[p] = int(kills[p]) + 1
    var values = blood[p]
    if int(kills[p]) < int(values.kills):
        return
    kills[p] = int(kills[p]) - int(values.kills)
    TempStats.add_stat(Keys.stat_percent_damage_hash, int(values.damage), p)

func finish() -> void:
    finished = true
    nightmare.clear()
    blood.clear()
    cooldowns.clear()
    kills.clear()
    gust.clear()
    hits.clear()
    # Main resets TempStats after end_of_the_wave, including this item's gain.
