shader_type canvas_item;
render_mode unshaded;

// Native outline parameters remain per enemy. The same immutable shader is
// shared, while petrify_031.gd creates a private ShaderMaterial for each target.
uniform float width : hint_range(0.0, 16.0) = 3.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform vec2 texture_size = vec2(1.0);
uniform vec4 outline_color_0 : hint_color = vec4(0.0);
uniform vec4 outline_color_1 : hint_color = vec4(0.0);
uniform vec4 outline_color_2 : hint_color = vec4(0.0);
uniform vec4 outline_color_3 : hint_color = vec4(0.0);
uniform vec4 stone_color : hint_color = vec4(0.46, 0.32, 0.18, 0.65);

float get_neighboring_alpha(sampler2D texture, vec2 uv, vec2 size) {
    float a = texture(texture, uv).a;
    a += texture(texture, uv + vec2(0, size.y)).a;
    a += texture(texture, uv + vec2(size.x, 0)).a;
    a += texture(texture, uv + vec2(-size.x, size.y)).a;
    a += texture(texture, uv + vec2(-size.x, size.y * 0.5)).a;
    a += texture(texture, uv + vec2(-size.x * 0.5, size.y)).a;
    a += texture(texture, uv + vec2(size.x, size.y)).a;
    a += texture(texture, uv + vec2(0, -size.y)).a;
    a += texture(texture, uv + vec2(-size.x, -size.y)).a;
    a += texture(texture, uv + vec2(-size.x, -size.y * 0.5)).a;
    a += texture(texture, uv + vec2(-size.x * 0.5, -size.y)).a;
    a += texture(texture, uv + vec2(size.x, -size.y)).a;
    a += texture(texture, uv + vec2(size.x, -size.y * 0.5)).a;
    a += texture(texture, uv + vec2(size.x * 0.5, -size.y)).a;
    return clamp(a, 0.0, 1.0);
}

void draw_outline(int outline_number, vec4 outline_color, sampler2D texture, vec2 uv, inout vec4 color) {
    vec2 size = vec2(width * float(outline_number)) / texture_size;
    float a = get_neighboring_alpha(texture, uv, size);
    color = vec4(mix(outline_color.rgb, color.rgb, color.a), a);
}

void fragment() {
    vec4 sprite_color = texture(TEXTURE, UV);
    COLOR = sprite_color;
    if (outline_color_0.a > 0.0) { draw_outline(1, outline_color_0, TEXTURE, UV, COLOR); }
    if (outline_color_1.a > 0.0) { draw_outline(2, outline_color_1, TEXTURE, UV, COLOR); }
    if (outline_color_2.a > 0.0) { draw_outline(3, outline_color_2, TEXTURE, UV, COLOR); }
    if (outline_color_3.a > 0.0) { draw_outline(4, outline_color_3, TEXTURE, UV, COLOR); }
    float grayscale = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
    COLOR.rgb = mix(COLOR.rgb, vec3(grayscale), desaturation);
    // Apply brown to the original body pixels, retaining outline hues.
    vec3 stone = stone_color.rgb * (0.6 + grayscale * 0.7);
    COLOR.rgb = mix(COLOR.rgb, stone, sprite_color.a * 0.76);
    COLOR.a *= alpha * stone_color.a;
}
