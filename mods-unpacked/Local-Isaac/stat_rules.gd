extends Reference

const PEAKS = "local_isaac_rock_bottom_peaks"
const CROWN_WAVE = "local_isaac_crown_damaged_wave"
const CHARACTER_ID = "character_local_isaac"
const MAX_HP_FACTOR = 0.67

static func count(name: String, p: int) -> int:
    if p < 0 or p >= RunData.get_player_count():
        return 0
    return RunData.get_nb_item(Keys.generate_hash("item_local_isaac_" + name), p)

static func eligible(stat_hash: int) -> bool:
    if stat_hash == Keys.generate_hash("stat_local_isaac_bombs"):
        return false
    return Utils.is_stat_key(stat_hash)

static func conditional_stat(stat_hash: int, value: float, p: int) -> float:
    if stat_hash == Keys.stat_max_hp_hash:
        # Isaac's character penalty applies to the whole effective Max HP,
        # including the native base 10, so every future gain is reduced too.
        if value > 0.0 and p >= 0 and p < RunData.get_player_count():
            var character = RunData.get_player_character(p)
            if character != null and character.my_id == CHARACTER_ID:
                return float(int(round(value * MAX_HP_FACTOR)))
        return value
    if stat_hash != Keys.stat_percent_damage_hash:
        return value
    var curses = load("res://mods-unpacked/Local-Isaac/curse_rules.gd")
    value += int(RunData.get_player_gold(p) / 30) * curses.sum_value("money_equals_power", p, "damage")
    if count("light_crown", p) > 0:
        var full = true
        var game = Utils.get_scene_node()
        if game is Main and p < game._players.size():
            var player = game._players[p]
            full = not player.dead and player.current_stats.health >= player.max_stats.health
        if full:
            var hit_wave = RunData.get_player_effects(p).get(Keys.generate_hash(CROWN_WAVE), -1)
            value += curses.max_value("light_crown", p, "damaged_damage" if hit_wave == RunData.current_wave else "full_damage")
    return value

static func lock_peak(stat_hash: int, value: float, p: int) -> float:
    if count("rock_bottom", p) <= 0 or not eligible(stat_hash):
        return value
    var peaks = RunData.get_player_effects(p)[Keys.generate_hash(PEAKS)]
    var peak = max(value, float(peaks.get(stat_hash, value)))
    peaks[stat_hash] = peak
    return peak

static func soy_factor(p: int) -> float:
    return load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("soy_milk", p, "damage_factor", 0.0) if count("soy_milk", p) > 0 else 1.0

static func attack_speed_factor(p: int) -> float:
    return load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("polyphemus", p, "attack_speed_factor", 0.0) if count("polyphemus", p) > 0 else 1.0
