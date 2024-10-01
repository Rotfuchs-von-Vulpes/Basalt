package worldRender

import gl "vendor:OpenGL"
import "vendor:sdl2"
import stb "vendor:stb/image"
import "core:strings"
import glm "core:math/linalg/glsl"
import math "core:math/linalg"

import "../skeewb"
import "../world"
import "../util"
import "../sky"
import mesh "meshGenerator"

iVec3 :: [3]i32
ivec2 :: [2]u32

ChunkBuffer :: struct{
    x, y, z: i32,
	VAO, VBO, EBO: u32,
    length: i32,
	faceSet: mesh.FaceSet,
	ranges: [mesh.Direction]ivec2,
}

mat4 :: glm.mat4x4
vec2 :: [2]f32
vec3 :: [3]f32
vec4 :: [4]f32

chunkMap := make(map[iVec3]ChunkBuffer)

setupChunk :: proc(chunk: world.Chunk) -> ChunkBuffer {
    ranges, indices, vertices := mesh.generateMesh(chunk)
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
	gl.EnableVertexAttribArray(4)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, 10 * size_of(f32), 0)
	gl.VertexAttribPointer(1, 3, gl.FLOAT, false, 10 * size_of(f32), 3 * size_of(f32))
	gl.VertexAttribPointer(2, 2, gl.FLOAT, false, 10 * size_of(f32), 6 * size_of(f32))
	gl.VertexAttribPointer(3, 1, gl.FLOAT, false, 10 * size_of(f32), 8 * size_of(f32))
	gl.VertexAttribPointer(4, 1, gl.FLOAT, false, 10 * size_of(f32), 9 * size_of(f32))

    return ChunkBuffer{chunk.pos.x, chunk.pos.y, chunk.pos.z, VAO, VBO, EBO, i32(len(indices)), {}, ranges}
}

eval :: proc(chunk: world.Chunk) -> ChunkBuffer {
    pos := iVec3{chunk.pos.x, chunk.pos.y, chunk.pos.z}
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

Render :: struct{
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
}

vertShader :: #load("../assets/shaders/blocks_vert.glsl", string)
fragShader :: #load("../assets/shaders/blocks_frag.glsl", string)

madera :: #load("../assets/textures/box.png", string)
preda :: #load("../assets/textures/stone.png", string)
terra :: #load("../assets/textures/dirt.png", string)
teratu :: #load("../assets/textures/dirt_with_grass.png", string)
matu :: #load("../assets/textures/grass.png", string)
area :: #load("../assets/textures/sand.png", string)
foia :: #load("../assets/textures/leaves.png", string)
arvre :: #load("../assets/textures/tree.png", string)
arvre2 :: #load("../assets/textures/tree_top.png", string)
pread :: #load("../assets/textures/cobble.png", string)

setupDrawing :: proc(render: ^Render) {
	shaderSuccess: bool
	render.program, shaderSuccess = gl.load_shaders_source(vertShader, fragShader)

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(render.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile blocks shaders\n %s\n %s", a, c)
    }

	gl.GenTextures(1, &render.texture)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, render.texture)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	width, height, channels: i32
	datas := []string{
		madera,
		preda,
		terra,
		teratu,
		matu,
		area,
		foia,
		arvre,
		arvre2,
		pread,
	}
	gl.TexImage3D(gl.TEXTURE_2D_ARRAY, 0, gl.SRGB8_ALPHA8, 16, 16, i32(len(datas)), 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
	for tex, idx in datas {
		pixels := stb.load_from_memory(raw_data(tex), i32(len(tex)), &width, &height, &channels, 4)
		gl.TexSubImage3D(gl.TEXTURE_2D_ARRAY, 0, 0, 0, i32(idx), 16, 16, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
		stb.image_free(pixels)
	}
	gl.GenerateMipmap(gl.TEXTURE_2D_ARRAY)
	if sdl2.GL_ExtensionSupported("GL_EXT_texture_filter_anisotropic") {
		filter: f32
		gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &filter)
		gl.TexParameterf(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAX_ANISOTROPY, filter)
	}
	render.uniforms = gl.get_uniforms_from_program(render.program)
}

testAabb :: proc(MPV: mat4, min, max: vec3) -> bool
{
	nxX := MPV[0][3] + MPV[0][0]; nxY := MPV[1][3] + MPV[1][0]; nxZ := MPV[2][3] + MPV[2][0]; nxW := MPV[3][3] + MPV[3][0]
	pxX := MPV[0][3] - MPV[0][0]; pxY := MPV[1][3] - MPV[1][0]; pxZ := MPV[2][3] - MPV[2][0]; pxW := MPV[3][3] - MPV[3][0]
	nyX := MPV[0][3] + MPV[0][1]; nyY := MPV[1][3] + MPV[1][1]; nyZ := MPV[2][3] + MPV[2][1]; nyW := MPV[3][3] + MPV[3][1]
	pyX := MPV[0][3] - MPV[0][1]; pyY := MPV[1][3] - MPV[1][1]; pyZ := MPV[2][3] - MPV[2][1]; pyW := MPV[3][3] - MPV[3][1]
	nzX := MPV[0][3] + MPV[0][2]; nzY := MPV[1][3] + MPV[1][2]; nzZ := MPV[2][3] + MPV[2][2]; nzW := MPV[3][3] + MPV[3][2]
	pzX := MPV[0][3] - MPV[0][2]; pzY := MPV[1][3] - MPV[1][2]; pzZ := MPV[2][3] - MPV[2][2]; pzW := MPV[3][3] - MPV[3][2]
	
	return nxX * (nxX < 0 ? min[0] : max[0]) + nxY * (nxY < 0 ? min[1] : max[1]) + nxZ * (nxZ < 0 ? min[2] : max[2]) >= -nxW &&
		pxX * (pxX < 0 ? min[0] : max[0]) + pxY * (pxY < 0 ? min[1] : max[1]) + pxZ * (pxZ < 0 ? min[2] : max[2]) >= -pxW &&
		nyX * (nyX < 0 ? min[0] : max[0]) + nyY * (nyY < 0 ? min[1] : max[1]) + nyZ * (nyZ < 0 ? min[2] : max[2]) >= -nyW &&
		pyX * (pyX < 0 ? min[0] : max[0]) + pyY * (pyY < 0 ? min[1] : max[1]) + pyZ * (pyZ < 0 ? min[2] : max[2]) >= -pyW &&
		nzX * (nzX < 0 ? min[0] : max[0]) + nzY * (nzY < 0 ? min[1] : max[1]) + nzZ * (nzZ < 0 ? min[2] : max[2]) >= -nzW &&
		pzX * (pzX < 0 ? min[0] : max[0]) + pzY * (pzY < 0 ? min[1] : max[1]) + pzZ * (pzZ < 0 ? min[2] : max[2]) >= -pzW;
}

frustumMove :: proc(chunks: ^[dynamic]ChunkBuffer, camera: ^util.Camera) {
	for &chunk in chunks {
		faces: mesh.FaceSet = {}

		if chunk.x <= camera.chunk.x {faces = faces + {.East}}
		if chunk.x >= camera.chunk.x {faces = faces + {.West}}
		if chunk.y <= camera.chunk.y {faces = faces + {.Up}}
		if chunk.y >= camera.chunk.y {faces = faces + {.Bottom}}
		if chunk.z <= camera.chunk.z {faces = faces + {.North}}
		if chunk.z >= camera.chunk.z {faces = faces + {.South}}

		chunk.faceSet = faces
	}
}

frustumCulling :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera) -> [dynamic]ChunkBuffer {
	chunksBuffers: [dynamic]ChunkBuffer = {}

	PV := camera.proj * camera.view
	for chunk in chunks {
		minC := 32 * vec3{f32(chunk.x), f32(chunk.y), f32(chunk.z)} - camera.pos
		maxC := minC + vec3{32, 32, 32}
		
		if testAabb(PV, minC, maxC) {append(&chunksBuffers, chunk)}
	}

	return chunksBuffers
}

