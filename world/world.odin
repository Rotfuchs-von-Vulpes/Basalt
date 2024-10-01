package world

import "../skeewb"
import "core:math/noise"
import "core:math/rand"
import "core:math"
import "core:fmt"
import "../util"

Primer :: [32][32][32]u32
HeightMap :: [32][32]i32

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Chunk :: struct {
    id: int,
    pos: iVec3,
    primer: Primer,
    opened: FaceSet,
}

allOpened: FaceSet = {.Bottom, .East, .North, .South, .Up, .West}

allChunks := [dynamic]Chunk{}
chunkMap := make(map[iVec3]int)
populated := make(map[iVec3]bool)

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

flooding :: proc(n: f32) -> f32 {
    return n > 0.5 ? n : math.clamp(pow(2 * n, 9), 0.1, 0.5)
}

mix :: proc(continent, eroding, peaking: f32) -> f32 {
    return continent < 0.5 ? flooding(continent) : continent + erode(eroding) * peake(peaking);
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

getNewChunk :: proc(idx: int, x, y, z: i32, heightMap: HeightMap) -> Chunk {
    primer := new(Primer)
    defer free(primer)

    open: FaceSet = {}
    
    for i in 0..<32 {
        for j in 0..<32 {
            height := int(heightMap[i][j])
            localHeight := height - int(y) * 32
            for k in 0..<32 {
                if k >= localHeight {
                    if k == 0 {
                        open += {.Bottom}
                    } else if k == 31 {
                        open += {.Up}
                    } else {
                        if i == 0 {
                            open += {.West}
                        } else if i == 31 {
                            open += {.East}
                        } else if j == 0 {
                            open += {.South}
                        } else if j == 31 {
                            open += {.North}
                        }
                    }
                    break
                }
                if height > 15 {
                    if localHeight - k == 1 {
                        primer[i][k][j] = 3
                    } else if localHeight - k < 4 {
                        primer[i][k][j] = 2
                    } else {
                        primer[i][k][j] = 1
                    }
                } else {
                    if localHeight - k == 1 {
                        primer[i][k][j] = 4
                    } else {
                        primer[i][k][j] = 1
                    }
                }
            }
        }
    }

    return Chunk{idx, {x, y, z}, primer^, open}
}

setBlock :: proc(x, y, z: i32, id: u32, c: ^Chunk) {
    if x >= 32 || x < 0 || y >= 32 || y < 0 || z >= 32 || z < 0 {
        return
    } else {
        c.primer[x][y][z] = id
    }
}

placeTree :: proc(x, y, z: i32, c: ^Chunk) {
    setBlock(x, y, z, 2, c)

    for i := y + 1; i <= y + 5; i += 1 {
        setBlock(x, i, z, 6, c)
    }

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, 7, c);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, 7, c);
            }
        }
    }
}

populate :: proc(c: ^Chunk) {
    x := c.pos.x
    y := c.pos.y
    z := c.pos.z


    state := rand.create(u64(math.abs(x * 263781623 + y * 3647463 + z)))
    rnd := rand.default_random_generator(&state)
    n := int(math.floor(3 * rand.float32(rnd) + 3))

    for i in 0..<n {
        x0 := u32(math.floor(32 * rand.float32(rnd)))
        z0 := u32(math.floor(32 * rand.float32(rnd)))

        toPlace := false
        y0: u32 = 0
        for j in 0..<32 {
            y0 = u32(j)
            if c.primer[x0][j][z0] == 3 {
                toPlace = true
                break
            }
        }

        if toPlace {
            placeTree(i32(x0), i32(y0), i32(z0), c)
        }
    }
}

getHeightMap :: proc(x, z: i32) -> HeightMap {
    height: HeightMap

    for i in 0..<32 {
        for j in 0..<32 {
            height[i][j] = getTerrain(x, z, i, j)
        }
    }

    return height
}

eval :: proc(x, y, z: i32) -> (Chunk, int) {
    pos := iVec3{x, y, z}
    idx, ok, _ := util.map_force_get(&chunkMap, pos)
    chunk := new(Chunk)
    defer free(chunk)
    if ok {
        terrain := getHeightMap(x, z)
        idx^ = len(allChunks)
        chunk^ = getNewChunk(idx^, x, y, z, terrain)
        append(&allChunks, chunk^)
    }
    return allChunks[idx^], idx^
}

