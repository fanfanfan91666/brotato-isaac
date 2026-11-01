extends ImageTexture

func _init() -> void:
    create_from_image(preload("res://mods-unpacked/Local-Isaac/content/characters/lilith/lilith_head.gd").image(), 0)
    set_size_override(Vector2(85, 70))
