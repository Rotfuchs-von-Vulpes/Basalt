package basalt

import "core:fmt"
import "core:strings"
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
import "frameBuffer"
import "util"
import "sky"

import "tracy"

screenWidth: i32 = 854
screenHeight: i32 = 480

playerCamera := util.Camera{
	{1, 33, 1}, 
	{0, 0, -1}, 
	{0, 1, 0}, 
	{1, 0, 0}, 
	{0, 0, 0}, 
	{2 * f32(screenWidth), 2 * f32(screenHeight)}, 
	math.MATRIX4F32_IDENTITY, math.MATRIX4F32_IDENTITY
}

chunks: [dynamic]worldRender.ChunkBuffer
allChunks: [dynamic]worldRender.ChunkBuffer

cameraSetup :: proc() {
	playerCamera.proj = math.matrix4_infinite_perspective_f32(45, playerCamera.viewPort.x / playerCamera.viewPort.y, 0.1)
}

cameraMove :: proc() {
	playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)
}

reloadChunks :: proc() {
	if allChunks != nil {delete(allChunks)}
	if chunks != nil {delete(chunks)}
	tmp := world.peak(playerCamera.chunk.x, playerCamera.chunk.y, playerCamera.chunk.z)
	defer delete(tmp)
	allChunks = worldRender.setupManyChunks(tmp)
	worldRender.frustumMove(&allChunks, &playerCamera)
	chunks = worldRender.frustumCulling(allChunks, &playerCamera)
}

main :: proc() {
	context = runtime.default_context()

	tracking_allocator := new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(tracking_allocator)
	
	start_tick := time.tick_now()

	sdl2.Init(sdl2.INIT_EVERYTHING)

	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))


	window := sdl2.CreateWindow("testando se muda alguma coisa", sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, screenWidth, screenHeight, sdl2.WINDOW_RESIZABLE | sdl2.WINDOW_OPENGL)
	if window == nil {
		skeewb.console_log(.ERROR, "could not create a window sdl error: %s", sdl2.GetError())
	}
	skeewb.console_log(.INFO, "successfully created a window")

	sdl2.SetRelativeMouseMode(true)

	gl_context := sdl2.GL_CreateContext(window);
	if gl_context == nil {
		skeewb.console_log(.ERROR, "could not create an OpenGL context sdl error: %s", sdl2.GetError())
	}
	skeewb.console_log(.INFO, "successfully created an OpenGL context")

	sdl2.GL_SetSwapInterval(1)

	gl.load_up_to(3, 3, sdl2.gl_set_proc_address)
	
	gl.Enable(gl.DEPTH_TEST)
	gl.Enable(gl.CULL_FACE)
	gl.CullFace(gl.BACK)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	blockRender := worldRender.Render{{}, 0, 0}
	fboRender := frameBuffer.Render{0, 0, 0, {}, 0, 0, 0}
	skyRender := sky.Render{0, 0, {}, 0, 0}
	sunRender := sky.Render{0, 0, {}, 0, 0}

	worldRender.setupDrawing(&blockRender)

	// tmp := world.peak(playerCamera.chunk.x, playerCamera.chunk.y, playerCamera.chunk.z, playerCamera.viewDistance)
	// defer delete(tmp)
	// allChunks = worldRender.setupManyChunks(tmp)

	gl.ClearColor(0.4666, 0.6588, 1.0, 1.0)

	playerCamera.proj = math.matrix4_infinite_perspective_f32(45, playerCamera.viewPort.x / playerCamera.viewPort.y, 0.1)
	playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)

	frameBuffer.setup(&playerCamera, &fboRender)

	sky.setup(&playerCamera, &skyRender)
	sky.setupSun(&playerCamera, &sunRender)

	worldRender.frustumMove(&allChunks, &playerCamera)
	chunks = worldRender.frustumCulling(allChunks, &playerCamera)

	lastTimeTicks := time.tick_now()
	nbFrames := 0
	fps := 0
	
	toFront := false
	toBehind := false
	toRight := false
	toLeft := false

	loop: for {
		tracy.FrameMark()
		duration := time.tick_since(start_tick)
		deltaTime := f32(time.duration_milliseconds(duration))

		event: sdl2.Event
			
		for sdl2.PollEvent(&event) {
			if event.type == .QUIT || event.type == .WINDOWEVENT && event.window.event == .CLOSE {
				break loop
			} else if event.type == .KEYUP {
				#partial switch (event.key.keysym.sym) {
					case .ESCAPE:
						break loop
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
						break loop
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
				
				playerCamera.view = math.matrix4_look_at_f32({0, 0, 0}, playerCamera.front, playerCamera.up)
				if chunks != nil {delete(chunks)}
				chunks = worldRender.frustumCulling(allChunks, &playerCamera)
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
			scale = math.vector_normalize(scale) * cameraSpeed * f32(time.duration_milliseconds(time.tick_since(last)))
			playerCamera.pos += scale;
			if chunks != nil {delete(chunks)}
			chunks = worldRender.frustumCulling(allChunks, &playerCamera)
		}
		last = time.tick_now()
		
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

		if moved {reloadChunks()}

		gl.UseProgram(fboRender.program)
		gl.BindFramebuffer(gl.FRAMEBUFFER, fboRender.id)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		gl.Viewport(0, 0, i32(playerCamera.viewPort.x), i32(playerCamera.viewPort.y))
		gl.UseProgram(skyRender.program)
		sky.draw(&playerCamera, skyRender, deltaTime)
		gl.UseProgram(sunRender.program)
		sky.drawSun(&playerCamera, sunRender, deltaTime)
		gl.Enable(gl.DEPTH_TEST)
		gl.UseProgram(blockRender.program)
		worldRender.drawChunks(chunks, &playerCamera, blockRender)
		
		gl.Viewport(0, 0, screenWidth, screenHeight)
		gl.UseProgram(fboRender.program)
		gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
		frameBuffer.draw(fboRender)

		sdl2.GL_SwapWindow(window)
		
		nbFrames += 1
		if time.duration_seconds(time.tick_since(lastTimeTicks)) >= 1.0 {
			fps = nbFrames
			nbFrames = 0
			lastTimeTicks = time.tick_now()
		}
		sdl2.SetWindowTitle(window, strings.unsafe_string_to_cstring(fmt.tprintfln("FPS: %d", fps)))
	}
	
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
	for key, value in skyRender.uniforms {
		delete(value.name)
	}
	for key, value in sunRender.uniforms {
		delete(value.name)
	}
	delete(blockRender.uniforms)
	delete(fboRender.uniforms)
	delete(skyRender.uniforms)
	delete(sunRender.uniforms)
	gl.DeleteProgram(blockRender.program)
	gl.DeleteProgram(fboRender.program)
	gl.DeleteProgram(skyRender.program)
	gl.DeleteProgram(sunRender.program)
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

yaw: f32 = -90.0;
pitch: f32 = 0.0;

lastChunkX := playerCamera.chunk.x
lastChunkY := playerCamera.chunk.y
lastChunkZ := playerCamera.chunk.z

last: time.Tick
cameraSpeed: f32 = 0.0125

// @(instrumentation_enter)
// tracy_enter :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
//     context = runtime.default_context()
// 	tracy.Zone(loc = loc)
// }

// @(instrumentation_exit)
// tracy_exit :: proc "contextless" (proc_address, call_site_return_address: rawptr, loc: runtime.Source_Code_Location) {
// 	//
// }
