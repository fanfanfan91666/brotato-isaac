shader_type canvas_item;
uniform vec4 wave_color;
varying vec4 wave_tint;
void vertex() {
    wave_tint = COLOR;
}
void fragment() {
    float d = length(UV - vec2(0.5)) * 2.0;
    float edge = 1.0 - smoothstep(0.94, 1.0, d);
    float ring = smoothstep(0.72, 0.88, d);
    float alpha = max(texture(TEXTURE, UV).a * 0.4, ring * 0.45) * edge;
    COLOR = vec4(wave_color.rgb * wave_tint.rgb, alpha * wave_tint.a);
}
