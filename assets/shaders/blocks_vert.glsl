#version 330 core

layout(location=0)in vec3 aPos;
layout(location=1)in vec3 aNormal;
layout(location=2)in vec2 aTexCoords;
layout(location=3)in float aOcclusion;
layout(location=4)in float aTextureID;

out vec3 Pos;
out vec3 Normal;
out vec2 TexCoords;
out float Occlusion;
out float TextureID;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    vec3 FragPos = vec3(model * vec4(aPos, 1.0));
    Pos = FragPos;
    Normal = aNormal;
    TexCoords = aTexCoords;
    Occlusion = aOcclusion;
    TextureID = aTextureID;
	gl_Position = projection * view * vec4(FragPos, 1.0);
}