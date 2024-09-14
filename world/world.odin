package world

import "../skeewb"
import "core:math/noise"
import "core:math"
import "core:fmt"
import "../util"

Primer :: [32][32][32]u32
HeightMap :: [32][32]i32

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

Chunk :: struct {
    pos: iVec3,
    primer: Primer,
}

chunkMap := make(map[iVec3]Chunk)
terrainMap := make(map[iVec3]HeightMap)
heightSlice := make(map[iVec2][2]int)

// getNoised :: proc(a, b: i32, c, d: int) -> int {
//     posX := f64(a)
//     posZ := f64(b)
//     x := f64(c)
//     z := f64(d)
//     return int(math.floor(32 * (0.5 * noise.noise_2d(0, {posX + x / 32, posZ + z / 32}) + 0.5)))
// }

Noise :: struct {
    seed: i64,
    octaves: int,
    lacunarity: f64,
    persistence: f32,
    scale: f64,
}

pow :: proc(n: f32, exp: int) -> f32 {
    tmp := n
    for i in 1..<exp {tmp *= n}
    return tmp
}

seed: i64 = 1;
continentalness := Noise{seed, 8, 2.25, 0.5, 0.01}
erosion := Noise{seed + 1, 4, 2, 0.375, 0.25}
peaksAndValleys := Noise{seed + 2, 12, 2, 0.75, 0.375}

peake :: proc(n: f32) -> f32 {
    return n * n * 0.25
}

erode :: proc(n: f32) -> f32 {
    return math.clamp(n, 0, 1)
}

mix :: proc(continent, eroding, peaking: f32) -> f32 {
    return continent < 0.5 ? continent : continent + erode(eroding) * peake(peaking);
}

getNoised :: proc(n: Noise, x, z: f64) -> f32 {
    noised: f32 = 0

    for i in 0..<n.octaves {
        noised += pow(n.persistence, i) * noise.noise_2d(n.seed + i64(i), {n.lacunarity * n.scale * x, n.lacunarity * n.scale * z})
    }

    return 0.5 * noised + 0.5
}

getTerrain :: proc(x, z: i32, i, j: int) -> i32 {
    posX := f64(x) + f64(i) / 32
    posZ := f64(z) + f64(j) / 32
    continent := getNoised(continentalness, posX, posZ)
    eroding := getNoised(erosion, posX, posZ)
    peaking := getNoised(peaksAndValleys, posX, posZ)
    earlyTerrain := mix(continent, eroding, peaking)

    return i32(31 * earlyTerrain)
}

getNewChunk :: proc(x, y, z: i32, heightMap: HeightMap) -> Chunk {
    primer := Primer{0..<32 = {0..<32 = {0..<32 = 0}}}
    
    for i in 0..<32 {
        for j in 0..<32 {
            height := int(heightMap[i][j])
            for k in 0..<height {
                if height > 15 {
                    if height - k == 1 {
                        primer[i][k][j] = 3
                    } else if height - k < 4 {
                        primer[i][k][j] = 2
                    } else {
                        primer[i][k][j] = 1
                    }
                } else {
                    if height - k == 1 {
                        primer[i][k][j] = 4
                    } else {
                        primer[i][k][j] = 1
                    }
                }
            }
        }
    }

    return Chunk{{x, y, z}, primer}
}

chopp :: proc(heightMap: HeightMap) -> ([dynamic]HeightMap, int) {
    heightsMaps: [dynamic]HeightMap = {HeightMap{}}
    init := 0

    for i in 0..<32 {
        for j in 0..<32 {
            tmp := heightMap[i][j]
            if tmp > 31 {
                idx := init
                for tmp > 31 {
                    if len(heightsMaps) == idx + init + 1 {append(&heightsMaps, HeightMap{})}
                    heightsMaps[idx][i][j] = 32
                    tmp = tmp - 32
                    idx += 1
                }
                heightsMaps[idx][i][j] = tmp
            } else if tmp < 0 {
                idx := 0
                for tmp < 0 {
                    init += 1
                    if len(heightsMaps) == idx + init + 1 {inject_at(&heightsMaps, 0, HeightMap{})}
                    heightsMaps[0][i][j] = 0
                    tmp = tmp + 32
                    idx += 1
                }
                heightsMaps[idx][i][j] = tmp
            } else {
                heightsMaps[0][i][j] = tmp
            }
        }
    }

    return heightsMaps, -init
}

createTerrain :: proc(x, z: i32) -> ([dynamic]HeightMap, int) {
    height: HeightMap

    for i in 0..<32 {
        for j in 0..<32 {
            height[i][j] = getTerrain(x, z, i, j)
        }
    }

    heights, init := chopp(height)
    heightSlice[{x, z}] = {init, len(heights) - 1}

    return heights, init
}

getHeightMap :: proc(x, z: i32) -> ([dynamic]HeightMap, int) {
    height: HeightMap

    for i in 0..<32 {
        for j in 0..<32 {
            height[i][j] = getTerrain(x, z, i, j)
        }
    }

    heights, init := chopp(height)
    heightSlice[{x, z}] = {init, len(heights) - 1}

    return heights, init
}

eval :: proc(x, y, z: i32) -> Chunk {
    pos := iVec3{x, y, z}
    chunk, ok, _ := util.map_force_get(&chunkMap, pos)
    if ok {
        terrains, init := getHeightMap(x, z)
        defer delete(terrains)
        if len(terrains) >= int(y) + init {
            chunk^ = getNewChunk(x, y, z, terrains[int(y) + init])
        } else if y > 0 {
            chunk^ = Chunk{{x, y, z}, Primer{0..<32 = {0..<32 = {0..<32 = 0}}}}
        } else {
            chunk^ = Chunk{{x, y, z}, Primer{0..<32 = {0..<32 = {0..<32 = 1}}}}
        }
    }
    return chunk^
}

