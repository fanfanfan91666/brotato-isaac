extends Reference

const SOURCE = preload("res://mods-unpacked/Local-Isaac/content/characters/lilith/lilith_source.png")
const HEAD_RECT = Rect2(15, 17, 34, 28)
const BODY_RECT = Rect2(23, 41, 18, 9)

static func image() -> Image:
    # The full face reaches the black chin at y=40. Keep the long side hair
    # while removing the small central torso below it; no original pixels move.
    var result = SOURCE.get_data().get_rect(HEAD_RECT)
    result.lock()
    for y in range(int(HEAD_RECT.size.y)):
        for x in range(int(HEAD_RECT.size.x)):
            if BODY_RECT.has_point(Vector2(x, y) + HEAD_RECT.position):
                result.set_pixel(x, y, Color.transparent)
    result.unlock()
    return result
