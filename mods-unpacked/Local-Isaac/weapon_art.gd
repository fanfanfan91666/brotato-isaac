extends Reference

# Static source geometry only; original item PNGs are never rewritten.
static func atlas(source: Texture, region: Rect2 = Rect2()) -> AtlasTexture:
    if source.resource_path.ends_with("/icon.png"):
        source.flags = 0
    var script = load("res://mods-unpacked/Local-Isaac/weapon_art.gd")
    if not script.has_meta("atlases"):
        script.set_meta("atlases", {})
    var cache = script.get_meta("atlases")
    var key = str(source.get_instance_id()) + ":" + str(region)
    if not cache.has(key):
        var result = AtlasTexture.new()
        result.atlas = source
        result.region = source.get_data().get_used_rect() if region.has_no_area() else region
        cache[key] = result
    return cache[key]
