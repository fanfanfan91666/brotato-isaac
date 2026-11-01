extends ImageTexture

const PORTRAIT = preload("res://mods-unpacked/Local-Isaac/content/characters/isaac/isaac_portrait.png")

func _init() -> void:
    # Set the texture's display size without changing the image pixels or the
    # Sprite's animated transforms. Match the visible oval rather than its large
    # transparent source canvas, leaving the original feet visible underneath.
    create_from_image(PORTRAIT.get_data(), 0)
    set_size_override(Vector2(84, 84))
