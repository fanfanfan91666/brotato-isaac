extends "res://ui/menus/ingame/character_panel_ui.gd"

const ISAAC_PREVIEW_BODY = preload("res://mods-unpacked/Local-Isaac/content/characters/isaac/isaac_body_texture.tres")
const LILITH_PREVIEW_BODY = preload("res://mods-unpacked/Local-Isaac/content/characters/lilith/lilith_body_texture.tres")
var _isaac_previous_preview_body: Texture = null

func apply_items_appearance(all_items: Array) -> void:
    var body_sprite = get_node("%Character").get_node("Sprite")
    if _isaac_previous_preview_body != null:
        body_sprite.texture = _isaac_previous_preview_body
        _isaac_previous_preview_body = null
    .apply_items_appearance(all_items)
    for item in all_items:
        if item is CharacterData:
            var head = load("res://mods-unpacked/Local-Isaac/head_visuals.gd").body(item.my_id)
            if head != null:
                _isaac_previous_preview_body = body_sprite.texture
                body_sprite.texture = head
                break
        if item is CharacterData and item.my_id == "character_local_isaac":
            _isaac_previous_preview_body = body_sprite.texture
            body_sprite.texture = ISAAC_PREVIEW_BODY
            break
        elif item is CharacterData and item.my_id == "character_local_lilith":
            _isaac_previous_preview_body = body_sprite.texture
            body_sprite.texture = LILITH_PREVIEW_BODY
            break
