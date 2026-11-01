extends StaticBody2D

signal died(entity, die_args)

const FLASH_SHADER = preload("res://resources/shaders/flash.gdshader")
const PICKAXE = "weapon_local_isaac_broken_pickaxe"
const DEATH_DURATION = 0.5
var system: Node
var variant: int = 0
var destroyed = false
var reserved = false
var health = 0
var max_health = 0
var current_number_of_hits = 0
var _flash_material: ShaderMaterial
var _non_flash_material: Material

func _ready() -> void:
    # Match native Neutral/tree wave scaling and its eight-hit upper limit.
    var tree_stats = load("res://mods-unpacked/Local-Isaac/scenery_rules_032.gd").current_tree_stats()
    health = EntityService.get_final_enemy_health(tree_stats.get_base_health(RunData.current_wave)) if tree_stats != null else 1
    max_health = health
    # Native Unit white flash, with a private material and the shared shader.
    # No idle animation or per-frame scenery work is needed.
    _flash_material = ShaderMaterial.new()
    _flash_material.shader = FLASH_SHADER
    _flash_material.set_shader_param("flash_color", Color.white)
    _flash_material.set_shader_param("flash_modifier", 1.0)

func accepts(hitbox) -> bool:
    return is_instance_valid(hitbox) and hitbox is Hitbox and hitbox.active and hitbox.deals_damage and not hitbox.is_disabled() and is_instance_valid(hitbox.from) and hitbox.from is Weapon and hitbox.from.weapon_id == PICKAXE and hitbox == hitbox.from._hitbox

func _on_hurtbox_area_entered(hitbox: Area2D) -> void:
    call_deferred("hurt_by_pickaxe", hitbox)

func hurt_by_pickaxe(hitbox) -> void:
    if destroyed or not accepts(hitbox) or hitbox.ignored_objects.has(self):
        return
    var args = TakeDamageArgs.new(hitbox.from.player_index, hitbox)
    var result = take_damage(hitbox.damage, args)
    if result[1] > 0:
        # Native signal handles one hit per swing, lifesteal and weapon damage.
        hitbox.hit_something(self, result[1])

func take_damage(amount: int, args = null) -> Array:
    if destroyed or args == null or not accepts(args.hitbox) or amount <= 0:
        return [0, 0, false]
    var hitbox = args.hitbox
    var critical = Utils.get_chance_success(hitbox.crit_chance)
    var damage = max(1, int(round(amount * (hitbox.crit_damage if critical else 1.0))))
    var pets = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd")
    var pet_owner = pets.source_owner(hitbox.from)
    if pets.enabled(pet_owner):
        damage = int(round(damage * pets.multiplier(pet_owner)))
    var dealt = min(health, damage)
    health = max(0, health - damage)
    current_number_of_hits += 1
    show_hit_feedback(damage, critical, args)
    if health <= 0 or current_number_of_hits >= 8 or RunData.get_player_effect_bool(Keys.one_shot_trees_hash, hitbox.from.player_index) or DebugService.one_shot_enemies:
        # Mark destroyed before rewarding, so competing/co-op hits cannot pay twice.
        break_from_bomb(hitbox.from.player_index)
        load("res://mods-unpacked/Local-Isaac/weapon_rules_026.gd").pickaxe_break(hitbox.from)
    else:
        flash()
    if critical:
        hitbox.critically_hit_something(self, dealt)
    return [damage, dealt, critical]

func show_hit_feedback(damage: int, critical: bool, args: TakeDamageArgs) -> void:
    var game = system.game
    if not is_instance_valid(game) or game._cleaning_up:
        return
    # Use the same capped, pooled impact effect and damage text as native trees;
    # stone shares their no-blood setting and respects both display preferences.
    if ProgressData.settings.visual_effects:
        game._effects_manager.play_hit_effect(global_position + Vector2(0, -16), args.hitbox.knockback_direction, args.get_effect_scale())
    if ProgressData.settings.damage_display:
        var text = game._floating_text_manager
        text.display(str(damage), global_position, Color.yellow if critical else Color.white, null, text.duration, false, text.direction, false)

func break_from_bomb(player_index: int) -> void:
    if destroyed:
        return
    destroyed = true
    collision_layer = 0
    collision_mask = 0
    $CollisionShape2D.set_deferred("disabled", true)
    # Clear the filter immediately even when called during a physics step.
    $Hurtbox.collision_layer = 0
    $Hurtbox.collision_mask = 0
    $Hurtbox.set_deferred("monitoring", false)
    $Hurtbox/Collision.set_deferred("disabled", true)
    system.rocks.erase(self)
    flash()
    # Match the native Entity death: one rotation, shrink and darken in 0.5s.
    # The body has already retired; only its original icon remains briefly.
    $DeathTween.interpolate_property($Sprite, "scale", $Sprite.scale, Vector2(0.00003, 0.00003), DEATH_DURATION, Tween.TRANS_CUBIC, Tween.EASE_OUT)
    $DeathTween.interpolate_property($Sprite, "rotation", $Sprite.rotation, $Sprite.rotation + PI * 2.0, DEATH_DURATION, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
    $DeathTween.interpolate_property($Sprite, "modulate", $Sprite.modulate, Color(0.35, 0.35, 0.35, 1.0), DEATH_DURATION, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
    $DeathTween.start()
    emit_signal("died", self, Utils.default_die_args)
    system.on_rock_broken(global_position, player_index)

func flash() -> void:
    if $Sprite.material != _flash_material:
        _non_flash_material = $Sprite.material
        $Sprite.material = _flash_material
    $FlashTimer.start()

func _on_flash_timeout() -> void:
    if $Sprite.material == _flash_material:
        $Sprite.material = _non_flash_material
