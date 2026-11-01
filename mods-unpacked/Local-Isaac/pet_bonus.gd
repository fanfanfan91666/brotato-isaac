extends Reference

const ITEM = "item_local_isaac_best_friends_forever"
const OWNER_META = "isaac_pet_damage_owner"
const FIXED_VOLLEY_META = "isaac_pet_fixed_volley"
const PLAYER_PROJECTILES_META = "isaac_player_projectiles"
const PLAYER_SPREAD_META = "isaac_player_projectile_spread"
const TEAR = preload("res://mods-unpacked/Local-Isaac/content/weapons/tear/tear.png")

static func enabled(p: int) -> bool:
    return p >= 0 and p < RunData.get_player_count() and RunData.get_nb_item(Keys.generate_hash(ITEM), p) > 0

static func multiplier(p: int) -> float:
    return load("res://mods-unpacked/Local-Isaac/curse_rules.gd").max_value("best_friends_forever", p, "damage_multiplier", 1.0)

static func pet_source(source: Node) -> Node:
    var current = source
    for _i in range(6):
        if not is_instance_valid(current):
            return null
        if current is Pet or current.get("is_pet") == true:
            return current
        current = current.get_parent()
    return null

static func source_owner(source: Node) -> int:
    var pet = pet_source(source)
    return int(pet.player_index) if pet != null else -1

static func custom_pet(source: Node) -> bool:
    var pet = pet_source(source)
    return pet != null and pet.get_script() != null and pet.get_script().resource_path.begins_with("res://mods-unpacked/Local-Isaac/")

static func pet_tracking_key(key: int) -> bool:
    if key == Keys.empty_hash:
        return false
    var script = load("res://mods-unpacked/Local-Isaac/pet_bonus.gd")
    if not script.has_meta("pet_tracking_keys") or script.get_meta("pet_catalog_size") != ItemService.items.size():
        var result = {}
        for item in ItemService.items:
            for effect in item.effects:
                if effect is PetEffect or effect.get("is_pet") == true:
                    result[item.my_id_hash] = true
                    break
        script.set_meta("pet_tracking_keys", result)
        script.set_meta("pet_catalog_size", ItemService.items.size())
    return script.get_meta("pet_tracking_keys").has(key)

static func hitbox_owner(hitbox: Hitbox, fallback_player: int) -> int:
    if hitbox == null:
        return -1
    if hitbox.has_meta(OWNER_META):
        return int(hitbox.get_meta(OWNER_META))
    var owner = source_owner(hitbox.from)
    if owner >= 0:
        return owner
    return fallback_player if pet_tracking_key(hitbox.damage_tracking_key_hash) else -1

static func update_pet_visual(pet: Node) -> void:
    if not is_instance_valid(pet) or not custom_pet(pet):
        return
    var animation = pet.get_node_or_null("Animation")
    if animation == null:
        return
    # Native idle animations own Animation.scale. Keep the bonus on the body,
    # where PetMotion combines it with the original sprite scale and recoil.
    if animation.has_meta("isaac_original_pet_scale"):
        animation.remove_meta("isaac_original_pet_scale")
    var motion = animation.get_node_or_null("Sprite/PetMotion")
    if motion != null:
        motion.set_body_multiplier(1.5 if enabled(pet.player_index) else 1.0)

static func configure_projectile(projectile: Node, source: Node, p: int) -> void:
    var owner = source_owner(source)
    projectile._hitbox.set_meta(OWNER_META, owner)
    if owner >= 0 and projectile._hitbox.burning_data != null:
        projectile._hitbox.burning_data = projectile._hitbox.burning_data.duplicate()
        projectile._hitbox.burning_data.from = source
        projectile._hitbox.burning_data.set_meta(OWNER_META, owner)
    # Undo only our own changes before reuse. Native shoot() may calculate a
    # different sprite scale on every shot (e.g. Particle Accelerator range).
    # Returning to the pool restores the previous shot before native shoot runs.
    if not custom_pet(source) or not enabled(p):
        return
    restore_projectile_visual(projectile)
    var sprite = projectile._sprite
    projectile.set_meta("isaac_bff_visual_managed", true)
    sprite.set_meta("isaac_original_projectile_scale", sprite.scale)
    var collision = projectile._hitbox.get_node_or_null("Collision")
    if collision != null:
        collision.set_meta("isaac_original_projectile_scale", collision.scale)
    if sprite.texture == null:
        return
    var max_size = max(sprite.texture.get_width(), sprite.texture.get_height())
    if max_size > 0 and not sprite.texture.resource_path.ends_with("/spirit_sword/wave.png"):
        var size = max(TEAR.get_width(), TEAR.get_height()) * 0.055
        var facing = Vector2(-1 if sprite.scale.x < 0 else 1, -1 if sprite.scale.y < 0 else 1)
        sprite.scale = facing * size / max_size
    if collision != null and projectile.get_script().resource_path.ends_with("/baby_projectile.gd"):
        collision.scale *= 1.5

static func restore_projectile_visual(projectile: Node) -> void:
    if not projectile.has_meta("isaac_bff_visual_managed"):
        return
    var sprite = projectile._sprite
    if sprite.has_meta("isaac_original_projectile_scale"):
        sprite.scale = sprite.get_meta("isaac_original_projectile_scale")
        sprite.remove_meta("isaac_original_projectile_scale")
    var collision = projectile._hitbox.get_node_or_null("Collision")
    if collision != null and collision.has_meta("isaac_original_projectile_scale"):
        collision.scale = collision.get_meta("isaac_original_projectile_scale")
        collision.remove_meta("isaac_original_projectile_scale")
    projectile.remove_meta("isaac_bff_visual_managed")
