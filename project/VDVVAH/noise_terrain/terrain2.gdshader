shader_type spatial;

uniform float persistance = 0.5;
uniform float number_of_octaves = 10.;
uniform float frequency = 0.25;
uniform float amplitude = 2.;

uniform sampler2D stone;
uniform sampler2D grass;
uniform sampler2D water;
uniform sampler2D snow;
uniform sampler2D sand;

const float levels[] = {-0.05, 0.1, 0.05, 0.4, 0.5};
const float slopes[] = {0.95, 0.9};

#define level(index) (levels[index] * amplitude)
#define slope(index) (slopes[index])

float _rand_function1(ivec2 vertex) {
	 int n = vertex.x + 43*vertex.y;
	n = (n << 13) ^ n;
	return 1.0 - float((n* (n*n*17+527482)+1526343561) & int (pow(2.0, 31.0) - 1.0)) / pow(2.0, 30.0);
}

float _rand_function2(ivec2 vertex) {
	int n = vertex.x + 57*vertex.y;
	n = (n << 13) ^ n;
	return 1.0 - float(n* (n*n*41+527482) & int (pow(2.0, 31.0) - 1.0)) / pow(2.0, 30.0);
}

vec2 _rand_vec_function(ivec2 vertex) {
	vec2 raw =  vec2(_rand_function1(vertex) , _rand_function2(vertex));
	return raw;
	return floor(raw.y / pow(raw.x, 0.4)) * normalize(raw);
}

float fade(float x) {
	return 6. * pow(x, 5.) - 15. * pow(x, 4.) + 10. * pow(x, 3.);
}

float mixer(float a, float b, float c) {
	return mix(a, b, fade(c));
}

float _rand_function_interpolation(vec2 args) {
	ivec2 lt_vertex_pos = ivec2(floor(args));
	vec2 local_pos = fract(args);

	vec2 vertex1 = vec2(lt_vertex_pos);
	vec2 vertex2 = vertex1 + vec2(0., 1.);
	vec2 vertex3 = vertex1 + vec2(1., 0.);
	vec2 vertex4 = vertex1 + vec2(1.);

#define vertex_value(index) (dot(_rand_vec_function(ivec2(vertex##index)), args - vertex##index))
	//#define vertex_value(index) _rand_function1(ivec2(vertex##index))

	float h1_interpolation = mixer(vertex_value(1), vertex_value(2), local_pos.y);
	float h2_interpolation = mixer(vertex_value(3), vertex_value(4), local_pos.y);
	float interpolation = mixer(h1_interpolation, h2_interpolation, local_pos.x);

#undef vertex_value

	return interpolation;
}

float _rand_function_interpolation(vec2 args, float num) {
	return _rand_function_interpolation(args * num);
}

float _terrain(vec2 args) {
	return _rand_function_interpolation(args);
}

float _terrain_iterated(vec2 args) {
	float sum = 0.;

	float _number_of_octaves = number_of_octaves;
	float _persistance = persistance;

	//float n = 12.;
	//_number_of_octaves = floor(sin(TIME / 2.) * n) + n;

	//_persistance = sin(TIME / 2.) * persistance;

	for (float k = 0.; k < _number_of_octaves; k++) {
		sum += _terrain(args * pow(2, k) * frequency) * pow(_persistance, k) * amplitude;
	}

	return sum;
}

float _generate_terrain(vec2 args) {
	//return sin(args.x+args.y) + cos(args.y);
	return _terrain_iterated(args);
}

vec3 _normal_of_terrain(vec3 args) {
	float EPSILON = 0.001;
	float value = args.y;

	return normalize(-cross(
				vec3(EPSILON, _generate_terrain(args.xz + vec2(EPSILON, 0.)) - value, 0.),
				vec3(0., _generate_terrain(args.xz + vec2(0., EPSILON)) - value, EPSILON)));
}

vec3 mix_texture(sampler2D tex1, sampler2D tex2, float k, vec2 uv) {
	return mix(texture(tex1, uv), texture(tex2, uv), k).xyz;
}

vec3 mix_texture(vec3 color, sampler2D tex, float k, vec2 uv) {
	return mix(color, texture(tex, uv).xyz, k);
}

vec3 normal_of_landscape(float height, vec3 normal) {
	// return (height < level(0)) ? vec3(0., 1., 0.): normal;
	return normal;
}

vec3 colorize_landscape(float height, vec2 uv, vec3 normal) {
	vec3 result_color;

	//if (height < levels[0]) {
		//normal = vec3(0., 1., 0.);
		//result_color = texture(water, uv).xyz;
	//} else
	if (height < level(1))
		result_color = texture(sand, uv).xyz;
	else if (height < level(2))
		result_color = mix_texture(sand, grass, smoothstep(level(1), level(2), height), uv);
	else if (height > level(4))
		result_color = texture(snow, uv).xyz;
	else if (height > level(3))
		result_color = mix_texture(grass, snow, smoothstep(level(3), level(4), height), uv);
	else
		result_color = texture(grass, uv).xyz;

	float _slope = length(normal.xz);

	if (_slope > slope(0))
		result_color = texture(stone, uv).xyz;
	else if (_slope > slope(1))
		result_color = mix_texture(result_color, stone, smoothstep(slope(1), slope(0), _slope), uv);

	return result_color;
}

void vertex() {
	vec3 vertex_w = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
	VERTEX.y = _generate_terrain(vertex_w.xz);
}

void fragment() {
	vec3 vertex_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.)).xyz;

	vertex_w.y = _generate_terrain(vertex_w.xz);
	vec3 normal = _normal_of_terrain(vertex_w);

	normal = normal_of_landscape(vertex_w.y, normal);
	ALBEDO = colorize_landscape(vertex_w.y, UV, normal);

	NORMAL = (VIEW_MATRIX * vec4(normal, 0.)).xyz;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
