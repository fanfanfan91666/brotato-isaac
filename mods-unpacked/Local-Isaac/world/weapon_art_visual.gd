extends Node2D

export(Texture) var source_texture
export(Rect2) var source_region = Rect2()
export(float) var art_length = 140.0
export(float) var art_angle = 0.0
export(Vector2) var grip_uv = Vector2(0.5, 0.5)
export(Vector2) var grip_offset = Vector2.ZERO
export(bool) var smooth_edges = false
var art: Sprite
const EDGE = preload("res://mods-unpacked/Local-Isaac/world/weapon_edge.shader")
onready var carrier: Sprite = get_parent()

func _ready() -> void:
    # Keep the native carrier/hitbox/muzzle/tweens, drawing approved art below
    # it. self_modulate affects only the carrier, not this child.
    carrier.self_modulate.a = 0.0
    art = Sprite.new()
    art.texture = load("res://mods-unpacked/Local-Isaac/weapon_art.gd").atlas(source_texture, source_region)
    var size = art.texture.get_size()
    var c = abs(cos(art_angle))
    var s = abs(sin(art_angle))
    var rotated_size = Vector2(size.x * c + size.y * s, size.x * s + size.y * c)
    var factor = art_length / max(rotated_size.x, rotated_size.y)
    art.scale = Vector2.ONE * factor
    art.rotation = art_angle
    art.position = grip_offset - ((grip_uv - Vector2(0.5, 0.5)) * size * factor).rotated(art_angle)
    if smooth_edges:
        var material = ShaderMaterial.new()
        material.shader = EDGE
        art.material = material
    add_child(art)

func _process(_delta: float) -> void:
    scale.y = -1.0 if carrier.flip_v else 1.0
