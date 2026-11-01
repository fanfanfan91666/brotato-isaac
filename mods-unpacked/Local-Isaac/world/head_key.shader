shader_type canvas_item;
render_mode unshaded;
uniform bool remove_gray = false;

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    if (remove_gray && distance(pixel.rgb, vec3(68.0 / 255.0)) < 0.004) {
        pixel.a = 0.0;
    }
    COLOR = pixel;
}
