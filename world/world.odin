package world

import "../skeewb"
import "core:math/noise"
import "core:math"

Primer :: [32 * 32 * 32]u32

iVec3 :: [3]i32

Chunk :: struct {
    x: i32,
    z: i32,
    primer: Primer,
}

chunkMap := make(map[iVec3]Chunk)

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
    chunkMap[{x, 0, z}] = chunk

    return chunk
}

eval :: proc(x: i32, z: i32) -> Chunk {
    pos := iVec3{x, 0, z}
    chunk, ok := chunkMap[pos]
    if !ok {
        chunk = getNewChunk(x, z)
    }
    return chunk
}

peak :: proc(x: i32, z: i32, radius: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}
    radiusP := radius + 1

    for i := -radiusP; i <= radiusP; i += 1 {
        for j := -radiusP; j <= radiusP; j += 1 {
            chunk := eval(x + i, z + j);
            if (i != -radiusP && i != radiusP) && (j != -radiusP && j != radiusP) {append(&chunksToView, chunk)}
        }
    }

    return chunksToView
}

nuke :: proc() {
    delete(chunkMap)
}
