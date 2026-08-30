
struct VertexInput {
    @location(0) position: vec3f,
    @location(1) uv : vec2f
};
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) uv: vec2f
};
struct Uniforms {
    // match order, type, and memory layout
    // wgsl -> C++ utility: 
    // https://eliemichel.github.io/WebGPU-AutoLayout/
    projMatrix: mat4x4f,
    viewMatrix: mat4x4f,
    modelMatrix: mat4x4f,
    time: f32,
    aspectRatio: f32,
    _padding: vec2f,
}
@group(0) @binding(0) var<uniform> u_Uniforms: Uniforms;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var o : VertexOutput;
    o.position = vec4f(in.position, 1.);
    o.uv = in.uv;
    return o;
}

const fov: f32 = 40.;
const WORLD_UP: vec3f = vec3f(0., 1., 0.);
const PI: f32 = 3.14159265;

struct Ray {
    origin: vec3f,
    dir: vec3f,
};

// clockwise 
fn rot(angle: f32) -> mat2x2f {
    return mat2x2f(cos(angle), -sin(angle), sin(angle), cos(angle));
}

fn sdTorus(p: vec3f, t: vec2f) -> f32 {
    let q = vec2f(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

fn hash31(p_in: vec3f) -> f32 {
    var p = fract(p_in * vec3f(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

fn valueNoise3D(p: vec3f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash31(i + vec3f(0,0,0)), hash31(i + vec3f(1,0,0)), u.x),
                   mix(hash31(i + vec3f(0,1,0)), hash31(i + vec3f(1,1,0)), u.x), u.y),
               mix(mix(hash31(i + vec3f(0,0,1)), hash31(i + vec3f(1,0,1)), u.x),
                   mix(hash31(i + vec3f(0,1,1)), hash31(i + vec3f(1,1,1)), u.x), u.y), u.z);
}

fn fbm(p_in: vec3f, iter: i32) -> f32 {
    var p = p_in;
    var v: f32 = 0.0;
    var amp: f32 = 0.5;
    for (var i: i32 = 0; i < iter; i++) {
        v   += amp * (valueNoise3D(p) * 2.0 - 1.0);
        p   *= 2.0;
        amp *= 0.5;
    }
    return v;
}

fn sceneSDF2(q: vec3f) -> f32 {

    let torus = sdTorus(q, vec2f(0.35, 0.06) * 1.2);
    return torus;
}

fn getDensity(q: vec3f) -> f32 {
    let t = u_Uniforms.time;
    let d = sceneSDF2(q);

    let base = smoothstep(.15, 0., d);

    // shape 
    let n = fbm(q * 4.0 - vec3f(-t * .4, 0.0, t* 0.), 2);
    var shape = smoothstep(-0.35, 0.35, n);
    shape = mix(.3, 1., shape);

    // erosion!
    let e = fbm(q * 12.0 - vec3f(-t * .3, t* 0.4, 0.0), 3);
    let edge = smoothstep(-0.01, .1, d);
    let erosion = mix(1.0, smoothstep(-0.2, 0.4, e), edge);

    let dens = base * shape * erosion;
    return max(0.0, dens) * 3.;
}

// Henyey-Greenstein phase function
// wi: light dir
// wo: view dir
fn phasef(wi: vec3f, wo: vec3f, g: f32) -> f32 {
    // return 1. / (4. * PI); // isotropic
    let cosTheta = dot(wi, wo);
    return (1. - g * g) / 
    (pow(1. + g * g - 2. * g * cosTheta, 1.5) * (4.*PI));
}

const matd_s: f32 = 3.;
const matd_a: f32 = 1.;
const matd_e: f32 = 0.;

fn shadowT(pos: vec3f, lightDir: vec3f, extScale: f32) -> f32 {
    var T_shadow: f32 = 1.0;
    let shadow_dt: f32 = 0.02;
    // float sjitter = fract(sin(dot(pos.xy + lightDir.xy, vec2(127.1, 311.7))) * 43758.5453);
    var shadowPos = pos + lightDir * shadow_dt;
    for (var j: i32 = 0; j < 10; j++) {
        shadowPos += lightDir * shadow_dt;
        let dens = getDensity(shadowPos);
        let d_t = dens * (matd_s + matd_a) * extScale;
        T_shadow *= exp(-d_t * shadow_dt);
        if (T_shadow < 1e-3) { break; }
    }
    return T_shadow;
}


fn msLighting(pos: vec3f, lightDir: vec3f, viewDir: vec3f, lightColor: vec3f, g: f32) -> vec3f {
    var result   = vec3f(0.);
  
    let T_light = shadowT(pos, lightDir, 1.0);
    let ms = 0.5*T_light + 0.25*pow(T_light,0.5) + 0.125*pow(T_light,0.25);
    result = lightColor * ms* phasef(lightDir, viewDir, g); 
    return result;
}

fn colAccumulate(ray: Ray) -> vec3f {
    
    var pos = ray.origin;
    var col = vec3f(0.); 
    var T: f32 = 1.0;
    let dt: f32 = 0.03;

    // bounding box 
    let sd = sceneSDF2(pos);
    pos += ray.dir * sd*.8;
    
    for (var i: i32 = 0; i < 40; i++) {
        pos += ray.dir * dt;
        let d = sceneSDF2(pos);

         
        let dens = getDensity(pos);
        if (dens < 1e-2) { continue; }

        let d_s = dens * matd_s; // scattering coeff
        let d_a = dens * matd_a; // absorption coeff
        let d_e = d_s + d_a; // extinction coeff
        
        let alpha = 1. - exp(-d_e * dt); // 1 - how much remains = current %
        
        let wo = - normalize(ray.dir); // view dir

        let wi0 = normalize(vec3f(-0.57, -0.4161, -0.7));
        let wi1 = normalize(vec3f(-.5, 1., -2.)); // light dir

        let c0 = vec3f(0.9412, 0.8314, 0.8667) * 150.;
        let c1 = vec3f(0.8196, 0.2824, 0.2824) * 10.;

        let g: f32 = 0.7;
        let msLight = msLighting(pos, wi0, wo, c0, g) + msLighting(pos, wi1, wo, c1, g);
        col += msLight * (d_s/(1e-6+d_e)) * alpha * T;

        T *= (1. - alpha);
    }
    let ambient = vec3f(0.0667, 0.0941, 0.2392) * (1.0 - T);
    col += ambient;
    let skyCol = vec3f(0.1569, 0.2314, 0.5961);
    
    col += skyCol * T;
    return col;
}

// shoot ray in right direction
fn rayMarch(uv: vec2f, camPos: vec3f, refPos: vec3f) -> vec3f {
    var ray: Ray;

    let forward = normalize(refPos - camPos);
    let right = normalize(cross(forward, WORLD_UP));
    let up = normalize(cross(right, forward));
    let screenPoint = right * uv.x * tan(radians(fov / 2.)) + // x on screen
                       up * uv.y * tan(radians(fov / 2.)) + // y on screen
                       normalize(forward); // screen center
    ray.origin = camPos;
    ray.dir = normalize(screenPoint);
    
    return colAccumulate(ray);
}

/// ACES filmic tone mapping
fn toneMapACES(C_in: vec3f) -> vec3f {
    var C = C_in;
    C = (C * (2.51*C + 0.03)) / (C * (2.43*C + 0.59) + 0.14);
    C = clamp(C, vec3f(0.0), vec3f(1.0));
    return C;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    var uv = in.uv * 2.0 - 1.0; // -1 to 1
    uv.x *= u_Uniforms.aspectRatio;
    var color = vec3f(uv, 0.);

    let cam = vec3f(0., -1., 2.) * .8;
    color = rayMarch(uv, cam, vec3f(0., 0.05, 0.));
    color = toneMapACES(color);

	return vec4f(color, 1.0);
}
