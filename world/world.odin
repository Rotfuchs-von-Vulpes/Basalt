package world

import "../skeewb"
import "core:math/noise"
import "core:math"

Primer :: [32 * 32 * 32]u32

iVec3 :: struct {
    x, y, z: i32
}

Chunk :: struct {
    x: i32,
    z: i32,
    primer: Primer,
}

chunks := [dynamic]Chunk{{0, 0, Primer{0..<(32 * 32 * 32) = 1}}}
chunkMap := make(map[iVec3]u64)

getNoised :: proc(a, b: i32, c, d: int) -> int {
    posX := f64(a)
    posZ := f64(b)
    x := f64(c)
    z := f64(d)
    return int(math.floor(32 * (0.5 * noise.noise_2d(0, {posX + x / 32, posZ + z / 32}) + 0.5)))
}

getNewChunk :: proc(x: i32, z: i32) -> Chunk {
    primer := Primer{0..<(32 * 32 * 32) = 0}

    for i in 0..<32 {
        for j in 0..<32 {
            height := getNoised(x, z, i, j)
            for k in 0..<height {
                primer[i * 32 * 32 + j * 32 + k] = 1
            }
        }
    }

    chunk := Chunk{x, z, primer}
    chunkMap[{x, 0, z}] = u64(len(chunks))

    append(&chunks, chunk)

    return chunk
}

peak :: proc(x: i32, z: i32, radius: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}

    for i := -radius; i <= radius; i += 1 {
        for j := -radius; j <= radius; j += 1 {
            append(&chunksToView, getNewChunk(x + i, z + j))
        }
    }

    return chunksToView
}

nuke :: proc() {
    delete(chunks)
    delete(chunkMap)
}
