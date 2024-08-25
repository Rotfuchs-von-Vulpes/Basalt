package basalt

import "core:fmt"
import "core:time"
import "core:mem"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"
import "skeewb"
import "base:runtime"
import "vendor:sdl2"
import gl "vendor:OpenGL"

import "world"
import "worldRender"

@(export)
load :: proc"c"(core: ^skeewb.core_interface) -> skeewb.module_desc {
	context = runtime.default_context()

	core.event_listen("start", skeewb.event_callback(start));
	core.event_listen("loop", skeewb.event_callback(loop));
	core.event_listen("quit", skeewb.event_callback(quit));

	return (skeewb.module_desc) {
		modid = "basalt",
		version = {0, 0, 1},
		interface = nil,
	}
}

start_tick: time.Tick

window: ^sdl2.Window
gl_context: sdl2.GLContext
screenWidth: i32 = 854
screenHeight: i32 = 480

playerCamera := worldRender.Camera{
	{1, 33, 1}, 
	{0, 0, -1}, 
	{0, 1, 0}, 
	{1, 0, 0}, 
	{0, 0, 0}, 6, 
	{f32(screenWidth), f32(screenHeight)}, 
	math.MATRIX4F32_IDENTITY, math.MATRIX4F32_IDENTITY
}

FrameBuffer :: struct{
	id: u32,
	vao: u32,
	vbo: u32,
	uniforms: map[string]gl.Uniform_Info,
	program: u32,
	texture: u32,
	depth: u32,
}

blockRender := worldRender.Render{{}, 0, 0}
fboRender := FrameBuffer{0, 0, 0, {}, 0, 0, 0}

chunks: [dynamic]worldRender.ChunkBuffer
allChunks: [dynamic]worldRender.ChunkBuffer

tracking_allocator: ^mem.Tracking_Allocator

quadVertices := [?]f32{
	// positions   // texCoords
	-1.0,  1.0,  0.0, 1.0,
	-1.0, -1.0,  0.0, 0.0,
	 1.0, -1.0,  1.0, 0.0,

	-1.0,  1.0,  0.0, 1.0,
	 1.0, -1.0,  1.0, 0.0,
	 1.0,  1.0,  1.0, 1.0
};

start :: proc"c"(core: ^skeewb.core_interface) {
	context = runtime.default_context()

	tracking_allocator = new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(tracking_allocator)
	
	start_tick = time.tick_now()

	sdl2.Init(sdl2.INIT_EVERYTHING)

	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))


	window = sdl2.CreateWindow("testando se muda alguma coisa", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, screenWidth, screenHeight, sdl2.WINDOW_RESIZABLE | sdl2.WINDOW_OPENGL)
	if (window == nil) {
		skeewb.console_log(.ERROR, "could not create a window sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created a window")

	sdl2.SetRelativeMouseMode(true)

	gl_context = sdl2.GL_CreateContext(window);
	if (gl_context == nil) {
		skeewb.console_log(.ERROR, "could not create an OpenGL context sdl error: %s", sdl2.GetError())
		core.quit(-1)
	}
	skeewb.console_log(.INFO, "successfully created an OpenGL context")

	sdl2.GL_SetSwapInterval(-1)

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)
	
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)

	// gl.Enable(gl.BLEND)
	// gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	worldRender.setupDrawing(core, &blockRender)

	// tmp := world.peak(playerCamera.chunk.x, playerCamera.chunk.y, playerCamera.chunk.z, playerCamera.viewDistance)
	// defer delete(tmp)
	// allChunks = worldRender.setupManyChunks(tmp)

	gl.ClearColor(0.4666, 0.6588, 1.0, 1.0)

	blockRender.uniforms = gl.get_uniforms_from_program(blockRender.program)

	worldRender.cameraSetup(&playerCamera, blockRender)
	worldRender.cameraMove(&playerCamera, blockRender)

	chunks = worldRender.frustumCulling(allChunks, &playerCamera)
	

	gl.GenFramebuffers(1, &fboRender.id)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fboRender.id)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &fboRender.texture)
	gl.BindTexture(gl.TEXTURE_2D, fboRender.texture)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB16F, screenWidth, screenHeight, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fboRender.texture, 0)
	
	gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &fboRender.depth)
	gl.BindTexture(gl.TEXTURE_2D, fboRender.depth)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT32, screenWidth, screenHeight, 0, gl.DEPTH_COMPONENT, gl.UNSIGNED_INT, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
	gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, raw_data([]f32{1, 1, 1, 1}))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.FramebufferTexture(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, fboRender.depth, 0)

	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != u32(gl.FRAMEBUFFER_COMPLETE) {
		skeewb.console_log(.ERROR, "Framebuffer is not complete!")
		core.quit(-1)
	}

	gl.GenVertexArrays(1, &fboRender.vao)
	gl.GenBuffers(1, &fboRender.vbo)
	gl.BindVertexArray(fboRender.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, fboRender.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(quadVertices)*size_of(quadVertices[0]), &quadVertices, gl.STATIC_DRAW)
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(quadVertices[0]), 2 * size_of(quadVertices[0]))

	vertShader := core.resource_load("quad_vert", "basalt/assets/shaders/quad_vert.glsl")
	fragShader := core.resource_load("quad_frag", "basalt/assets/shaders/quad_frag.glsl")

	shaderSuccess: bool
	fboRender.program, shaderSuccess = gl.load_shaders_source(core.resource_string(vertShader), core.resource_string(fragShader))

    if !shaderSuccess {
        info: [^]u8
        gl.GetShaderInfoLog(fboRender.program, 1024, nil, info)
        a, b, c, d := gl.get_last_error_messages()
        skeewb.console_log(.ERROR, "could not compile fbo shaders\n %s\n %s", a, c)
    }
	
	fboRender.uniforms = gl.get_uniforms_from_program(fboRender.program)
	gl.UseProgram(fboRender.program)
	
	gl.Uniform1i(fboRender.uniforms["screenTexture"].location, 0)
	gl.Uniform1i(fboRender.uniforms["depthTexture"].location, 1)
	gl.Uniform1f(fboRender.uniforms["viewWidth"].location, f32(screenWidth))
	gl.Uniform1f(fboRender.uniforms["viewHeight"].location, f32(screenHeight))
	inv := math.inverse(playerCamera.proj)
	gl.UniformMatrix4fv(fboRender.uniforms["projectionInverse"].location, 1, false, &inv[0, 0])
}

