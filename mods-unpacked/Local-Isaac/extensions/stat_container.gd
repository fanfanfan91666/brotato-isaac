extends "res://ui/menus/shop/stat_container.gd"

func update_player_stat(player_index: int) -> void:
    .update_player_stat(player_index)
    if key in ["STAT_LOCAL_ISAAC_BOMBS", "STAT_LOCAL_ISAAC_DEVIL_ROOM_CHANCE", "STAT_LOCAL_ISAAC_ANGEL_ROOM_CHANCE"]:
        # Match the native stat icon width and let the existing row set height.
        _icon.rect_min_size = Vector2(40, 0)
    if key in ["STAT_LOCAL_ISAAC_DEVIL_ROOM_CHANCE", "STAT_LOCAL_ISAAC_ANGEL_ROOM_CHANCE"]:
        _value.text += "%"
