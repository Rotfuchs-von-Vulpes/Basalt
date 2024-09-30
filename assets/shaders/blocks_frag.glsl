#version 330 core

out vec4 fragColor;
in vec3 Pos;
in vec3 Normal;
in vec2 TexCoords;
in float Occlusion;
in float TextureID;

uniform sampler2DArray textures;
uniform vec3 sunDirection;
uniform vec3 skyColor;
uniform vec3 fogColor;

float luminance(vec3 color) {
    return dot(color, vec3(0.2125f, 0.7153f, 0.0721f));
}

vec3 sunColor = vec3(0.98f, 0.73f, 0.15f);
vec3 moonColor = vec3(0.9725f, 0.9765f, 0.9765f);

const vec3 _Ambient = vec3(0.02f, 0.04f, 0.08f);

float AdjustTorchLighting(in float torchLight) {
    return max(3 * pow(torchLight, 4), 0.0f);
}

float AdjustSkyLighting(in float skyLight) {
    return max(pow(skyLight, 3), 0.0f);
}

vec2 AdjustLightmap(in vec2 lightmap) {
    vec2 newLightmap = lightmap;
    newLightmap.r = AdjustTorchLighting(lightmap.r);
    newLightmap.g = AdjustSkyLighting(lightmap.g);

    return newLightmap;
}

vec3 CalculateLighting(vec3 albedo, vec3 normal, vec2 lightmapCoords, vec3 fragCoords) {
    float sunVisibility  = clamp((dot( sunDirection, vec3(0.0, 1.0, 0.0)) + 0.05) * 10.0, 0.0, 1.0);
    float moonVisibility = clamp((dot(-sunDirection, vec3(0.0, 1.0, 0.0)) + 0.05) * 10.0, 0.0, 1.0);

    vec2 lightmap = AdjustLightmap(lightmapCoords);
    vec3 torchColor = vec3(0.98f, 0.68f, 0.55f);
    vec3 torchLight = lightmap.x * torchColor;
    vec3 skyLight = lightmap.y * skyColor;

    vec3 lightColor = torchLight + skyLight;

    vec3 ndotl = sunColor * clamp(4 * dot(normal, sunDirection), 0.0f, 1.0f) * sunVisibility;
    ndotl += moonColor * clamp(4 * dot(normal, -sunDirection), 0.0f, 1.0f) * moonVisibility;
    ndotl *= 1.3;
    ndotl *= (luminance(skyColor) + 0.01f);
    ndotl *= lightmap.g;

    vec3 lighting = ndotl + lightColor + _Ambient;

    vec3 diffuse = albedo.rgb;
    diffuse *= lighting;

    return diffuse;
}

vec3 ACESFilm(vec3 rgb) {
  rgb *= 0.6;
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return (rgb*(a*rgb+b))/(rgb*(c*rgb+d)+e);
}

void main()
{
    vec4 albedo = texture(textures,vec3(TexCoords, TextureID));
    if (albedo.a < 0.5) discard;
    float occluse = 0.25 * Occlusion + 0.25;
    albedo.rgb = pow(ACESFilm(albedo.rgb), vec3(1.0 / 2.2)) * occluse;

    vec3 diffuse = CalculateLighting(albedo.rgb, Normal, vec2(0, 1), gl_FragCoord.xyz);

    float fragDist = length(Pos) / 6;
    float fogFactor = 1.0 - exp(fragDist * fragDist * -0.005);
    fogFactor = clamp(fogFactor, 0.0, 1.0);

    fragColor = vec4(mix(diffuse, fogColor, fogFactor), albedo.a);
}