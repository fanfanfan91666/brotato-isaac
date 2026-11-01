extends Node

# Per-player, per-wave state. This component does not replace a native base class.
const GOLD = Color(1.0, 0.78, 0.12, 1.0)
const RULES_PATH = "res://mods-unpacked/Local-Isaac/zodiac_rules.gd"
var player: Node
var taurus_bonus = 0
var taurus_elapsed = 0.0
var taurus_triggered = false
var taurus_invincibility_left = 0.0
var aries_granted = false
var cancer_active = false
var wave_number = -1
var wave_active = false
var gold_bars = []

static func attach(owner_player: Node) -> Node:
    var existing = owner_player.get_node_or_null("IsaacZodiac")
    if existing != null:
        return existing
    var result = load("res://mods-unpacked/Local-Isaac/world/zodiac_player.gd").new()
    result.name = "IsaacZodiac"
    result.player = owner_player
    owner_player.add_child(result)
    return result

func initialize(owner_player: Node) -> void:
    player = owner_player

func _ready() -> void:
    if player == null:
        player = get_parent()

func owner_index() -> int:
    return int(player.player_index) if is_instance_valid(player) else -1

func owns(name: String) -> bool:
    var p = owner_index()
    return p >= 0 and p < RunData.get_player_count() and load(RULES_PATH).has(name, p)

func config(name: String) -> Dictionary:
    return load(RULES_PATH).config(name, owner_index())

func begin_wave() -> void:
    wave_number = RunData.current_wave
    wave_active = true
    taurus_bonus = 0
    taurus_elapsed = 0.0
    taurus_triggered = false
    taurus_invincibility_left = 0.0
    aries_granted = false
    cancer_active = false
    restore_gold()

func ensure_wave() -> bool:
    if not is_instance_valid(player) or owner_index() < 0 or owner_index() >= RunData.get_player_count():
        return false
    if not RunData.wave_in_progress or player.dead:
        if wave_active:
            end_wave()
        return false
    if not wave_active or wave_number != RunData.current_wave:
        begin_wave()
    return true

func prepare_hit() -> void:
    if ensure_wave():
        update_health(player.current_stats.health, player.max_stats.health)

func update_health(current: int, maximum: int) -> void:
    if not ensure_wave():
        return
    if owns("cancer") and current > 0 and maximum > 0 and current * 2 < maximum:
        cancer_active = true

func damage_factor() -> float:
    if not ensure_wave() or not owns("cancer") or not cancer_active:
        return 1.0
    return float(config("cancer").damage_taken_percent) / 100.0

func iframe_factor() -> float:
    return float(config("virgo").iframe_multiplier) if owns("virgo") else 1.0

func is_invulnerable() -> bool:
    return wave_active and RunData.wave_in_progress and is_instance_valid(player) and not player.dead and owns("taurus") and taurus_invincibility_left > 0.0

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if is_inside_tree() and get_tree().paused:
        return
    if not ensure_wave() or delta <= 0.0:
        return
    update_health(player.current_stats.health, player.max_stats.health)
    # Expire an existing interval before possibly creating a new one. A single
    # large step must never consume the just-triggered ten-second interval.
    if taurus_invincibility_left > 0.0:
        taurus_invincibility_left = max(0.0, taurus_invincibility_left - delta)
        if taurus_invincibility_left < 0.000001:
            taurus_invincibility_left = 0.0
    if owns("taurus"):
        advance_taurus(delta)
    elif taurus_bonus > 0:
        TempStats.remove_stat(Keys.stat_speed_hash, taurus_bonus, owner_index())
        taurus_bonus = 0
        taurus_elapsed = 0.0
        taurus_invincibility_left = 0.0
    if owns("aries") and not aries_granted:
        var aries = config("aries")
        if Utils.get_stat(Keys.stat_speed_hash, owner_index()) >= float(aries.speed_threshold):
            player._hit_protection += int(aries.charges)
            aries_granted = true
            update_shield_hud()
    update_gold()

func advance_taurus(delta: float) -> void:
    if taurus_triggered:
        return
    var taurus = config("taurus")
    var cap = int(taurus.speed_cap)
    var step = int(taurus.speed_step)
    taurus_elapsed += delta
    while taurus_elapsed + 0.000001 >= 1.0 and taurus_bonus < cap:
        taurus_elapsed = max(0.0, taurus_elapsed - 1.0)
        var added = int(min(step, cap - taurus_bonus))
        TempStats.add_stat(Keys.stat_speed_hash, added, owner_index())
        taurus_bonus += added
    if taurus_bonus >= cap:
        taurus_triggered = true
        # Remainder is time spent after reaching the cap in this same step.
        taurus_invincibility_left = max(0.0, float(taurus.invincible_duration) - taurus_elapsed)
        taurus_elapsed = 0.0

func current_game():
    var game = Utils.get_scene_node()
    return game if game is Main else null

func update_shield_hud() -> void:
    var game = current_game()
    var p = owner_index()
    if game != null and p >= 0 and p < game._players_ui.size():
        game._players_ui[p].update_hit_protection_count(player, player._hit_protection)

func update_gold() -> void:
    if not is_invulnerable():
        restore_gold()
        return
    var game = current_game()
    var p = owner_index()
    if game == null or p < 0 or p >= game._players_ui.size():
        return
    var ui = game._players_ui[p]
    for bar in [ui.life_bar, ui.player_life_bar]:
        var found = false
        for entry in gold_bars:
            if entry[0] == bar:
                found = true
                break
        if not found:
            gold_bars.append([bar, bar.progress_color])
        bar.progress_color = GOLD
        bar._non_flash_color = GOLD
        bar.tint_progress = GOLD

func restore_gold() -> void:
    for entry in gold_bars:
        var bar = entry[0]
        if is_instance_valid(bar):
            bar.progress_color = entry[1]
            if is_instance_valid(player) and player.has_method("life_bar_effects"):
                bar.update_color_from_effects(player.life_bar_effects())
            # A pending native health-flash timer must not retain the last gold
            # tint after the gameplay protection has ended.
            bar.tint_progress = bar._non_flash_color
    gold_bars.clear()

func end_wave() -> void:
    wave_active = false
    taurus_invincibility_left = 0.0
    restore_gold()
    # Native wave-end TempStats.reset removes this wave's accumulated speed.
    # Do not subtract it again after the native reset.

func _exit_tree() -> void:
    restore_gold()
