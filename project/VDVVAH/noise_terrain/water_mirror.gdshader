shader_type spatial;
render_mode unshaded;

uniform sampler2D depth_tex : hint_depth_texture;
uniform sampler2D scr_tex : hint_screen_texture;

uniform sampler2D normal_map;
uniform sampler2D water;

uniform int steps = 100;
uniform float max_dist = 2.;
uniform float detect_threshold = 0.05;
uniform int binary_search_steps = 8;
uniform float opacity = 0.8;

vec3 from_view_to_nds(mat4 projection_matrix, vec3 vec) {
	vec4 temp = projection_matrix * vec4(vec, 1.);
	return (temp / temp.w).xyz;
}

vec3 from_nds_to_view(mat4 inv_projection_matrix, vec3 vec) {
	vec4 temp = inv_projection_matrix * vec4(vec, 1.);
	return (temp / temp.w).xyz;
}

vec3 from_nds_to_uv(vec3 nds) {
	return vec3((nds.xy + 1.) / 2., nds.z);
}

vec2 from_nds_to_uv(vec2 nds) {
	return (nds + 1.) / 2.;
}

vec2 from_uv_to_nds(vec2 uv) {
	return uv * 2. - 1.;
}

vec3 normal_from_world_to_view(mat4 view_matrix, vec3 normal) {
	return (view_matrix * vec4(normal, 0.)).xyz;
}

float get_depth(vec2 xy_nds) {
	return texture(depth_tex, from_nds_to_uv(xy_nds)).r;
}

int cmp_for_binary(vec3 mean) {
	return int(sign(mean.z - get_depth(mean.xy)));
}

vec3 binary_search(vec3 left_v, vec3 right_v, mat4 projection_matrix) {
	vec3 mean, mean_nds;

	for (int k = 0; k < binary_search_steps; k++) {
		mean = (left_v + right_v) / 2.;
		mean_nds = from_view_to_nds(projection_matrix, mean);

		switch (cmp_for_binary(mean_nds)) {
			case -1:
				left_v = mean;
				break;
			case 0:
				return mean_nds;
			case 1:
				right_v = mean;
				break;
		}
	}
	return mean_nds;
}

vec3 find_intersection(vec3 start_point_v, vec3 reflection_direction_v,
	mat4 projection_matrix, mat4 inv_projection_matrix, out bool intersection_exist) {
	bool flag = false;
	float dist;

	vec3 _step = reflection_direction_v * (max_dist / float(steps));
	vec3 last_point;
	vec3 this_point = start_point_v;
	vec3 this_point_nds;
	float depth_zv;

	for (int k = 0; k < steps; k++) {
		last_point = this_point;
		this_point += _step;

		this_point_nds = from_view_to_nds(projection_matrix, this_point);
		depth_zv = from_nds_to_view(inv_projection_matrix, vec3(0., 0., get_depth(this_point_nds.xy))).z;
		//TO DO: сравнивать глубина в пространстве view - depth зависит от расстояния от камеры нелинейно (я расскажу)
		dist = this_point.z - depth_zv;

		if (this_point_nds.x > 1. || this_point_nds.x < -1. || this_point_nds.y > 1. || this_point_nds.y < -1.)
			break;

		if (dist > 0. && dist < detect_threshold) {
			flag = true;
			break;
		}
	}

	intersection_exist = flag;

	//return intersection_exist ? this_point_nds: vec3(0.);
	return intersection_exist ? binary_search(last_point, this_point, projection_matrix): vec3(0.);
}

vec3 unpack_normal(vec3 normal) {
	vec3 n = normal * 2.0 - 1.0;
	n.z *= -1.0;
	return n;
}

//#define MOVING_WATER

void vertex() {
#ifdef MOVING_WATER
	vec3 normal = texture(normal_map, UV + TIME * vec2(0.1, 0.1)).xzy;
	NORMAL += 0.2 * normal;
#endif
	NORMAL = normalize(NORMAL);
}

void fragment() {
	vec3 reflection_v = normalize(reflect(normalize(VERTEX), NORMAL));

	bool intersection_exist = true;

	vec2 Uv = UV;

	//vec3 test_vertex = (VERTEX + vec3(5., 5., 0.)) / 10.;
	vec2 uv = from_nds_to_uv(find_intersection(VERTEX, reflection_v, PROJECTION_MATRIX, INV_PROJECTION_MATRIX, intersection_exist).xy);
#ifdef MOVING_WATER
	Uv = UV + TIME * vec2(0.05, 0.05);
#endif


	if (intersection_exist)
		ALBEDO = mix(texture(water, Uv).xyz, texture(scr_tex, uv).xyz, smoothstep(0., 1., length(uv)));
	else
		ALBEDO = texture(water, Uv).xyz;
	ALPHA = opacity;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
