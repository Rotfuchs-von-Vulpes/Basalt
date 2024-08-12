package worldRender

import gl "vendor:OpenGL"
import "vendor:sdl2"
import stb "vendor:stb/image"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"

import "../skeewb"
import "../world"
import "../util"
import mesh "meshGenerator"

ChunkBuffer :: struct{
    x, y, z: i32,
	VAO, VBO, EBO: u32,
    length: i32
}

iVec3 :: struct {
    x, y, z: i32
}

mat4 :: glm.mat4
vec2 :: glm.vec2
vec3 :: glm.vec3
vec4 :: glm.vec4

chunkMap := make(map[iVec3]ChunkBuffer)

setupChunk :: proc(chunk: world.Chunk) -> ChunkBuffer {
    indices, vertices := mesh.generateMesh(chunk)
    defer delete(indices)
    defer delete(vertices)
    VAO, VBO, EBO: u32
    
	gl.GenVertexArrays(1, &VAO)
	gl.BindVertexArray(VAO)

	gl.GenBuffers(1, &VBO)
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
	
	gl.GenBuffers(1, &EBO)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)

	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 9 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 9 * size_of(f32), 3 * size_of(f32))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 9 * size_of(f32), 6 * size_of(f32))
	gl.VertexAttribPointer(3, 1, gl.FLOAT, false, 9 * size_of(f32), 8 * size_of(f32))

    return ChunkBuffer{chunk.x, chunk.y, chunk.z, VAO, VBO, EBO, i32(len(indices))}
}

eval :: proc(chunk: world.Chunk) -> ChunkBuffer {
    pos := iVec3{chunk.x, chunk.y, chunk.z}
    chunkBuffer, ok, _ := util.map_force_get(&chunkMap, pos)
    if ok {
        chunkBuffer^ = setupChunk(chunk)
    }
    return chunkBuffer^
}

setupManyChunks :: proc(chunks: [dynamic]world.Chunk) -> [dynamic]ChunkBuffer {
    chunksBuffers: [dynamic]ChunkBuffer

    for chunk in chunks {
        append(&chunksBuffers, eval(chunk))
    }

    return chunksBuffers;
}

Camera :: struct{
	pos: vec3,
	front: vec3,
	up: vec3,
	right: vec3,
	chunk: [3]i32,
	viewDistance: i32,
    viewPort: vec2,
	proj, view: mat4
}

Render :: struct{
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
}

setupDrawing :: proc(core: ^skeewb.core_interface, render: ^Render) {
	vertShader := core.resource_load("vert", "basalt/assets/shaders/test_vert.glsl")
	fragShader := core.resource_load("frag", "basalt/assets/shaders/test_frag.glsl")

	shaderSuccess : bool
	render.program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        len: i32
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile shaders\n %s\n %s", a, c)
    }

	gl.GenTextures(1, &render.texture)
	gl.BindTexture(gl.TEXTURE_2D, render.texture)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	width, height, channels: i32
	data := core.resource_string(core.resource_load("madera", "basalt/assets/textures/default_box.png"))
	pixels := stb.load_from_memory(raw_data(data), cast(i32) len(data), &width, &height, &channels, 4)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
	gl.GenerateMipmap(gl.TEXTURE_2D)
	if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
		filter: f32
		gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &filter)
		gl.TexParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAX_ANISOTROPY, filter)
	}
}

cameraSetup :: proc(camera: ^Camera, render: Render) {
	camera.proj = glm.mat4PerspectiveInfinite(45, camera.viewPort.x / camera.viewPort.y, 0.1)
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
}

cameraMove :: proc(camera: ^Camera, render: Render) {
	camera.view = glm.mat4LookAt({0, 0, 0}, camera.front, camera.up)
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
}

frustumCulling :: proc(chunks: [dynamic]ChunkBuffer, camera: ^Camera) -> [dynamic]ChunkBuffer {
	chunksBuffers: [dynamic]ChunkBuffer

	PV := camera.proj * camera.view
	for chunk in chunks {
		minC := [3]f32{f32(chunk.x) * 32 - camera.pos.x, f32(chunk.y) * 32 - camera.pos.y, f32(chunk.z) * 32 - camera.pos.z}
		maxC := minC + [3]f32{32, 32, 32}
		
		corners := [?][3]f32{
			{minC.x, minC.y, minC.z},
			{minC.x, minC.y, maxC.z},
			{minC.x, maxC.y, minC.z},
			{minC.x, maxC.y, maxC.z},
			{maxC.x, minC.y, minC.z},
			{maxC.x, minC.y, maxC.z},
			{maxC.x, maxC.y, minC.z},
			{maxC.x, maxC.y, maxC.z},
		}

		minor, major: [3]f32 = {2, 2, 2}, {-2, -2, -2}
		for corner in corners {
			MPV := PV * vec4{corner.x, corner.y, corner.z, 1}

			x := MPV.x / MPV.w
			y := MPV.y / MPV.w
			z := MPV.z / MPV.w
			minor.x = min(minor.x, x)
			minor.y = min(minor.y, y)
			minor.z = min(minor.z, z)
			major.x = max(major.x, x)
			major.y = max(major.y, y)
			major.z = max(major.z, z)

			if major.x > -1 || minor.x < 1 && major.y > -1 || minor.y < 1 && major.z > -1 || minor.z < 1 {
				append(&chunksBuffers, chunk)
				break
			}
		}
	}

	return chunksBuffers
}

drawChunks :: proc(chunks: [dynamic]ChunkBuffer, camera: Camera, render: Render) {
	gl.ActiveTexture(gl.TEXTURE0);
	gl.BindTexture(gl.TEXTURE_2D, render.texture);

	for chunk in chunks {
		pos := [3]f32{f32(chunk.x) * 32 - camera.pos.x, f32(chunk.y) * 32 - camera.pos.y, f32(chunk.z) * 32 - camera.pos.z}
		model := math.matrix4_translate_f32(pos)
		gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])

		gl.BindVertexArray(chunk.VAO);
		gl.DrawElements(gl.TRIANGLES, chunk.length, gl.UNSIGNED_INT, nil)
	}
}

nuke :: proc() {
	for pos, &chunk in chunkMap {
		gl.DeleteBuffers(1, &chunk.VBO)
		gl.DeleteBuffers(1, &chunk.EBO)
	}
    delete(chunkMap)
}