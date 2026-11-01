extends "res://weapons/weapon_stats/melee_weapon_stats.gd"

func get_cooldown_value(player_index: int, multiplier: float) -> float:
    var motion = load("res://mods-unpacked/Local-Isaac/world/slow_melee_motion.gd").new(self, player_index)
    return motion.get_shooting_total_duration() + cooldown * multiplier / 60.0
