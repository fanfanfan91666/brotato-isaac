extends ImageTexture

func _init() -> void:
    create_from_image(load("res://mods-unpacked/Local-Isaac/content/items/moms_knife/knife_effect.png").get_data(), Texture.FLAG_FILTER)
    set_size_override(Vector2(128, 128))
