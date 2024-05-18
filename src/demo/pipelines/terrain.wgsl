@import "engine/shaders/noise.wgsl";

struct Vertex {
	// array instead of vec to avoid alignment issues
	position: array<f32, 3>,
	normal: array<f32, 3>,
	uv: array<f32, 2>,
}

struct Triangle {
	vertices: array<Vertex, 3>,
}

struct Uniforms {
	t: f32,
}

@group(0) @binding(0)
var<uniform> u: Uniforms;

@group(0) @binding(1)
var<storage, read_write> triangles: array<Triangle>;

// Shape the land mesh
@compute @workgroup_size(256)
fn mainLand(@builtin(global_invocation_id) globalId: vec3<u32>) {
	let id = globalId.x;
	var tri = triangles[id];

	// Speed of undulations
	let t = u.t * 10.0;

	// For each vertex in the triangle
	for (var i = 0; i < 3; i++) {
		let p = toVec(tri.vertices[i].position);
		//tri.vertices[i].position[1] = landWithRiverHeight(p, t);
		tri.vertices[i].position[1] = landIslandHeight(p, t);
	}
	let normal = calculateNormal(tri);
	for (var i = 0; i < 3; i++) {
		tri.vertices[i].normal = array(normal.x, normal.y, normal.z);
	}
	triangles[id] = tri;
}

// Shape the water mesh
@compute @workgroup_size(256)
fn mainWater(@builtin(global_invocation_id) globalId: vec3<u32>) {
	let id = globalId.x;
	var tri = triangles[id];

	// Speed of undulations
	let t = u.t * 10.0;

	// For each vertex in the triangle
	for (var i = 0; i < 3; i++) {
		let p = toVec(tri.vertices[i].position);
		tri.vertices[i].position[1] = waterHeight(p, t);
	}
	let normal = calculateNormal(tri);
	for (var i = 0; i < 3; i++) {
		tri.vertices[i].normal = array(normal.x, normal.y, normal.z);
	}
	triangles[id] = tri;
}

fn waterHeight(op: vec3f, t: f32) -> f32 {
	var p = op / 32.0;

	var d = fractalNoise(vec3(p.x + t / 128.0, 1000.0 + t / 512.0, p.z), 2) * 8.0;

	return d;
}

fn landIslandHeight(op: vec3f, t: f32) -> f32 {
	var p = op / 128.0;

	let n0 = fractalNoise(vec3(p.x, 1000.0 * u.t, p.z), 3);
	let n1 = fractalNoise(vec3(p.x, -1717.0 * u.t, p.z), 3) * 2.0 - 1.0;
	var d = 48.0;

	d *= 1.0 - smoothstep(0.0, 1.2, pow(length(p*2.2), 2.4) * (1.0 - n1/2.0)) - n0 / 1.0;


	return d;
}

fn landWithRiverHeight(op: vec3f, t: f32) -> f32 {
	var p = op / 1024.0;

	var d = fractalNoise(vec3(p.x, u.t, p.z), 3) * 96.0;

	let riverWidth = 1.0 / 12.0;
	var riverOffset = fractalNoise(vec3(100.0, u.t, p.z/5.0), 2) - 0.5;
	riverOffset *= 2.0;
	// Start at origin so its always under camera
	riverOffset *= smoothstep(-1.0, -0.4, p.z);


	let river = abs(p.x + riverOffset);
	// Flatten near river
	d *= smoothstep(0.0, riverWidth, river);
	// Boost far from river
	d *= 1.0 + smoothstep(riverWidth, riverWidth * 8.0, river) * 2.0;
	return d;
}

fn calculateNormal(tri: Triangle) -> vec3f {
	let p0 = toVec(tri.vertices[0].position);
	let p1 = toVec(tri.vertices[1].position);
	let p2 = toVec(tri.vertices[2].position);

	let v0 = p1 - p0;
	let v1 = p2 - p0;
	return normalize(cross(v0, v1));
}

fn toVec(v: array<f32, 3>) -> vec3f {
	return vec3(v[0], v[1], v[2]);
}
