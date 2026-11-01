extends "res://items/consumables/consumable.gd"

func drop(pos: Vector2, p_rotation: float, p_push_back_destination: Vector2) -> void:
    .drop(pos, p_rotation, p_push_back_destination)
    # Native fruit/crate loot can also select the registered bomb consumable.
    # Cover every drop entry without changing the shared Item movement class.
    if consumable_data == null or consumable_data.my_id != "consumable_local_isaac_bomb":
        return
    var game = Utils.get_scene_node()
    if game is Main and not game._cleaning_up and game.get("isaac_bomb_system") != null:
        game.isaac_bomb_system.setup_bomb_pickup(self)