drawChunks :: proc(chunks: [dynamic]ChunkBuffer, camera: ^util.Camera, render: Render) {
	gl.UniformMatrix4fv(render.uniforms["projection"].location, 1, false, &camera.proj[0, 0])
	gl.UniformMatrix4fv(render.uniforms["view"].location, 1, false, &camera.view[0, 0])
	gl.Uniform3f(render.uniforms["sunDirection"].location, sky.sunDirection.x, sky.sunDirection.y, sky.sunDirection.z)
	gl.Uniform3f(render.uniforms["skyColor"].location, sky.skyColor.r, sky.skyColor.g, sky.skyColor.b)
	gl.Uniform3f(render.uniforms["fogColor"].location, sky.fogColor.r, sky.fogColor.g, sky.fogColor.b)
	for chunk in chunks {
		pos := vec3{f32(chunk.x) * 32 - camera.pos.x, f32(chunk.y) * 32 - camera.pos.y, f32(chunk.z) * 32 - camera.pos.z}
		model := math.matrix4_translate_f32(pos)
		gl.UniformMatrix4fv(render.uniforms["model"].location, 1, false, &model[0, 0])

		gl.BindVertexArray(chunk.VAO)
		if .North in chunk.faceSet {
			start := chunk.ranges[.North][0]
			end := chunk.ranges[.North][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
		if .South in chunk.faceSet {
			start := chunk.ranges[.South][0]
			end := chunk.ranges[.South][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
		if .East in chunk.faceSet {
			start := chunk.ranges[.East][0]
			end := chunk.ranges[.East][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
		if .West in chunk.faceSet {
			start := chunk.ranges[.West][0]
			end := chunk.ranges[.West][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
		if .Up in chunk.faceSet {
			start := chunk.ranges[.Up][0]
			end := chunk.ranges[.Up][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
		if .Bottom in chunk.faceSet {
			start := chunk.ranges[.Bottom][0]
			end := chunk.ranges[.Bottom][1]
			gl.DrawElements(gl.TRIANGLES, i32(end - start), gl.UNSIGNED_INT, (rawptr)(uintptr(start) * size_of(u32)))
		}
	}
}

nuke :: proc() {
	for pos, &chunk in chunkMap {
		gl.DeleteBuffers(1, &chunk.VBO)
		gl.DeleteBuffers(1, &chunk.EBO)
	}
    delete(chunkMap)
}

destroy :: proc(chunks: [dynamic]^world.Chunk) {
	for chunk in chunks {
		delete_key(&chunkMap, iVec3{chunk.pos.x, chunk.pos.y, chunk.pos.z})
	}
}