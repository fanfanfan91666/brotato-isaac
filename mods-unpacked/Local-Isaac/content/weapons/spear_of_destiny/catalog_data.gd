extends "res://items/global/weapon_data.gd"

# These two weapons currently have approved names, artwork and initial rarity.
# Keep combat values out of the codex until the user specifies their behavior.
func get_weapon_stats_text(_player_index: int, _hide_if_non_unlock_in_codex: bool = false) -> String:
    return tr("LOCAL_ISAAC_WEAPON_CATALOG_PENDING")

func _is_silhouette_in_codex() -> bool:
    return false
