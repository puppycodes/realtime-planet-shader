// Procedural Blue Planet by Julien Sulpis (https://twitter.com/jsulpis)
//
// https://www.shadertoy.com/view/Ds3XRl
//
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License
//

#version 300 es

precision mediump float;

in vec2 uv;
uniform float uTime;
uniform vec2 uResolution;
out vec4 fragColor;

// Planets geometry
#define PLANET_POSITION vec3(0, 0, 0)
#define PLANET_RADIUS 2.
#define NOISE_STRENGTH .2
#define ROTATION_SPEED -.1
#define PLANET_ROTATION rotateY(uTime * ROTATION_SPEED)

#define MOON_RADIUS .08
#define MOON_ROTATION_SPEED ROTATION_SPEED * 5.
#define MOON_OFFSET vec3(PLANET_RADIUS * 1.2, PLANET_RADIUS / 4., 0.)
#define MOON_ROTATION_AXIS (MOON_OFFSET - PLANET_POSITION) * rotateZ(PI/2.)

// Planet colors
#define WATER_COLOR_DEEP vec3(0.01, 0.05, 0.15)
#define WATER_COLOR_SURFACE vec3(0.02, 0.12, 0.27)
#define SAND_COLOR vec3(1.0, 1.0, 0.85)
#define TREE_COLOR vec3(.02, .1, .06)
#define ROCK_COLOR vec3(0.15, 0.12, 0.12)
#define ICE_COLOR  vec3(0.8, .9, .9)
#define CLOUD_COLOR  vec3(1., 1., 1.)
#define ATMOSPHERE_COLOR vec3(0.05, 0.3, 0.9)

#define WATER_SURFACE_LEVEL 0.0
#define SAND_LEVEL .028
#define TREE_LEVEL .03
#define ROCK_LEVEL .1
#define ICE_LEVEL .15
#define TRANSITION .02

// Lighting
#define SUN_DIR normalize(vec3(1.0, 1.0, 0.))
#define SUN_COLOR vec3(1.0, 1.0, 0.9) * 3.
#define AMBIENT_LIGHT vec3(.003)
#define SPACE_BLUE vec3(0., 0., 0.002)

// Ray tracing
#define MAX_BOUNCES 1 // something's wrong with the normals when using more than one bounce...
#define EPSILON 1e-3
#define INFINITY 1e10
#define CAMERA_POSITION vec3(0., 0., 6.0)

#define PI acos(-1.)

//=========//
//  Types  //
//=========//

struct Ray {
  vec3 origin;
  vec3 direction;
};

struct Material {
  vec3 color;
  float diffuse;
  float specular;
};

struct Hit {
  float len;
  vec3 normal;
  Material material;
};

struct Sphere {
  vec3 position;
  float radius;
};

Hit miss = Hit(INFINITY, vec3(0.), Material(vec3(0.), -1., -1.));
Sphere planet = Sphere(PLANET_POSITION, PLANET_RADIUS);


//===============================================//
//  Generic utilities stolen from smarter people //
//===============================================//


float inverseLerp(float v, float minValue, float maxValue) {
  return (v - minValue) / (maxValue - minValue);
}

float remap(float v, float inMin, float inMax, float outMin, float outMax) {
  float t = inverseLerp(v, inMin, inMax);
  return mix(outMin, outMax, t);
}

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
  return mod289(((x * 34.0) + 1.0) * x);
}

// https://github.com/yiwenl/glsl-fbm/blob/master/3d.glsl
float noise(vec3 p) {
  vec3 a = floor(p);
  vec3 d = p - a;
  d = d * d * (3.0 - 2.0 * d);

  vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
  vec4 k1 = permute(b.xyxy);
  vec4 k2 = permute(k1.xyxy + b.zzww);

  vec4 c = k2 + a.zzzz;
  vec4 k3 = permute(c);
  vec4 k4 = permute(c + 1.0);

  vec4 o1 = fract(k3 * (1.0 / 41.0));
  vec4 o2 = fract(k4 * (1.0 / 41.0));

  vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
  vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

  return o4.y * d.y + o4.x * (1.0 - d.y);
}

// https://iquilezles.org/articles/intersectors/
float sphIntersect(in Ray ray, in Sphere sphere) {
  vec3 oc = ray.origin - sphere.position;
  float b = dot(oc, ray.direction);
  float c = dot(oc, oc) - sphere.radius * sphere.radius;
  float h = b * b - c;
  if(h < 0.0)
    return -1.; // no intersection
  return -b - sqrt(h);
}

