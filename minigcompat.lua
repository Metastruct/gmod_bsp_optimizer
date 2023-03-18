_G.unpack = table.unpack or unpack
file = io
local io = io

io.Open = function(a, b)
    return io.open(a, b)
end

local File = debug.getmetatable(io.stdin).__index

function File:Tell()
    return self:seek('cur', 0)
end

function File:Skip(n)
    return self:seek('cur', n)
end

function File:Seek(p)
    return self:seek('set', p)
end

function File:Read(n)
    return self:read(n or '*a')
end

function File:Write(d)
    return self:write(d)
end

function File:Size()
    local pos = self:Tell()
    local sz = self:seek('end')
    self:seek('set', pos)

    return sz
end

local tmp = {}

function File.ReadString(f, n, ch)
    n = n or 256
    ch = ch or '\0'
    local startpos = f:Tell()
    local offset = 0
    local tmpn = 0
    local sz = f:Size()

    --TODO: Use n and sz instead
    for i = 1, 1048576 do
        --	while true do
        if f:Tell() >= sz then return nil, 'eof' end
        local str = f:Read(n)
        --if not str then return nil,'eof','wtf' end
        local pos = str:find(ch, 1, true)

        if pos then
            --offset = offset + pos
            --reset position
            f:Seek(startpos + offset + pos)
            tmp[tmpn + 1] = str:sub(1, pos - 1)

            return table.concat(tmp, '', 1, tmpn + 1)
        else
            tmpn = tmpn + 1
            tmp[tmpn] = str
            offset = offset + n
        end
    end

    return nil, 'not found'
end

local vstruct = require'vstruct'

local function gen(name, fmt)
    fmt = vstruct.compile('val:' .. fmt)
    local t = {}

    local function ReadFunc(fd)
        local ret = fmt:read(fd, t)

        return ret.val
    end

    File['Read' .. name] = ReadFunc

    local function WriteFunc(fd, data)
        t.val = data
        return fmt:write(fd, t)
    end

    File['Write' .. name] = WriteFunc

    return FileFunc
end

gen('Float', 'f4')
gen('Double', 'f8')
gen('Bool', 'b1')
gen('Byte', 'u1')
gen('Long', 'i4')
gen('ULong', 'u4')
gen('Short', 'i2')
gen('UShort', 'u2')

local getmetatable = debug.getmetatable
local string_meta = getmetatable''

function isstring(s)
    return getmetatable(s) == string_meta
end

function isnumber(s)
    return type(s) == 'number'
end

function istable(s)
    return type(s) == 'table'
end

function Vector(x, y, z)
    return {x, y, z}
end

function Angle(p, y, r)
    return {p, y, r}
end