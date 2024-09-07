#version 330 core

out vec4 fragColor;
in vec2 TexCoords;
in vec3 Pos;

uniform vec3 skyColor;
uniform vec3 fogColor;

void main()
{
    vec3 direction = normalize(Pos);

    vec3 sky = mix(skyColor, fogColor, clamp(length(2.0 * direction - vec3(0, 1, 0)) - 1.0, 0.0, 1.0));

    fragColor = vec4(sky, 1.0);
}