// Comes from a course by SimonDev (https://www.youtube.com/channel/UCEwhtpXrg5MmwlH04ANpL8A)
// https://simondev.teachable.com/p/glsl-shaders-from-scratch
float fbm(vec3 p, int octaves, float persistence, float lacunarity, float exponentiation) {
  float amplitude = 0.5;
  float frequency = 3.0;
  float total = 0.0;
  float normalization = 0.0;

  for(int i = 0; i < octaves; ++i) {
    float noiseValue = noise(p * frequency);
    total += noiseValue * amplitude;
    normalization += amplitude;
    amplitude *= persistence;
    frequency *= lacunarity;
  }

  total /= normalization;
  total = total * 0.8 + 0.1;
  total = pow(total, exponentiation);

  return total;
}

mat3 rotateY(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return mat3(//
    vec3(c, 0, s),//
    vec3(0, 1, 0),//
    vec3(-s, 0, c)//
  );
}

mat3 rotateZ(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return mat3(//
    vec3(c, -s, 0),//
    vec3(s, c, 0),//
    vec3(0, 0, 1)//
  );
}

// https://github.com/dmnsgn/glsl-rotate/blob/main/rotation-3d.glsl
mat3 rotate3d(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;

  return mat3(//
    oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s,//
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s,//
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c//
  );
}

vec3 nmzHash33(vec3 q) {
  uvec3 p = uvec3(ivec3(q));
  p = p * uvec3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
  p = p.yzx * (p.zxy ^ (p >> 3U));
  return vec3(p ^ (p >> 16U)) * (1.0 / vec3(0xffffffffU));
}

// nimitz - https://www.shadertoy.com/view/XsyGWV
vec3 stars(in vec3 p) {
  vec3 c = vec3(0.);
  float res = uResolution.x * 0.8;

  for(float i = 0.; i < 5.; i++) {
    vec3 q = fract(p * (.15 * res)) - 0.5;
    vec3 id = floor(p * (.15 * res));
    vec2 rn = nmzHash33(id).xy;
    float c2 = 1. - smoothstep(0., .6, length(q));
    c2 *= step(rn.x, .0005 + i * 0.002);
    c += c2 * (mix(vec3(1.0, 0.49, 0.1), vec3(0.75, 0.9, 1.), rn.y) * 0.25 + 0.75);
    p *= 1.4;
  }
  return c * c;
}

// Comes from a course by SimonDev (https://www.youtube.com/channel/UCEwhtpXrg5MmwlH04ANpL8A)
// https://simondev.teachable.com/p/glsl-shaders-from-scratch
float domainWarpingFBM(vec3 p) {
  int octaves = 3;
  float persistence = .3;
  float lacunarity = 5.;
  float expo = 1.;

  vec3 offset = vec3(//
    fbm(p, octaves, persistence, lacunarity, expo), //
    fbm(p + vec3(43.235, 23.112, 0.0), octaves, persistence, lacunarity, expo), //
    0.0//
  );

  return fbm(p + 1. * offset, 2, persistence, lacunarity, expo);
}

// Zavie - https://www.shadertoy.com/view/lslGzl
vec3 simpleReinhardToneMapping(vec3 color) {
  float exposure = 1.5;
  color *= exposure / (1. + color / exposure);
  color = pow(color, vec3(1. / 2.4));
  return color;
}


//========//
//  Misc  //
//========//

float planetNoise(vec3 p) {
  float fbm = fbm(p * .8, 6, .5, 2., 5.) * NOISE_STRENGTH;

  // Flatten the noise on the oceans
  return mix(//
    fbm / 3. + NOISE_STRENGTH / 50., //
    fbm, //
    smoothstep(SAND_LEVEL, SAND_LEVEL + TRANSITION / 2., fbm * 5.)//
  );
}

/**
* Standard ray-sphere intersection but with fbm noise added on the radius.
* Probably not exact (especially near the edges), but it looks good enough
*/
float planetDist(in vec3 ro, in vec3 rd) {
  Ray ray = Ray(ro, rd);
  float smoothSphereDist = sphIntersect(ray, planet);

  vec3 intersection = ro + smoothSphereDist * rd;
  vec3 intersectionWithRotation = (intersection - PLANET_POSITION) * PLANET_ROTATION + PLANET_POSITION;

  return sphIntersect(ray, Sphere(PLANET_POSITION, PLANET_RADIUS + planetNoise(intersectionWithRotation)));
}