toFront := false
toBehind := false
toRight := false
toLeft := false

yaw: f32 = -90.0;
pitch: f32 = 0.0;

lastChunkX := playerCamera.chunk.x
lastChunkY := playerCamera.chunk.y
lastChunkZ := playerCamera.chunk.z

reloadChunks :: proc() {
	if allChunks != nil {delete(allChunks)}
	if chunks != nil {delete(chunks)}
	tmp := world.peak(playerCamera.chunk.x, playerCamera.chunk.y, playerCamera.chunk.z, playerCamera.viewDistance)
	defer delete(tmp)
	allChunks = worldRender.setupManyChunks(tmp)
	chunks = worldRender.frustumCulling(allChunks, &playerCamera)
}

loop :: proc"c"(core: ^skeewb.core_interface) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(tracking_allocator)
	
	duration := time.tick_since(start_tick)
	t := f32(time.duration_seconds(duration))

	event: sdl2.Event
		
	for sdl2.PollEvent(&event) {
		if event.type == .QUIT || event.type == .WINDOWEVENT && event.window.event == .CLOSE {
			quit(core)
			core.quit(0)
		} else if event.type == .KEYUP {
			#partial switch (event.key.keysym.sym) {
				case .ESCAPE:
					quit(core)
					core.quit(0)
				case .W:
					toFront = false
				case .S:
					toBehind = false
				case .A:
					toLeft = false
				case .D:
					toRight = false
			}
		} else if event.type == .KEYDOWN {
			#partial switch (event.key.keysym.sym) {
				case .ESCAPE:
					quit(core)
					core.quit(0)
				case .W:
					toFront = true
				case .S:
					toBehind = true
				case .A:
					toLeft = true
				case .D:
					toRight = true
			}
		} else if event.type == .MOUSEMOTION {
			xpos :=  f32(event.motion.xrel)
			ypos := -f32(event.motion.yrel)
		
			sensitivity: f32 = 0.25
			xoffset := xpos * sensitivity
			yoffset := ypos * sensitivity
		
			yaw += xoffset
			pitch += yoffset

			if pitch >= 89 {
				pitch = 89
			}
			if pitch <= -89 {
				pitch = -89
			}

			yawRadians := yaw * math.RAD_PER_DEG
			pitchRadians := pitch * math.RAD_PER_DEG
		
			playerCamera.front = {
				math.cos(yawRadians) * math.cos(pitchRadians),
				math.sin(pitchRadians),
				math.sin(yawRadians) * math.cos(pitchRadians)
			}
			playerCamera.front = math.vector_normalize(playerCamera.front)
			
			playerCamera.up = {
				-math.sin(pitchRadians) * math.cos(yawRadians),
				 math.cos(pitchRadians),
				-math.sin(pitchRadians) * math.sin(yawRadians)
			}
			playerCamera.up = math.vector_normalize(playerCamera.up)

			playerCamera.right = math.cross(playerCamera.front, playerCamera.up)
			
			gl.UseProgram(blockRender.program)
			worldRender.cameraMove(&playerCamera, blockRender)
			if chunks != nil {delete(chunks)}
			chunks = worldRender.frustumCulling(allChunks, &playerCamera)

			gl.UseProgram(fboRender.program)
			gl.UniformMatrix4fv(fboRender.uniforms["view"].location, 1, false, &playerCamera.view[0, 0])
		} else if event.type == .MOUSEBUTTONDOWN {
			if event.button.button == 1 {
				chunksToDelete, pos, ok := world.destroy(playerCamera.pos, playerCamera.front)
				defer delete(chunksToDelete)
				if ok {
					worldRender.destroy(chunksToDelete)
					reloadChunks()
				}
			} else if event.button.button == 3 {
				chunksToDelete, pos, ok := world.place(playerCamera.pos, playerCamera.front)
				defer delete(chunksToDelete)
				if ok {
					worldRender.destroy(chunksToDelete)
					reloadChunks()
				}
			}
		}
	}

	cameraSpeed: f32 = 0.125
	scale: [3]f32 = {0, 0, 0}

	if toFront != toBehind {
		if toFront {
			scale += playerCamera.front
		} else {
			scale -= playerCamera.front
		}
	}

	if toLeft != toRight {
		if toLeft {
			scale -= playerCamera.right
		} else {
			scale += playerCamera.right
		}
	}

	if scale.x != 0 || scale.y != 0 || scale.z != 0 {
		scale = math.vector_normalize(scale) * cameraSpeed
		playerCamera.pos += scale;
		if chunks != nil {delete(chunks)}
		chunks = worldRender.frustumCulling(allChunks, &playerCamera)
	}
	
	chunkX := i32(math.floor(playerCamera.pos.x / 32))
	chunkY := i32(math.floor(playerCamera.pos.y / 32))
	chunkZ := i32(math.floor(playerCamera.pos.z / 32))
	moved := false

	if chunkX != lastChunkX {
		playerCamera.chunk.x = chunkX
		lastChunkX = chunkX
		moved = true
	}
	if chunkY != lastChunkY {
		playerCamera.chunk.y = chunkY
		lastChunkY = chunkY
		moved = true
	}
	if chunkZ != lastChunkZ {
		playerCamera.chunk.z = chunkZ
		lastChunkZ = chunkZ
		moved = true
	}

	gl.UseProgram(blockRender.program)
	if moved {reloadChunks()}

	gl.BindFramebuffer(gl.FRAMEBUFFER, fboRender.id)
	gl.Enable(gl.DEPTH_TEST)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

	worldRender.drawChunks(chunks, playerCamera, blockRender)
	
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
	gl.Disable(gl.DEPTH_TEST)
	//gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(fboRender.program)
	gl.BindVertexArray(fboRender.vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, fboRender.texture)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D, fboRender.depth)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	sdl2.GL_SwapWindow(window)
}

