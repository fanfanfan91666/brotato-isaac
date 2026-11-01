extends Node2D

# Keep native Consumable/Item movement, collisions and pickup signals. This
# child switches between the supplied single- and double-bomb artwork.
const COUNT_FONT = preload("res://resources/fonts/actual/base/font_26_outline.tres")
const DOUBLE_TEXTURE = preload("res://mods-unpacked/Local-Isaac/content/bombs/double_bomb.png")
const DOUBLE_SHADER = preload("res://mods-unpacked/Local-Isaac/world/bomb_bundle_031.shader")

var amount = 1
var second_icon: Sprite = null
var count_label: Label = null

func configure(value: int) -> void:
    amount = max(1, value)
    var primary = get_parent().get_node("Sprite")
    if second_icon == null:
        second_icon = Sprite.new()
        second_icon.name = "DoubleBomb"
        second_icon.texture = DOUBLE_TEXTURE
        second_icon.scale = Vector2.ONE * 30.0 / max(DOUBLE_TEXTURE.get_width(), DOUBLE_TEXTURE.get_height())
        var material = ShaderMaterial.new()
        material.shader = DOUBLE_SHADER
        second_icon.material = material
        add_child(second_icon)
        count_label = Label.new()
        count_label.name = "BombCount"
        count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        count_label.add_font_override("font", COUNT_FONT)
        count_label.rect_position = Vector2(3, 2)
        count_label.rect_scale = Vector2(0.5, 0.5)
        add_child(count_label)
    second_icon.visible = amount > 1
    primary.visible = amount == 1
    primary.position = Vector2.ZERO
    count_label.text = "x" + str(amount)
    count_label.visible = amount > 2
    show()

func clear() -> void:
    amount = 1
    get_parent().get_node("Sprite").position = Vector2.ZERO
    get_parent().get_node("Sprite").show()
    if second_icon != null:
        second_icon.hide()
        count_label.hide()
    hide()
