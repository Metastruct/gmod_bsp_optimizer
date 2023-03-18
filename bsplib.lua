local function ReadUChar(f, n)
    return string.byte(f:Read(n or 1), 1, n or 1)
end

local BSP = {}
BSP.__index = BSP

BSP.__tostring = function(self)
    return 'BSP:?.bsp'
end

local function unsigned(n, bits)
    if n < 0 then return math.abs(n) + 2 ^ (bits - 1) end

    return n
end

local _M = {}

function _M.open(fd)
    local self = setmetatable({}, BSP)
    self.fd = assert(fd)

    return self
end

local HEADER_LUMPS = 64

function BSP:GetHeader()
    local t = self.header
    if t then return t end
    t = {}
    self.header = t
    local f = self.fd
    --print(f:seek('cur',0),f:read(4),f:seek('cur',0),f:seek('set',0))
    local bspsize = f:Size()
    assert(f:Tell() == 0, f:Tell() == f:Tell(), 'not in beginning of file')
    local FOURCC = f:Read(4)
    --print('FOURCC @', f:Tell())
    assert(f:Tell() < 10, 'what coordinates are these where the hell is she taking him')
    if FOURCC ~= 'VBSP' then return nil, 'not bsp' end
    t.version = assert(f:ReadLong(), 'ReadLong is broken')
    if t.version ~= 20 and t.version ~= 21 and t.version ~= 19 then return nil, 'invalid version' end
    --print('BSP VER:',t.version)
    --print('TELL=',f:Tell(),f:Tell())
    t.lumps = {}

    for i = 1, HEADER_LUMPS do
        local info = {
            fileofs = f:ReadLong(),
            filelen = f:ReadLong(),
            version = f:ReadLong(),
            fourCC = f:Read(4),
        }

        if info.fourCC == '\0\0\0\0' then
            info.fourCC = nil
        end

        t.lumps[i - 1] = info
        --print(require'inspect'{i,f:Tell(),info})
        assert(info.fileofs <= bspsize, 'invalid header lump offset')
        assert(info.fileofs >= 0, 'invalid offset in header')
        assert(info.filelen <= bspsize, 'invalid header lump len')
        assert(info.filelen >= 0, 'invalid filelen in header')
    end

    t.mapRevision = f:ReadLong()

    return t
end

function BSP:GetGameLumps()
    local t = self.gamelumps

    if t then
        return t
    else
        t = {}
        self.gamelumps = t
    end

    local f = self.fd
    local bspsize = f:Size()
    local lump = self:GetHeader().lumps[35]
    assert(lump)
    f:Seek(lump.fileofs)
    assert(f:Tell() <= (lump.fileofs + lump.filelen))
    t.lumpCount = f:ReadLong()
    --print('gamelumps: ',t.lumpCount)
    assert(t.lumpCount > 0 and t.lumpCount < 1000)

    for i = 1, t.lumpCount do
        local info = {
            id = f:Read(4),
            flags = f:ReadShort(),
            version = f:ReadShort(),
            fileofs = f:ReadLong(),
            filelen = f:ReadLong(),
        }

        t[i] = info
        --print(require'inspect'{t[i].fileofs,t[i].filelen})
        local endpos = info.fileofs + info.filelen
        assert(info.fileofs <= bspsize, 'invalid header lump offset')
        assert(info.fileofs >= 0, 'invalid offset in header')
        assert(info.filelen <= bspsize, 'invalid header lump len')
        assert(info.filelen >= 0, 'invalid filelen in header')
        assert((info.fileofs + info.filelen) < bspsize, 'end offset OOB')
    end
    --print('tell=',f:Tell(),'(lump.fileofs+lump.filelen)=',(lump.fileofs+lump.filelen))

    return t
end

local sprp_stringtable = {}
local sprp_stringtable_inv = {}

for s in ('Skin PropType FirstLeaf MaxGPULevel MinGPULevel Flags MinCPULevel MaxCPULevel ' .. 'unknown LeafCount ForcedFadeScale FadeMaxDist DiffuseModulation Origin FadeMinDist ' .. 'Solid Angles LightingOrigin MinDXLevel MaxDXLevel DisableX360'):gmatch'[^% ]+' do
    local pos = #sprp_stringtable_inv + 1
    sprp_stringtable[s] = pos
    sprp_stringtable_inv[pos] = s
end

local function minify(t, t2)
    for k, v in next, t do
        local oldk = k
        k = sprp_stringtable[k]
        assert(k, oldk)
        t2[k] = v
    end
end

local function maxify(t, t2)
    for k, v in next, t do
        k = sprp_stringtable_inv[tonumber(k)]
        assert(k)
        t2[k] = v
    end
