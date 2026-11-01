extends "res://singletons/utils.gd"

const ISAAC_STATS = preload("res://mods-unpacked/Local-Isaac/stat_rules.gd")
var _isaac_recording = [false, false, false, false]

func get_stat(stat_hash: int, p: int) -> float:
    if stat_hash == Keys.stat_curse_hash and p >= 0 and not RunData.get_player_effects(p).has(stat_hash):
        return 0.0
    var value = .get_stat(stat_hash, p)
    if p < 0 or p >= RunData.get_player_count():
        return value
    value = ISAAC_STATS.conditional_stat(stat_hash, value, p)
    return ISAAC_STATS.lock_peak(stat_hash, value, p)

func get_scaling_stat_icon_text(stat_hsh: int, scaling: float = 1.0, show_plus_prefix: bool = true) -> String:
    if stat_hsh == Keys.stat_curse_hash and ItemService.get_stat_small_icon(stat_hsh) == null:
        return ("+" if show_plus_prefix and scaling > 0 else "") + str(round(scaling * 100)) + "% " + tr("STAT_CURSE")
    return .get_scaling_stat_icon_text(stat_hsh, scaling, show_plus_prefix)

func reset_stat_cache(p: int) -> void:
    .reset_stat_cache(p)
    if p < 0 or p >= RunData.get_player_count() or p >= 4 or _isaac_recording[p]:
        return
    if ISAAC_STATS.count("rock_bottom", p) <= 0:
        return
    # Capture every effective stat immediately after changes, including temporary
    # buffs. Never write the protected value back into the original stat sources.
    _isaac_recording[p] = true
    for data in ItemService.stats:
        if ISAAC_STATS.eligible(data.stat_hash):
            get_stat(data.stat_hash, p)
    _isaac_recording[p] = false
