--[[
    LyxGuard - SHA-256 + HMAC-SHA256 (Lua puro)

    License: MIT

    FiveM no expone crypto nativo desde Lua. Este modulo implementa SHA-256 y
    HMAC-SHA256 usando los operadores de bits nativos de Lua 5.4 (el manifest ya
    declara `lua54 'yes'`). Los payloads del anticheat son pequenos, asi que el
    costo es despreciable.

    API global:
      LyxSHA2.sha256(message)            -> hex string (64 chars)
      LyxSHA2.hmac_sha256(key, message)  -> hex string (64 chars)

    Ambos aceptan strings. `key` puede ser cualquier string (se ajusta al blocksize).
]]

LyxSHA2 = LyxSHA2 or {}

-- 32-bit helpers ---------------------------------------------------------------

local MASK32 = 0xFFFFFFFF

local function band(a, b) return (a & b) & MASK32 end
local function bxor(a, b) return (a ~ b) & MASK32 end
local function bnot(a) return (~a) & MASK32 end

local function rrotate(x, n)
    x = x & MASK32
    return ((x >> n) | (x << (32 - n))) & MASK32
end

local function shr(x, n)
    return (x & MASK32) >> n
end

-- SHA-256 constants ------------------------------------------------------------

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

-- Core transform ---------------------------------------------------------------

local function preprocess(message)
    local len = #message
    local bitLen = len * 8

    -- Append 0x80, then zeros until length ≡ 56 (mod 64), then 64-bit big-endian length.
    message = message .. string.char(0x80)
    while (#message % 64) ~= 56 do
        message = message .. string.char(0)
    end

    -- 64-bit length (big-endian). We only support < 2^32 bytes (plenty for events).
    for i = 7, 0, -1 do
        message = message .. string.char((bitLen >> (i * 8)) & 0xFF)
    end

    return message
end

function LyxSHA2.sha256(message)
    if type(message) ~= 'string' then
        message = tostring(message)
    end

    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    message = preprocess(message)

    local w = {}

    for chunkStart = 1, #message, 64 do
        -- Load 16 big-endian words.
        for i = 0, 15 do
            local j = chunkStart + i * 4
            local b1, b2, b3, b4 = message:byte(j, j + 3)
            w[i + 1] = ((b1 << 24) | (b2 << 16) | (b3 << 8) | b4) & MASK32
        end

        -- Extend to 64 words.
        for i = 17, 64 do
            local s0v = bxor(bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18)), shr(w[i - 15], 3))
            local s1v = bxor(bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19)), shr(w[i - 2], 10))
            w[i] = (w[i - 16] + s0v + w[i - 7] + s1v) & MASK32
        end

        local a, b, c, d = h0, h1, h2, h3
        local e, f, g, h = h4, h5, h6, h7

        for i = 1, 64 do
            local S1 = bxor(bxor(rrotate(e, 6), rrotate(e, 11)), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = (h + S1 + ch + K[i] + w[i]) & MASK32
            local S0 = bxor(bxor(rrotate(a, 2), rrotate(a, 13)), rrotate(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local temp2 = (S0 + maj) & MASK32

            h = g
            g = f
            f = e
            e = (d + temp1) & MASK32
            d = c
            c = b
            b = a
            a = (temp1 + temp2) & MASK32
        end

        h0 = (h0 + a) & MASK32
        h1 = (h1 + b) & MASK32
        h2 = (h2 + c) & MASK32
        h3 = (h3 + d) & MASK32
        h4 = (h4 + e) & MASK32
        h5 = (h5 + f) & MASK32
        h6 = (h6 + g) & MASK32
        h7 = (h7 + h) & MASK32
    end

    return string.format('%08x%08x%08x%08x%08x%08x%08x%08x',
        h0, h1, h2, h3, h4, h5, h6, h7)
end

-- Convert a hex string (from sha256) to raw bytes.
local function hexToBytes(hex)
    return (hex:gsub('%x%x', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- HMAC-SHA256 ------------------------------------------------------------------

local BLOCK_SIZE = 64

function LyxSHA2.hmac_sha256(key, message)
    if type(key) ~= 'string' then key = tostring(key) end
    if type(message) ~= 'string' then message = tostring(message) end

    -- Keys longer than the block size are hashed down first.
    if #key > BLOCK_SIZE then
        key = hexToBytes(LyxSHA2.sha256(key))
    end

    -- Pad key to block size.
    if #key < BLOCK_SIZE then
        key = key .. string.rep('\0', BLOCK_SIZE - #key)
    end

    local oParts = {}
    local iParts = {}
    for i = 1, BLOCK_SIZE do
        local kb = key:byte(i)
        oParts[i] = string.char(kb ~ 0x5c)
        iParts[i] = string.char(kb ~ 0x36)
    end

    local oKeyPad = table.concat(oParts)
    local iKeyPad = table.concat(iParts)

    local inner = hexToBytes(LyxSHA2.sha256(iKeyPad .. message))
    return LyxSHA2.sha256(oKeyPad .. inner)
end

return LyxSHA2
