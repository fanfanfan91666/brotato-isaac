extends "res://ui/menus/shop/stat_container.gd"

func update_player_stat(player_index: int) -> void:
    .update_player_stat(player_index)
    if key == "STAT_LOCAL_ISAAC_BOMBS":
        # Double both display dimensions, including the row height, without clipping.
        _icon.rect_min_size = Vector2(80, 52)