peak :: proc(x, y, z: i32, radius: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}
    radiusP := radius + 1

    for i := -radiusP; i <= radiusP; i += 1 {
        for j := -radiusP; j <= radiusP; j += 1 {
            chunk := eval(x + i, 0, z + j)
            extremes := heightSlice[{i + x, j + z}]
            for k := extremes[0]; k <= extremes[1]; k += 1 {
                chunk = eval(x + i, i32(k), z + j)
                if (i != -radiusP && i != radiusP) && (j != -radiusP && j != radiusP) {append(&chunksToView, chunk)}
            }
        }
    }

    return chunksToView
}

getPosition :: proc(pos: iVec3) -> (^Chunk, iVec3, bool) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 32)),
        i32(math.floor(f32(pos.y) / 32)),
        i32(math.floor(f32(pos.z) / 32))
    }

    chunk, ok, _ := util.map_force_get(&chunkMap, chunkPos)

    iPos: iVec3
    iPos.x = pos.x %% 32
    iPos.y = pos.y %% 32
    iPos.z = pos.z %% 32

    if ok {
        if chunkPos.y < 1 {
            chunkP := Chunk{chunkPos, Primer{0..<32 = {0..<32 = {0..<32 = 1}}}}
            chunk^ = chunkP
            slice := &heightSlice[{chunkPos.x, chunkPos.z}]
            slice[0] = int(chunkPos.y)
        } else {
            chunkP := Chunk{chunkPos, Primer{0..<32 = {0..<32 = {0..<32 = 0}}}}
            chunk^ = chunkP
            slice := &heightSlice[{chunkPos.x, chunkPos.z}]
            slice[1] = int(chunkPos.y)
        }
        ok = true
    }

    return chunk, iPos, !ok
}

toiVec3 :: proc(vec: vec3) -> iVec3 {
    return iVec3{
        i32(math.floor(vec.x)),
        i32(math.floor(vec.y)),
        i32(math.floor(vec.z)),
    }
}

raycast :: proc(origin, direction: vec3, place: bool) -> (^Chunk, iVec3, bool) {
    fPos := origin
    pos, pPos, lastBlock: iVec3

    chunk, pChunk: ^Chunk
    ok: bool = true

    step: f32 = 0.05
    length: f32 = 0
    maxLength: f32 = 10
    for length < maxLength {
        iPos := toiVec3(fPos)

        if lastBlock != iPos {
            chunk, pos, ok = getPosition(iPos)
            if ok && chunk.primer[pos.x][pos.y][pos.z] != 0 {
                if place {
                    offset := iPos - lastBlock
                    if math.abs(offset.x) + math.abs(offset.y) + math.abs(offset.z) != 1 {
                        if offset.x != 0 {
                            chunk, pos, ok = getPosition({iPos.x + offset.x, iPos.y, iPos.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z] != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.y != 0 {
                            chunk, pos, ok = getPosition({iPos.x, iPos.y + offset.y, iPos.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z] != 0 {
                                return chunk, pos, true
                            }
                        }
                        if offset.z != 0 {
                            chunk, pos, ok = getPosition({iPos.x, iPos.y, iPos.z + offset.z})
                            if ok && chunk.primer[pos.x][pos.y][pos.z] != 0 {
                                return chunk, pos, true
                            }
                        }
                    } else {
                        return pChunk, pPos, true
                    }
                } else {
                    return chunk, pos, true
                }
            }

            lastBlock = iPos
        }

        pPos = pos
        pChunk = chunk
        fPos += step * direction
        length += step
    }

    return chunk, pos, false
}

atualizeChunks :: proc(chunk: ^Chunk, pos: iVec3) -> [dynamic]^Chunk {
    chunks: [dynamic]^Chunk

    offsetX: i32 = 0
    offsetY: i32 = 0
    offsetZ: i32 = 0

    if pos.x >= 16 {
        offsetX += 1
    } else {
        offsetX -= 1
    }

    if pos.y >= 16 {
        offsetY += 1
    } else {
        offsetY -= 1
    }

    if pos.z >= 16 {
        offsetZ += 1
    } else {
        offsetZ -= 1
    }

    for i in 0..=1 {
        for j in 0..=1 {
            for k in 0..=1 {
                chunkPos: iVec3 = {
                    chunk.pos.x + i32(i) * offsetX,
                    chunk.pos.y + i32(j) * offsetY,
                    chunk.pos.z + i32(k) * offsetZ
                }
                chunkCorner, ok, _ := util.map_force_get(&chunkMap, chunkPos)

                if ok {
                    if chunkPos.y < 1 {
                        chunkP := Chunk{chunkPos, Primer{0..<32 = {0..<32 = {0..<32 = 1}}}}
                        chunkCorner^ = chunkP
                        slice := &heightSlice[{chunkPos.x, chunkPos.z}]
                        slice[0] = int(chunkPos.y)
                    } else {
                        chunkP := Chunk{chunkPos, Primer{0..<32 = {0..<32 = {0..<32 = 0}}}}
                        chunkCorner^ = chunkP
                        slice := &heightSlice[{chunkPos.x, chunkPos.z}]
                        slice[1] = int(chunkPos.y)
                    }
                }

                append(&chunks, chunkCorner)
            }
        }
    }

    return chunks
}

destroy :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, false)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x][pos.y][pos.z] = 0

    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

place :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, true)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x][pos.y][pos.z] = 1
    
    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

nuke :: proc() {
    delete(chunkMap)
    delete(terrainMap)
}
