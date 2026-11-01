shader_type canvas_item;
render_mode unshaded;

// Display the supplied screenshot pixels without its dark gray backdrop.
// Its black outlines remain distinct from this slightly lighter background.
uniform vec3 background_color = vec3(0.13, 0.123, 0.123);
uniform float tolerance = 0.045;
varying vec4 item_tint;

void vertex() {
    item_tint = COLOR;
}

void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    float foreground = smoothstep(tolerance, tolerance + 0.018, distance(sample_color.rgb, background_color));
    COLOR = vec4(sample_color.rgb, sample_color.a * foreground) * item_tint;
}
