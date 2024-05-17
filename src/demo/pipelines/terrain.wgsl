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

@compute @workgroup_size(256)
fn main(@builtin(global_invocation_id) globalId: vec3<u32>) {
	let id = globalId.x;
	var tri = triangles[id];

	// Speed of undulations
	let t = u.t * 10.0;

	// For each vertex in the triangle
	for (var i = 0; i < 3; i++) {
		let p = toVec(tri.vertices[i].position);
		tri.vertices[i].position[1] = surfaceHeight(p, t);
	}
	let normal = calculateNormal(tri);
	for (var i = 0; i < 3; i++) {
		tri.vertices[i].normal = array(normal.x, normal.y, normal.z);
	}
	triangles[id] = tri;
}

fn surfaceHeight(op: vec3f, t: f32) -> f32 {
	var p = op / 512.0;

	var d = fractalNoise(vec3(p.x + t / 512.0, 0.0, p.z), 3) * 48.0;

	let roadWidth = 0.1;
	d *= smoothstep(0.0, roadWidth, abs(p.x));
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
