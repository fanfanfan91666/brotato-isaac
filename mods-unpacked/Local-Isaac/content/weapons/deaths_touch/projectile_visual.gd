extends Sprite

func _ready() -> void:
    # Death's Touch alone grows from 57 to 68.4 pixels. Set the scale once;
    # native rotation/pooling and BFF's saved-scale restoration keep owning it.
    texture = load("res://mods-unpacked/Local-Isaac/weapon_art.gd").atlas(texture)
    scale = Vector2.ONE * (68.4 / max(texture.get_width(), texture.get_height()))
