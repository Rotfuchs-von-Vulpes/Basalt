package world

import "../skeewb"
import "core:math"
import "core:math/rand"
import "core:fmt"
import "../util"
import "terrain"

Primer :: [32][32][32]u32

iVec2 :: [2]i32
iVec3 :: [3]i32
vec3 :: [3]f32

Direction :: enum {Up, Bottom, North, South, East, West}
FaceSet :: bit_set[Direction]

Chunk :: struct {
    id: int,
    pos: iVec3,
    sides: [Direction]int,
    primer: Primer,
    opened: FaceSet,
    level: int
}

allOpened: FaceSet = {.Bottom, .East, .North, .South, .Up, .West}

allChunks := [dynamic]Chunk{}
chunkMap := make(map[iVec3]int)
nodeMap := make(map[iVec3]int)
blocked := make(map[iVec3]bool)
populated := make(map[iVec3]bool)

getNewChunk :: proc(id: int, x, y, z: i32) -> Chunk {
    primer := new(Primer)
    defer free(primer)

    open: FaceSet = {}

    sides: [Direction]int = {
        .Up = -1,
        .Bottom = -1,
        .North = -1,
        .South = -1,
        .East = -1,
        .West = -1
    }

    return Chunk{id, {x, y, z}, sides, primer^, open, 0}
}

setBlocksChunk :: proc(chunk: ^Chunk, heightMap: terrain.HeightMap) {
    for i in 0..<32 {
        for j in 0..<32 {
            height := int(heightMap[i][j])
            localHeight := height - int(chunk.pos.y) * 32
            for k in 0..<32 {
                if k >= localHeight {
                    if k == 0 {
                        chunk.opened += {.Bottom}
                    } else if k == 31 {
                        chunk.opened += {.Up}
                    }
                    if i == 0 {
                        chunk.opened += {.West}
                    } else if i == 31 {
                        chunk.opened += {.East}
                    } else if j == 0 {
                        chunk.opened += {.South}
                    } else if j == 31 {
                        chunk.opened += {.North}
                    }
                    break
                }
                if height > 15 {
                    if localHeight - k == 1 {
                        chunk.primer[i][k][j] = 3
                    } else if localHeight - k < 4 {
                        chunk.primer[i][k][j] = 2
                    } else {
                        chunk.primer[i][k][j] = 1
                    }
                } else {
                    if localHeight - k == 1 {
                        chunk.primer[i][k][j] = 4
                    } else {
                        chunk.primer[i][k][j] = 1
                    }
                }
            }
        }
    }

    chunk.level = 1
}

setBlock :: proc(x, y, z: i32, id: u32, c: ^Chunk, chunks: ^[dynamic]int) {
    x := x; y := y; z := z; c := c

    for x >= 32 {
        x -= 32
        side := c.sides[.East]
        if side == -1 {
            side = eval(c.pos.x + 1, c.pos.y, c.pos.z)
            c.sides[.East] = side
        }
        if .East not_in c.opened {
            append(chunks, side)
            c.opened += {.East}
        }
        c = &allChunks[side]
    }
    for x < 0 {
        x += 32
        side := c.sides[.West]
        if side == -1 {
            side = eval(c.pos.x - 1, c.pos.y, c.pos.z)
            c.sides[.West] = side
        }
        if .West not_in c.opened {
            append(chunks, side)
            c.opened += {.West}
        }
        c = &allChunks[side]
    }
    for y >= 32 {
        y -= 32
        side := c.sides[.Up]
        if side == -1 {
            side = eval(c.pos.x, c.pos.y + 1, c.pos.z)
            c.sides[.Up] = side
            //skeewb.console_log(.INFO, "ah, %s", .Up in c.opened ? "true" : "false")
        }
        if .Up not_in c.opened {
            append(chunks, side)
            c.opened += {.Up}
        }
        c = &allChunks[side]
    }
    for y < 0 {
        y += 32
        side := c.sides[.Bottom]
        if side == -1 {
            side = eval(c.pos.x, c.pos.y - 1, c.pos.z)
            c.sides[.Bottom] = side
        }
        if .Bottom not_in c.opened {
            append(chunks, side)
            c.opened += {.Bottom}
        }
        c = &allChunks[side]
    }
    for z >= 32 {
        z -= 32
        side := c.sides[.North]
        if side == -1 {
            side = eval(c.pos.x, c.pos.y, c.pos.z + 1)
            c.sides[.North] = side
        }
        if .North not_in c.opened {
            append(chunks, side)
            c.opened += {.North}
        }
        c = &allChunks[side]
    }
    for z < 0 {
        z += 32
        side := c.sides[.South]
        if side == -1 {
            side = eval(c.pos.x, c.pos.y, c.pos.z - 1)
            c.sides[.South] = side
        }
        if .South not_in c.opened {
            append(chunks, side)
            c.opened += {.South}
        }
        c = &allChunks[side]
    }

    c.primer[x][y][z] = id
}

placeTree :: proc(x, y, z: i32, c: ^Chunk, chunks: ^[dynamic]int) {
    setBlock(x, y, z, 2, c, chunks)

    for i := y + 1; i <= y + 5; i += 1 {
        setBlock(x, i, z, 6, c, chunks)
    }

    for i: i32 = x - 2; i <= x + 2; i += 1 {
        for j: i32 = z - 2; j <= z + 2; j += 1 {
            for k: i32 = y + 3; k <= y + 4; k += 1 {
                xx := i == x - 2 || i == x + 2
                zz := j == z - 2 || j == z + 2

                if xx && zz || i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks);
            }
        }
    }
    
    for i: i32 = x - 1; i <= x + 1; i += 1 {
        for j: i32 = z - 1; j <= z + 1; j += 1 {
            for k: i32 = y + 5; k <= y + 6; k += 1 {
                xx := i == x - 1 || i == x + 1
                zz := j == z - 1 || j == z + 1

                if xx && zz || k == y + 5 && i == x && j == z {continue}

                setBlock(i, k, j, 7, c, chunks);
            }
        }
    }
}