add :: proc(x, y, z: i32, toAdd: bool, chunks, chunksToView: ^[dynamic]Chunk) -> ^Chunk {
    _, idx := eval(x, y, z)
    chunk := &allChunks[idx]
    append(chunks, chunk^)
    if toAdd {
        append(chunksToView, chunk^)
    }

    return chunk
}

peak :: proc(x, y, z: i32, radius: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}
    chunks := [dynamic]Chunk{}
    defer delete(chunks)
    r := radius + 1

    for i := -r; i <= r; i += 1 {
        for j := -r; j <= r; j += 1 {
            toAdd := (i != -r && i != r) && (j != -r && j != r)
            pChunk := add(x + i, 0, z + j, toAdd, &chunks, &chunksToView)
            chunk := pChunk
            k := 1
            for (.Up in chunk.opened) {
                chunk = add(x + i, i32(k), z + j, toAdd, &chunks, &chunksToView)
                k += 1
            }
            chunk = pChunk
            k = -1
            for (.Bottom in chunk.opened) {
                chunk = add(x + i, i32(k), z + j, toAdd, &chunks, &chunksToView)
                k -= 1
            }
        }
    }

    for chunk in chunks {
        p := populated[chunk.pos]
        if p {continue}
        populate(&allChunks[chunk.id])
        populated[chunk.pos] = true
    }

    return chunksToView
}

getPosition :: proc(pos: iVec3) -> (int, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 32)),
        i32(math.floor(f32(pos.y) / 32)),
        i32(math.floor(f32(pos.z) / 32))
    }

    _, idx := eval(chunkPos.x, chunkPos.y, chunkPos.z)

    iPos: iVec3
    iPos.x = pos.x %% 32
    iPos.y = pos.y %% 32
    iPos.z = pos.z %% 32

    return idx, iPos
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

    idx: int
    pChunk: ^Chunk
    ok: bool = true

    step: f32 = 0.05
    length: f32 = 0
    maxLength: f32 = 10
    for length < maxLength {
        iPos := toiVec3(fPos)

        if lastBlock != iPos {
            idx, pos = getPosition(iPos)
            if ok && allChunks[idx].primer[pos.x][pos.y][pos.z] != 0 {
                if place {
                    offset := iPos - lastBlock
                    if math.abs(offset.x) + math.abs(offset.y) + math.abs(offset.z) != 1 {
                        if offset.x != 0 {
                            idx, pos = getPosition({iPos.x + offset.x, iPos.y, iPos.z})
                            if ok && allChunks[idx].primer[pos.x][pos.y][pos.z] != 0 {
                                return &allChunks[idx], pos, true
                            }
                        }
                        if offset.y != 0 {
                            idx, pos = getPosition({iPos.x, iPos.y + offset.y, iPos.z})
                            if ok && allChunks[idx].primer[pos.x][pos.y][pos.z] != 0 {
                                return &allChunks[idx], pos, true
                            }
                        }
                        if offset.z != 0 {
                            idx, pos = getPosition({iPos.x, iPos.y, iPos.z + offset.z})
                            if ok && allChunks[idx].primer[pos.x][pos.y][pos.z] != 0 {
                                return &allChunks[idx], pos, true
                            }
                        }
                    } else {
                        return pChunk, pPos, true
                    }
                } else {
                    return &allChunks[idx], pos, true
                }
            }

            lastBlock = iPos
        }

        pPos = pos
        pChunk = &allChunks[idx]
        fPos += step * direction
        length += step
    }

    return &allChunks[idx], pos, false
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
                _, idx := eval(chunkPos.x, chunkPos.y, chunkPos.z)

                append(&chunks, &allChunks[idx])
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
    if pos.x == 0 {
        chunk.opened += {.West}
    } else if pos.x == 31 {
        chunk.opened += {.East}
    } else if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 31 {
        chunk.opened += {.Up}
    } else if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 31 {
        chunk.opened += {.North}
    }

    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

place :: proc(origin, direction: vec3) -> ([dynamic]^Chunk, iVec3, bool) {
    chunks: [dynamic]^Chunk
    chunk, pos, ok := raycast(origin, direction, true)

    if !ok {return chunks, pos, false}
    chunk.primer[pos.x][pos.y][pos.z] = 5
    
    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

nuke :: proc() {
    delete(chunkMap)
    delete(allChunks)
}