vec3 planetNormal(vec3 p) {
  vec3 rd = PLANET_POSITION - p;
  float dist = planetDist(p, rd);
  vec2 e = vec2(.01, 0);

  vec3 normal = dist - vec3(planetDist(p - e.xyy, rd), planetDist(p - e.yxy, rd), planetDist(p + e.yyx, rd));
  return normalize(normal);
}

vec3 currentMoonPosition() {
  mat3 moonRotation = rotate3d(MOON_ROTATION_AXIS, uTime * MOON_ROTATION_SPEED);
  return MOON_OFFSET * moonRotation + PLANET_POSITION;
}

vec3 spaceColor(vec3 direction) {
  mat3 backgroundRotation = rotateY(-uTime * ROTATION_SPEED / 4.);
  vec3 backgroundCoord = direction * backgroundRotation;
  float spaceNoise = fbm(backgroundCoord * 3., 4, .5, 2., 6.);

  return stars(backgroundCoord) + mix(SPACE_BLUE, ATMOSPHERE_COLOR / 4., spaceNoise);
}

//===============//
//  Ray Tracing  //
//===============//

Hit intersectPlanet(Ray ray) {
  float len = sphIntersect(ray, planet);

  if(len < 0.) {
    return miss;
  }

  vec3 position = ray.origin + len * ray.direction;
  vec3 rotatedCoord = (position - PLANET_POSITION) * PLANET_ROTATION + PLANET_POSITION;
  float altitude = 5. * planetNoise(rotatedCoord);

  vec3 normal = planetNormal(position);

  vec3 color = mix(WATER_COLOR_DEEP, WATER_COLOR_SURFACE, smoothstep(WATER_SURFACE_LEVEL, WATER_SURFACE_LEVEL + TRANSITION, altitude));
  color = mix(color, SAND_COLOR, smoothstep(SAND_LEVEL, SAND_LEVEL + TRANSITION / 2., altitude));
  color = mix(color, TREE_COLOR, smoothstep(TREE_LEVEL, TREE_LEVEL + TRANSITION, altitude));
  color = mix(color, ROCK_COLOR, smoothstep(ROCK_LEVEL, ROCK_LEVEL + TRANSITION, altitude));
  color = mix(color, ICE_COLOR, smoothstep(ICE_LEVEL, ICE_LEVEL + TRANSITION, altitude));

  vec3 cloudsCoord = rotateY(uTime * -.005) * rotatedCoord + vec3(uTime * .008);
  float cloudsDensity = remap(domainWarpingFBM(cloudsCoord), -1.0, 1.0, 0.0, 1.0);
  cloudsDensity *= smoothstep(.75, .85, cloudsDensity);
  cloudsDensity *= smoothstep(ROCK_LEVEL, (ROCK_LEVEL + TREE_LEVEL) / 2., altitude);
  color = mix(color, CLOUD_COLOR, cloudsDensity);

  float specular = smoothstep(SAND_LEVEL + TRANSITION, SAND_LEVEL, altitude);

  return Hit(len, normal, Material(color, 1., specular));
}

Hit intersectMoon(Ray ray) {
  vec3 moonPosition = currentMoonPosition();
  float length = sphIntersect(ray, Sphere(moonPosition, MOON_RADIUS));

  if(length < 0.) {
    return miss;
  }

  vec3 position = ray.origin + length * ray.direction;
  vec3 originalPosition = position * rotate3d(MOON_ROTATION_AXIS, -uTime * MOON_ROTATION_SPEED);
  vec3 color = vec3(sqrt(fbm(originalPosition * 12., 6, .5, 2., 5.)));
  vec3 normal = normalize(position - moonPosition);

  return Hit(length, normal, Material(color, 1., 0.));
}

Hit intersectScene(Ray ray) {
  Hit planetHit = intersectPlanet(ray);
  Hit moonHit = intersectMoon(ray);

  if(moonHit.len < planetHit.len) {
    return moonHit;
  }

  return planetHit;
}


