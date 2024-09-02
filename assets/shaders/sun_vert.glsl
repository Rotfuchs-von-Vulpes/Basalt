#version 330 core

layout(location=0)in vec2 aPos;
layout(location=1)in vec2 aTexCoords;

out vec2 TexCoords;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    vec3 FragPos = vec3(model * vec4(vec3(aPos, 0.0), 1.0));
    TexCoords = aTexCoords;
	gl_Position = projection * view * vec4(FragPos, 1.0);
}