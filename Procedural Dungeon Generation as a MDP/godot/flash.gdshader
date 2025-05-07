shader_type canvas_item;
uniform vec3 flash_color : source_color;
uniform bool do_flash = false;
uniform float flash_amount = 0.5;

void fragment() {
	if (do_flash) {
		vec3 final_color = mix(COLOR.rgb, flash_color, flash_amount);
		COLOR = vec4(final_color, COLOR.a);
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