end

function BSP:GetStaticPropsDataOffset(name)
	error"WIP"
end

function BSP:GetStaticProps()
    local t = self.staticprops
    if t then return t end
    t = t or {}
    self.staticprops = t
    local f = self.fd
    local lumps = self:GetGameLumps()
    assert(lumps)
    local l

    for i = 1, lumps.lumpCount do
        local lump = lumps[i]

        if lump.id == 'prps' then
            l = lump
            break
        end
    end

    assert(l)
    local v = l.version
    assert(v >= 4 and v < 11, 'Version unsupported: ' .. v)
    f:Seek(l.fileofs)
    local dictEntries = f:ReadLong()
    assert(dictEntries >= 0 and dictEntries < 9999)
    t.names = {}

    for i = 1, dictEntries do
        t.names[i - 1] = f:Read(128):match'^[^%z]+' or ''
    end

    local leafEntries = f:ReadLong()
    assert(leafEntries >= 0)
    t.leaf = {}
    t.leafEntries = leafEntries

    for i = 1, leafEntries do
        t.leaf[i] = f:ReadShort(2) -- ushort
    end

    local staticprops = f:ReadLong()
    assert(staticprops >= 0 and staticprops < 8192 * 2)
    --print('staticprops',staticprops)
    t.entries = {}

    for i = 1, staticprops do
        local _ = {}
        t.entries[i] = _
        _.Origin = Vector(f:ReadFloat(), f:ReadFloat(), f:ReadFloat()) -- 	Vector		Origin
        _.Angles = Angle(f:ReadFloat(), f:ReadFloat(), f:ReadFloat()) --QAngle		Angles
        local PropType = f:ReadUShort() --  unsigned short	PropType;	 -- index into model name dictio
        _.PropType = assert(t.names[PropType])
        --print('PropType',PropType)
        assert(_.PropType, 'name not found for: ' .. PropType)
        _.FirstLeaf = f:ReadUShort() -- unsigned short	FirstLeaf;	 -- index into leaf array
        _.LeafCount = f:ReadUShort() --  unsigned short	LeafCount;
        _.Solid = f:ReadByte() -- unsigned char	Solid;
        _.Flags_Offset = f:Tell()
        _.Flags = f:ReadByte() -- unsigned char	Flags;
        _.Skin = f:ReadLong() -- int		Skin;
        assert(_.Skin)
        _.FadeMinDist_Offset = f:Tell()
        _.FadeMinDist = f:ReadFloat() --float		FadeMinDist;
        _.FadeMaxDist = f:ReadFloat() --float		FadeMaxDist;
        _.LightingOrigin = Vector(f:ReadFloat(), f:ReadFloat(), f:ReadFloat()) -- 	Vector		LightingOrigin;  -- for lighting

        if v >= 5 then
            _.ForcedFadeScale = f:ReadFloat() -- 	float		ForcedFadeScale; -- fade distance scale
        end

        if v == 6 or v == 7 then
            _.MinDXLevel = f:ReadShort() -- 	unsigned short  MinDXLevel;      -- minimum DirectX version to be visible
            _.MaxDXLevel = f:ReadShort() -- 	unsigned short  MaxDXLevel;      -- maximum DirectX version to be visible
        end

        if v >= 8 then
            _.MinCPULevel = ReadUChar(f) -- 	unsigned char   MinCPULevel;
            _.MaxCPULevel = ReadUChar(f) -- 	unsigned char   MaxCPULevel;
            _.MinGPULevel = ReadUChar(f) -- 	unsigned char   MinGPULevel;
            _.MaxGPULevel = ReadUChar(f) -- 	unsigned char   MaxGPULevel;
        end

        if v >= 7 then
            _.DiffuseModulation = Color(string.byte(f:Read(4), 1, 4)) --         color32         DiffuseModulation; -- per instance color and alpha modulation
        end

        if v >= 10 then
            _.unknown = f:ReadFloat() --         float           unknown;
        end

        -- appears to be removed in v10
        if v == 9 then
            _.DisableX360 = ReadUChar(f) == 1 --         bool            DisableX360;     -- if true, don't show on XBox 360
        end
    end

    return t
end

--PrintTable(game.OpenBSP():GetGameLumps())
--for k,v in next,game.OpenBSP():GetStaticProps().entries  do
--	print(v.PropType)
--
--	if k>3 then break end
--end
--
--
--for k,v in next,OpenBSP('maps/gm_construct_m_128.bsp'):GetStaticProps().entries  do
--	print(v.PropType)
--	if k>3 then break end
--end
return _M