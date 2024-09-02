#version 330 core

out vec4 fragColor;
in vec2 TexCoords;

uniform sampler2DArray textures;

void main()
{
    fragColor = vec4(1);
}