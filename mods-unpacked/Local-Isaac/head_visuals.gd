extends Reference

const PATH = "res://mods-unpacked/Local-Isaac/head_visuals.gd"
const IDS = ["lilith", "magdalene", "cain", "blue_baby", "judas", "keeper", "forgotten"]
const KEY_SHADER = preload("res://mods-unpacked/Local-Isaac/world/head_key.shader")

static func cache() -> Dictionary:
    var script = load(PATH)
    if not script.has_meta("portraits"):
        script.set_meta("portraits", {})
    return script.get_meta("portraits")

static func body(id: String) -> Texture:
    return cache().get(id, {}).get("body", null)

static func remove_legacy_face(p: int) -> void:
    if body(RunData.get_player_character(p).my_id) == null:
        return
    var appearances = RunData.players_data[p].appearances
    for appearance in appearances.duplicate():
        if appearance.is_character_appearance and appearance.sprite != null and appearance.sprite.resource_path in ["res://items/characters/well_rounded/well_rounded_eyes.png", "res://items/characters/well_rounded/well_rounded_mouth.png"]:
            appearances.erase(appearance)

static func source_bounds(source: Texture, keyed: bool) -> Rect2:
    var picture = source.get_data()
    if not keyed:
        return picture.get_used_rect()
    var low = picture.get_size()
    var high = Vector2(-1, -1)
    picture.lock()
    for y in picture.get_height():
        for x in picture.get_width():
            var pixel = picture.get_pixel(x, y)
            if pixel.a < 0.01 or (abs(pixel.r - 68.0 / 255.0) < 0.003 and abs(pixel.g - 68.0 / 255.0) < 0.003 and abs(pixel.b - 68.0 / 255.0) < 0.003):
                continue
            low.x = min(low.x, x)
            low.y = min(low.y, y)
            high.x = max(high.x, x)
            high.y = max(high.y, y)
    picture.unlock()
    return Rect2(low, high - low + Vector2.ONE)

static func render(owner: Node, source: Texture, bounds: Rect2, size: int, coverage: float, center_y: float, keyed: bool, align_bottom: bool) -> Dictionary:
    var viewport = Viewport.new()
    viewport.name = "HeadRender"
    viewport.size = Vector2(size, size)
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.world_2d = World2D.new()
    viewport.usage = Viewport.USAGE_2D
    viewport.render_target_v_flip = true
    viewport.render_target_update_mode = Viewport.UPDATE_ONCE
    owner.add_child(viewport)
    var atlas = AtlasTexture.new()
    atlas.atlas = source
    var data_size = source.get_data().get_size()
    var factor = source.get_size() / data_size
    atlas.region = Rect2(bounds.position * factor, bounds.size * factor)
    var sprite = Sprite.new()
    sprite.texture = atlas
    var scale = float(size) * coverage / max(atlas.region.size.x, atlas.region.size.y)
    sprite.scale = Vector2.ONE * scale
    sprite.position = Vector2(size * 0.5, size * center_y)
    if align_bottom:
        sprite.position.y -= atlas.region.size.y * scale * 0.5
    var material = ShaderMaterial.new()
    material.shader = KEY_SHADER
    material.set_shader_param("remove_gray", keyed)
    sprite.material = material
    viewport.add_child(sprite)
    var texture = viewport.get_texture()
    texture.flags = Texture.FLAG_FILTER
    return {"texture": texture, "viewport": viewport}

static func install(owner: Node):
    if not cache().empty():
        return
    var reference = ItemService.get_element_safe(ItemService.characters, "character_local_isaac")
    if reference == null:
        return
    var reference_picture = reference.icon.get_data()
    var reference_bounds = reference_picture.get_used_rect()
    var coverage = max(reference_bounds.size.x, reference_bounds.size.y) / reference_picture.get_width()
    var icon_center = (reference_bounds.position.y + reference_bounds.size.y * 0.5) / reference_picture.get_height()
    var body_bottom = reference_bounds.end.y / reference_picture.get_height()
    for name in IDS:
        var id = "character_local_" + name
        var character = ItemService.get_element_safe(ItemService.characters, id)
        var source = character.icon
        var keyed = name != "lilith"
        var bounds = source_bounds(source, keyed)
        var portrait = render(owner, source, bounds, 128, coverage, icon_center, keyed, false)
        var battle = render(owner, source, bounds, 84, coverage, body_bottom, keyed, true)
        cache()[id] = {"source": source, "bounds": bounds, "icon": portrait.texture, "body": battle.texture, "viewports": [portrait.viewport, battle.viewport]}
        character.icon = portrait.texture
    yield(owner.get_tree(), "idle_frame")
    yield(VisualServer, "frame_post_draw")
    # Explicitly freeze the Node-side mode too; UPDATE_ONCE can leave its
    # property at ONCE even after the renderer internally consumed the update.
    for row in cache().values():
        for viewport in row.viewports:
            viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
