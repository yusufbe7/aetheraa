shader_type canvas_item;

// Sichqoncha ustiga kelganda chetlarida OQ border yonadi.
// hovered = true bo'lganda ishlaydi. Trees/rocks bilan bir xil his.

uniform bool hovered = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 1.0;

void fragment() {
	vec4 mod_col = COLOR;              // node modulate (flash uchun)
	vec4 col = texture(TEXTURE, UV);
	if (hovered && col.a < 0.4) {
		vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;
		float a = 0.0;
		a += texture(TEXTURE, UV + vec2(ts.x, 0.0)).a;
		a += texture(TEXTURE, UV - vec2(ts.x, 0.0)).a;
		a += texture(TEXTURE, UV + vec2(0.0, ts.y)).a;
		a += texture(TEXTURE, UV - vec2(0.0, ts.y)).a;
		a += texture(TEXTURE, UV + vec2(ts.x, ts.y)).a;
		a += texture(TEXTURE, UV + vec2(-ts.x, ts.y)).a;
		a += texture(TEXTURE, UV + vec2(ts.x, -ts.y)).a;
		a += texture(TEXTURE, UV + vec2(-ts.x, -ts.y)).a;
		if (a > 0.0) {
			COLOR = outline_color;
			return;
		}
	}
	COLOR = col * mod_col;
}
