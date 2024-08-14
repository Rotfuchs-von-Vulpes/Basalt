#version 330 core

out vec4 fragColor;
in vec3 Normal;
in vec2 TexCoords;
in float Occlusion;

uniform sampler2DArray textures;

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

vec3 skyColor = vec3(0.4666, 0.6588, 1.0);

vec3 CalculateLighting(vec3 albedo, vec3 normal, vec2 lightmapCoords, vec3 fragCoords) {
    vec3 sunDirection = normalize(-vec3(-0.2f, -1.0f, -0.3f));
    float sunVisibility  = clamp((dot( sunDirection, vec3(0.0, 1.0, 0.0)) + 0.05) * 10.0, 0.0, 1.0);

    vec2 lightmap = AdjustLightmap(lightmapCoords);
    vec3 torchColor = vec3(0.98f, 0.68f, 0.55f);
    vec3 torchLight = lightmap.x * torchColor;
    vec3 skyLight = lightmap.y * skyColor;

    vec3 lightColor = torchLight + skyLight;

    vec3 ndotl = sunColor * clamp(4 * dot(normal, sunDirection), 0.0f, 1.0f) * sunVisibility;
    ndotl *= 1.3;
    ndotl *= (luminance(skyColor) + 0.01f);
    ndotl *= lightmap.g;

    vec3 lighting = ndotl + lightColor + _Ambient;

    vec3 diffuse = albedo.rgb;
    diffuse *= lighting;

    return diffuse;
}

void main()
{
    int id = Normal.y > 0 ? 4 : Normal.y < 0 ? 2 : 3;
    vec4 albedo = texture(textures,vec3(TexCoords, id));
    float occluse = 0.25 * Occlusion + 0.25;
    albedo.rgb = pow(albedo.rgb, vec3(1.0 / 2.2)) * occluse;

    vec3 diffuse = CalculateLighting(albedo.rgb, Normal, vec2(0, 1), gl_FragCoord.xyz);

    fragColor = vec4(diffuse, albedo.a);
}