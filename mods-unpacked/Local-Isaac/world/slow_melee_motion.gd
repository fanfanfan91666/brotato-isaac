extends "res://weapons/shooting_behaviors/melee_shooting_data.gd"

var isaac_speed_factor = 1.0

func _init(from_stats: Resource, player_index: int, use_global_stats: bool = true).(from_stats, player_index, use_global_stats) -> void:
    if use_global_stats and from_stats.has_meta("isaac_attack_speed_factor"):
        isaac_speed_factor = from_stats.get_meta("isaac_attack_speed_factor")
        atk_duration /= isaac_speed_factor
        back_duration /= isaac_speed_factor

func get_atk_duration() -> float:
    return .get_atk_duration() / isaac_speed_factor