vec3 radiance(Ray ray, inout float spaceMask) {
  vec3 color = vec3(0.0);
  vec3 attenuation = vec3(1.0);

  for(int i = 1; i <= MAX_BOUNCES; i++) {
    Hit hit = intersectScene(ray);

    if(hit.len < INFINITY) {
      spaceMask = 0.;

      vec3 hitPosition = ray.origin + hit.len * ray.direction;
      Hit shadowHit = intersectScene(Ray(hitPosition + EPSILON * SUN_DIR, SUN_DIR));
      float hitDirectLight = clamp(
        step(INFINITY, shadowHit.len) 
        + step(length(hitPosition - PLANET_POSITION) - PLANET_RADIUS, .1), // don't cast shadow on the planet, only the moon
        0., 
        1.
      );

      // Diffuse
      float directLightIntensity = pow(clamp(dot(hit.normal, SUN_DIR), 0.0, 1.0), 2.); // the power softens the shadow. Not physically accurate but it looks better to me
      vec3 diffuseLight = hitDirectLight * directLightIntensity * SUN_COLOR;
      vec3 diffuseColor = hit.material.color.rgb * (AMBIENT_LIGHT + diffuseLight);

      // Phong specular
      vec3 reflected = normalize(reflect(-SUN_DIR, hit.normal));
      float phongValue = pow(max(0.0, dot(ray.direction, reflected)), 10.) * .6;
      vec3 specularColor = hit.material.specular * vec3(phongValue);

      color += attenuation * (diffuseColor + specularColor);

      // Next bounce
      attenuation *= hit.material.specular;

      vec3 reflection = reflect(ray.direction, hit.normal);
      ray = Ray(ray.origin + hit.len * ray.direction + EPSILON * reflection, reflection);

    } else {
      if(spaceMask == 1.) {
        color += attenuation * spaceColor(ray.direction);
      }
      break;
    }
  }
  return color;
}

//========//
//  Main  //
//========//

vec3 atmosphereColor(vec3 ro, vec3 rd, float spaceMask) {
  float planetDist = sphIntersect(Ray(ro, rd), planet);
  float moonDist = sphIntersect(Ray(ro, rd), Sphere(currentMoonPosition(), MOON_RADIUS));
  float closestHit = planetDist;
  if (planetDist < 0. || moonDist >= 0. && moonDist < planetDist) {
    closestHit = moonDist;
  }
  vec3 position = ro + closestHit * rd;
  
  float distCameraToPlanetOrigin = length(PLANET_POSITION - CAMERA_POSITION);
  float distCameraToPlanetEdge = sqrt(distCameraToPlanetOrigin * distCameraToPlanetOrigin - PLANET_RADIUS * PLANET_RADIUS);
  float distCameraToMoon = length(currentMoonPosition() - CAMERA_POSITION);
  float isMoonInFront = smoothstep(-PLANET_RADIUS/2., PLANET_RADIUS/2., distCameraToPlanetEdge - distCameraToMoon);

  float moonMask = (1.0 - spaceMask) * step(PLANET_RADIUS + EPSILON, length(position - PLANET_POSITION));
  float planetMask = 1.0 - spaceMask - moonMask;

  vec3 coordFromCenter = (ro + rd * distCameraToPlanetEdge) - PLANET_POSITION;
  float distFromEdge = abs(length(coordFromCenter) - PLANET_RADIUS);
  float planetEdge = max(1. - distFromEdge, 0.);
  float atmosphereDensity = pow(remap(dot(SUN_DIR, coordFromCenter), -2., 1., 0., 1.), 5.);

  vec3 atmosphere = pow(planetEdge, 80.) * ATMOSPHERE_COLOR;
  atmosphere += pow(planetEdge, 30.) * ATMOSPHERE_COLOR * (1.5 - planetMask);
  atmosphere += pow(planetEdge, 4.) * ATMOSPHERE_COLOR * .02;
  atmosphere += pow(planetEdge, 2.) * ATMOSPHERE_COLOR * .1 * planetMask;

  return atmosphere * atmosphereDensity * (1. - moonMask * isMoonInFront);
}

void main() {
  vec3 ro = vec3(CAMERA_POSITION);
  vec3 rd = normalize(vec3(uv.x, uv.y, -1));
  Ray ray = Ray(ro, rd);

  float spaceMask = 1.;

  vec3 color = radiance(ray, spaceMask);

  color += atmosphereColor(ro, rd, spaceMask);

  // color grading
  color = simpleReinhardToneMapping(color);

  // vignette
  color *= 1. - 0.5 * pow(length(uv), 3.);

  fragColor = vec4(color, 1.0);
}