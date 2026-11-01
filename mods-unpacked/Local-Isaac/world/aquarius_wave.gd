extends Node2D

# Reuse the native Lantern aura texture, with a private light-blue recolouring
# shader and an expanding half-second ring. This sprite has no damage hitbox.
const TEXTURE = preload("res://dlcs/dlc_1/items/lantern/effects/lantern_effect_4.png")
const SHADER = preload("res://mods-unpacked/Local-Isaac/world/aura_wave.shader")
const DURATION = 0.5
var radius = 200.0
var age = 0.0
var wave_sprite: Sprite
var tint = Color(0.43, 0.84, 1.0)

func _ready() -> void:
    wave_sprite = Sprite.new()
    wave_sprite.texture = TEXTURE
    # Carry only the canvas tint from vertex(), so the original yellow texture
    # does not tint blue to green or multiply its faint alpha a second time.
    var material = ShaderMaterial.new()
    material.shader = SHADER
    material.set_shader_param("wave_color", tint)
    wave_sprite.material = material
    add_child(wave_sprite)
    update_visual()

func _process(delta: float) -> void:
    age += delta
    if age >= DURATION or not RunData.wave_in_progress:
        queue_free()
        return
    update_visual()

func update_visual() -> void:
    var growth = lerp(0.08, 1.0, min(age / 0.1, 1.0))
    var size = radius * 2.0 / TEXTURE.get_width() * growth
    wave_sprite.scale = Vector2.ONE * size
    wave_sprite.modulate.a = 1.0 - pow(age / DURATION, 2.0)