quit :: proc"c"(core: ^skeewb.core_interface){
	context = runtime.default_context()
	prev_allocator := context.allocator
	context.allocator = mem.tracking_allocator(tracking_allocator)

	defer free(tracking_allocator)
	defer context.allocator = prev_allocator
	defer mem.tracking_allocator_destroy(tracking_allocator)
	
	worldRender.nuke()
	world.nuke()

	for key, value in blockRender.uniforms {
		delete(value.name)
	}
	for key, value in fboRender.uniforms {
		delete(value.name)
	}
	delete(blockRender.uniforms)
	delete(fboRender.uniforms)
	gl.DeleteProgram(blockRender.program)
	gl.DeleteProgram(fboRender.program)
	gl.DeleteFramebuffers(1, &fboRender.id)
	for &chunk in chunks {
		gl.DeleteBuffers(1, &chunk.VBO)
		gl.DeleteBuffers(1, &chunk.EBO)
	}
	delete(allChunks)
	delete(chunks)
	
	sdl2.GL_DeleteContext(gl_context)
	sdl2.DestroyWindow(window)
	sdl2.Quit()
	
	temp := runtime.default_temp_allocator_temp_begin()
	defer runtime.default_temp_allocator_temp_end(temp)
	skeewb.console_log(.INFO, "printing leaks...")
	for _, leak in tracking_allocator.allocation_map {
		skeewb.console_log(.INFO, fmt.tprintf("%v leaked %m\n", leak.location, leak.size))
	}
	for bad_free in tracking_allocator.bad_free_array {
		skeewb.console_log(.INFO, fmt.tprintf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory))
	}
}
