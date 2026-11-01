extends Sprite

func _ready() -> void:
    # The body is the original icon, cropped and sized once. Native projectile
    # rotation, bounce, opacity and pooling continue to own the carrier Sprite.
    texture = load("res://mods-unpacked/Local-Isaac/weapon_art.gd").atlas(texture)
    scale = Vector2.ONE * (57.0 / max(texture.get_width(), texture.get_height()))
