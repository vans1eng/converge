shader_type canvas_item;

uniform vec4 icon_color : source_color = vec4(1.0);

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, 1.2);
	float body = rounded_box(p - vec2(0.0, 0.23), vec2(0.43, 0.30), 0.06);
	vec2 arc_point = p - vec2(0.0, -0.20);
	float arc = max(abs(length(arc_point) - 0.27) - 0.06, arc_point.y);
	float left_leg = rounded_box(p - vec2(-0.27, -0.10), vec2(0.06, 0.11), 0.0);
	float right_leg = rounded_box(p - vec2(0.27, -0.10), vec2(0.06, 0.11), 0.0);
	float silhouette = min(body, min(arc, min(left_leg, right_leg)));
	float key_circle = length(p - vec2(0.0, 0.18)) - 0.10;
	float key_stem = rounded_box(p - vec2(0.0, 0.29), vec2(0.045, 0.10), 0.015);
	float distance_to_edge = max(silhouette, -min(key_circle, key_stem));
	float pixel_width = max(fwidth(distance_to_edge), 0.0001);
	float coverage = 1.0 - smoothstep(-pixel_width * 0.5, pixel_width * 0.5, distance_to_edge);
	COLOR = vec4(icon_color.rgb, icon_color.a * coverage);
}
