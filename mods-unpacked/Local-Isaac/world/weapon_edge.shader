shader_type canvas_item;
render_mode unshaded;

void fragment() {
    vec4 tint = COLOR;
    vec2 p = UV / TEXTURE_PIXEL_SIZE - vec2(0.5);
    vec2 base = floor(p);
    vec2 f = fract(p);
    vec4 a = texture(TEXTURE, (base + vec2(0.5, 0.5)) * TEXTURE_PIXEL_SIZE);
    vec4 b = texture(TEXTURE, (base + vec2(1.5, 0.5)) * TEXTURE_PIXEL_SIZE);
    vec4 c = texture(TEXTURE, (base + vec2(0.5, 1.5)) * TEXTURE_PIXEL_SIZE);
    vec4 d = texture(TEXTURE, (base + vec2(1.5, 1.5)) * TEXTURE_PIXEL_SIZE);
    vec4 original = texture(TEXTURE, (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE);
    float alpha = mix(mix(a.a, b.a, f.x), mix(c.a, d.a, f.x), f.y);
    // Only coverage changes. All fully opaque interior pixels keep their exact
    // nearest-neighbour RGB, including the original low-resolution shading.
    if (original.a < 0.01) {
        vec4 edge = a;
        if (b.a > edge.a) edge = b;
        if (c.a > edge.a) edge = c;
        if (d.a > edge.a) edge = d;
        original.rgb = edge.rgb;
    }
    original.a = clamp((alpha - 0.5) / 0.16 + 0.5, 0.0, 1.0);
    COLOR = original * tint;
}
