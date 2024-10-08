#version 330 core

layout(location=0)in vec2 aPos;
layout(location=1)in vec2 aTexCoords;

out vec2 TexCoords;
out vec3 Pos;

uniform mat4 view;
uniform mat4 model;
uniform mat4 projection;

void main() {
    TexCoords = aTexCoords;
    vec3 FragPos = vec3(model * vec4(vec3(aPos, 0.0), 1.0));
    Pos = FragPos;
	gl_Position = projection * view * vec4(FragPos, 1.0);
}