populate :: proc(popChunks: ^[dynamic]int, chunks: ^[dynamic]int) {
    for idx, i in popChunks {
        c := &allChunks[idx]

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
                placeTree(i32(x0), i32(y0), i32(z0), c, chunks)
            }
        }

        c.level = 2
    }
}

eval :: proc(x, y, z: i32) -> int {
    pos := iVec3{x, y, z}
    idx, ok, _ := util.map_force_get(&chunkMap, pos)
    chunk := new(Chunk)
    defer free(chunk)
    if ok {
        //terrain := terrain.getHeightMap(x, z)
        idx^ = len(allChunks)
        chunk^ = getNewChunk(idx^, x, y, z)
        setBlocksChunk(chunk, terrain.getHeightMap(x, z))
        append(&allChunks, chunk^)
    }
    return idx^
}

length :: proc(v: iVec3) -> i32 {
    return i32((v.x * v.x + v.y * v.y + v.z * v.z))
}

VIEW_DISTANCE :: 6

addWorm :: proc(pos, center: iVec3, history: ^map[iVec3]bool) -> bool {
    if abs(pos.x - center.x) > VIEW_DISTANCE + 2 || abs(pos.y - center.y) > VIEW_DISTANCE + 2 || abs(pos.z - center.z) > VIEW_DISTANCE + 2 {return false}

    if pos in history {return false}

    //skeewb.console_log(.INFO, "added: %d, %d, %d", pos.x, pos.y, pos.z)

    history[pos] = true

    return true
}

peak :: proc(x, y, z: i32) -> [dynamic]Chunk {
    chunksToView := [dynamic]Chunk{}
    //chunks := [dynamic]Chunk{}
    //defer delete(chunks)
    chunksToSide := [dynamic]int{}
    defer delete(chunksToSide)
    chunksToPopulate := [dynamic]int{}
    defer delete(chunksToPopulate)
    r: i32 = VIEW_DISTANCE + 2
    rr: i32 = VIEW_DISTANCE + 1

    worms: [dynamic]iVec3 = {{x, y, z}}
    defer delete(worms)
    history := make(map[iVec3]bool)
    defer delete(history)
    history[worms[0]] = true

    for i := 0; i < len(worms); i += 1 {
        worm := worms[i]
        idx := eval(worm.x, worm.y, worm.z)
        append(&chunksToSide, idx)
        c := &allChunks[idx]
        // if c.level == 0 {setBlocksChunk(c, terrain.getHeightMap(worm.x, worm.z))}
        if c.level == 1 && abs(worm.x - x) < VIEW_DISTANCE + 1 && abs(worm.y - y) < VIEW_DISTANCE + 1 && abs(worm.z - z) < VIEW_DISTANCE + 1 {append(&chunksToPopulate, idx)}

        if .West in c.opened && addWorm(worm + {-1, 0, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x - 1, worm.y, worm.z})
        }
        if .East in c.opened && addWorm(worm + { 1, 0, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x + 1, worm.y, worm.z})
        }
        if .Bottom in c.opened && addWorm(worm + { 0,-1, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y - 1, worm.z})
        }
        if .Up in c.opened && addWorm(worm + { 0, 1, 0}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y + 1, worm.z})
        }
        if .South in c.opened && addWorm(worm + { 0, 0,-1}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y, worm.z - 1})
        }
        if .North in c.opened && addWorm(worm + { 0, 0, 1}, {x, y, z}, &history) {
            append(&worms, iVec3{worm.x, worm.y, worm.z + 1})
        }
    }

    populate(&chunksToPopulate, &chunksToSide)

    for idx in chunksToSide {
        chunk := allChunks[idx]
        dist := chunk.pos - iVec3{x, y, z}
        if abs(dist.x) < VIEW_DISTANCE && abs(dist.y) < VIEW_DISTANCE && abs(dist.z) < VIEW_DISTANCE {append(&chunksToView, chunk)}
    }

    return chunksToView
}

getPosition :: proc(pos: iVec3) -> (int, iVec3) {
    chunkPos := iVec3{
        i32(math.floor(f32(pos.x) / 32)),
        i32(math.floor(f32(pos.y) / 32)),
        i32(math.floor(f32(pos.z) / 32))
    }

    idx := eval(chunkPos.x, chunkPos.y, chunkPos.z)

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
                idx := eval(chunkPos.x, chunkPos.y, chunkPos.z)

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
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 31 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
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
    if pos.x == 0 {
        chunk.opened += {.West}
    } else if pos.x == 31 {
        chunk.opened += {.East}
    }
    if pos.y == 0 {
        chunk.opened += {.Bottom}
    } else if pos.y == 31 {
        chunk.opened += {.Up}
    }
    if pos.z == 0 {
        chunk.opened += {.South}
    } else if pos.z == 31 {
        chunk.opened += {.North}
    }
    
    chunks = atualizeChunks(chunk, pos)

    return chunks, pos, true
}

nuke :: proc() {
    delete(chunkMap)
    delete(allChunks)
}
