_G._GAME_SECRET = _G._GAME_SECRET or "12345678"
_G._LICENSE_OK = true
_G._BYPASS_LOADED = _G._BYPASS_LOADED or false
-- ==============================================================================
-- ============================ BẮT ĐẦU FULL LOGIC MOD ==========================
-- ==============================================================================

-- ==============================================================================
-- ==================== نظام الترخيص والأكواد (VIP License) =====================
-- ==============================================================================

local function _VIPLicense_Init()
    local licenseScope
    local VIPLicenseConfig = {
        game = 'BGMI',
        manualExpiry = nil,
        secret = 'Vm8Lk7Uj2JmsjCPVPVjrLa7zgfx3uz5E',
        validKeys = {
            "VIP-DEMO-0001",
            { key = "1V-KEY-VIP", expires = "2026-11-30 23:59:59" },
            { key = "2V-KEY-VIP2", expires = "2026-11-29 23:59:59" },
            -- أضف مفاتيحك هنا
        },
    }

    -- ============================================================================
    -- 1) VIPLicenseCore : خوارزمية MD5 + إدارة الجلسة + التحقق من الأكواد
    -- ============================================================================
    local VIPLicenseCore = (function()
        local Primitives = (function()
            local floor, abs, max = math.floor, math.abs, math.max
            local byte, char, format = string.byte, string.char, string.format
            local U32 = 4294967296
            local AND, XOR = {}, {}
            for a = 0, 15 do for b = 0, 15 do
                local av, bv, both, different, place = a, b, 0, 0, 1
                for _ = 1, 4 do
                    local x, y = av % 2, bv % 2
                    if x == 1 and y == 1 then both = both + place end
                    if x ~= y then different = different + place end
                    av, bv, place = floor(av / 2), floor(bv / 2), place * 2
                end
                AND[a * 16 + b], XOR[a * 16 + b] = both, different
            end end
            local function bitop(a, b, lookup)
                local value, place = 0, 1
                for _ = 1, 8 do
                    value = value + lookup[(a % 16) * 16 + b % 16] * place
                    a, b, place = floor(a / 16), floor(b / 16), place * 16
                end
                return value
            end
            local function band(a, b) return bitop(a, b, AND) end
            local function bxor(a, b) return bitop(a, b, XOR) end
            local function rol(value, amount)
                local divisor = 2 ^ (32 - amount)
                return (value % divisor) * 2 ^ amount + floor(value / divisor)
            end
            local function little32(value)
                return char(value % 256, floor(value / 256) % 256,
                    floor(value / 65536) % 256, floor(value / 16777216) % 256)
            end
            local K = {
                0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
                0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
                0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
                0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
                0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
                0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
                0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
                0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
            }
            local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
            local function md5_raw(input)
                assert(type(input) == "string", "MD5 input must be a string")
                local size = #input
                local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                    .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
                local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
                local words = {}
                for offset = 1, #message, 64 do
                    for j = 0, 15 do
                        local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                        words[j] = a + b * 256 + c * 65536 + d * 16777216
                    end
                    local a, b, c, d = h0, h1, h2, h3
                    for i = 0, 63 do
                        local f, g, shiftBase
                        if i < 16 then
                            f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                        elseif i < 32 then
                            f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                        elseif i < 48 then
                            f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                        else
                            local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                            f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                        end
                        local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                            SHIFT[shiftBase + i % 4 + 1])) % U32
                        a, b, c, d = d, nextB, b, c
                    end
                    h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
                end
                return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
            end
            local function hex(input)
                return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
            end
            local function md5(input) return hex(md5_raw(input)) end
            local function form_encode(input)
                assert(type(input) == "string", "Form value must be a string")
                return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                    return format("%%%02X", byte(c)) end):gsub(" ", "+"))
            end
            local function constant_time_equal(a, b)
                if type(a) ~= "string" or type(b) ~= "string" then return false end
                local difference = abs(#a - #b)
                for i = 1, max(#a, #b) do
                    difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
                end
                return difference == 0
            end
            local function name_uuid(input)
                local digest = md5_raw(input)
                local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                    .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
                return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                    .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
            end
            return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                    constant_time_equal = constant_time_equal, name_uuid = name_uuid}
        end)()

        local SESSION_KEY = '__LunarLicenseSessionV7'
        local function loadSession()
            local t = rawget(_G, SESSION_KEY)
            if type(t) == 'table' and t.authorized == true and t.scope == licenseScope then return t end
        end
        local function saveSession(expiresAt)
            _G[SESSION_KEY] = {authorized = true, expiresAt = expiresAt, scope = licenseScope}
        end
        local function clearSession() _G[SESSION_KEY] = nil end

        local CreateLocalExpiry = function(cfg)
            local E = {}
            local expiredText = 'Mod expired. Contact VIP Server for renewal.'
            local tamperText  = "Don't be over smart"
            local blockedMessage, blockedPhase
            local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
            local function parse(text)
                if type(text) ~= 'string' then return nil end
                local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
                y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
                if not y or not m or not d or not h or not n or not s or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
                local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
                local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
                if d < 1 or d > months[m] then return nil end
                local prior = y - 1
                local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                    - math.floor(prior / 100) + math.floor(1969 / 100)
                    + math.floor(prior / 400) - math.floor(1969 / 400)
                for i = 1, m - 1 do days = days + months[i] end
                return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
            end
            local expiry = cfg.manualExpiry and parse(cfg.manualExpiry) or nil
            if cfg.manualExpiry and not expiry then
                blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
            end
            local function block(message, phase)
                if not blockedMessage then blockedMessage, blockedPhase = message, phase end
                return false, blockedMessage, blockedPhase
            end
            function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
            function E.MarkTampered() return block(tamperText, 'tampered') end
            function E.GetExpiry() return expiry end
            function E.Accept(now, keyExpiry)
                if blockedMessage then return E.Status() end
                if not finite(now) or now < 0 then
                    return block('Clock verification unavailable.', 'error')
                end
                local effective = expiry
                if keyExpiry then
                    if not effective or keyExpiry < effective then effective = keyExpiry end
                end
                if effective and now >= effective then return false, expiredText, 'expired' end
                return true
            end
            function E.GetEffectiveExpiry(keyExpiry)
                local effective = expiry
                if keyExpiry then
                    if not effective or keyExpiry < effective then effective = keyExpiry end
                end
                return effective
            end
            function E.Parse(t) return parse(t) end
            return E
        end

        local CreateAuth = function(P, cfg, deps)
            local A = {}
            licenseScope = P.md5(cfg.game .. "\0" .. (cfg.secret or "") .. "\0offlinekeys")
            local phase, message = 'locked', 'Enter your key to sign in.'
            local allowed, generation = false, 0
            local expiresAt
            local startFn, stopFn, payloadStarted, restartRequired
            local localExpiry = deps.localExpiry
            do
                local stored = loadSession()
                if stored then
                    allowed = true; expiresAt = stored.expiresAt
                    phase, message = 'active', 'Session restored'
                end
            end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then message, phase = text, state end
            end
            local function readClock()
                local ok, n = pcall(deps.clock)
                if ok and type(n) == 'number' and n == n and n >= 0 then return n end
            end
            local function notify(text, state)
                message, phase = text, state
                if type(deps.status) == 'function' then pcall(deps.status, text, state) end
            end
            local function stopPayload()
                if payloadStarted then
                    payloadStarted = false
                    local ok, accepted = pcall(stopFn)
                    if not ok or accepted == false then restartRequired = true end
                end
            end
            local function revoke(text, state)
                generation = generation + 1
                allowed, expiresAt = false, nil
                stopPayload()
                local localDenied = false
                if localExpiry then
                    local ok, localText, localPhase = localExpiry.Status()
                    if not ok then text, state, localDenied = localText, localPhase, true end
                end
                notify(restartRequired and not localDenied
                    and 'Restart required: payload cleanup failed.' or text, state or 'error')
            end
            local function startPayload()
                if payloadStarted or not startFn then return true end
                payloadStarted = true
                local before = generation
                local ok, accepted = pcall(startFn)
                if not ok or accepted == false then
                    restartRequired = true
                    revoke('Restart required: offline script startup failed.', 'error')
                    return false
                end
                return generation == before and allowed
            end

            local keyIndex = {}
            do
                local list = cfg.validKeys or {}
                for _, entry in ipairs(list) do
                    local k, exp
                    if type(entry) == "string" then
                        k = entry
                    elseif type(entry) == "table" and type(entry.key) == "string" then
                        k = entry.key
                        if entry.expires then
                            exp = localExpiry and localExpiry.Parse(entry.expires) or nil
                        end
                    end
                    if k and #k > 0 then
                        keyIndex[k] = {expires = exp}
                    end
                end
            end

            local function verifyKey(key)
                local entry = keyIndex[key]
                if not entry then return false, "Invalid key.", nil end
                return true, nil, entry.expires
            end

            local function begin(key)
                if restartRequired then return false end
                if localExpiry then
                    local ok, text, state = localExpiry.Status()
                    if not ok then revoke(text, state); return false end
                end
                if type(key) ~= 'string' then key = '' end
                key = key:match('^%s*(.-)%s*$')
                if #key == 0 or #key > 512 then
                    revoke('Enter a valid key.', 'denied'); return false
                end
                local now = readClock()
                if not now then
                    revoke('Phone clock unavailable. Please try again.', 'error'); return false
                end
                local okSerial, serial = pcall(deps.serial, key)
                if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                    local failure = tostring(serial)
                    local text = 'Device identifier unavailable.'
                    if not okSerial and failure:find('DEVICE_CACHE_CONFLICT', 1, true) then
                        text = 'Saved device records conflict. Restore the registered device backup.'
                    elseif not okSerial and failure:find('DEVICE_CACHE_RECOVERY_REQUIRED', 1, true) then
                        text = 'Saved device data could not be recovered. Check storage or restore its backup.'
                    elseif not okSerial and failure:find('DEVICE_CACHE_SAVE_FAILED', 1, true) then
                        text = 'Device cache could not be saved. Check game storage access.'
                    end
                    revoke(text, 'error'); return false
                end
                generation = generation + 1
                notify('Verifying key...', 'pending')
                local okV, valid, reason, keyExpiry = pcall(verifyKey, key)
                if not okV then
                    revoke('Key verification failed.', 'error'); return false
                end
                if not valid then
                    revoke('Expired: ' .. tostring(reason), 'denied'); return false
                end
                if localExpiry then
                    local accepted, text, state = localExpiry.Accept(now, keyExpiry)
                    if not accepted then revoke(text, state); return false end
                end
                allowed = true
                expiresAt = localExpiry and localExpiry.GetEffectiveExpiry(keyExpiry) or keyExpiry
                saveSession(expiresAt)
                if not startPayload() then return false end
                notify('Login successful.', 'active')
                return true
            end

            function A.Login(key) if allowed then return false end; return begin(key) end
            function A.Tick() end
            function A.IsAuthorized()
                if allowed and not restartRequired then return true end
                local stored = loadSession()
                if stored and not restartRequired then
                    allowed = true; expiresAt = stored.expiresAt; return true
                end
                return false
            end
            function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
            function A.FailClosed(text, requiresRestart)
                if requiresRestart == true then restartRequired = true end
                revoke(text or 'Access unavailable.', 'error')
            end
            function A.ReportClockTampering()
                if localExpiry then localExpiry.MarkTampered() end
                revoke("Don't be over smart", 'tampered')
            end
            function A.Bind(onStart, onStop)
                if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                    return false, 'START_AND_STOP_REQUIRED'
                end
                if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
                startFn, stopFn = onStart, onStop
                if A.IsAuthorized() then return startPayload() end
                return true
            end
            function A.Unbind()
                revoke('Offline script disconnected.', 'locked')
                startFn, stopFn = nil, nil
            end
            function A.GetRemainingSeconds() return nil end
            function A.GetState()
                local authorized = A.IsAuthorized()
                return {
                    phase = phase, message = message, authorized = authorized,
                    sessionAuthorized = authorized, expiresAt = expiresAt,
                    accessPolicy = "offline_whitelist", expiryCheckPolicy = "login_only",
                    periodicRecheck = false, pending = false,
                    linked = startFn ~= nil, restartRequired = restartRequired == true,
                }
            end
            return A
        end

        local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
        function Core.new(config, dependencies)
            assert(type(config) == 'table' and type(dependencies) == 'table',
                'License configuration and dependencies required')
            local deps = {}
            for key, value in pairs(dependencies) do deps[key] = value end
            if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config) end
            return CreateAuth(Primitives, config, deps)
        end
        return Core
    end)()

    -- ============================================================================
    -- 2) UI.Build : واجهة تسجيل الدخول (نافذة الكود)
    -- ============================================================================
    local UI = {Version = "LunarUI.V10.Glass.OfflineKeys.1"}
    local function member(o, k)
        if o == nil then return nil end
        local ok, v = pcall(function() return o[k] end); if ok then return v end
    end
    local function valid(o)
        if o == nil then return false end
        local ok, v = pcall(slua.isValid, o); return ok and v == true
    end
    local vectorClass = rawget(_G, "FVector2D") or import("Vector2D")
    local colorClass = rawget(_G, "FLinearColor") or import("LinearColor")
    local function vector(x, y) return vectorClass(x, y) end
    local function color(r, g, b, a)
        local function linear(v) v = v / 255; if v <= 0.04045 then return v / 12.92 end; return ((v + 0.055) / 1.055) ^ 2.4 end
        return colorClass(linear(r), linear(g), linear(b), a or 1)
    end
    local function visibility(w, v)
        local fn = member(w, "SetWidgetVisibility") or member(w, "SetVisibility")
        assert(type(fn) == "function", "UI_VISIBILITY_UNAVAILABLE"); fn(w, v)
    end
    local function parent()
        local ok, t = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t, "GetMainControlBaseUI")) ~= "function" then return end
        local found, root = pcall(t.GetMainControlBaseUI); if not found or not valid(root) then return end
        local p = member(root, "CanvasPanel_0"); if not valid(p) then p = member(root, "CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible = false
        if d.Event and d.Handle ~= nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Submit = nil; d.Event = nil; d.Handle = nil; d.Container = nil; d.Parent = nil
        d.Input = nil; d.Button = nil; d.Status = nil; d.Title = nil; d.Detail = nil; d.Hint = nil; d.Design = nil; d.Cache = nil
    end

    function UI.Build(kind, key, status, submit)
        local p = parent(); if not p then return nil, "UI_NOT_READY" end
        local enums = UEnums.ESlateVisibility
        local passive = enums.SelfHitTestInvisible
        if enums.Visible == nil or passive == nil then return nil, "UI_ENUM_UNAVAILABLE" end
        local welcome = kind == "welcome"
        local W, H = welcome and 600 or 500, welcome and 276 or 248
        local scale = welcome and 0.8 or 1
        pcall(function()
            local v = p:GetCachedGeometry():GetLocalSize()
            if v.X > 24 and v.Y > 24 then scale = math.min(scale, (v.X - 24) / W, (v.Y - 24) / H) end
        end)
        local d = {Parent = p, Visible = false, Submit = submit, Scale = scale}
        local ok, buildError = pcall(function()
            local function make(class, outer)
                local w = CGame:NewObjectFromPath("/Script/UMG." .. class, outer)
                assert(valid(w), "UI_WIDGET_UNAVAILABLE"); return w
            end
            d.Container = make("CanvasPanel", p)
            local design = make("CanvasPanel", d.Container); d.Design = design
            local artRoot = design
            local canCache, cache = pcall(make, "InvalidationBox", d.Container)
            if canCache and valid(cache) and type(member(cache, "SetCanCache")) == "function" then
                local attached = pcall(function() cache:AddChild(design); cache:SetCanCache(true); visibility(cache, passive) end)
                if attached then artRoot = cache; d.Cache = cache end
            end
            local artSlot = d.Container:AddChildToCanvas(artRoot)
            artSlot:SetAutoSize(false); artSlot:SetPosition(vector(0, 0)); artSlot:SetSize(vector(W, H)); artSlot:SetZOrder(1)
            visibility(design, passive)
            local function add(w, x, y, ww, hh, z, dynamic)
                local slot = (dynamic and d.Container or design):AddChildToCanvas(w)
                slot:SetAutoSize(false); slot:SetPosition(vector(x, y)); slot:SetSize(vector(ww, hh)); slot:SetZOrder(z)
                return slot
            end
            local artwork = {}
            local function drawRect(x, y, ww, hh, c, z, opacity)
                local w = make("Border", d.Container)
                w:SetBrushColor(colorClass(c.R, c.G, c.B, opacity or .5)); visibility(w, passive)
                add(w, x, y, ww, hh, z); return w
            end
            local function rect(x, y, ww, hh, c, z, opacity)
                artwork[#artwork+1] = {X = x, Y = y, W = ww, H = hh, C = c, Z = z, A = opacity or .5, Order = #artwork+1}
            end
            local function renderArt()
                table.sort(artwork, function(a, b)
                    if a.Z == b.Z then return a.Order > b.Order end
                    return a.Z > b.Z
                end)
                local covered = {}
                local function put(out, x, y, w, h)
                    if w > .00001 and h > .00001 then out[#out+1] = {X = x, Y = y, W = w, H = h} end
                end
                for _, shape in ipairs(artwork) do
                    local pieces = {{X = shape.X, Y = shape.Y, W = shape.W, H = shape.H}}
                    for _, cover in ipairs(covered) do
                        local nextPieces = {}
                        for _, piece in ipairs(pieces) do
                            local x1 = math.max(piece.X, cover.X); local y1 = math.max(piece.Y, cover.Y)
                            local x2 = math.min(piece.X + piece.W, cover.X + cover.W)
                            local y2 = math.min(piece.Y + piece.H, cover.Y + cover.H)
                            if x2 <= x1 or y2 <= y1 then nextPieces[#nextPieces+1] = piece
                            else
                                put(nextPieces, piece.X, piece.Y, piece.W, y1 - piece.Y)
                                put(nextPieces, piece.X, y2, piece.W, piece.Y + piece.H - y2)
                                put(nextPieces, piece.X, y1, x1 - piece.X, y2 - y1)
                                put(nextPieces, x2, y1, piece.X + piece.W - x2, y2 - y1)
                            end
                        end
                        pieces = nextPieces; if #pieces == 0 then break end
                    end
                    local changed = true
                    while changed do
                        changed = false
                        for i = 1, #pieces do
                            local a = pieces[i]
                            for j = i + 1, #pieces do
                                local b = pieces[j]
                                local vertical = math.abs(a.X - b.X) < .00001 and math.abs(a.W - b.W) < .00001
                                    and (math.abs(a.Y + a.H - b.Y) < .00001 or math.abs(b.Y + b.H - a.Y) < .00001)
                                local horizontal = math.abs(a.Y - b.Y) < .00001 and math.abs(a.H - b.H) < .00001
                                    and (math.abs(a.X + a.W - b.X) < .00001 or math.abs(b.X + b.W - a.X) < .00001)
                                if vertical or horizontal then
                                    local x, y = math.min(a.X, b.X), math.min(a.Y, b.Y)
                                    a.W = math.max(a.X + a.W, b.X + b.W) - x
                                    a.H = math.max(a.Y + a.H, b.Y + b.H) - y; a.X = x; a.Y = y
                                    table.remove(pieces, j); changed = true; break
                                end
                            end
                            if changed then break end
                        end
                    end
                    for _, piece in ipairs(pieces) do
                        drawRect(piece.X, piece.Y, piece.W, piece.H, shape.C, shape.Z, shape.A)
                    end
                    covered[#covered+1] = shape
                end
                artwork = nil
            end
            local function sample(stops, t, opacity)
                t = math.max(0, math.min(1, t)); local a, b, u
                if t <= .5 then a, b, u = stops[1], stops[2], t * 2 else a, b, u = stops[2], stops[3], (t - .5) * 2 end
                return color(a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u, a[3] + (b[3] - a[3]) * u, opacity)
            end
            local function panel(x, y, ww, hh, cut, stops, z, columns, opacity)
                columns = math.min(columns, 12)
                for i = 0, columns - 1 do
                    local a = ww * i / columns; local b = ww * (i + 1) / columns
                    local inset = math.max(0, cut - math.min(a, ww - b))
                    rect(x + a, y + inset, b - a, hh - inset * 2, sample(stops, (i + .5) / columns, opacity), z, opacity)
                end
            end
            local function rail(x, y, ww, hh, stops, z, columns)
                columns = math.min(columns, 12)
                for i = 0, columns - 1 do
                    rect(x + ww * i / columns, y, ww / columns, hh, sample(stops, (i + .5) / columns), z)
                end
            end
            local function line(ax, ay, bx, by, th, c, z)
                local dx, dy = bx - ax, by - ay
                local len = math.sqrt(dx * dx + dy * dy)
                if len <= 0 then return end
                local angle
                if dx == 0 then angle = dy >= 0 and 90 or -90
                else angle = math.atan(dy / dx) * 180 / math.pi; if dx < 0 then angle = angle + 180 end end
                local w = drawRect((ax + bx - len) / 2, (ay + by - th) / 2, len, th, c, z, z >= 7 and 1 or .5)
                w:SetRenderTransformPivot(vector(.5, .5)); w:SetRenderAngle(angle)
            end
            local slate = import("SlateColor")
            local fontObject
            if slua and type(slua.loadObject) == "function" then
                local loaded, obj = pcall(slua.loadObject, "/Engine/EngineFonts/Roboto.Roboto")
                if loaded and valid(obj) then fontObject = obj end
            end
            local function style(w, size, c, bold)
                local font = member(w, "Font")
                if font then
                    if type(font) == "table" then local copy = {}; for k, v in pairs(font) do copy[k] = v end; font = copy end
                    font.Size = size
                    if fontObject then font.FontObject = fontObject; font.TypefaceFontName = bold and "Bold" or "Regular" end
                    if font.OutlineSettings then
                        local outline = font.OutlineSettings
                        if type(outline) == "table" then local copy = {}; for k, v in pairs(outline) do copy[k] = v end; outline = copy end
                        outline.OutlineSize = 0; font.OutlineSettings = outline
                    end
                    w:SetFont(font)
                end
                w:SetColorAndOpacity(slate(c))
                pcall(function() w:SetShadowOffset(vector(0, 0)); w:SetShadowColorAndOpacity(color(0, 0, 0, 0)) end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value, x, y, ww, hh, size, c, z, bold, center, dynamic)
                local w = make("TextBlock", d.Container); w:SetText(value); style(w, size, c, bold)
                visibility(w, passive); add(w, x, y, ww, hh, z, dynamic)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local frame = {{28, 220, 255}, {92, 123, 255}, {155, 105, 255}}
            local bright = {{188, 250, 255}, {202, 215, 255}, {226, 198, 255}}
            local edge = {{12, 72, 104}, {37, 52, 112}, {69, 38, 112}}
            local body = {{8, 22, 39}, {13, 25, 49}, {17, 22, 45}}
            local header = {{11, 34, 58}, {20, 35, 70}, {36, 29, 67}}
            local gold = {{16, 105, 143}, {55, 104, 213}, {125, 73, 198}}
            local white = color(239, 249, 255)
            local forest = color(151, 232, 255)
            local burgundy = color(182, 215, 255)
            panel(6, 6, W - 12, H - 12, 10, body, 2, 24, .86)
            rail(13, 0, W - 26, 6, frame, 3, 24)
            rail(13, H - 6, W - 26, 6, frame, 3, 24)
            rect(0, 13, 6, H - 26, color(28, 220, 255), 3)
            rect(W - 6, 13, 6, H - 26, color(155, 105, 255), 3)
            rail(13, 1, W - 26, 1.5, bright, 3, 24)
            rail(13, H - 3, W - 26, 1.5, edge, 3, 24)
            rect(1, 13, 1.5, H - 26, color(125, 235, 255), 3)
            rect(W - 3, 13, 1.5, H - 26, color(190, 165, 255), 3)
            for _, s in ipairs({{1, 13, 13, 1}, {1, H - 13, 13, H - 1}}) do line(s[1], s[2], s[3], s[4], 2, color(188, 250, 255), 3) end
            for _, s in ipairs({{W - 13, 1, W - 1, 13}, {W - 13, H - 1, W - 1, H - 13}}) do line(s[1], s[2], s[3], s[4], 2, color(226, 198, 255), 3) end
            panel(10, 10, W - 20, 65, 16, gold, 4, 24, .68)
            panel(13, 13, W - 26, 59, 14, header, 5, 32, .94)
            rail(24, 17, W - 48, 1.2, bright, 6, 24)
            if welcome then
                d.Title = text("VIP ACCESS // WELCOME", 24, 22, W - 48, 42, 19, white, 7, true, true)
                local pw = math.min(340, W - 72); local px = (W - pw) / 2
                panel(px, 99, pw, 51, 12, gold, 4, 16, .82)
                panel(px + 3, 102, pw - 6, 45, 10, {{12, 82, 126}, {35, 106, 201}, {83, 63, 158}}, 5, 20, .96)
                d.Detail = text("Kill limit 8-10", px + 16, 109, pw - 32, 34, 23, white, 7, true, true)
                d.Hint = text("PREMIUM ACCESS • READY WHEN YOU ARE", 30, 165, W - 60, 32, 17, forest, 7, true, true)
            else
                d.Title = text("VIP GLASS", 22, 15, W - 44, 31, 24, white, 7, true, true)
                text("SECURE KEY AUTHENTICATION", 22, 45, W - 44, 21, 12, white, 7, true, true)
                line(W / 2 - 118, 56, W / 2 - 47, 56, 1, color(251, 244, 228), 7)
                line(W / 2 + 47, 56, W / 2 + 118, 56, 1, color(251, 244, 228), 7)
                text("LICENSE KEY", 22, 82, W - 44, 20, 13, burgundy, 7, true, false)
                rail(27, 104, W - 54, 2, gold, 4, 24)
                rail(27, 143, W - 54, 2, gold, 4, 24)
                rect(20, 111, 2, 27, color(188, 108, 59), 4)
                rect(W - 22, 111, 2, 27, color(114, 179, 105), 4)
                line(20, 111, 27, 104, 2, color(242, 219, 164), 4)
                line(W - 27, 104, W - 20, 111, 2, color(242, 219, 164), 4)
                line(20, 138, 27, 145, 2, color(242, 219, 164), 4)
                line(W - 27, 145, W - 20, 138, 2, color(242, 219, 164), 4)
                d.Input = make("EditableTextBox", d.Container)
                d.Input:SetText(key or "")
                local fg = forest; local bg = color(255, 244, 216, 0)
                local inputStyle = member(d.Input, "WidgetStyle")
                if inputStyle then
                    if type(inputStyle) == "table" then local copy = {}; for k, v in pairs(inputStyle) do copy[k] = v end; inputStyle = copy end
                    local inputFont = member(inputStyle, "Font")
                    if inputFont then
                        if type(inputFont) == "table" then local copy = {}; for k, v in pairs(inputFont) do copy[k] = v end; inputFont = copy end
                        inputFont.Size = 17
                        if fontObject then inputFont.FontObject = fontObject; inputFont.TypefaceFontName = "Regular" end
                        inputStyle.Font = inputFont
                    end
                    inputStyle.ForegroundColor = slate(fg); inputStyle.ReadOnlyForegroundColor = slate(fg)
                    for _, name in ipairs({"BackgroundImageNormal", "BackgroundImageHovered", "BackgroundImageFocused", "BackgroundImageReadOnly"}) do
                        local brush = member(inputStyle, name)
                        if brush then
                            if type(brush) == "table" then local copy = {}; for k, v in pairs(brush) do copy[k] = v end; brush = copy end
                            brush.TintColor = slate(bg); inputStyle[name] = brush
                        end
                    end
                    d.Input.WidgetStyle = inputStyle
                else
                    local inputFont = member(d.Input, "Font")
                    if inputFont then
                        if type(inputFont) == "table" then local copy = {}; for k, v in pairs(inputFont) do copy[k] = v end; inputFont = copy end
                        inputFont.Size = 17; d.Input.Font = inputFont
                    end
                    d.Input.ForegroundColor = fg; d.Input.BackgroundColor = bg
                end
                local setForeground = member(d.Input, "SetForegroundColor")
                if type(setForeground) == "function" then setForeground(d.Input, fg) end
                pcall(function() d.Input:SetHintText("Enter your key") end)
                visibility(d.Input, enums.Visible); add(d.Input, 23, 107, W - 46, 35, 8, true)
                d.Hint = text("ENCRYPTED LOCAL KEY STORAGE", 22, 149, W - 44, 19, 11, burgundy, 7, false, false)
                d.Status = text(status or "Enter your key", 22, 170, W - 44, 23, 11, burgundy, 8, false, false, true)
            end
            local button = make("Button", d.Container); d.Button = button
            local by = welcome and 212 or 201; local bh = welcome and 42 or 34
            local bw = welcome and 202 or 190; local bx = (W - bw) / 2
            panel(bx - 4, by - 3, bw + 8, bh + 6, 9, gold, 4, 16, .82)
            panel(bx, by, bw, bh, 8, {{10, 137, 183}, {39, 121, 229}, {100, 77, 201}}, 5, 16, .98)
            pcall(function() button:SetBackgroundColor(color(255, 255, 255, 0)) end)
            visibility(button, enums.Visible)
            local label = make("TextBlock", button); label:SetText(welcome and "CONTINUE" or "UNLOCK ACCESS"); style(label, 17, white, true); visibility(label, passive)
            local labelSlot = button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2); labelSlot:SetVerticalAlignment(2) end)
            add(button, bx, by, bw, bh, 9, true)
            d.Event = button.OnClicked
            d.Handle = d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                if welcome then
                    destroy(d); d.Dismissed = true
                    local l = _G.LunarLoginRuntime; if l and l.WelcomeUI == d then l.WelcomeUI = nil end
                    return
                end
                local okRead, k = pcall(function() return d.Input:GetText() end)
                if not okRead or type(k) ~= "string" then return end
                k = k:match("^%s*(.-)%s*$")
                if #k == 0 or #k > 512 then d.Status:SetText("Enter a valid key"); return end
                if d.Submit then d.Submit(k) end
            end)
            renderArt()
            local slot = p:AddChildToCanvas(d.Container); slot:SetAutoSize(false); slot:SetSize(vector(W, H)); slot:SetZOrder(9200)
            local anchors = slot:GetAnchors(); anchors.Minimum = vector(.5, .5); anchors.Maximum = vector(.5, .5)
            slot:SetAnchors(anchors); slot:SetAlignment(vector(.5, .5)); slot:SetPosition(vector(0, 0))
            d.Container:SetRenderTransformPivot(vector(.5, .5)); d.Container:SetRenderScale(vector(scale, scale))
            visibility(d.Container, passive)
        end)
        if not ok then UI.LastBuildError = tostring(buildError); destroy(d); return nil, "UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError = nil
        d.Visible = true; return d
    end
    _G.LunarUIAssetCache = nil

    -- ============================================================================
    -- 3) إنشاء LunarLoginRuntime : الحالة الرئيسية لتسجيل الدخول
    -- ============================================================================
    local existing = _G.LunarLoginRuntime
    if existing and existing.UIFactory and existing.UIFactory.Version ~= UI.Version
        and existing.Scope == VIPLicenseCore.Primitives.md5(VIPLicenseConfig.game .. "\0" .. (VIPLicenseConfig.secret or "") .. "\0offlinekeys") then
        local visibleWelcome = existing.WelcomeUI and existing.WelcomeUI.Visible
        if existing.DestroyUI then existing.DestroyUI() end
        existing.UIFactory.Build = UI.Build; existing.UIFactory.Version = UI.Version
        if visibleWelcome then existing.WelcomeShown = false end
        existing.NeedsUpdate = true
    end

    local function hex(s) return (s:gsub('.', function(c) return string.format('%02x', string.byte(c)) end)) end
    local function unhex(s)
        if type(s) ~= "string" or #s > 1024 or #s % 2 ~= 0 or s:find('[^%x]') then return nil end
        return (s:gsub('..', function(v) return string.char(tonumber(v, 16)) end))
    end

    local current = _G.LunarLoginRuntime
    local expectedScope = VIPLicenseCore.Primitives.md5(VIPLicenseConfig.game .. "\0" .. (VIPLicenseConfig.secret or "") .. "\0offlinekeys")
    if not current or current.Scope ~= expectedScope then
        if current and current.DestroyUI then current.DestroyUI() end
        local L = {Authorized = false, Pending = false, NeedsUpdate = true, WelcomeShown = false,
            Key = "", Seed = "", Scope = expectedScope, StorageVersion = 1, Status = "Enter your key", Diagnostics = {DeviceReads = 0}}
        _G.LunarLoginRuntime = L
        L.UIFactory = UI
        -- مسارات حفظ الكود
        local paths = {}
        local basePaths = {
            "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/",
            "Documents/ShadowTrackerExtra/Saved/SaveGames/",
            "ShadowTrackerExtra/Saved/SaveGames/",
        }
        for _, base in ipairs(basePaths) do
            table.insert(paths, base .. "VIP_SERVER_LOGIN_V7_settings.lua")
        end
        -- إضافة مسارات ios
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/VIP_SERVER_LOGIN_V7_settings.lua")
            end
        end

        local function identityPath(path)
            local changed, count = path:gsub("VIP_SERVER_LOGIN_V7_settings%.lua$", "VIP_SERVER_DEVICE_V1_settings.lua")
            if count > 0 then return changed end
            return path .. ".device"
        end
        local function plainKeyPath(base)
            local prefix = base:match("^(.*[/\\])[^/\\]+$") or ""
            return prefix .. "VIP_SERVER_PLAINKEY_V1_settings.lua"
        end
        local function digest(key, seed)
            return VIPLicenseCore.Primitives.md5("LUNAR-DEVICE-1\0" .. L.Scope .. "\0" .. key .. "\0" .. seed)
        end
        local function readRecord(path, identity)
            if not (io and type(io.open) == "function") then return nil, "unreadable" end
            local ok, file, reason, code = pcall(io.open, path, "r")
            if not ok then return nil, "unreadable" end
            if not file then
                local text = type(reason) == "string" and reason:lower() or ""
                if reason == nil or code == 2 or text:find("no such file", 1, true)
                    or text:find("not found", 1, true) or text:find("does not exist", 1, true) then
                    return nil, "missing"
                end
                return nil, "unreadable"
            end
            local good, data = pcall(function() return file:read(4097) end)
            pcall(function() file:close() end)
            if not good or type(data) ~= "string" then return nil, "unreadable" end
            if #data > 4096 then return nil, "invalid" end
            local scope = data:match('%f[%w_]Scope%s*=%s*"([%x]+)"')
            if scope and scope ~= L.Scope then return nil, "other_scope" end
            if scope ~= L.Scope then return nil, "invalid" end
            local key = unhex(data:match('%f[%w_]KeyHex%s*=%s*"([^"]*)"'))
            local seed = unhex(data:match('%f[%w_]SeedHex%s*=%s*"([^"]*)"'))
            if key == nil or seed == nil or #seed == 0 or #seed > 512 then return nil, "invalid" end
            local check = data:match('%f[%w_]Check%s*=%s*"([%x]+)"')
            local version = data:match('%f[%w_]Version%s*=%s*(%d+)')
            if identity or check or version then
                if version ~= "1" or check ~= digest(key, seed) then return nil, "invalid" end
            end
            return {Key = key, Seed = seed, Path = path, Identity = identity, Checked = version == "1"}, "valid"
        end
        local function candidates()
            local list, seen = {}, {}
            local function add(path)
                if type(path) == "string" and not seen[path] then seen[path] = true; list[#list+1] = path end
            end
            add(L.Path); add(L.PreferredPath)
            for _, path in ipairs(paths) do add(path) end
            return list
        end
        local function recover()
            if L.IdentityPinned then return true end
            local identities, legacy, issues = {}, {}, {}
            local function collect(base, path, identity)
                local record, state = readRecord(path, identity)
                if record then
                    record.Base = base
                    local list = identity and identities or legacy; list[#list+1] = record
                elseif state == "invalid" or (state == "unreadable" and base == L.PreferredPath) then
                    issues[#issues+1] = state
                end
            end
            for _, base in ipairs(candidates()) do
                local device = identityPath(base)
                collect(base, device, true); collect(base, device .. ".bak", true)
                collect(base, base, false); collect(base, base .. ".bak", false)
            end
            local list = #identities > 0 and identities or legacy
            local first = list[1]
            if first then
                for _, record in ipairs(list) do
                    if record.Seed ~= first.Seed then
                        L.IdentityError = "DEVICE_CACHE_CONFLICT"; L.Diagnostics.Identity = "conflict"; return false
                    end
                end
                L.Seed = first.Seed; L.Key = first.Key; L.Path = first.Base
                if L.Key == "" then
                    for _, record in ipairs(list) do
                        if record.Key ~= "" then L.Key = record.Key; break end
                    end
                end
                if L.Key == "" then
                    for _, record in ipairs(legacy) do
                        if record.Seed == L.Seed and record.Key ~= "" then L.Key = record.Key; break end
                    end
                end
                L.IdentityPinned = true; L.IdentityPersisted = true; L.HasIdentityRecord = first.Identity
                L.IdentityError = nil; L.Dirty = true
                L.Diagnostics.Identity = first.Identity and "restored" or "legacy_migration"
                return true
            end
            if #issues > 0 then
                L.IdentityError = "DEVICE_CACHE_RECOVERY_REQUIRED"; L.Diagnostics.Identity = "recovery_required"; return false
            end
            L.IdentityError = nil; L.Diagnostics.Identity = "new_install"; return true
        end
        local function payload(key, seed)
            return 'return { Version = 1, Scope = "' .. L.Scope .. '", KeyHex = "' .. hex(key)
                .. '", SeedHex = "' .. hex(seed) .. '", Check = "' .. digest(key, seed) .. '" }'
        end
        local function plainPayload(key)
            return 'return { Key = "' .. key:gsub("\\", "\\\\"):gsub('"', '\\"')
                .. '", Scope = "' .. L.Scope .. '" }'
        end
        -- كتابة آمنة للملف
        local function verifiedWrite(path, identity, key, seed, data)
            local current, state = readRecord(path, identity)
            if current and current.Checked and current.Seed == seed and current.Key == key then return true end
            if state == "unreadable" or state == "other_scope" then return false end
            if current and current.Seed ~= seed and (identity or not L.HasIdentityRecord) then return false end
            local file = io.open(path, "w")
            if not file then return false end
            file:write(data)
            file:close()
            local result = readRecord(path, identity)
            return result ~= nil and result.Checked and result.Seed == seed and result.Key == key
        end
        -- حفظ الكود العادي (بدون هوية الجهاز)
        L.SavePlain = function()
            local key = L.AttemptKey or L.Key
            if type(key) ~= "string" or key == "" then return false end
            local data = plainPayload(key)
            local ok = false
            for _, base in ipairs(candidates()) do
                local pp = plainKeyPath(base)
                local f = io.open(pp, "w")
                if f then
                    f:write(data); f:close()
                    ok = true
                end
            end
            return ok
        end
        L.LoadPlain = function()
            if type(L.Key) == "string" and L.Key ~= "" then return true end
            for _, base in ipairs(candidates()) do
                local pp = plainKeyPath(base)
                local okR, file = pcall(io.open, pp, "r")
                if okR and file then
                    local data = file:read("*a") or ""
                    file:close()
                    local scope = data:match('Scope%s*=%s*"([%x]+)"')
                    if scope == L.Scope then
                        local key = data:match('Key%s*=%s*"([^"]*)"')
                        if key and key ~= "" then
                            L.Key = key
                            return true
                        end
                    end
                end
            end
            return false
        end
        L.Save = function()
            pcall(L.SavePlain)
            if L.Seed == "" or L.IdentityError then return false end
            local key = L.AttemptKey or L.Key
            local data = payload(key, L.Seed)
            local preferred = candidates()
            for _, base in ipairs(preferred) do
                local device = identityPath(base)
                local old, oldState = readRecord(base, false)
                local current, currentState = readRecord(device, true)
                if oldState ~= "unreadable" and currentState ~= "unreadable"
                    and oldState ~= "other_scope" and currentState ~= "other_scope"
                    and (not old or old.Seed == L.Seed or L.HasIdentityRecord)
                    and (not current or current.Seed == L.Seed) then
                    local a = verifiedWrite(device, true, key, L.Seed, data)
                    local b = verifiedWrite(device .. ".bak", true, key, L.Seed, data)
                    local c = verifiedWrite(base, false, key, L.Seed, data)
                    local d = verifiedWrite(base .. ".bak", false, key, L.Seed, data)
                    if (a or b) and ((a and b) or c or d) then
                        L.Path = base; L.Key = key; L.IdentityPinned = true; L.IdentityPersisted = true; L.HasIdentityRecord = true
                        L.IdentityError = nil; L.Dirty = not (a and b and c and d)
                        L.SaveRetryAt = L.Dirty and (os.time() + 30) or nil
                        L.SaveError = L.Dirty and "Device backup repair pending" or nil
                        L.Diagnostics.Identity = L.Dirty and "backup_pending" or "saved"
                        return true
                    end
                end
            end
            L.Dirty = true; L.SaveRetryAt = os.time() + 30
            L.SaveError = "Device cache could not be verified"; L.Diagnostics.Identity = "save_failed"
            return false
        end
        L.BindSettingsPath = function(featurePath)
            L.PreferredPath = featurePath
            if not L.IdentityPinned then recover() end
            if L.Seed ~= "" and not L.IdentityError and (L.Dirty or not L.IdentityPersisted) then L.Save() end
        end
        L.EnsureIdentity = function()
            if not L.IdentityPinned then
                L.Seed = ""
                assert(recover(), L.IdentityError or "DEVICE_CACHE_RECOVERY_REQUIRED")
            end
            if L.Seed == "" then
                L.Diagnostics.DeviceReads = L.Diagnostics.DeviceReads + 1
                local id = Client.GetPhoneDeviceID()
                assert(type(id) == "string" and #id > 0 and #id <= 512, "DEVICE_ID_UNAVAILABLE")
                L.Seed = id
            end
            local saved = L.Save()
            assert(saved or L.IdentityPersisted, "DEVICE_CACHE_SAVE_FAILED")
        end
        recover()
        L.LoadPlain()
        L.DestroyUI = function() destroy(L.LoginUI); destroy(L.WelcomeUI); L.LoginUI = nil; L.WelcomeUI = nil end
        local function wake()
            local f = _G.LunarFeatures; if f and f.Wake and not f.Token.Stopped then f.Wake() end
        end
        L.Core = VIPLicenseCore
        L.Auth = VIPLicenseCore.new(VIPLicenseConfig, {
            clock = function() local t = os.time(); return t end,
            wall = function() return os.time() end,
            serial = function(key)
                L.EnsureIdentity()
                return VIPLicenseCore.Primitives.name_uuid('VIP-SERVER-V1\0' .. key .. '\0' .. L.Seed)
            end,
            status = function(message, phase)
                L.Status = message; L.Pending = phase == "pending"
                if phase == "active" then
                    L.Authorized = true; L.Key = L.AttemptKey or L.Key; L.Save()
                    destroy(L.LoginUI); L.LoginUI = nil
                else L.Authorized = false end
                L.NeedsUpdate = true
                local d = L.LoginUI
                if d then
                    if d.StatusText ~= message then d.Status:SetText(message); d.StatusText = message end
                    if d.Busy ~= L.Pending then
                        d.Busy = L.Pending
                        pcall(function() d.Input:SetIsEnabled(not L.Pending); d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
                wake()
            end
        })
        L.Authorized = L.Auth.IsAuthorized()
        L.Login = function(key)
            if L.Authorized or L.Pending then return false end
            L.AttemptKey = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
            local ok, result = pcall(L.Auth.Login, L.AttemptKey)
            if not ok then L.Status = "Login could not start"; L.Pending = false; L.NeedsUpdate = true; wake(); return false end
            if result and L.Seed ~= "" then
                L.Key = L.AttemptKey
                pcall(L.Save)
            end
            return result
        end
        L.AutoLoginAttempted = false
        local function tryAutoLogin()
            if L.Authorized then return true end
            if type(L.Key) ~= "string" or L.Key == "" then return false end
            if L.Pending then return false end
            L.AutoLoginAttempted = true
            local ok, res = pcall(L.Login, L.Key)
            return ok and res == true
        end
        L.TryAutoLogin = tryAutoLogin
        tryAutoLogin()
        L.Logout = function()
            L.Auth.Logout(); L.Authorized = false; L.DestroyUI(); L.NeedsUpdate = true; wake()
        end
        L.Update = function()
            if not L.Authorized and not L.Pending then
                if type(L.Key) == "string" and L.Key ~= "" then
                    if not L.AutoLoginAttempted or L.IdentityError or (L.SaveError ~= nil) then
                        L.TryAutoLogin()
                    end
                end
            end
            if L.Dirty and (not L.SaveRetryAt or os.time() >= L.SaveRetryAt or os.time() < L.SaveRetryAt - 30) then L.Save() end
            if L.Authorized then
                if not L.WelcomeShown then
                    local d = UI.Build("welcome")
                    if d then L.WelcomeUI = d; L.WelcomeShown = true end
                end
                L.NeedsUpdate = not L.WelcomeShown or L.Dirty
                return
            end
            local p = parent()
            if L.LoginUI and (not valid(L.LoginUI.Container) or p ~= L.LoginUI.Parent) then destroy(L.LoginUI); L.LoginUI = nil end
            if not L.LoginUI then
                local d = UI.Build("login", L.Key, L.Status, L.Login)
                if d then
                    d.Busy = L.Pending; d.StatusText = L.Status; L.LoginUI = d
                    pcall(function() d.Input:SetIsEnabled(not L.Pending); d.Button:SetIsEnabled(not L.Pending) end)
                end
            end
            L.NeedsUpdate = true
        end
    end

    _G.VIPLicenseLogin = function(key) return _G.LunarLoginRuntime.Login(key) end
    _G.VIPLicenseLogout = function() return _G.LunarLoginRuntime.Logout() end
    _G.VIPLicenseStatus = function()
        local l = _G.LunarLoginRuntime
        return {authorized = l.Authorized, pending = l.Pending, message = l.Status,
            periodicRecheck = false, expiryCheckPolicy = "login_only", saveOK = not l.Dirty, identityState = l.Diagnostics.Identity}
    end
end

-- استدعاء التهيئة
_VIPLicense_Init()

-- ==============================================================================
-- ==================== نهاية نظام الترخيص والأكواد =============================
-- ==============================================================================

-- ==============================================================================
-- ============================ BẮT ĐẦU CÁC HỆ THỐNG KHÁC =======================
-- ==============================================================================

-- [جميع الأنظمة الأخرى من BRPlayerCharacterBase.lua الأصلي توضع هنا]
-- (هذا هو المكان الذي يبدأ فيه كود `_G.StartAdvancedSystems = function(self)`...)

_G.StartAdvancedSystems = function(self)
    -- فحص الكود الجديد
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then Msg.Show(4, "LICENSE", "الرجاء إدخال الكود في القائمة لتفعيل الميزات.") end
        end)
        return
    end
    -- ============================================================
    -- 40-LAYER BYPASS (PORTED FROM bb.lua)
    -- ============================================================
    if not _G._BYPASS_LOADED then
        _G._BYPASS_LOADED = true
        local noop = function() return true end
        local retTrue = function() return true end
        pcall(function()
            local H = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if H then
                H.ControlMHActive=noop; H.Tick=noop; H.OnTick=noop; H.TriggerAvatarCheck=noop
                H.StartAvatarCheck=noop; H.ReportItemID=noop; H.OnReportItemID=noop
                H.ReceiveAnyDamage=noop; H.OnWeaponHitRecord=noop; H.ShowSecurityAlert=noop
                H.StaticShowSecurityAlertInDev=noop; H.SendHisarData=noop; H.ValidateSecurityData=noop
                H.CheckWeaponIntegrity=retTrue; H.CheckAvatarIntegrity=retTrue; H.CheckBulletIntegrity=retTrue
                H.bMHActive=false; H.mHActive=0
                if H.BlackList then for k in pairs(H.BlackList) do H.BlackList[k]=nil end end
            end
        end)
        pcall(function()
            local banPaths = {"client.slua.logic.ban.ClientBanLogic","client.slua.logic.ban.BanTipsLogic","GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem","GameLua.Mod.BaseMod.Common.Security.DSReportPlayerSubsystem","GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem","GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem"}
            for _,p in ipairs(banPaths) do
                local m = package.loaded[p]
                if m then for k,v in pairs(m) do if type(v)=="function" then m[k]=noop end end end
            end
        end)
        pcall(function()
            local T = _G.TLog
            if T then T.Info=noop; T.Warning=noop; T.Error=noop; T.Report=noop end
            local CS = _G.CrashSight
            if CS then CS.ReportException=noop; CS.Log=noop end
        end)
        pcall(function()
            local console = import("KismetSystemLibrary")
            if console then
                -- SLIM BYPASS: self-report console commands disabled (ban cause)
                -- console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
                -- console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
            end
        end)
        -- SLIM BYPASS: heartbeat/telemetry block removed (missing heartbeat = instant 10yr flag)
    end

    -- purane dead timer handles clear (next match me naye PC par naye timer lagenge)
    _G._chamsTimer = nil
    _G._pbc_WH_TIMER = nil
    _G._bf_Timer = nil
    -- ============================================================
    -- SRC HUB AIMBOT V2 - ULTRA OPTIMIZED (NO LAG)
    -- ============================================================
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local GameplayStatics = import("GameplayStatics")
    local KismetSystemLibrary = import("KismetSystemLibrary")
    local KismetMathLibrary = import("KismetMathLibrary")
    local FVector2D = import("Vector2D")
    local HitResultClass = import("HitResult")
    local ui_util = require("client.common.ui_util")

    local function Valid(obj)
        if not obj then return false end
        if slua and slua.isValid then
            local ok, v = pcall(slua.isValid, obj)
            if not ok or not v then return false end
        end
        return true
    end

    _G.AimbotConfig = _G.AimbotConfig or {
        Enable = false,  -- SLIM BYPASS: default OFF (menu se ON karo)
        NormalAimbot = false,
        Bone = 2,              -- 1 = الرأس, 2 = الصدر, 3 = الخصر
        Speed = 50,            -- سرعة التصويب (1-100)
        FOV = 30,              -- مجال الرؤية (درجة)
        Distance = 250,        -- المسافة القصوى (متر)
        Smooth = true,         -- تفعيل التمليس (السلاسة)
        VisCheck = true,       -- التحقق من الرؤية
        IgnoreKnock = false,   -- تجاهل المصابين
        IgnoreBot = false,     -- تجاهل البوتات
        Condition = 1,         -- 1 = عند الإطلاق فقط, 2 = دائماً
        TargetMode = 1,        -- 1 = Nearest (Closest to crosshair), 2 = Low HP
        WallTarget = false,    -- Lock enemy behind wall (through wall aimbot)
        InScopeAimbot = false, -- Hard aimbot when scope is ON (10m-100m)
        LongRange = false,     -- Long range mode (500m+)
        LongRangeRecoil = 0,  -- ALWAYS OFF (locked): recoil compression band, No Recoil system use karo
        Bone = "spine_03",     -- Aim bone: "head", "spine_03" (chest), "pelvis"
    }
    -- LOCK: Long Range Recoil hamesha OFF (menu slider hataya, neeche force-locked)
    _G.AimbotConfig.LongRangeRecoil = 0

    -- العظام الأساسية فقط لتقليل الضغط بدلاً من 20 عظمة
    local PriorityBones = { "spine_03", "head", "pelvis" }

    -- إعادة استخدام الكائنات لمنع إجهاز الذاكرة (Garbage Collection Stutter)
    local ReusableStartPos = { X = 0, Y = 0, Z = 0 }
    local ReusableScreenPos = FVector2D and FVector2D() or { X = 0, Y = 0 }
    local CachedHitResult = HitResultClass and HitResultClass() or {}

    -- Target Lock System: prevents aimbot confusion with multiple enemies
    local _LockedTarget = nil
    local _LockedTargetLostTime = 0

    local function IsPlayerFiring(player)
        if not Valid(player) then return false end
        if player.bIsWeaponFiring == true then return true end
        if player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and player.WeaponManagerComponent.bIsWeaponFiring == true then
            return true
        end
        
        local pc = nil
        if type(player.GetPlayerControllerSafety) == "function" then
            pc = player:GetPlayerControllerSafety()
        end
        
        return Valid(pc) and pc.bIsWeaponFiring == true
    end

    -- OPTIMIZE: shared pawn-list cache (5 alag loops har frame GetAll na kare, 0.2s TTL)
    _G._SH_PawnListCache = _G._SH_PawnListCache or { data = {}, t = 0 }
    local function GetRawPawnList()
        local now = os.clock()
        local c = _G._SH_PawnListCache
        if c.data and (now - (c.t or 0)) < 0.2 and #c.data > 0 then return c.data end
        local all = {}
        pcall(function()
            if GameplayData.GetAllPlayerCharacters then
                all = GameplayData.GetAllPlayerCharacters() or {}
            elseif GameplayData.GameCharacters then
                for _, char in pairs(GameplayData.GameCharacters) do all[#all + 1] = char end
            end
        end)
        c.data = all
        c.t = now
        return all
    end

    local function GetEnemyTargets(player, radius)
        local result = {}
        if not Valid(player) then return result end

        local allCharacters = GetRawPawnList()
        
        local myTeam = type(player.GetTeamID) == "function" and player:GetTeamID() or nil
        
        for _, actor in pairs(allCharacters) do
            if Valid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
                if actor:GetTeamID() ~= myTeam then
                    local dist = player:GetDistanceTo(actor)
                    if dist <= radius then
                        table.insert(result, actor)
                    end
                end
            end
        end
        -- HOT-DROP MODE: bheed napo. 18+ par level 1, 35+ par level 2 (ESP slicing + lambe vis-cache).
        -- 25 se zyada hue to nearest 25 hi aage (aimbot candidate cap) - door wale agle tick me.
        local n = #result
        _G._SH_Density = n
        _G._SH_PerfLv = (n > 35) and 2 or ((n > 18) and 1 or 0)
        _G._SH_VisTTL = (_G._SH_PerfLv >= 2) and 0.30 or ((_G._SH_PerfLv == 1) and 0.22 or 0.15)
        if n > 25 then
            local scored = {}
            for _, actor in ipairs(result) do
                local d = 99999999
                pcall(function()
                    local dd = player:GetDistanceTo(actor)
                    if dd then d = dd end
                end)
                scored[#scored + 1] = { a = actor, d = d }
            end
            table.sort(scored, function(x, y) return x.d < y.d end)
            result = {}
            for i = 1, 25 do result[i] = scored[i].a end
        end
        return result
    end

    local function GetBoneLocationSafety(target, boneName)
        if not Valid(target) or not boneName then return nil end
        local pos = nil
        pcall(function()
            if type(target.GetBonePos) == "function" then
                pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0})
            end
            if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    pos = target:GetSocketLocation(boneName)
                end
            end
        end)
        return pos
    end

    -- فحص رؤية خفيف وسريع
    local function IsBoneVisible(pc, camLoc, target, bonePos)
        if not Valid(pc) or not Valid(target) or not bonePos or not camLoc then return false end
        if not KismetSystemLibrary or not KismetSystemLibrary.LineTraceSingle then return true end

        local dx = bonePos.X - camLoc.X
        local dy = bonePos.Y - camLoc.Y
        local dz = bonePos.Z - camLoc.Z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist < 50 then return true end

        ReusableStartPos.X = camLoc.X + (dx / dist) * 60
        ReusableStartPos.Y = camLoc.Y + (dy / dist) * 60
        ReusableStartPos.Z = camLoc.Z + (dz / dist) * 60

        local bVisible = false
        pcall(function()
            local bHit = KismetSystemLibrary.LineTraceSingle(
                pc, ReusableStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true
            )

            if bHit then
                local hitActor = nil
                if type(CachedHitResult.GetActor) == "function" then
                    hitActor = CachedHitResult:GetActor()
                elseif CachedHitResult.Actor then
                    hitActor = CachedHitResult.Actor
                end

                if Valid(hitActor) then
                    if hitActor == target or (type(hitActor.IsChildOf) == "function" and hitActor:IsChildOf(target)) then
                        bVisible = true
                    end
                end
            else
                bVisible = true
            end
        end)

        return bVisible
    end

    -- OPTIMIZE: visibility cache (LineTrace har frame nahi, 0.15s TTL per enemy)
    -- 20 enemy x 40fps = 800 raycast/sec ki jagah ~130/sec. Aim same, lag aadha.
    _G._SH_VisCache = _G._SH_VisCache or {}
    local function IsBoneVisibleFast(pc, camLoc, target, bonePos)
        local key = nil
        pcall(function() key = target.PlayerKey or target:GetPlayerKey() end)
        if not key then return IsBoneVisible(pc, camLoc, target, bonePos) end
        key = tostring(key)
        local now = os.clock()
        local e = _G._SH_VisCache[key]
        if e and (now - (e.t or 0)) < (_G._SH_VisTTL or 0.15) then return e.v end
        local v = IsBoneVisible(pc, camLoc, target, bonePos)
        _G._SH_VisCache[key] = { v = v, t = now }
        return v
    end

    local function ProcessAimbotFrame()
        if _G.MemoryConfig then
            if _G.MemoryConfig.IpadView then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = _G.MemoryConfig.IpadFOV or 120
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = true
            elseif _G.MemoryConfig._IpadWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local uTPPCam = player.ThirdPersonCameraComponent
                        if Valid(uTPPCam) and not player.bIsWeaponAiming then
                            uTPPCam.FieldOfView = 90
                        end
                    end
                end)
                _G.MemoryConfig._IpadWasActive = false
            end

            -- ===== SMALL SCOPE (magnified only, red dot stock) =====
            if _G.MemoryConfig.SmallScope then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    local aiming = Valid(player) and (player.bIsWeaponAiming or player.bIsGunADS or player.bIsAiming or player.bIsScopeAiming or player.bADS)
                    local pc = (Valid(player) and type(player.GetPlayerControllerSafety) == "function") and player:GetPlayerControllerSafety() or nil
                    local function doRestore()
                        if Valid(pc) then
                            if type(pc.FOV) == "function" then pc:FOV(0) end
                            local camMgr = pc.PlayerCameraManager
                            if Valid(camMgr) then
                                if _G.MemoryConfig._SmallScopeSavedFOV ~= nil then camMgr.DefaultFOV = _G.MemoryConfig._SmallScopeSavedFOV _G.MemoryConfig._SmallScopeSavedFOV = nil end
                                if type(camMgr.UnlockFOV) == "function" then camMgr:UnlockFOV() end
                            end
                        end
                        _G.MemoryConfig._SmallScopeWasActive = false
                    end
                    if aiming and Valid(pc) then
                        -- Har tick FOV sample karo (latch-race fix): game ka zoom ADS ke
                        -- kuch frame BAAD lagta hai, pehle-frame latch hamesha "not mag" pakadta tha
                        local curFOV = nil
                        pcall(function()
                            local cm0 = pc.PlayerCameraManager
                            if Valid(cm0) and type(cm0.GetFOVAngle) == "function" then curFOV = cm0:GetFOVAngle() end
                        end)
                        local scopeFOVNow = _G.MemoryConfig.SmallScopeFOV or 75
                        local magNow = (curFOV == nil or curFOV < 60)
                        if not magNow and curFOV and _G.MemoryConfig._SmallScopeWasActive
                           and math.abs(curFOV - scopeFOVNow) < 3 then
                            magNow = true -- hamara forced FOV hai, red-dot mat samjho
                        end
                        if _G.MemoryConfig._scopeLatched == nil then
                            _G.MemoryConfig._scopeIsMag = magNow
                            _G.MemoryConfig._scopeLatched = true
                            if _G.SH_Dbg then _G.SH_Dbg("scope ads curfov=" .. tostring(curFOV) .. " mag=" .. tostring(magNow)) end
                        elseif magNow and not _G.MemoryConfig._scopeIsMag then
                            -- Game ka zoom late aaya: latch update karo taaki scope lage
                            _G.MemoryConfig._scopeIsMag = true
                            if _G.SH_Dbg then _G.SH_Dbg("scope late-zoom curfov=" .. tostring(curFOV)) end
                        end
                        if not _G.MemoryConfig._scopeIsMag then
                            doRestore()
                        else
                            local scopeFOV = _G.MemoryConfig.SmallScopeFOV or 75
                            if type(pc.FOV) == "function" then pc:FOV(scopeFOV) end
                            local camMgr = pc.PlayerCameraManager
                            if Valid(camMgr) then
                                if _G.MemoryConfig._SmallScopeSavedFOV == nil then _G.MemoryConfig._SmallScopeSavedFOV = camMgr.DefaultFOV end
                                camMgr.DefaultFOV = scopeFOV
                                if type(camMgr.SetFOV) == "function" then camMgr:SetFOV(scopeFOV) end
                            end
                            _G.MemoryConfig._SmallScopeWasActive = true
                        end
                    else
                        _G.MemoryConfig._scopeLatched = nil
                        doRestore()
                    end
                end)
            elseif _G.MemoryConfig._SmallScopeWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    local pc = (Valid(player) and type(player.GetPlayerControllerSafety) == "function") and player:GetPlayerControllerSafety() or nil
                    if Valid(pc) then
                        if type(pc.FOV) == "function" then pc:FOV(0) end
                        local camMgr = pc.PlayerCameraManager
                        if Valid(camMgr) then
                            if _G.MemoryConfig._SmallScopeSavedFOV ~= nil then camMgr.DefaultFOV = _G.MemoryConfig._SmallScopeSavedFOV _G.MemoryConfig._SmallScopeSavedFOV = nil end
                            if type(camMgr.UnlockFOV) == "function" then camMgr:UnlockFOV() end
                        end
                    end
                end)
                _G.MemoryConfig._SmallScopeWasActive = false
            end
            -- ===== END SMALL SCOPE =====

            if _G.MemoryConfig.SmallCrosshair then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 0.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = true
            elseif _G.MemoryConfig._CrosshairWasActive then
                pcall(function()
                    local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
                    if Valid(player) then
                        local weapon = nil
                        if type(player.GetCurrentShootWeapon) == "function" then 
                            weapon = player:GetCurrentShootWeapon()
                        elseif type(player.GetCurrentWeapon) == "function" then 
                            weapon = player:GetCurrentWeapon() 
                        elseif player.WeaponManagerComponent and Valid(player.WeaponManagerComponent) and type(player.WeaponManagerComponent.GetCurrentWeapon) == "function" then
                            weapon = player.WeaponManagerComponent:GetCurrentWeapon()
                        end
                        if Valid(weapon) then
                            local entity = weapon.ShootWeaponEntity or weapon.ShootWeaponEntity_GEN_VARIABLE
                            if Valid(entity) then
                                entity.GameDeviationFactor = 1.0
                            end
                        end
                    end
                end)
                _G.MemoryConfig._CrosshairWasActive = false
            end

            
        end

        if not _G.AimbotConfig.Enable then _LockedTarget = nil; return end
        
        local player = type(GameplayData.GetPlayerCharacter) == "function" and GameplayData.GetPlayerCharacter() or nil
        if not Valid(player) then return end
        
        local pc = type(player.GetPlayerControllerSafety) == "function" and player:GetPlayerControllerSafety() or nil
        if not Valid(pc) then return end

        -- ===== IN SCOPE AIMBOT (Hard aimbot when scope ON, 10-100m) =====
        if _G.AimbotConfig.InScopeAimbot then
            local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
            if Valid(camManager) then
                local currentFOV = camManager.GetFOVAngle and camManager:GetFOVAngle() or 90.0
                -- Scope ON = FOV less than 40
                if currentFOV < 40.0 then
                    local cond = _G.AimbotConfig.Condition or 1
                    if cond == 1 and not IsPlayerFiring(player) then
                        -- InScope: also work when just scoped (not firing)
                    else
                        local maxDist = 100 * 100  -- 100m max
                        local minDist = 10 * 100   -- 10m min
                        local enemies = GetEnemyTargets(player, maxDist)
                        if enemies and #enemies > 0 then
                            local myLoc = player:K2_GetActorLocation()
                            local camLoc = camManager:GetCameraLocation()
                            local camRot = camManager:GetCameraRotation()
                            if myLoc and camLoc and camRot then
                                local bestDist = 999999
                                local bestTarget = nil
                                local bestBonePos = nil

                                for _, e in ipairs(enemies) do
                                    if Valid(e) and e:IsAlive() then
                                        local eLoc = e:K2_GetActorLocation()
                                        if eLoc then
                                            local dx = eLoc.X - myLoc.X
                                            local dy = eLoc.Y - myLoc.Y
                                            local dz = eLoc.Z - myLoc.Z
                                            local dist3D = math.sqrt(dx*dx + dy*dy + dz*dz)
                                            if dist3D >= minDist and dist3D <= maxDist then
                                                -- Check if visible
                                                local bonePos = GetBoneLocationSafety(e, _G.AimbotConfig.Bone or "spine_03")
                                                if bonePos then
                                                    local screenOk = pc:ProjectWorldLocationToScreen(bonePos, ReusableScreenPos, false)
                                                    if screenOk and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                                                        local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
                                                        if viewportSize then
                                                            local cx = viewportSize.X * 0.5
                                                            local cy = viewportSize.Y * 0.5
                                                            local sdx = ReusableScreenPos.X - cx
                                                            local sdy = ReusableScreenPos.Y - cy
                                                            local screenDist = math.sqrt(sdx * sdx + sdy * sdy)
                                                            local inScopeFOV = (cx * 0.3)  -- tight FOV for scope
                                                            if screenDist < inScopeFOV and screenDist < bestDist then
                                                                bestDist = screenDist
                                                                bestTarget = e
                                                                bestBonePos = bonePos
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                if bestTarget and bestBonePos then
                                    -- HARD AIM: Direct snap, no smoothing
                                    local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestBonePos)
                                    if targetRot then
                                        local deltaYaw = targetRot.Yaw - camRot.Yaw
                                        local deltaPitch = targetRot.Pitch - camRot.Pitch
                                        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                                        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                                        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                                        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

                                        local finalPitch = camRot.Pitch + deltaPitch
                                        local finalYaw = camRot.Yaw + deltaYaw
                                        pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ShInScope")
                                        return  -- InScope handled, skip normal aimbot
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        -- ===== END IN SCOPE AIMBOT =====

        -- ===== LONG RANGE AIMBOT (500m+ direct snap, big FOV) =====
        if _G.AimbotConfig.LongRange then
            local maxDist = _G.AimbotConfig.Distance or 500
            local enemies = GetEnemyTargets(player, maxDist * 100)
            if enemies and #enemies > 0 then
                local myLoc = player:K2_GetActorLocation()
                local camLoc = camManager:GetCameraLocation()
                local camRot = camManager:GetCameraRotation()
                if myLoc and camLoc and camRot then
                    local bestScreenDist = 999999
                    local bestTarget = nil
                    local bestBonePos = nil
                    for _, e in ipairs(enemies) do
                        if Valid(e) and e:IsAlive() then
                            local eLoc = e:K2_GetActorLocation()
                            if eLoc then
                                local dx = eLoc.X - myLoc.X
                                local dy = eLoc.Y - myLoc.Y
                                local distM = math.sqrt(dx*dx + dy*dy) / 100
                                if distM <= maxDist then
                                    local bonePos = GetBoneLocationSafety(e, "spine_03")
                                    if bonePos then
                                        local screenOk = pc:ProjectWorldLocationToScreen(bonePos, ReusableScreenPos, false)
                                        if screenOk and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                                            local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
                                            if viewportSize then
                                                local cx = viewportSize.X * 0.5
                                                local cy = viewportSize.Y * 0.5
                                                local sdx = ReusableScreenPos.X - cx
                                                local sdy = ReusableScreenPos.Y - cy
                                                local screenDist = math.sqrt(sdx * sdx + sdy * sdy)
                                                local longFOV = cx * 0.8  -- huge FOV for long range
                                                if screenDist < longFOV and screenDist < bestScreenDist then
                                                    bestScreenDist = screenDist
                                                    bestTarget = e
                                                    bestBonePos = bonePos
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestTarget and bestBonePos then
                        local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestBonePos)
                        if targetRot then
                            local deltaYaw = targetRot.Yaw - camRot.Yaw
                            local deltaPitch = targetRot.Pitch - camRot.Pitch
                            if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                            if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                            if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                            if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
                            local finalPitch = camRot.Pitch + deltaPitch
                            local finalYaw = camRot.Yaw + deltaYaw
                            if _G.AimbotConfig.Smooth ~= false then
                                local speedVal = _G.AimbotConfig.Speed or 50
                                local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
                                finalPitch = camRot.Pitch + (deltaPitch * smoothFactor)
                                finalYaw = camRot.Yaw + (deltaYaw * smoothFactor)
                            end
                            -- RECOIL COMPRESSION (Lexus logic): fire karte time recoil upar fekta hai,
                            -- door ka target miss hota hai. Neeche khincho taaki goli body par rahe.
                            local rcVal = _G.AimbotConfig.LongRangeRecoil or 0
                            if rcVal > 0 and IsPlayerFiring(player) then
                                finalPitch = finalPitch - ((rcVal / 8.0) * 1.5)
                            end
                            pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ShLongRange")
                            return
                        end
                    end
                end
            end
        end
        -- ===== END LONG RANGE AIMBOT =====

        -- ===== NORMAL AIMBOT (No FOV, No VisCheck, Instant Snap) =====
        if _G.AimbotConfig.NormalAimbot then
            local maxDistM = _G.AimbotConfig.Distance or 250
            local enemies = GetEnemyTargets(player, maxDistM * 100)
            if not enemies or #enemies == 0 then return end

            local myLoc = player:K2_GetActorLocation()
            if not myLoc then return end

            local bestDist = 999999
            local bestTarget = nil
            local bestDistMeters = 0
            for _, e in ipairs(enemies) do
                if Valid(e) and e:IsAlive() then
                    local eLoc = e:K2_GetActorLocation()
                    if eLoc then
                        local dx = eLoc.X - myLoc.X
                        local dy = eLoc.Y - myLoc.Y
                        local d = math.sqrt(dx*dx + dy*dy)
                        if d < bestDist then
                            bestDist = d
                            bestTarget = e
                            bestDistMeters = d / 100
                        end
                    end
                end
            end
            if not bestTarget then return end

            local aimBone = _G.AimbotConfig.Bone or "spine_03"
            if bestDistMeters > 100 then
                aimBone = "spine_03"
            end

            local headPos = nil
            pcall(function()
                local mesh = bestTarget.Mesh
                if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
                    headPos = mesh:GetSocketLocation(aimBone)
                end
            end)
            if not headPos or (headPos.X == 0 and headPos.Y == 0 and headPos.Z == 0) then
                headPos = GetBoneLocationSafety(bestTarget, aimBone)
            end
            if not headPos then
                pcall(function() headPos = bestTarget:K2_GetActorLocation() end)
                if headPos and aimBone == "spine_03" then headPos.Z = headPos.Z + 50 end
            end
            if not headPos then return end

            local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
            if not Valid(camManager) then return end
            local camLoc = camManager:GetCameraLocation()
            if not camLoc then return end

            local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, headPos)
            if not targetRot then return end

            local finalPitch = targetRot.Pitch
            local finalYaw = targetRot.Yaw

            if _G.AimbotConfig.Smooth ~= false then
                local speedVal = _G.AimbotConfig.Speed or 50
                local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
                local currentRot = pc:GetControlRotation()
                if currentRot then
                    local deltaYaw = targetRot.Yaw - currentRot.Yaw
                    local deltaPitch = targetRot.Pitch - currentRot.Pitch
                    if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
                    if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
                    if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
                    if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
                    finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
                    finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
                end
            end

            pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ShNormalAimbot")
            return
        end
        -- ===== END NORMAL AIMBOT =====
        
        local cond = _G.AimbotConfig.Condition or 1
        if cond == 1 and not IsPlayerFiring(player) then _LockedTarget = nil; return end
        
        local maxDistMeters = _G.AimbotConfig.Distance or 250
        local enemies = GetEnemyTargets(player, maxDistMeters * 100)
        if not enemies or #enemies == 0 then return end
        
        local camManager = GameplayStatics.GetPlayerCameraManager(pc, 0)
        if not Valid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        local camRot = camManager:GetCameraRotation()
        if not camLoc or not camRot then return end

        local viewportSize = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize() or nil
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = ((_G.AimbotConfig.FOV or 30) / 100.0) * centerX
        
        local bestTarget = nil
        local bestTargetBonePos = nil
        local bestScore = 99999999
        
        local useVisCheck = _G.AimbotConfig.VisCheck ~= false
        local igKnock = _G.AimbotConfig.IgnoreKnock or false
        local igBot = _G.AimbotConfig.IgnoreBot or false
        local targetMode = _G.AimbotConfig.TargetMode or 1  -- 1=Nearest, 2=LowHP
        local wallTarget = _G.AimbotConfig.WallTarget or false  -- Through wall aimbot

        -- مرحلة 1: تصفية الهدف الأقرب للشاشة أولاً (بدون إهدار المعالج في LineTrace)
        local _lockStillValid = false
        for _, target in ipairs(enemies) do
            if Valid(target) then
                if igKnock and target.HealthStatus == 1 then goto continue end
                
                if igBot then
                    local tIsBot = (target.bIsAI == true or target.IsAI == true)
                    local pState = target.PlayerState
                    if Valid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                    if tIsBot then goto continue end
                end

                local eLoc = target:K2_GetActorLocation()
                local distM = 0
                if eLoc and myLoc then
                    distM = math.sqrt((eLoc.X - myLoc.X)^2 + (eLoc.Y - myLoc.Y)^2) / 100
                end
                local aimBone = _G.AimbotConfig.Bone or "spine_03"
                if distM > 100 then
                    aimBone = "spine_03"
                end
                local targetBonePos = GetBoneLocationSafety(target, aimBone)
                if targetBonePos and (targetBonePos.X ~= 0 or targetBonePos.Y ~= 0 or targetBonePos.Z ~= 0) then
                    local success = pc:ProjectWorldLocationToScreen(targetBonePos, ReusableScreenPos, false)
                    if success and ReusableScreenPos.X > 0 and ReusableScreenPos.Y > 0 then
                        local dx = ReusableScreenPos.X - centerX
                        local dy = ReusableScreenPos.Y - centerY
                        local distScreen = math.sqrt(dx * dx + dy * dy)

                        if distScreen <= FOV_RADIUS then
                            -- VisCheck: Skip targets behind walls (unless WallTarget enabled)
                            -- OPTIMIZE: cached raycast (0.15s TTL), same accuracy, 6x kam raycast
                            if useVisCheck and not wallTarget then
                                local isVisible = IsBoneVisibleFast(pc, camLoc, target, targetBonePos)
                                if not isVisible then goto continue end
                            end

                            if _LockedTarget and _LockedTarget == target then
                                _lockStillValid = true
                                if targetMode == 2 then
                                    local hp = target.Health or 0
                                    if hp < bestScore then
                                        bestScore = hp
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                else
                                    bestScore = distScreen
                                    bestTarget = target
                                    bestTargetBonePos = targetBonePos
                                end
                            else
                                if targetMode == 2 then
                                    local hp = target.Health or 99999
                                    if hp < bestScore then
                                        bestScore = hp
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                else
                                    if distScreen < bestScore then
                                        bestScore = distScreen
                                        bestTarget = target
                                        bestTargetBonePos = targetBonePos
                                    end
                                end
                            end
                        end
                    end
                end
            end
            ::continue::
        end

        -- If locked target is still valid and in FOV, force use it
        if _LockedTarget and _lockStillValid and Valid(_LockedTarget) and _LockedTarget:IsAlive() then
            bestTarget = _LockedTarget
            local lockBone = GetBoneLocationSafety(_LockedTarget, _G.AimbotConfig.Bone or "spine_03")
            if lockBone then bestTargetBonePos = lockBone end
        elseif _LockedTarget then
            _LockedTarget = nil
        end

        -- Lock new target if none locked
        if bestTarget and not _LockedTarget then
            _LockedTarget = bestTarget
        end
        
        if not Valid(bestTarget) or not bestTargetBonePos then _LockedTarget = nil; return end
        
        -- حساب التوجيه والسلاسة
        local targetRot = KismetMathLibrary.FindLookAtRotation(camLoc, bestTargetBonePos)
        if not targetRot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = targetRot.Yaw - camRot.Yaw
        local deltaPitch = targetRot.Pitch - camRot.Pitch
        
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        -- تعويض السكوب عند فتح الزوم (FIXED: less aggressive pitch correction)
        local currentFOV = camManager.GetFOVAngle and camManager:GetFOVAngle() or 90.0
        if currentFOV < 65.0 then
            local zoomRatio = (65.0 - currentFOV) / 65.0
            local distMeters = player:GetDistanceTo(bestTarget) / 100.0
            if distMeters > 30 then
                -- Reduced correction to prevent aim going into ground
                local pitchCorrection = math.min((distMeters - 30) * 0.006 * zoomRatio, 1.8)
                deltaPitch = deltaPitch - pitchCorrection
            end
        end

        local speedVal = _G.AimbotConfig.Speed or 50
        local finalPitch = currentRot.Pitch + deltaPitch
        local finalYaw = currentRot.Yaw + deltaYaw

        if _G.AimbotConfig.Smooth ~= false then
            local smoothFactor = math.max(0.01, math.min(speedVal / 100.0, 1.0))
            finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
            finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        end
        
        -- RECOIL COMPRESSION (AUTO distance curve): paas me halka, door auto zyada.
        -- slider = master strength (1-8), distance curve automatic.
        local rcVal = _G.AimbotConfig.LongRangeRecoil or 8
        if rcVal > 0 and IsPlayerFiring(player) and Valid(bestTarget) then
            local rDistM = 0
            pcall(function() rDistM = player:GetDistanceTo(bestTarget) / 100.0 end)
            if not rDistM or rDistM < 0 then rDistM = 0 end
            local rScale = 0.3 + math.min(rDistM / 100.0, 2.7)
            finalPitch = finalPitch - ((rcVal / 8.0) * 1.5 * rScale)
        end
        
        pc:SetControlRotation({ Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }, "ShAimbot")
    end

    -- Aimbot driver (time_ticker self-loop, match-proof)
    _G._aimbotGen = 0
    _G.StartAimbotLoop = function()
        _G._aimbotGen = (_G._aimbotGen or 0) + 1
        local gen = _G._aimbotGen
        pcall(function()
            local function AimbotTick()
                if gen ~= _G._aimbotGen then return end
                pcall(function()
                    local tt = require("common.time_ticker")
                    if tt and tt.AddTimerOnce then tt.AddTimerOnce(0.07, AimbotTick) end
                end)
                local _mc = _G.MemoryConfig
                local _needMem = _mc and (_mc.IpadView or _mc.SmallScope or _mc.SmallCrosshair)
                local _needRestore = _mc and (_mc._IpadWasActive or _mc._SmallScopeWasActive or _mc._CrosshairWasActive)
                if (_G.AimbotConfig and _G.AimbotConfig.Enable) or _needMem or _needRestore then pcall(ProcessAimbotFrame) end
                -- NO RECOIL (shake ON): dead code nahi, har tick weapon entity pe apply
                if _G.LexusConfig and _G.LexusConfig.NoRecoilEnabled and _G.ApplyNoRecoil then
                    pcall(_G.ApplyNoRecoil)
                end
            end
            local tt0 = nil
            pcall(function() tt0 = require("common.time_ticker") end)
            if tt0 and tt0.AddTimerOnce then
                tt0.AddTimerOnce(0.07, AimbotTick)
                _G._aimbotTimer = true
            elseif _G.Game and _G.Game.AddGameTimer then
                _G._aimbotTimer = _G.Game:AddGameTimer(0.07, true, AimbotTick)
            elseif slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if Valid(pc) and type(pc.AddGameTimer) == "function" then
                    _G._aimbotTimer = pc:AddGameTimer(0.07, true, AimbotTick)
                end
            end
        end)
    end
    pcall(function() if _G.StartAimbotLoop then _G.StartAimbotLoop() end end)




    -- ============================================================
    -- CHAMS (ENGINE DYEING) - PORTED FROM LEXUS / help.lua (WORKING)
    -- ============================================================
    _G.BRChamsConfig = _G.BRChamsConfig or {
        Enable = true,
        VisColor = 3,   -- 1=Red 2=Blue 3=Green 4=Yellow 5=Orange 6=Pink
        OccColor = 1,   -- 1=Red 2=Blue 3=Green 4=Yellow 5=Orange 6=Pink
    }

    local _chams_LC = nil
    local function _chamsGetLC()
        if _chams_LC == nil then _chams_LC = import("LinearColor") or _G.FLinearColor end
        return _chams_LC
    end
    local _chams_SK = nil
    local function _chamsGetSK()
        if _chams_SK == nil then _chams_SK = import("SkeletalMeshComponent") end
        return _chams_SK
    end

    local function ChamsGetColors(isBot)
        local vi = _G.BRChamsConfig.VisColor or 3
        local oc = _G.BRChamsConfig.OccColor or 1
        local LC = _chamsGetLC()
        local mk = function(r, g, b, a) return (LC and LC(r, g, b, a)) or {R=r, G=g, B=b, A=a} end
        local P = {
            [1] = mk(100, 0, 0, 1),
            [2] = mk(0, 40, 100, 1),
            [3] = mk(0, 100, 0, 1),
            [4] = mk(100, 100, 0, 1),
            [5] = mk(100, 50, 0, 1),
            [6] = mk(100, 0, 60, 1),
        }
        local vis = P[vi] or P[3]
        local occ = P[oc] or P[1]
        return vis, occ
    end

    local function ChamsGetMeshes(enemy)
        local meshes = {}
        if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
        pcall(function()
            local SK = _chamsGetSK()
            if SK and type(enemy.GetComponentsByClass) == "function" then
                local childs = enemy:GetComponentsByClass(SK)
                if childs then
                    local count = type(childs.Num) == "function" and childs:Num() or #childs
                    for i = 1, count do
                        local comp = type(childs.Get) == "function" and childs:Get(i - 1) or childs[i]
                        if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                    end
                end
            end
        end)
        pcall(function()
            local w = enemy:GetCurrentWeapon()
            if Valid(w) and Valid(w.Mesh) then table.insert(meshes, w.Mesh) end
        end)
        return meshes
    end

    local _chamsConsoleReady = false
    local function ChamsEnableConsole()
        if _chamsConsoleReady then return end
        pcall(function()
            local KSL = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KSL and world then
                KSL.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KSL.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KSL.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KSL.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                _chamsConsoleReady = true
            end
        end)
    end

    local function ApplyChams(enemy)
        if not Valid(enemy) then return end
        pcall(function()
            ChamsEnableConsole()
            local isBot = false
            pcall(function()
                if enemy.bIsAI == true or enemy.IsAI == true then isBot = true end
                local ps = enemy.PlayerState or (type(enemy.GetPlayerState) == "function" and enemy:GetPlayerState())
                if Valid(ps) and (ps.bIsABot == true or ps.bIsBot == true) then isBot = true end
            end)
            local meshes = ChamsGetMeshes(enemy)
            local visColor, occColor = ChamsGetColors(isBot)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(true)
                            mesh:SetDrawDyeingMode(1)
                            mesh:SetVisibleDyeingColor(visColor)
                            mesh:SetOccludedDyeingColor(occColor)
                            mesh:SetDyeingColorFadeDistance(99999.0)
                            mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                            mesh:SetDrawHighlight(true)
                            mesh:OverrideHighlightColor(visColor)
                            mesh:SetHighlightCanBeOccluded(false)
                            mesh:SetDrawIdeaOutline(true)
                            mesh:SetIdeaOutlineNew(true)
                            mesh:SetIdeaOutlineOcclusionHighlight(true)
                            mesh:OverrideIdeaOutlineColor(visColor)
                            mesh:SetIdeaOutlineOcclusionColor(occColor)
                            mesh:OverrideIdeaOutlineThickness(20.0)
                            mesh:SetIdeaOverrideOutlineAndOcclusion(true)
                            mesh:SetRenderCustomDepth(true)
                            mesh:SetCustomDepthStencilValue(255)
                        end
                    end)
                end
            end
        end)
    end

    local function UndoChams(enemy)
        if not Valid(enemy) then return end
        pcall(function()
            local meshes = ChamsGetMeshes(enemy)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(false)
                            mesh:SetDrawHighlight(false)
                            mesh:SetDrawIdeaOutline(false)
                            mesh:SetRenderCustomDepth(false)
                        end
                    end)
                end
            end
        end)
    end

    _G._chamsTimer = _G._chamsTimer or nil
    -- OPTIMIZE: already-colored enemy ko har 0.3s dobara paint mat karo (5s skip)
    _G._SH_ChamsDone = _G._SH_ChamsDone or {}
    local function ChamsTick()
        if not _G.BRChamsConfig or not _G.BRChamsConfig.Enable then return end
        pcall(function()
            local GDP = GameplayData
            if not GDP then return end
            local all = GetRawPawnList()
            if not all or #all == 0 then
                all = (GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters()) or {}
            end
            local localChar = nil
            pcall(function() localChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
            local myTeam = nil
            if Valid(localChar) and type(localChar.GetTeamID) == "function" then
                myTeam = localChar:GetTeamID()
            end
            local now = os.clock()
            for _, enemy in pairs(all) do
                if Valid(enemy) and enemy ~= localChar then
                    local isEnemy = true
                    if myTeam and type(enemy.GetTeamID) == "function" then
                        isEnemy = enemy:GetTeamID() ~= myTeam
                    end
                    if isEnemy then
                        if _G.BRChamsConfig.Enable then
                            local ck = nil
                            pcall(function() ck = tostring(enemy.PlayerKey or "") end)
                            if ck and ck ~= "" and _G._SH_ChamsDone[ck] and (now - _G._SH_ChamsDone[ck]) < 5 then
                                -- skip, already painted
                            else
                                ApplyChams(enemy)
                                if ck and ck ~= "" then _G._SH_ChamsDone[ck] = now end
                            end
                        else UndoChams(enemy) end
                    end
                end
            end
        end)
    end

    _G.BRStartChams = function()
        ChamsEnableConsole()
        if _G._chamsTimer then return end
        pcall(function()
            if _G.Game and _G.Game.AddGameTimer then
                _G._chamsTimer = _G.Game:AddGameTimer(0.3, true, ChamsTick)
            elseif slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if Valid(pc) and type(pc.AddGameTimer) == "function" then
                    _G._chamsTimer = pc:AddGameTimer(0.3, true, ChamsTick)
                end
            end
        end)
    end

    _G.BRStopChams = function()
        if _G._chamsTimer then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_G._chamsTimer) end end)
            _G._chamsTimer = nil
        end
        pcall(function()
            local GDP = GameplayData
            if not GDP then return end
            local all = (GDP.GetAllPlayerCharacters and GDP.GetAllPlayerCharacters()) or {}
            for _, enemy in pairs(all) do UndoChams(enemy) end
        end)
    end

    -- ============================================================
    -- PBC WALLHACK (PORTED FROM bb.lua) - ENGINE DYEING + AVATAR SLOTS
    -- ============================================================
    _G.PBCWallhackConfig = _G.PBCWallhackConfig or {
        Enable = false,
        VisColor = 1,
        OccColor = 4,
    }

    local _pbc_LC = nil
    local function _pbcGetLC()
        if _pbc_LC == nil then _pbc_LC = import("LinearColor") or _G.FLinearColor end
        return _pbc_LC
    end

    local _pbc_AVATAR_SLOTS = {0,1,2,3,4,5,6,7}
    _G.PBC_PROCESSED_PAWNS = _G.PBC_PROCESSED_PAWNS or {}

    local _pbc_colorData = {
        [1]={R=0,G=2,B=0,A=0},
        [2]={R=3,G=5,B=0,A=5},
        [3]={R=4,G=1,B=0,A=5},
        [4]={R=2,G=0,B=0,A=2},
        [5]={R=2,G=4,B=18,A=5},
        [6]={R=2,G=2,B=2,A=2},
        [7]={R=0,G=3,B=3,A=3},
    }
    local _pbc_COLOR_PALETTE = {}
    for i,d in pairs(_pbc_colorData) do
        local LC = _pbcGetLC()
        _pbc_COLOR_PALETTE[i] = LC and LC(d.R, d.G, d.B, d.A) or {R=d.R, G=d.G, B=d.B, A=d.A}
    end

    local _pbcConsoleReady = false
    local function PBCSetupConsole()
        if _pbcConsoleReady then return end
        pcall(function()
            local K = import("KismetSystemLibrary")
            local w = slua.getWorld()
            if K and w then
                K.ExecuteConsoleCommand(w, "r.EnableDrawDyeingColor 1")
                K.ExecuteConsoleCommand(w, "r.CustomDepth 3")
                K.ExecuteConsoleCommand(w, "r.IdeaOutline.Enable 1")
                K.ExecuteConsoleCommand(w, "r.Highlight.Enable 1")
            end
            _pbcConsoleReady = true
        end)
    end

    local function PBCApplyToMesh(m, vc, oc)
        if not m or not slua.isValid(m) then return end
        pcall(function()
            m:SetDrawDyeing(true)
            m:SetDrawDyeingMode(1)
            m:SetVisibleDyeingColor(vc)
            m:SetOccludedDyeingColor(oc)
            m:SetDyeingColorFadeDistance(99999.0)
            m:SetDyeingColorMinMaxDistance(0.0, 99999.0)
            m:SetDrawHighlight(true)
            m:OverrideHighlightColor(vc)
            m:SetHighlightCanBeOccluded(false)
            m:SetDrawIdeaOutline(true)
            m:SetIdeaOutlineNew(true)
            m:SetIdeaOutlineOcclusionHighlight(true)
            m:OverrideIdeaOutlineColor(vc)
            m:SetIdeaOutlineOcclusionColor(oc)
            m:OverrideIdeaOutlineThickness(20.0)
            m:SetIdeaOverrideOutlineAndOcclusion(true)
            m:SetRenderCustomDepth(true)
            m:SetCustomDepthStencilValue(255)
        end)
    end

    local function PBCGetColorFromIndex(i)
        return _pbc_COLOR_PALETTE[i] or _pbc_COLOR_PALETTE[1]
    end

    -- FIX: timer handle global rakho taaki next match me dead timer clear karke restart ho sake
    _G._pbc_WH_TIMER = _G._pbc_WH_TIMER or nil
    local _pbc_WH_TIMER = _G._pbc_WH_TIMER
    local function _pbc_SetTimer(h) _pbc_WH_TIMER = h; _G._pbc_WH_TIMER = h end
    local function PBCTick()
        if not _G.PBCWallhackConfig or not _G.PBCWallhackConfig.Enable then return end
        pcall(function()
            local lp = GameplayData.GetPlayerCharacter()
            if not slua.isValid(lp) then return end
            PBCSetupConsole()
            _G.PBC_TICK = (_G.PBC_TICK or 0) + 1
            if _G.PBC_TICK % 6 == 0 then _G.PBC_PROCESSED_PAWNS = {} end
            local mt = lp.TeamID or 0
            local all = Game:GetAllPlayerPawns() or {}
            local pc = 0
            for _,p in pairs(all) do
                if pc >= 20 then break end
                if not slua.isValid(p) or p == lp then goto pbc_cont end
                if p.PlayerKey and _G.PBC_PROCESSED_PAWNS[p.PlayerKey] then goto pbc_cont end
                local alive = false
                pcall(function() if p.Health and p.Health > 0 then alive = true end end)
                if alive and p.TeamID and p.TeamID ~= mt then
                    local vc = PBCGetColorFromIndex(_G.PBCWallhackConfig.VisColor or 1)
                    local oc = PBCGetColorFromIndex(_G.PBCWallhackConfig.OccColor or 3)
                    pcall(function()
                        if slua.isValid(p.Mesh) then PBCApplyToMesh(p.Mesh, vc, oc) end
                        local a = p.CharacterAvatarComp2_BP or (type(p.getAvatarComponent2) == "function" and p:getAvatarComponent2())
                        if a and a.GetMeshCompBySlot then
                            for _,s in ipairs(_pbc_AVATAR_SLOTS) do
                                local m = a:GetMeshCompBySlot(s)
                                if slua.isValid(m) then PBCApplyToMesh(m, vc, oc) end
                            end
                        end
                    end)
                    if p.PlayerKey then _G.PBC_PROCESSED_PAWNS[p.PlayerKey] = true end
                    pc = pc + 1
                end
                ::pbc_cont::
            end
        end)
    end

    _G.PBCStartWallhack = function()
        if _pbc_WH_TIMER or _G._pbc_WH_TIMER then return end
        if not _G.PBCWallhackConfig or not _G.PBCWallhackConfig.Enable then return end
        PBCSetupConsole()
        if _G.Game and _G.Game.AddGameTimer then
            _pbc_SetTimer(_G.Game:AddGameTimer(0.3, true, PBCTick))
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) and pc.AddGameTimer then
                _pbc_SetTimer(pc:AddGameTimer(0.3, true, PBCTick))
            end
        end
    end

    _G.PBCStopWallhack = function()
        if _pbc_WH_TIMER or _G._pbc_WH_TIMER then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_pbc_WH_TIMER or _G._pbc_WH_TIMER) end end)
            _pbc_SetTimer(nil)
        end
        _G.PBC_PROCESSED_PAWNS = {}
    end

    -- ============================================================
    -- BLUE FRAME ESP (Native Game Method - REAL BLUE FRAME)
    -- Uses Replay_CreateEnemyFrameUI / Replay_SetVisiableOfFrameUI
    -- ============================================================
    _G.BlueFrameConfig = _G.BlueFrameConfig or { Enable = false }
    _G._bf_Timer = _G._bf_Timer or nil
    local _bf_Timer = _G._bf_Timer
    local function _bf_SetTimer(h) _bf_Timer = h; _G._bf_Timer = h end

    local function _bf_DrawFrame()
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not slua.isValid(pc) then return end
            local localChar = pc:GetPlayerCharacterSafety()
            if not slua.isValid(localChar) then return end
            local allChars = Game:GetAllPlayerPawns() or {}
            local localTeam = localChar.TeamID or 0
            for _, enemy in pairs(allChars) do
                if slua.isValid(enemy) and enemy ~= localChar and enemy.TeamID ~= localTeam then
                    local isAlive = true
                    pcall(function()
                        if enemy.HealthStatus then
                            local ECharHPStatus = import("ECharacterHealthStatus")
                            isAlive = (enemy.HealthStatus ~= ECharHPStatus.FinishedLastBreath)
                        end
                    end)
                    if isAlive then
                        pcall(function()
                            if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then
                                enemy:Replay_CreateEnemyFrameUI(true, true)
                            end
                            if enemy.Replay_SetVisiableOfFrameUI then
                                enemy:Replay_SetVisiableOfFrameUI(true)
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then
                                enemy:Replay_SetVisiableOfFrameUI(false)
                            end
                        end)
                    end
                end
            end
        end)
    end

    _G.BlueFrameStart = function()
        if _bf_Timer or _G._bf_Timer then return end
        if not _G.BlueFrameConfig or not _G.BlueFrameConfig.Enable then return end
        if _G.Game and _G.Game.AddGameTimer then
            _bf_SetTimer(_G.Game:AddGameTimer(0.3, true, _bf_DrawFrame))
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) and pc.AddGameTimer then
                _bf_SetTimer(pc:AddGameTimer(0.3, true, _bf_DrawFrame))
            end
        end
    end

    _G.BlueFrameStop = function()
        if _bf_Timer or _G._bf_Timer then
            pcall(function() if _G.Game then _G.Game:RemoveGameTimer(_bf_Timer or _G._bf_Timer) end end)
            _bf_SetTimer(nil)
        end
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) then
                local localChar = pc:GetPlayerCharacterSafety()
                if slua.isValid(localChar) then
                    local allChars = Game:GetAllPlayerPawns() or {}
                    local localTeam = localChar.TeamID or 0
                    for _, enemy in pairs(allChars) do
                        if slua.isValid(enemy) and enemy ~= localChar and enemy.TeamID ~= localTeam then
                            pcall(function()
                                if enemy.Replay_SetVisiableOfFrameUI then
                                    enemy:Replay_SetVisiableOfFrameUI(false)
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end

    -- ============================================================
    -- CAR FLY SYSTEM (SRC HUB Vehicle Fly With Horn by XThrlen)
    -- Horn HOLD = UP | Horn Stop = HOVER
    -- Speed = Hover Fly | L/R = turn
    -- Back tap = Back | Back HOLD = Slowly LAND
    -- ============================================================
    _G.CarFlyConfig = _G.CarFlyConfig or { Enable = false, FlySpeed = 1.0 }

    local TXtime_ticker_CF = nil
    pcall(function() TXtime_ticker_CF = require('common.time_ticker') end)

    local CF_CFG = {
        RiseSpeed     = 1800,       -- horn dabao = tez upar jaao (pehle 650 tha)
        HoverRise     = 900,        -- horn hold karne pe持续上升 speed
        FallSpeed     = 600,        -- landing speed
        FlyForwardMax = 2600,
        FlyBackMax    = 1400,
        FlyAccel      = 4500,
        Damp          = 1.8,
        TurnRate      = 110,
        TapBackTime   = 0.25,
        LightMass     = 150,
        ServerSync    = true,
        SyncInterval  = 0.05,
        TiltDamping   = 8.0,        -- car ko level rakhega flight me
        HoverDamp     = 0.6,        -- hover me smooth movement
    }

    local CF_S = { veh=nil, lastVeh=nil, flying=false,
                   vx=0, vy=0, vz=0, downT=0,
                   lastLandZ=nil, landT=0, syncT=0,
                   savedMass=nil, mc=nil,
                   hoverZ=nil, tiltX=0, tiltY=0 }

    local function CF_GetMyVehicle()
        local ok, veh = pcall(function()
            if not slua_GameFrontendHUD then return nil end
            local pc = slua_GameFrontendHUD:GetPlayerController()
            if not pc or not slua.isValid(pc) then return nil end
            local ch = pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety() or nil
            if not ch or not slua.isValid(ch) then return nil end
            return ch:GetCurrentVehicle()
        end)
        if ok and veh and slua.isValid(veh) then return veh end
        return nil
    end

    local function CF_ReadInputs(veh)
        local inp = { down=false, fwd=false, steer=0 }
        pcall(function()
            local mc = veh:GetMovementComponent()
            if not mc or not slua.isValid(mc) then return end
            local rb = tonumber(mc.RawBrakeInput) or 0
            local bi = tonumber(mc.BrakeInput) or 0
            local rt = tonumber(mc.RawThrottleInput) or 0
            local ti = tonumber(mc.ThrottleInput) or 0
            local st = tonumber(mc.RawSteeringInput) or 0
            if rb > 0.05 or bi > 0.05 or rt < -0.05 or ti < -0.05 then inp.down = true end
            if rt > 0.05 or ti > 0.05 then inp.fwd = true end
            if st > 0.05 or st < -0.05 then inp.steer = st end
            if not (inp.down or inp.fwd or inp.steer ~= 0) then
                local rs = mc.ReplicatedState
                if rs then
                    if (tonumber(rs.BrakeInput) or 0) > 0.05 then inp.down = true end
                    if (tonumber(rs.ThrottleInput) or 0) > 0.05 then inp.fwd = true end
                    local s2 = tonumber(rs.SteeringInput) or 0
                    if s2 > 0.05 or s2 < -0.05 then inp.steer = s2 end
                end
            end
        end)
        return inp
    end

    local CF_SETV_MODE = 0
    local function CF_SetVel(rc, vec)
        if CF_SETV_MODE ~= 2 then
            if pcall(function() rc:SetAllPhysicsLinearVelocity(vec, false) end) then
                CF_SETV_MODE = 1
                return true
            end
            CF_SETV_MODE = 2
        end
        local ok = pcall(function() rc:SetPhysicsLinearVelocity(vec, false, "None") end)
        if not ok then
            ok = pcall(function() rc:SetPhysicsLinearVelocity(vec, false) end)
        end
        return ok
    end

    local CF_ANG_MODE = 0
    local function CF_SetAngVel(rc, vx, vy, vz)
        if CF_ANG_MODE ~= 2 then
            if pcall(function() rc:SetPhysicsAngularVelocityInDegrees(FVector(vx, vy, vz), false, "None") end) then
                CF_ANG_MODE = 1
                return true
            end
            CF_ANG_MODE = 2
        end
        return pcall(function() rc:SetPhysicsAngularVelocity(FVector(vx, vy, vz), false, "None") end)
    end

    local function CF_SaveAndLighten(veh)
        pcall(function()
            local mc = veh:GetMovementComponent()
            if mc and slua.isValid(mc) then
                CF_S.mc = mc
                local okM, mval = pcall(function() return tonumber(mc.Mass) end)
                CF_S.savedMass = (okM and mval) or nil
                pcall(function() mc.Mass = CF_CFG.LightMass end)
            end
        end)
    end

    local function CF_RestoreMass()
        pcall(function()
            if CF_S.mc and slua.isValid(CF_S.mc) and CF_S.savedMass then
                CF_S.mc.Mass = CF_S.savedMass
            end
        end)
        CF_S.mc, CF_S.savedMass = nil, nil
    end

    local function CF_EnterFly()
        CF_SaveAndLighten(CF_S.veh)
        CF_S.flying, CF_S.vx, CF_S.vy, CF_S.vz = true, 0, 0, 0
        CF_S.downT, CF_S.hoverZ, CF_S.landT, CF_S.lastLandZ = 0, nil, 0, nil
        CF_S.tiltX, CF_S.tiltY = 0, 0
    end

    local function CF_ExitFly(reason)
        CF_RestoreMass()
        CF_S.flying, CF_S.vx, CF_S.vy, CF_S.vz = false, 0, 0, 0
        CF_S.downT, CF_S.hoverZ, CF_S.landT, CF_S.lastLandZ = 0, nil, 0, nil
        CF_S.tiltX, CF_S.tiltY = 0, 0
    end

    local function CF_Tick(dt)
        if not _G.CarFlyConfig or not _G.CarFlyConfig.Enable then return end
        dt = math.min(tonumber(dt) or 0.033, 0.1)

        -- Speed multiplier (1.0 to 5.0)
        local speedMul = _G.CarFlyConfig.FlySpeed or 1.0

        local veh = CF_GetMyVehicle()
        if veh ~= CF_S.veh then
            if CF_S.flying then CF_ExitFly('EXIT VEHICLE') end
            CF_S.veh = veh
        end
        CF_S.lastVeh = veh
        if not veh then return end

        local horn = false
        pcall(function() horn = (veh.bIsUsingHorn == true) end)
        local inp = CF_ReadInputs(veh)

        if horn and not CF_S.flying then
            CF_EnterFly()
        end
        if not CF_S.flying then return end

        if inp.down then CF_S.downT = CF_S.downT + dt else CF_S.downT = 0 end
        local descending = inp.down and (CF_S.downT >= CF_CFG.TapBackTime)
        local backing    = inp.down and not descending

        local okL, loc = pcall(veh.K2_GetActorLocation, veh)
        if not okL or not loc then return end

        -- Smooth Z velocity (prevents jitter)
        local targetVz = 0
        if horn then
            -- Horn hold = keep going UP smoothly
            if CF_S.hoverZ == nil then CF_S.hoverZ = loc.Z end
            CF_S.hoverZ = CF_S.hoverZ + CF_CFG.HoverRise * speedMul * dt
            local diff = CF_S.hoverZ - loc.Z
            targetVz = diff * 4.0 * speedMul
            targetVz = math.max(math.min(targetVz, CF_CFG.RiseSpeed * speedMul), -CF_CFG.FallSpeed * speedMul)
        elseif descending then
            targetVz = -CF_CFG.FallSpeed * speedMul
            CF_S.hoverZ = nil
        else
            -- Hover: maintain current altitude smoothly
            if CF_S.hoverZ == nil then CF_S.hoverZ = loc.Z end
            local diff = CF_S.hoverZ - loc.Z
            targetVz = diff * 3.0
            targetVz = math.max(math.min(targetVz, 400), -350)
        end
        
        -- Smooth interpolation (prevents sudden jumps)
        CF_S.vz = CF_S.vz + (targetVz - CF_S.vz) * CF_CFG.HoverDamp

        local fx, fy = 0, 0
        pcall(function()
            local f = veh:GetActorForwardVector()
            fx, fy = f.X, f.Y
        end)
        local flen = math.sqrt(fx * fx + fy * fy)
        if flen > 0.001 then fx, fy = fx / flen, fy / flen end

        if inp.fwd then
            CF_S.vx = CF_S.vx + fx * CF_CFG.FlyAccel * speedMul * dt
            CF_S.vy = CF_S.vy + fy * CF_CFG.FlyAccel * speedMul * dt
        elseif backing then
            CF_S.vx = CF_S.vx - fx * CF_CFG.FlyAccel * speedMul * dt
            CF_S.vy = CF_S.vy - fy * CF_CFG.FlyAccel * speedMul * dt
        else
            local d = math.max(0, 1 - CF_CFG.Damp * dt)
            CF_S.vx, CF_S.vy = CF_S.vx * d, CF_S.vy * d
        end
        local hs = math.sqrt(CF_S.vx * CF_S.vx + CF_S.vy * CF_S.vy)
        local hmax = backing and CF_CFG.FlyBackMax or CF_CFG.FlyForwardMax
        if hs > hmax then
            local sc = hmax / hs
            CF_S.vx, CF_S.vy = CF_S.vx * sc, CF_S.vy * sc
        end

        local vec = FVector(CF_S.vx, CF_S.vy, CF_S.vz)
        pcall(function()
            local rc = veh:K2_GetRootComponent()
            if rc and slua.isValid(rc) then CF_SetVel(rc, vec) end
        end)
        pcall(function()
            local m = veh.Mesh
            if m and slua.isValid(m) then CF_SetVel(m, vec) end
        end)

        -- Tilt stabilization: keep car level during flight (prevents flipping/glitching)
        pcall(function()
            local rc = veh:K2_GetRootComponent()
            if rc and slua.isValid(rc) then
                local turnAng = -(inp.steer or 0) * CF_CFG.TurnRate
                -- Add damping to roll/pitch to keep car flat
                CF_SetAngVel(rc, -CF_S.tiltX * CF_CFG.TiltDamping, -CF_S.tiltY * CF_CFG.TiltDamping, turnAng)
            end
        end)

        -- Track tilt for stabilization
        pcall(function()
            local rot = veh:K2_GetActorRotation()
            if rot then
                CF_S.tiltX = rot.Pitch * 0.1
                CF_S.tiltY = rot.Roll * 0.1
            end
        end)

        CF_S.syncT = CF_S.syncT + dt
        if CF_CFG.ServerSync and CF_S.syncT >= CF_CFG.SyncInterval then
            CF_S.syncT = 0
            pcall(veh.ServerImpulseVehicle, veh, FVector(CF_S.vx, CF_S.vy, CF_S.vz), false)
        end

        if descending then
            if CF_S.lastLandZ and math.abs(loc.Z - CF_S.lastLandZ) < 2 then
                CF_S.landT = CF_S.landT + dt
            else
                CF_S.landT = 0
            end
            CF_S.lastLandZ = loc.Z
            if CF_S.landT >= 0.35 then
                CF_ExitFly('LANDED')
                return
            end
        else
            CF_S.landT, CF_S.lastLandZ = 0, nil
        end
    end

    _G.CarFlyConfig.Start = function()
        if _G.CarFlyConfig._Timer then return end
        pcall(function()
            if TXtime_ticker_CF then
                _G.CarFlyConfig._Timer = TXtime_ticker_CF.AddTimerLoop(0, CF_Tick, -1, 0)
            else
                local pc = nil
                pcall(function() pc = slua_GameFrontendHUD:GetPlayerController() end)
                if pc and slua.isValid(pc) and pc.AddGameTimer then
                    _G.CarFlyConfig._Timer = pc:AddGameTimer(0.03, true, CF_Tick)
                end
            end
        end)
    end

    _G.CarFlyConfig.Stop = function()
        CF_ExitFly('DISABLED')
        if _G.CarFlyConfig._Timer then
            pcall(function()
                if TXtime_ticker_CF then
                    TXtime_ticker_CF.RemoveTimer(_G.CarFlyConfig._Timer)
                else
                    local pc = nil
                    pcall(function() pc = slua_GameFrontendHUD:GetPlayerController() end)
                    if pc and slua.isValid(pc) and pc.RemoveGameTimer then
                        pc:RemoveGameTimer(_G.CarFlyConfig._Timer)
                    end
                end
            end)
            _G.CarFlyConfig._Timer = nil
        end
    end

    -- ============================================================
    -- FAST CAR SYSTEM (by kali)
    -- ============================================================
    _G.FastCarEnabled = _G.FastCarEnabled or false
    _G.FastCarSpeed = _G.FastCarSpeed or 3000.0

    _G.FastCarTimer = nil

    local function FastCarTick()
        if not _G.FastCarEnabled then return end
        pcall(function()
            local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not PlayerController then return end
            local uCharacter = PlayerController:GetPlayerCharacterSafety()
            if not uCharacter then return end
            local currentVehicle = uCharacter.CurrentVehicle or (type(uCharacter.GetVehicle) == "function" and uCharacter:GetVehicle())
            if not currentVehicle or not slua.isValid(currentVehicle) then return end

            local rootComp = currentVehicle.RootComponent or (type(currentVehicle.K2_GetRootComponent) == "function" and currentVehicle:K2_GetRootComponent())
            if not rootComp or not slua.isValid(rootComp) then return end

            local moveComp = currentVehicle.VehicleMovement or currentVehicle.MovementComponent
            if not moveComp or not slua.isValid(moveComp) then return end

            local isAccelerating = false
            local throttle = 0
            pcall(function() throttle = tonumber(moveComp.ThrottleInput) or 0 end)
            if throttle < 0.05 then
                pcall(function() throttle = tonumber(moveComp.RawThrottleInput) or 0 end)
            end
            if throttle > 0.05 then isAccelerating = true end

            local speed = _G.FastCarSpeed or 3000.0

            if isAccelerating then
                local fwd = nil
                pcall(function() fwd = currentVehicle:GetActorForwardVector() end)
                if fwd then
                    local vel = FVector(fwd.X * speed, fwd.Y * speed, 0)
                    pcall(function() rootComp:SetAllPhysicsLinearVelocity(vel, false) end)
                end
            else
                local curVel = nil
                pcall(function() curVel = rootComp:GetPhysicsLinearVelocity() end)
                if curVel then
                    local damp = FVector(curVel.X * 0.9, curVel.Y * 0.9, curVel.Z)
                    pcall(function() rootComp:SetAllPhysicsLinearVelocity(damp, false) end)
                end
            end
        end)
    end

    _G.StartFastCar = function()
        if _G.FastCarTimer then return end
        _G.FastCarEnabled = true
        pcall(function()
            if slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if pc and slua.isValid(pc) and pc.AddGameTimer then
                    _G.FastCarTimer = pc:AddGameTimer(0.02, true, FastCarTick)
                end
            end
        end)
    end

    _G.StopFastCar = function()
        _G.FastCarEnabled = false
        if _G.FastCarTimer then
            pcall(function()
                local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if pc and slua.isValid(pc) and pc.RemoveGameTimer then
                    pc:RemoveGameTimer(_G.FastCarTimer)
                end
            end)
            _G.FastCarTimer = nil
        end
    end

    -- ============================================================
    -- BAT NEW POWER (Bat Wings: 10x Speed + 10x Height + Infinite Bar)
    -- + Vampire instant max + Sonar god-scan + Drain 5x
    -- ON: configs 10x + energy methods hooked. OFF: originals restore.
    -- ============================================================
    _G.BatPowerConfig = _G.BatPowerConfig or { Enable = false }
    _G._BatSaved = _G._BatSaved or nil
    _G._BatMethodsSaved = _G._BatMethodsSaved or nil

    local function BatSaveOrig(tbl, key, holder)
        if holder[key] == nil and tbl[key] ~= nil then
            if type(tbl[key]) == "table" then
                local c = {}
                for k, v in pairs(tbl[key]) do c[k] = v end
                holder[key] = c
            else
                holder[key] = tbl[key]
            end
        end
    end

    _G.ApplyBatPower = function()
        if _G._BatMethodsSaved then return end
        _G._BatDiag = { fly="MISS", cfg="MISS", feat="MISS", ui="MISS", vamp="MISS" }
        local D = _G._BatDiag
        _G._BatSaved = _G._BatSaved or {}
        _G._BatMethodsSaved = _G._BatMethodsSaved or {}
        local S = _G._BatSaved
        pcall(function()
            local CommonFlyMoveConfig = require("GameLua.Mod.BaseMod.GamePlay.SpecialMove.CommonFlyMoveConfig")
            if CommonFlyMoveConfig then
                local FlyMoveType = CommonFlyMoveConfig.FlyMoveType.BatFly
                local P = CommonFlyMoveConfig.FlyMoveParams[FlyMoveType]
                if P then
                    D.fly = "OK"
                    BatSaveOrig(P, "FlyRightMaxSpeed", S)
                    BatSaveOrig(P, "FlyBackMaxSpeed", S)
                    BatSaveOrig(P, "GravityScale", S)
                    BatSaveOrig(P, "FlyingMaxHeightAboveGround", S)
                    BatSaveOrig(P, "ExcessHeightFallAccel", S)
                    BatSaveOrig(P, "ExcessHeightMaxFallSpeed", S)
                    BatSaveOrig(P, "FlyingHeightFromCeiling", S)
                    BatSaveOrig(P, "RotationSpeed", S)
                    BatSaveOrig(P, "CameraLagSpeed", S)
                    P.FlyRightMaxSpeed = 9600
                    P.FlyBackMaxSpeed = 9600
                    P.FlyForwardMaxSpeed = 9600
                    P.FlyMaxSpeed = 9600
                    P.MaxFlySpeed = 9600
                    P.GravityScale = 0
                    P.FlyingMaxHeightAboveGround = 15000
                    P.ExcessHeightFallAccel = 9800
                    P.ExcessHeightMaxFallSpeed = 6000
                    P.FlyingHeightFromCeiling = 3000
                    P.RotationSpeed = 70
                    P.CameraLagSpeed = 4000
                    if P.CameraOffsetData then
                        BatSaveOrig(P.CameraOffsetData, "SpringArmLength", S)
                        P.CameraOffsetData.SpringArmLength = 800
                    end
                end
            end
        end)
        pcall(function()
            local BatFlyConfig = require("GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyConfig")
            if BatFlyConfig then
                D.cfg = "OK"
                _G._BatFlyConfigRef = BatFlyConfig
                BatSaveOrig(BatFlyConfig, "EnergyRecoverInterval", S)
                BatSaveOrig(BatFlyConfig, "EnergyRecoverPerSecondByType", S)
                BatSaveOrig(BatFlyConfig, "DamageToEnergyRatio", S)
                BatSaveOrig(BatFlyConfig, "AttachMaxDistance", S)
                BatSaveOrig(BatFlyConfig, "AttachCrosshairTraceDistance", S)
                BatSaveOrig(BatFlyConfig, "AttachTeammateSearchRadius", S)
                BatSaveOrig(BatFlyConfig, "AttachMonsterSearchRadius", S)
                BatSaveOrig(BatFlyConfig, "FollowSearchRadius", S)
                BatSaveOrig(BatFlyConfig, "FlashDistance", S)
                BatSaveOrig(BatFlyConfig, "SonarFanRadius", S)
                BatSaveOrig(BatFlyConfig, "SonarFanAngle", S)
                BatSaveOrig(BatFlyConfig, "SonarDamage", S)
                BatSaveOrig(BatFlyConfig, "AttachDrainDamage", S)
                BatSaveOrig(BatFlyConfig, "AttachDrainHealRatio", S)
                BatSaveOrig(BatFlyConfig, "AttachDrainInterval", S)
                BatSaveOrig(BatFlyConfig, "SonarSlowBuffDurationOnLeave", S)
                BatSaveOrig(BatFlyConfig, "SonarDamageIntrval", S)
                BatSaveOrig(BatFlyConfig, "CheckValidInterval", S)
                BatSaveOrig(BatFlyConfig, "StandbyTriggerTime", S)
                BatFlyConfig.SkillEnergyCostByID = BatFlyConfig.SkillEnergyCostByID or {}
                if BatFlyConfig.SkillID then BatFlyConfig.SkillEnergyCostByID[BatFlyConfig.SkillID] = 0 end
                if BatFlyConfig.DashSkillID then BatFlyConfig.SkillEnergyCostByID[BatFlyConfig.DashSkillID] = 0 end
                if BatFlyConfig.SonarSkillID then BatFlyConfig.SkillEnergyCostByID[BatFlyConfig.SonarSkillID] = 0 end
                BatFlyConfig.EnergyRecoverInterval = 0.1
                BatFlyConfig.EnergyRecoverPerSecondByType = {
                    [BatFlyConfig.AttachTargetType.Building] = 50,
                    [BatFlyConfig.AttachTargetType.Teammate] = 50,
                    [BatFlyConfig.AttachTargetType.Monster] = 50,
                }
                BatFlyConfig.DamageToEnergyRatio = 0
                BatFlyConfig.AttachMaxDistance = 2500
                BatFlyConfig.AttachCrosshairTraceDistance = 5000
                BatFlyConfig.AttachTeammateSearchRadius = 2500
                BatFlyConfig.AttachMonsterSearchRadius = 2500
                BatFlyConfig.FollowSearchRadius = 1500
                BatFlyConfig.FlashDistance = 5000
                BatFlyConfig.SonarFanRadius = 8000
                BatFlyConfig.SonarFanAngle = 53
                BatFlyConfig.SonarDamage = {50, 100, 150}
                BatFlyConfig.AttachDrainDamage = 5000
                BatFlyConfig.AttachDrainHealRatio = 0.2
                BatFlyConfig.AttachDrainInterval = 0.1
                BatFlyConfig.SonarSlowBuffDurationOnLeave = 30
                BatFlyConfig.SonarDamageIntrval = 0.2
                BatFlyConfig.CheckValidInterval = 999999
                BatFlyConfig.StandbyTriggerTime = 5
                BatFlyConfig._SH_Modded = true
                BatFlyConfig.FollowParams = BatFlyConfig.FollowParams or {}
                BatSaveOrig(BatFlyConfig.FollowParams, "MaxFollowDistance", S)
                BatSaveOrig(BatFlyConfig.FollowParams, "MaxLostDistance", S)
                BatFlyConfig.FollowParams.MaxFollowDistance = 2000
                BatFlyConfig.FollowParams.MaxLostDistance = 5000
            end
        end)
        pcall(function()
            local VT = nil
            for _, p in ipairs({
                "GameLua.ExtraModule.SkillCore.Gameplay.BatFly.VampireTransformConfig",
                "GameLua.ExtraModule.SkillCore.Gameplay.Vampire.VampireTransformConfig",
                "GameLua.Mod.BaseMod.GamePlay.Vampire.VampireTransformConfig",
            }) do
                local ok, mod = pcall(require, p)
                if ok and mod and mod.KillVampireCountToLevel then VT = mod break end
            end
            if VT then
                D.vamp = "OK"
                _G._BatSavedVT = _G._BatSavedVT or {}
                if not _G._BatSavedVT.done then
                    _G._BatSavedVT.mod = VT
                    _G._BatSavedVT.KV = VT.KillVampireCountToLevel
                    _G._BatSavedVT.KH = VT.KillHumanCountToLevel
                    if VT.MaxVampireCount then _G._BatSavedVT.Max = VT.MaxVampireCount end
                    _G._BatSavedVT.done = true
                end
                VT.KillVampireCountToLevel = { [1]=1, [2]=1, [3]=1, [4]=1 }
                VT.KillHumanCountToLevel = { [1]=1, [2]=1, [3]=1, [4]=1 }
                if VT.MaxVampireCount then VT.MaxVampireCount = 50 end
            end
        end)
        pcall(function()
            local BatFlyFeature = require("GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyFeature")
            if BatFlyFeature then
                D.feat = "OK"
                local M = _G._BatMethodsSaved
                M.DeductEnergy = BatFlyFeature.DeductEnergy
                M.CheckValidFunc = BatFlyFeature.CheckValidFunc
                M.HandleOnPlayerTakeDamage = BatFlyFeature.HandleOnPlayerTakeDamage
                M.GetCurrentEnergy = BatFlyFeature.GetCurrentEnergy
                M.HasEnergy = BatFlyFeature.HasEnergy
                function BatFlyFeature:DeductEnergy(nAmount)
                    if nAmount == nil or nAmount <= 0 then
                        if M.DeductEnergy then return M.DeductEnergy(self, nAmount) end
                        return
                    end
                    return
                end
                function BatFlyFeature:CheckValidFunc()
                    return true
                end
                function BatFlyFeature:HandleOnPlayerTakeDamage(_, __, uDamageInfo)
                    return
                end
                function BatFlyFeature:GetCurrentEnergy()
                    return self:GetMaxEnergy()
                end
                function BatFlyFeature:HasEnergy(nEnergy)
                    return true
                end
            end
        end)
        pcall(function()
            local BatFlyControlUI = nil
            local ok4 = false
            ok4, BatFlyControlUI = pcall(require, "GameLua.Mod.Library.Client.Hero.BatFly.BatFlyControlUI")
            if not ok4 or not BatFlyControlUI then
                ok4, BatFlyControlUI = pcall(require, "GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyControlUI")
            end
            if ok4 and BatFlyControlUI then
                D.ui = "OK"
                local M = _G._BatMethodsSaved
                M.QueryEnergyPercent = BatFlyControlUI.QueryEnergyPercent
                M.TickPower = BatFlyControlUI.TickPower
                function BatFlyControlUI:QueryEnergyPercent()
                    return 1.0
                end
                function BatFlyControlUI:TickPower(uCharacter)
                    self.fPercent = 1.0
                    self.fBufferPercent = 1.0
                    self:ApplyPercent(1.0, 1.0)
                    self:RefreshLowEnergyGlow(false)
                    self:RefreshPowerVisible(true)
                    return
                end
            end
        end)
    end

    _G.RestoreBatPower = function()
        pcall(function()
            local S = _G._BatSaved or {}
            local CommonFlyMoveConfig = require("GameLua.Mod.BaseMod.GamePlay.SpecialMove.CommonFlyMoveConfig")
            if CommonFlyMoveConfig then
                local P = CommonFlyMoveConfig.FlyMoveParams[CommonFlyMoveConfig.FlyMoveType.BatFly]
                if P then
                    for k, v in pairs(S) do
                        if k ~= "EnergyRecoverPerSecondByType" and k ~= "SonarDamage" and P[k] ~= nil then
                            P[k] = v
                        end
                    end
                    if P.CameraOffsetData and S.SpringArmLength then
                        P.CameraOffsetData.SpringArmLength = S.SpringArmLength
                    end
                    P.FlyForwardMaxSpeed = nil
                    P.FlyMaxSpeed = nil
                    P.MaxFlySpeed = nil
                end
            end
        end)
        pcall(function()
            local BatFlyConfig = _G._BatFlyConfigRef or require("GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyConfig")
            local S = _G._BatSaved or {}
            if BatFlyConfig then
                for k, v in pairs(S) do
                    if BatFlyConfig[k] ~= nil and k ~= "SpringArmLength" then
                        BatFlyConfig[k] = v
                    end
                end
                if BatFlyConfig.FollowParams then
                    if S.MaxFollowDistance then BatFlyConfig.FollowParams.MaxFollowDistance = S.MaxFollowDistance end
                    if S.MaxLostDistance then BatFlyConfig.FollowParams.MaxLostDistance = S.MaxLostDistance end
                end
            end
        end)
        pcall(function()
            local V = _G._BatSavedVT
            if V and V.mod then
                if V.KV then V.mod.KillVampireCountToLevel = V.KV end
                if V.KH then V.mod.KillHumanCountToLevel = V.KH end
                if V.Max ~= nil then V.mod.MaxVampireCount = V.Max end
            end
        end)
        pcall(function()
            local M = _G._BatMethodsSaved or {}
            local BatFlyFeature = require("GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyFeature")
            if BatFlyFeature then
                if M.DeductEnergy then BatFlyFeature.DeductEnergy = M.DeductEnergy end
                if M.CheckValidFunc then BatFlyFeature.CheckValidFunc = M.CheckValidFunc end
                if M.HandleOnPlayerTakeDamage then BatFlyFeature.HandleOnPlayerTakeDamage = M.HandleOnPlayerTakeDamage end
                if M.GetCurrentEnergy then BatFlyFeature.GetCurrentEnergy = M.GetCurrentEnergy end
                if M.HasEnergy then BatFlyFeature.HasEnergy = M.HasEnergy end
            end
        end)
        pcall(function()
            local M = _G._BatMethodsSaved or {}
            local ok4, BatFlyControlUI = pcall(require, "GameLua.Mod.Library.Client.Hero.BatFly.BatFlyControlUI")
            if not ok4 or not BatFlyControlUI then
                ok4, BatFlyControlUI = pcall(require, "GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyControlUI")
            end
            if ok4 and BatFlyControlUI then
                if M.QueryEnergyPercent then BatFlyControlUI.QueryEnergyPercent = M.QueryEnergyPercent end
                if M.TickPower then BatFlyControlUI.TickPower = M.TickPower end
            end
        end)
        _G._BatMethodsSaved = nil
    end

    _G.StartBatPower = function()
        _G.BatPowerConfig.Enable = true
        _G.ApplyBatPower()
    end

    _G.StopBatPower = function()
        _G.BatPowerConfig.Enable = false
        _G.RestoreBatPower()
    end

    -- Har match me dobara lagao (game modules refresh kar deta hai).
    -- Marker check: fresh tables aayi to saved-state saaf karke naye se save karo.
    _G.ReapplyBatPower = function()
        if not (_G.BatPowerConfig and _G.BatPowerConfig.Enable) then return end
        pcall(function()
            local C = nil
            local ok, mod = pcall(require, "GameLua.ExtraModule.SkillCore.Gameplay.BatFly.BatFlyConfig")
            if ok then C = mod end
            if C and not C._SH_Modded then
                _G._BatSaved = nil
                _G._BatMethodsSaved = nil
                _G._BatSavedVT = nil
            end
        end)
        _G.ApplyBatPower()
    end

    -- ============================================================
    -- FORCE TPP (FPP match me TPP view) - scope khula to FPP render hoga
    -- Button ON karte hi start, har match me CharacterBase dobara start karega.
    -- ============================================================
    _G.ForceTPP_Enable = _G.ForceTPP_Enable or false
    local _HRD_FORCE_TPP_TIMER = nil
    local _HRD_SCOPE_CHECK_TIMER = nil
    local _HRD_TPP_HOOKED = false
    local _HRD_HookedPawn = nil
    local _HRD_TimerOnGame = false
    local _HRD_TimerPC = nil
    local _HRD_IsScopeOpen = false

    local function HRD_CheckScopeState()
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not slua.isValid(pc) then return end
            local uPawn = pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety() or nil
            if not slua.isValid(uPawn) then return end
            if uPawn.bIsWeaponAiming or uPawn.bIsGunADS then
                _HRD_IsScopeOpen = true
            else
                _HRD_IsScopeOpen = false
            end
        end)
    end

    _G.HRD_ForceTPPView = function()
        if not _G.ForceTPP_Enable then return end
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if not slua.isValid(pc) then return end
            local uPawn = pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety() or nil
            if not slua.isValid(uPawn) then return end
            if uPawn.bIsWeaponAiming or uPawn.bIsGunADS then return end
            if uPawn.SetCurrentPersonPerspective then
                uPawn:SetCurrentPersonPerspective(false, false)
            end
            if uPawn.LocalSwitchPersonPerspective then
                uPawn:LocalSwitchPersonPerspective(false, true, true)
            end
            if pc.SwitchFpp then
                pc:SwitchFpp(false)
            end
            pcall(function()
                local SI = _G.SI_BattleInterface
                if SI and SI.ClientSetFpp then SI.ClientSetFpp(uPawn, false) end
            end)
            if slua.isValid(pc.PlayerCameraManager) then
                pc.PlayerCameraManager:SetCameraMode(0)
            end
            pcall(function()
                local CGameState = require("GameLua.GameCore.Data.CGameState")
                if CGameState and CGameState.IsFPPGameMode then
                    CGameState.IsFPPGameMode = false
                end
            end)
            if uPawn ~= _HRD_HookedPawn then
                _HRD_TPP_HOOKED = false
                _HRD_HookedPawn = nil
            end
            if uPawn.GetIsFPP and not _HRD_TPP_HOOKED then
                local oldFPP = uPawn.GetIsFPP
                uPawn.GetIsFPP = function()
                    if _G.ForceTPP_Enable then
                        if _HRD_IsScopeOpen then return true end
                        return false
                    end
                    return oldFPP()
                end
                _HRD_TPP_HOOKED = true
                _HRD_HookedPawn = uPawn
            end
        end)
    end

    _G.HRD_StartForceTPP = function()
        if not _G.ForceTPP_Enable then return false end
        if _HRD_FORCE_TPP_TIMER then
            if _HRD_TimerOnGame then return true end
            if _HRD_TimerPC and slua.isValid(_HRD_TimerPC) then return true end
            _HRD_FORCE_TPP_TIMER = nil
            _HRD_SCOPE_CHECK_TIMER = nil
            _HRD_TimerPC = nil
        end
        local created = false
        if _G.Game and _G.Game.AddGameTimer then
            _HRD_SCOPE_CHECK_TIMER = _G.Game:AddGameTimer(0.05, true, HRD_CheckScopeState)
            _HRD_FORCE_TPP_TIMER = _G.Game:AddGameTimer(0.2, true, _G.HRD_ForceTPPView)
            _HRD_TimerOnGame = true
            created = true
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) and pc.AddGameTimer then
                _HRD_SCOPE_CHECK_TIMER = pc:AddGameTimer(0.05, true, HRD_CheckScopeState)
                _HRD_FORCE_TPP_TIMER = pc:AddGameTimer(0.2, true, _G.HRD_ForceTPPView)
                _HRD_TimerOnGame = false
                _HRD_TimerPC = pc
                created = true
            end
        end
        return created
    end

    _G.HRD_StopForceTPP = function()
        _G.ForceTPP_Enable = false
        pcall(function()
            if _G.Game and _G.Game.RemoveGameTimer then
                if _HRD_FORCE_TPP_TIMER then _G.Game:RemoveGameTimer(_HRD_FORCE_TPP_TIMER) end
                if _HRD_SCOPE_CHECK_TIMER then _G.Game:RemoveGameTimer(_HRD_SCOPE_CHECK_TIMER) end
            end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua.isValid(pc) and pc.RemoveGameTimer then
                if _HRD_FORCE_TPP_TIMER then pc:RemoveGameTimer(_HRD_FORCE_TPP_TIMER) end
                if _HRD_SCOPE_CHECK_TIMER then pc:RemoveGameTimer(_HRD_SCOPE_CHECK_TIMER) end
            end
        end)
        _HRD_FORCE_TPP_TIMER = nil
        _HRD_SCOPE_CHECK_TIMER = nil
        _HRD_TimerPC = nil
    end

    -- ============================================================
    -- FAKE HWID (ANTI-BAN) - PORTED FROM LEXUS / help.lua
    -- ============================================================
    _G.BRFakeHWID = _G.BRFakeHWID or { Enable = false }  -- SLIM BYPASS: default OFF (toggle se ON karo)

    local function BRFakeHWID_Notify(msg)
        local s = "[BR] " .. tostring(msg)
        pcall(function() print(s) end)
        pcall(function()
            local sh = import("ScriptHelperClient")
            if sh and sh.AddOnScreenDebugMessage then
                sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1, G=1, B=0, A=1}, {X=1.2, Y=1.2})
            end
        end)
    end

    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then return tostring(_G.Original_GetDeviceId()) end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then return tostring(SystemLib.GetDeviceId()) end
        return "UNKNOWN_DEVICE"
    end

    local function InitFakeHWID()
        pcall(function()
            local SystemLib = import("KismetSystemLibrary")
            if SystemLib and not _G.FakeHWID_Hooked then
                _G.Original_GetDeviceId = SystemLib.GetDeviceId
                SystemLib.GetDeviceId = function(...)
                    if _G.BRFakeHWID.Enable then
                        if not _G.FakeHWID_String then
                            local chars = "0123456789ABCDEF"
                            local hwid = ""
                            for i = 1, 32 do
                                local idx = math.random(1, #chars)
                                hwid = hwid .. chars:sub(idx, idx)
                                if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                            end
                            _G.FakeHWID_String = hwid
                        end
                        return _G.FakeHWID_String
                    end
                    if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                    return "UNKNOWN"
                end
                _G.FakeHWID_Hooked = true
                BRFakeHWID_Notify("Fake HWID Hook Active")
            end
        end)
    end

    InitFakeHWID()

    -- ============================================================
-- ===== COPIED SKIN SYSTEM (from help.lua) START =====
_G.LexusConfig = _G.LexusConfig or {
    FakeHWID = false,
    EspLoai5 = false, EspLoai6 = false, EspLoai7 = false, EspLoai9 = false,
    Esp7_SoLuong = true, Esp7_VuKhi = true, Esp7_TuThe = true,
    Esp9_Count = true, Esp9_Name = true, Esp9_HP = true, Esp9_Team = true,
    Esp9_Weapon = true, Esp9_Distance = true, Esp9_Line = true, Esp9_Skeleton = true,
    EspAntenna = false, EspOutline = false, OutlineThickness = 10,
    Esp3ShowName = true, Esp3ShowHP = true,
    ColorBodyNew = false, ChamsColorVis = 3, ChamsColorOcc = 1,
    WeaponGlow = false,
    CustomAimbot = false, CustomAimbotClose = false, CustomMagicBullet = false,
    CustomHRecoil = false, CustomVRecoil = false,
    LessShake = false, Accuracy = false, Crosshair = false, AutoHead = false, GodMode = false,
    NoRecoilEnabled = true, RecoilReduction = 100, WeaponAimbot = false,
    AimTouchEnable = false,
    AimTouchHipfire = false, AimTouchHipIgKnock = false, AimTouchHipIgBot = false, AimTouchHipVisCheck = false,
    AimTouchSG = false, AimTouchSGAutoFire = false, AimTouchSGIgKnock = false, AimTouchSGIgBot = false, AimTouchSGVisCheck = false,
    AimTouchScopeAll = false, AimTouchScopeIgKnock = false, AimTouchScopeIgBot = false, AimTouchScopeVisCheck = false,
    AimTouchScopeSniper = false, AimTouchSniperIgKnock = false, AimTouchSniperIgBot = false, AimTouchSniperVisCheck = false,
    AimTouchMortar = false,
    IpadView = false, UnlockFPS = false,
    SmallScope = false, SmallScopeFOV = 75,
    BugManEnable = false, FastCar = false, FastCarSpeed = 3000,
    WallVehicle = false, WhiteBody = false, BlackSky = false,
    RemoveFog = false, RemoveGrass = false, RemoveTrees = false,
    ModEmote = false, ModSkin = true, SkinDeadBox = true, SkinAttachment = true,
    KillMessage = false, KillCountUI = false, SkinOpenLink = false,
    EspV3_Master = true, EspV3_Count = true, EspV3_Box = true, EspV3_Line = true, EspV3_Health = true,
    EspV3_Name = true, EspV3_Dist = true, EspV3_Weapon = true, EspV3_Flag = true, EspV3_State = true,
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0, NativeESPReady = false, MenuStep = 0, GraphicsUnlocked = false,
    TrackedMarks = {}, EnemyMarks = {}, CustomTextData = nil,
    PrevGraphicsState = {}, LastMagicConfigHash = "",
}

-- ════════════════════════════════════════════════════
-- ICON LOADER — COMPLETE FIX (v2)
-- Fixes: multi-pkg path, base64 decode, 4-layer fallback,
--        retry cap, debug logging
-- ════════════════════════════════════════════════════

-- [ICON-FIX] Multi-package save-path detector (all PUBG variants)
local function _SH_GetSavePaksDir()
    if _G._SH_SaveDir then return _G._SH_SaveDir end
    local packages = {
        "com.tencent.ig",
        "com.rekoo.pubgm",
        "com.pubg.krmobile",
        "com.vng.pubgmobile",
        "com.pubg.imobile",
        "com.tencent.tmgp.pubgmhd",
    }
    local suffixes = {
        "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/",
        "/files/",
    }
    for _, pkg in ipairs(packages) do
        for _, sfx in ipairs(suffixes) do
            local dir = "/storage/emulated/0/Android/data/" .. pkg .. sfx
            local test = io.open(dir .. ".wtest", "w")
            if test then
                test:close()
                os.remove(dir .. ".wtest")
                _G._SH_SaveDir = dir
                if _G.SH_Dbg then _G.SH_Dbg("ICON save-dir=" .. dir) end
                return dir
            end
        end
    end
    _G._SH_SaveDir = "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/"
    if _G.SH_Dbg then _G.SH_Dbg("ICON save-dir=FALLBACK") end
    return _G._SH_SaveDir
end
_SH_GetSavePaksDir()

    -- ============================================================
    -- ESP V3: snaplines + name + player/bot counter (icons: victortipvala-sys/esp-icons)
    -- ============================================================
    _G.LexusConfig = _G.LexusConfig or {}
    if _G.LexusConfig.EspV3_Master == nil then _G.LexusConfig.EspV3_Master = true end
    for _, _ek in ipairs({"EspV3_Count","EspV3_Box","EspV3_Line","EspV3_Health","EspV3_Name","EspV3_Dist","EspV3_Weapon","EspV3_Flag","EspV3_State"}) do
        if _G.LexusConfig[_ek] == nil then _G.LexusConfig[_ek] = true end
    end
    pcall(function() local _f0 = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt", "w") if _f0 then _f0:write("boot" .. string.char(10)) _f0:close() end end)
    _G.SH_Dbg = function(m) pcall(function() local f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt", "a") if f then f:write(tostring(m) .. string.char(10)) f:close() end end) end
    -- [ICON-FIX] Embedded base64 icons — CORRECT decoder + correct write path
    pcall(function()
        local dir = _G._SH_SaveDir or _SH_GetSavePaksDir()
        if _G.SH_Dbg then _G.SH_Dbg("ICON base64 write-dir=" .. dir) end
        local function _need(p)
            local f = io.open(p, "r")
            if f then f:close() return false end
            return true
        end
        -- [ICON-FIX] Correct base64 decoder (4 chars -> 3 bytes)
        local function _b64d(data)
            local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
            data = string.gsub(data, '[^' .. b .. '=]', '')
            return (data:gsub('.', function(x)
                if x == '=' then return '' end
                local r, f = '', (b:find(x, 1, true) or 0) - 1
                for i = 6, 1, -1 do
                    r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
                end
                return r
            end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
                if #x ~= 8 then return '' end
                local cc = 0
                for i = 1, 8 do
                    cc = cc + (x:sub(i, i) == '1' and 2^(8 - i) or 0)
                end
                return string.char(cc)
            end))
        end
        -- [ICON-FIX] Embedded base64 strings — unchanged
        local _icons = { {"ic_danger_enemy.png", [[iVBORw0KGgoAAAANSUhEUgAAAIAAAABACAYAAADS1n9/AAAMG0lEQVR42u2deXAUVR7HP6+nZ5LJ5L5mMgkTCEfCEYKcBjbhUlAUOcRVwFJ0LXZ1BTGiCAkW4MUNWmgJurIetZRaJbVatRSCIOFaWQiKIKcJRwhJCBASkkCO6f0jN2RyzPRMQjK/qqk+5r3+dffv+37v9/u+7n4CJ8l6MxYBKUIwQwi0Aqj7k0T9bXHbtmRjf/U+iSbq19mm+nj2HquRuvXO1UY5qZG6al2rnXJeVtvwi0AymUlBsADwoA2IwC22RFUAfGghQKngSwXGCVcaVLgN3uoAWB1BoFLOXiGIcbfYu8e7SWqcxPvd8NBZ2QzNM75wW1g1b0dbAIAo5gMg0d2CW95CW/teOQyA98wMBZ51G/juFIcAoIAQgrXtudG3d2/mEADWmXgAhUFuA3dUDyB4wm3QDpoGbuyMZ0EpE4WLDVidQUgennh36YHW24fijFOUXb3stqYrAVBYQj80+LqyhUo6DyyPPkXExOkEDU6sl0/ezM4k+7tNZH31CSUZp9pH/CGc7+3s7gIUie6O5K3elig6T5jabH2m+8YzavvvxL27gaAhw++4O56mCDrPfJX4rUfpvmAlGi+DO/5wKgAE3RxR3O3xZ4lf+SkaT32TZaNnpXDvJ99hsEQ1fVNlLZbnXqH/v35CF2x0xyNqAmA9aFebeHVNGL+gsMARxVm7tqLx8CR0SGKj5XrOWUSvV95s8fF9Ygdyz6ZdyD5+zotHOlIWsCKMJwvNHEewHIjDwXGEy2n7KSu8TljiGIQso/P1v6OMcfhYYmYvtFuHV1Q00Uv/4c4YGhFNUwUW9UY3TuIbIVggILCxcekG99kog9VKcL/BdBo7kZ7PJaH19SM79YfaMW5ZJuGzLegCgmx3Q1YrRWeOowsKsVnG0K0Xhb8e4Oa5M80737a0rwX17JTrTXoAr6tsRDDJGei7lPoDOv9ALh/cy8Vt39X7zzJxOobIro3Wz/3xe46/ldSknshZC91N3Z4uYIWRLorCVGcpz9q1FYCL278n9+fUei6503jbHJO1rJQDMx7k0F8nkZe6lR0DQ8lP22+zvO898XiGR7YrwwlXAKBcENkSXS3NWwNjB1BeUowpccwd+X5II8GhpNXRa+EaUBQAwiZMw79/fKO6/f90f9s2YCs91NJ4IKdwvu6ZqH1SQ1dtRNZ7YRo2GiFJYLVWdjthEWj0Xo1Xtlrx7hqDX+yA5gWEXXq4U8CWAmB+DunLTBwEBjpDeUHGKQL79McjMJiAPv3JP3IQoNHAr4b4CYsgYetvCI1M2fVrTV+of1CHNLDDaaACK5ylPHvvjpr1sKpuQBcQRFzyyqYN6u2L0FTiV+sX0GT54DGTCBr9SIczsMMAmJfNN8AhpwBgXy0ATAmVAOiTtJjgwQnquzq/AKJXfYFU1bW4OYDmxACVN0pZamW2RsMete9b7oHdWMvLkGQtwQPikQ3eeEfWZ5hv5eWQ89OWO4wmbCxr1gX4D0pAb6lNJTXevuiCQrmVedZt+eYSQQDbi7gwxoduAvqqRVwIQCkrxTx8LAazBaHRcOXQfkqvXiZs5IMAFP5xgt3TRqPReaJUlFNekE9ZQf6dy8LaX0XVsjQnizNvvYxX5+54RUUDUHTyNzI3LEMoyl1N+kgqEkHNpnOtEvMlK5MBLzWDpku7txEycFhlN5A4hsOLXgKrlcC4QRxdPp+4hauJGG/fcyemCdM59vcpFKTtQx/RmfPr3qzJNDpCjq+6rlUmFgrBEjVfn9L5+DF+x+/ojWYK00+yZWQMAvDwCyD+482EDBnu0AWWF+RzfM40ru3aou7rWNj/upgzXhWzU863aDRQyHxQmRioJ9EzXkRvNAPgExWNl9lS2Td5GRw2PoDs64/foASXtpq7KcBsEQCSMrkKFKmlvNPYifR9ZUl9t12VDpZcyqQw/aQqevL3/agqS9eh0kBniX9MLMPWflHJANYRYx1aOP3LjxzWU5xximv7d3TIHN9ZALihhmK/qGhkg/cd+43VtDCQsWkDRefTHdKTsWJ+zZiBW9QBwCVVOICDe2vWlYqKmnWdfyABfSuZ54qSYg7NnYG19JZ9RNPmz7m89Vu3lVUGwG41gqaS3EvcqGrdR5YnU5he+ySvMaG2G8g7sJv/zZraYhDkbf83J+b9pd0ZTO3uq0kiaHk4/UYZ8HzYG//JvpQKiX1WeFCAsblpi619QX0HUph+irRFc/Dv2ZfAqpE9SdZy9puNNeWK/jhBzs7/EDxkOLrA4Mb5itJbpK9+g9NLZoO1wnkkjZ3Hc/RrI2o/EdQ0FWyliywx1Grlxg0rICEkO8mg2yX9639y5ZefK939zZKa/b49eiMkCd/uPTHfP4EzHy3j+tE0do7pQ8QjU+k05WkCByciaXW1wd65M+Ru3cyFjWspzclCCAgYlIB3TF+yvvig9VqoaEceZXUE+qRMStaYmCskVqhJqgxY/B49nplNcdZ59jzzMMaho+iVtBjZy5u8/TtJmzuDW9kXa+pqtDr05k5oDT6UZmdSdi2v9ngaDRFPvkD35FVYy8ooOLiHk68+TVletn3f9GmIpLGjrjO/N2QvEWSz6rJwIpQKXhJgkQRdhKCHUPATgutCQQiBr9oAMI8cx87HR9BrVgpRTzzH4ZTnkQ0+xCavRCkrJeOzdZzbtIHis6cbvCmyl4HQ+ybQZdZCDF1jyD+Qytm1b9AteTWyXyBHZ4zh1m117Wbp2gkAbHYBJRfJ8jQiI5gMyDX8n4KfM1zRzSu5pM4YR7+UVZhGPICQZSQPTyStFiFJCA9Pus6cS9eZcynKOMW1w/+lNC+HiuIi9OZO6M0WAgYnIulqv0ul8TJQXliANtiIbPAh7qs9HH1yFCWnj7nD/+Z2AcvNDMNKVyEIlxTihCBegEVtXl2SNcS9vhRj/EgOLfgbsa+9gzFBnef4ygvyOfHydHz7DcE46SmOPDqE8iu5bg/Q1FjAUhPPK1b2CMGnQiEeWJ90iUgF5qiNwMhHphIzcy5e4ZFoDT54BKj3CJfs64+H2YLsH4hHRGdiPvwWJKn9tVa1j7nMxBRggSToKqjp89MEpArBnOZ4gOa0KH2IiYd2/I6uGY92qSVn304ie+OaNuUBHBmBdIoHUCSyBWwDDlM7CNSfOh5ADVQOWLTWpcYHsCS9iUfVyKNqrUm4vgU77B1v3/E1aP4w8gyCZKx0dvYJ+PXoTaeHHnM9Bao3YJ75GmcXv9iqLrhNUcErjBjOmNiuCD4G5xsfoNcL8+4YEXSVhEx5Fm1QaLs2cIsAUArvKjDCVcq13j5EPvzn1rt4Tz1B46d16DSwHgAUSHCl8vBRD9XL21tDAsdOdgOgDgL2uRoArS3e9wxFdnEA2mYBUF7OfASnXZW3Bsb2b/3cWqPBKyauzef4zopP5CVGXlcgVCPIRiFV0TBSlPMZMNqZUbHGwxNfF7+waUv00X0p/Pmnu47EUQUACrwj4JyiECLAIMopQuE0gnKh8nwCdcUz2IiQ5TZxE3SmcIcterdmEJKAH4FIoPq7agYE/XCi8aszgLYiGoNPh/ggVMMeQLBfUggGegE6VykuvX6NI2sW2XzHry7F2WiZqhWb/1VvC9vHKTnxa4cNAsXbwYRVaDhRw/W3kbdnmuLlm1sXXDRxE607sZSdcl5KzuMSCrPaHDJxi8vSwDdy+VzAOreB26ibdgUPkJLDLOAloLwt561uAzuRCErJ4X2sjAMK3AZs+ySO6gAASM5lm2IlAYWLbtO2f2/W4Dhsci5HhMy9QJrbwB0gCGxI5l0ks8STYSisAcruKoO6ZxJVF/xLA/CT9cRKChYEFqFgkQQWQc3Pz5V5tZoTR7eJyZ9x/HUxe3kAVRrH+ij8SkuxaBQsKIRqKh8bDxUQXLW0CAiuJpucMHP4GaHwZbU7k6R6rq2bBI8Kgb7qYt+WFMqkKmRUHWuEgOGichq8lgAgX0CmBJkILmiojJuk29yrdPs+qZH/6i6lRv6rU8YBue5S7/h1b3RFRZhlBTMKBgFmAR4ShCngKYFJgJekECoEBiEIqbrh4YKqKegbBsChBzJsf8304AC0hVcIx0DeyGMNf98grQuRVpmnhMJjVdPdZwN5Am5oBGcluKFAnqSQJUNmmY4LvY+p862E1pT/A0yWGDod/ujuAAAAAElFTkSuQmCC]]}, {"ic_clear_boot.png", [[iVBORw0KGgoAAAANSUhEUgAAAIAAAABACAYAAADS1n9/AAALGElEQVR42u1de1BU1xn/ffcuC8siDxUhCL4QHEBsFCTG56Sx8ZFo6oPYcdIYY4Muamw7Y5qaToNtiUmnCZpEXOgjyRQSIzbRMRhfkzhqUVsDQQWrJAryUFDkjbDLvad/wPJY9gn7hPsxw91793z3nnO/3/3O9/3OuWcJA5AlW5d4NimbHhcIsziOjQAwhmPcRYGEk3mpeWWQxG2E4jbPvAUAHEedB7q2IICIera67zr3g0BQ9CnT+Q8cR5UM0PbRJQBcZ5nufZ0OB3SdHuC4zo2+ru4z13Md/bqBAOJ1zeI660IGyurO0as9QO8yner65+hzHt29ItLTNXyOfnVBv/aIINwm4qoBlIGj480+DedyYnI0dgdA/OaZrJ+RDQHAwNYQAPrcHANlDQPAtI7RrX59OWMGIZOAtkTH1LUHpKsHaAN6LSA6IMr4XR9NzyixFwC4IeXP2JBqjZKA9bwgFP/i0ssfb8jbMFICgK3xwtwCMTIQXiBP/rsNBZvmSABwJQ/D9HeZyf1BXjyMg3g6qSBprQSAIQogS7wBI3yUVJD0tN0A4Ei36C33RtKCl5GxTo03V6dixvgZEkjMd1kejJCz8erGH7mGBxggqgmEnStTsOaxNQgfE46EiQl4a/UuxEkgsEQUTKS/prAUzvkAMIsPw/3i5KBwzJjQ19hEhFXxqyTzWuYOZlZdrdritjGAr8LP4HE/I8eNBl6MDWMQ0Gsp36TI3BIAN+7eQEt7S7/jBWUFEldguTxyZ/Sd5W4JgKa2Jrz15dto07b1GP92AT65+IlzI3MzXZjrAYjWD45kcKLkleQh8YPnkJqYisP5h3Dmxtm+/P5QSf3s25w5bukBdNKqaUVjawPuNNwdllyADciigKQrSeGD8wB2QKm/0h+ho0Ihk8n6j+ABPf8I8PX2Q0RQBLzl3j2jaboyeoNNjQ8bUdlYCYEJwwcwSHqjEHF/3FicfIxn+Dw9Jr3Zqg4kfvNMBthgFLBrP3Z8LJIXqTA1bKrd7slD7UPkXs1F1qVsaASNZaN/Q2XE02RZqgaJO8VW8W+Z8Zlah3cB86Pn4731e+xqfABQeCiwevpqvL38LchlcokT6HEPQWCUzin4IlWxaqFDARCgDMCOlb+FjHdcXDklaArWJayT7N5fIhhDrqpItdxhAFgatxRKT6XDW7okejHkvHVeYJiQR3Iw7AYzHd3ZDABRoVFOaaWXzAvjRo5zLFfgJvhhhIkbijcEOAQASk9vpzVUKVc690abmwfAnFUv1IdFh9W7NA8giQVcwQC7LGL4NIVSRPM8QNdFrGLgLOQORCbixOWTuFxeCIVcgccmP4aESQlm9epb63Hk8hFU1lchcEQgFkU/hdCAUAkclksbePZny4ggO0mH2IHt2a+ioLSgO1f9/NIXSExIRPJClVG98gfl2H5wOx601nXnuYcLD+O1xb/B7EmzJdNa9oS+o45Sl9o1C/CQeSBDpYZqkWFj5pzPQf6tfMyJnI3s5CxkbshARHAEDv7noMlRv7RTu/GgpQ4vzl6HrJf+iZ3LUiCXeWD313sMjiAG+gQiffVeLIlaLNm9U24qfBWpducBQgJCEBMWg7lRhscjLpRcAEccdvx0B8aOHIuI4Aj8evGvAAAXf7hoUKe5vRlXKq4gOiQaaxPWInBEIGSHnIVV01ehsa0R16uv99MJHz0J40eOR1xYvGT6zp55S1pY2kOHEkGGRCNowXM8PHiPnuS0i7nTCh1GKt/5p5/be/A6Pe3AKjN85o38a1/Mvq8sLWxXAMyYMB1aQYs9x95Dm7YN9S31+ODUXgDA9PGPGkknlYgIikBheSGOFx0HYwwlNSX4ouALeMo8MSV4ilNSO/cBEEu1prRdg8Dn5z2Ps9fPIbcgF7nf5XYHdPOnzMfcyLl93L5SruzOQrYtfAXbc17FOyffxbun0jrfrQOHzT/eDH+Fv/ukciZG8RhY9zuKNpRCdYy6wGUAoJArkPlyBvbn7Udh+WUo5ArMmjwLy6Y/05MpCB1I/ngzno17FqviVgIAIoMikfFzNT67dABlD8owymcUlsU+g2mh04YXF2A9PpqtVbAKAP24AgvcopeHF15c8KLR7w/lH0ZVfRWy8rKwKOYp+Hj5AACC/YKx7clXpIjOOhGtVXAqE9jU1oSsvKzuz9kXsiUTDk7s6wFsLe3adqyIW9E9A2iM7xjJhIPrN864FQBGjxiNdXNfsN/tsJbeduvkny5puPa9vbpn2vr91tHvR7x/z2UB4PDnw07jHa4RM7IHckG+XlWkGsXAxqEYEEThUwAn7AaA6vpq3Km7i8LSywgZ+YjTGl9aW4bm9mYU3S1y9E23Ryo30PjvL+qYjJNJPyT5ZYZnNljsOHSTQi2aIIle6wTpTQbd/VIa4sNNU7G7Du/CiaKThtf5MTBB0lfhizdXpCIyKNLkeXd8+ToKqwqN1rfPOkIWTiDtM6HTwvqamiw7IF3OqnrXAvAF4AGgDkAJgHJG+P5B1P3XcyhHcHoWUHj7slXlG9saUVLz/fDK/fW6LCtkVJfxASAAQAKAaQR20ZjxB9YFDKJf5Dneah3ZAHSGqTQCdIQxlg+OKgGMIlGsVkerD7lMEJj8ExXOXj/X82KI3lx5oPdLIYQRXj6YNelxybQWGL+jQxYj89D6E6NkMLYTgA+IsLEoOTED6QftDgBRNE9CzYmcgzmRNl/nCKIoDHcAeMlk2qNgFNv1IN0D8BUj+rdCIz9lStFmMUBNQ43TWl/TfM/ifnWIihyg2F77gQASibFftsvb/7DpqvHVxWwGgLPXzjml5bdqb6G6qdqmXMEQAtAEBmwF0blNRarTm4o3TbUbAM7fOI9vb37rcGLn7xf+4dKRvAvJAsbobNK1LbF2AQBjDL/f/wbybxU4pDUaQYO0b9KQX57vZpkecxqACPAnUdhidRBoKYXa+LAR2z7chgXRCzAvah6C/MZ0X7lfVUjvsH4ZXYagV0YrdOB6zXUcLz6Gey333YaqtacXtIbeJuD+4LMAM1zAmWtncOZ/Z/qvMj4QdgxmFlWWxBq5qYXmHcfzAGYA41qc+lAVOg9OXEuk8FMVqx4XRfLleFblmqOBFqyKIYlVfX8Lg9gKkb6VQRjJgFaO2BUmwmtIvhuon8oN67UEO58fJUBPAtAtOe/NgHhGqJZJz4f1XdYQEA2AawSmlt4OtkUq537rB8gZIKtltbkSAFzF41jDFdggJpCBW5MTk6PhLCYkmGQndwGQGWkAkLg3Zm+RTdPAfqmcFLm7Ik6+Y6KwOjM28wfdMc5FUSp5HFu7fYbPvH29Zvc2vk09gCMCLzLNJkkex7CIRHhjX8y+Pxn6cuimgRIgAOAuA61XR6cfM1ZA4gF0eDH03qP7AagKQCUYVTBi/+UEqNXT0utMKcgYUKprsNmxFYM3hfW6iQZG+fTyD5MnJ3Sva2iiqAxAqA08RDsId/QqqABYUK8DtQxoMlKXMAC8pYAZ5HhHCwPugVDBMdSIhAoiqgTECgJVUAduBz8adNvcimBWm8SVZWHGsnEeQkcIEY0lohDGKIR4FgyiCQR4MaJgIvgTkX+vEUSBQKfBsWy5p/zznOdy+rxA8XT22gA5r1nGEfMmjm7eH33/69NPnDa4lMmaIz97CIKXsZ+CNTHSeYeI2gHUEEetINQS0AQO9wh8HQhVjKGaSKxjYNUtvi1V9vwN4WHRSy79cGmwHHIvDTRtR9cfHfQPEyQeSORJwf8OHMABAjEqB8915VTUwIuo13WuJFIZL+dZKUorjIFJEkmcJv8HntCxqwTldwwAAAAASUVORK5CYII=]]} }
        for _, it in ipairs(_icons) do
            local p = dir .. it[1]
            if _need(p) then
                local ok, bin = pcall(_b64d, it[2])
                if ok and bin and #bin > 100 and bin:sub(1, 4) == "\137PNG" then
                    local w = io.open(p, "wb")
                    if w then w:write(bin) w:close() end
                    if _G.SH_Dbg then _G.SH_Dbg("ICON wrote " .. p) end
                else
                    if _G.SH_Dbg then _G.SH_Dbg("ICON b64 fail " .. it[1]) end
                end
            end
        end
    end)
    -- [ICON-FIX] Prefetch: jsDelivr CDN → GitHub raw → old worker (in that order)
    pcall(function()
        if _G._espIconPrefetch then return end
        _G._espIconPrefetch = true
        local MM = ModuleManager
        if not MM then pcall(function() MM = require("GameLua.GameCore.Module.ModuleManager") end) end
        local http = nil
        if MM and MM.GetModule and MM.CommonModuleConfig then
            pcall(function() http = MM:GetModule(MM.CommonModuleConfig.http_manager) end)
        end
        if not (http and http.Post) then return end
        local SAVE = _G._SH_SaveDir or _SH_GetSavePaksDir()
        local function prefetchOne(urls, filename, idx)
            idx = idx or 1
            if idx > #urls then
                if _G.SH_Dbg then _G.SH_Dbg("ICON prefetch failed all " .. filename) end
                return
            end
            local sp = SAVE .. filename
            local f0 = io.open(sp, "r")
            if f0 then f0:close() return end
            if _G.SH_Dbg then _G.SH_Dbg("ICON prefetch " .. filename .. " try#" .. idx) end
            http:Post(urls[idx],
                { ["User-Agent"] = "game=ShadowTrackerExtra engine=UE4 platform=Android" },
                "", nil, function(s, resp)
                if s and resp and #resp > 100 then
                    pcall(function()
                        local w = io.open(sp, "wb")
                        if w then w:write(resp) w:close() end
                        if _G.SH_Dbg then _G.SH_Dbg("ICON prefetch OK " .. filename .. " size=" .. #resp) end
                    end)
                else
                    if _G.SH_Dbg then _G.SH_Dbg("ICON prefetch fail# " .. idx .. " " .. filename) end
                    prefetchOne(urls, filename, idx + 1)
                end
            end, 15)
        end
        prefetchOne({
            "https://cdn.jsdelivr.net/gh/victortipvala-sys/esp-icons@main/ic_danger_enemy.png",
            "https://raw.githubusercontent.com/victortipvala-sys/esp-icons/main/ic_danger_enemy.png",
            "https://late-feather-24ce.victortipvala.workers.dev/icon_player.png",
        }, "ic_danger_enemy.png", 1)
        prefetchOne({
            "https://cdn.jsdelivr.net/gh/victortipvala-sys/esp-icons@main/ic_clear_boot.png",
            "https://raw.githubusercontent.com/victortipvala-sys/esp-icons/main/ic_clear_boot.png",
            "https://late-feather-24ce.victortipvala.workers.dev/icon_bot.png",
        }, "ic_clear_boot.png", 1)
    end)
local ESPV3Bridge = (function()
    local _ESPV3_DBG = "/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt"
    local function _edbg(m)
        pcall(function()
            local f = io.open(_ESPV3_DBG, "a")
            if f then f:write(tostring(m) .. string.char(10)) f:close() end
        end)
    end
-- R4: requested options are separate from renderer status.
-- One cancellable 20 Hz timer; existing FastTick supervises it and provides a fallback.
local initializeRenderer = (function()
-- ESP V3: cleaned & corrected renderer section
-- Returns initializer; loading module does NOT initialize it.

local recoveredStrings = {
    [1]  = "SlateBlueprintLibrary",
    [2]  = "/Script/UMG.SlateBlueprintLibrary",
    [3]  = "WidgetLayoutLibrary",
    [4]  = "/Script/UMG.WidgetLayoutLibrary",
    [5]  = "Vector2D",
    [6]  = "Vector",
    [7]  = "LinearColor",
    [8]  = "SlateColor",
    [9]  = "/Script/SlateCore.SlateColor",
    [10] = "Player",
    [11] = "Bot",
    [12] = "Head",
    [13] = "head",
    [14] = "root",
    [15] = "Root",
    [16] = "Prone",
    [17] = "Crouch",
    [18] = "Fist",
    [19] = "Open",
    [20] = "Knocked",
    [21] = "Cover",
    [22] = "AsyncTaskDownloadImage",
    [23] = "/Script/UMG.AsyncTaskDownloadImage",
    [24] = "/Script/UMG.CanvasPanel",
    [25] = "/Script/UMG.Border",
    [26] = "/Script/UMG.Image",
    [27] = "/Script/UMG.TextBlock",
    [28] = "GameLua.Mod.BaseMod.Common.UI.InGameUITools",
    [29] = "client.slua_ui_framework.util",
    [30] = "common.asset_util",
    [31] = "GameLua.GameCore.Module.ModuleManager",
    [32] = "client.slua.logic.image_download.image_download_mgr",
    [33] = "ic_danger_enemy.png",
    [34] = "ic_clear_boot.png",
    [35] = "/Game/UMG/Texture/Atlas/NationalflagUI/Frames/T_icon_flag_iland_png.T_icon_flag_iland_png",
    [36] = "RegionConfig",
}

local URL_PLAYER     = "https://cdn.jsdelivr.net/gh/victortipvala-sys/esp-icons@main/ic_danger_enemy.png" -- [ICON-FIX] -- [FIXED]
local URL_PLAYER_CDN = "https://raw.githubusercontent.com/victortipvala-sys/esp-icons/main/ic_danger_enemy.png" -- [ICON-FIX]
local URL_BOT        = "https://cdn.jsdelivr.net/gh/victortipvala-sys/esp-icons@main/ic_clear_boot.png" -- [ICON-FIX] -- [FIXED]
local URL_BOT_CDN    = "https://raw.githubusercontent.com/victortipvala-sys/esp-icons/main/ic_clear_boot.png" -- [ICON-FIX]

local function decodeRecoveredString(index)
    return recoveredStrings[index]
end

-- ============================================================
-- MAIN INITIALIZER
-- ============================================================
local LoadESPV3System
function LoadESPV3System()
    -- Guard: already loaded?
    -- Instance-owned initialization: failed imports can be retried.

    -- ---------------------------------------------------------
    -- Engine class handles (resolved lazily inside LoadESPV3System)
    -- ---------------------------------------------------------
    local SlateBlueprintLibrary, WidgetLayoutLibrary
    local Vector2D, Vector, LinearColor, SlateColor
    local zeroVector, whiteColor, redColor, greenColor, yellowColor, blueColor
    local redSlateColor, greenSlateColor

    -- ---------------------------------------------------------
    -- Safe object validation
    -- ---------------------------------------------------------
    local function isValidObject(obj)
        if not obj then return false end
        if slua and slua.isValid then
            local ok, valid = pcall(slua.isValid, obj)
            return ok and valid == true
        end
        return true
    end

    -- ---------------------------------------------------------
    -- Import engine classes
    -- ---------------------------------------------------------
    local function importEngineClasses()
        if not import then return end
        local function importFn(name)
            local ok, value = pcall(import, name)
            if ok then return value end
        end

        SlateBlueprintLibrary = importFn("SlateBlueprintLibrary", nil)
            or importFn("/Script/UMG.SlateBlueprintLibrary", nil)

        WidgetLayoutLibrary = importFn("WidgetLayoutLibrary", nil)
            or importFn("/Script/UMG.WidgetLayoutLibrary", nil)

        Vector2D      = importFn("Vector2D", nil)
        Vector        = importFn("Vector", nil)
        LinearColor   = importFn("LinearColor", nil)
        SlateColor    = importFn("SlateColor", nil)
            or importFn("/Script/SlateCore.SlateColor", nil)
    end
    importEngineClasses()
    assert(Vector2D and Vector and LinearColor and CGame and CGame.NewObjectFromPath,
        "ESP V3: engine widget/vector APIs unavailable")
    assert(UEnums and UEnums.ESlateVisibility, "ESP V3: visibility enums unavailable")

    local function readBool(object, member, fallback)
        local value = object[member]
        if type(value) == "function" then value = value(object) end
        if value == nil then return fallback end
        return value == true or value == 1
    end

    -- ---------------------------------------------------------
    -- Build color constants (safe fallbacks)
    -- ---------------------------------------------------------
    if Vector2D then
        zeroVector = Vector2D(0, 0)
    end

    if LinearColor then
        whiteColor  = LinearColor(1.0, 1.0, 1.0, 1.0)
        redColor    = LinearColor(1.0, 0.15, 0.15, 1.0)
        greenColor  = LinearColor(0.0, 1.0, 0.05, 1.0)
        yellowColor = LinearColor(1.0, 0.95, 0.0, 1.0)
        blueColor   = LinearColor(0.18, 0.62, 1.0, 1.0)
    end

    -- Native SLua builds differ in their struct constructor overloads.
    local function toSlateColor(color)
        if not SlateColor then return color end
        local ok, wrapped = pcall(SlateColor, color)
        if ok and wrapped then return wrapped end
        ok, wrapped = pcall(function()
            local result = SlateColor()
            result.SpecifiedColor = color
            return result
        end)
        if ok and wrapped then return wrapped end
        return color
    end

    -- SlateColor wrappers (fall back to LinearColor if unavailable)
    if SlateColor and redColor then
        redSlateColor = toSlateColor(redColor)
    else
        redSlateColor = redColor
    end

    if SlateColor and greenColor then
        greenSlateColor = toSlateColor(greenColor)
    else
        greenSlateColor = greenColor
    end

    -- ---------------------------------------------------------
    -- Icon URL tables (2 entries: primary + CDN fallback)
    -- ---------------------------------------------------------
    local playerIconURLs = { URL_PLAYER, URL_PLAYER_CDN }
    local botIconURLs    = { URL_BOT,    URL_BOT_CDN }

    -- ---------------------------------------------------------
    -- Image cache + counter dimensions
    -- ---------------------------------------------------------
    local imageCache      = {}
    -- Counter presets: Compact(55x32/t14) Standard(65x36/t16) Large(75x42/t18) XL(90x50/t20)
    local counterIconSize = 65  -- Standard width
    local counterTextSize = 36  -- Standard height

    -- ---------------------------------------------------------
    -- File existence check
    -- ---------------------------------------------------------
    local function fileExists(path)
        if not path or path == "" then return false end
        local f = io.open(path, "r")
        if f then
            f:close()
            return true
        end
        return false
    end

    -- ---------------------------------------------------------
    -- Asset search paths (per PUBG package variant)
    -- ---------------------------------------------------------
    local function getAssetSearchPaths(filename)
        local saveDir = _G._SH_SaveDir or _SH_GetSavePaksDir() -- [ICON-FIX]
        local paths = {
            saveDir .. filename,  -- [ICON-FIX]
            "/storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/storage/emulated/0/Android/data/com.tencent.tmgp.pubgmhd/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "/Documents/ShadowTrackerExtra/Saved/Paks/" .. filename,
            "ShadowTrackerExtra/Saved/Paks/" .. filename,
            "../../ShadowTrackerExtra/Saved/Paks/" .. filename,
            "../../../ShadowTrackerExtra/Saved/Paks/" .. filename,
        }

        -- Add HOME-relative path if available
        pcall(function()
            if os and os.getenv then
                local home = os.getenv("HOME")
                if home and home ~= "" then
                    table.insert(paths, 1,
                        home .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. filename)
                end
            end
        end)

        return paths
    end

    -- ---------------------------------------------------------
    -- loadWidgetImage: try local files â†’ remote download â†’ fallback
    -- ---------------------------------------------------------
    -- ════════════════════════════════════
    -- ICON LOADER (FIXED)
    -- ════════════════════════════════════
    local function loadWidgetImage(imageWidget, remoteURLs, filename, cacheKey, counterData)
        if not imageWidget or not isValidObject(imageWidget) then return end
        if not _G._espImgProbeDone then
            _G._espImgProbeDone = true
            _G.SH_Dbg("imgmod probe run")
            pcall(function()
                local a1, a2, a3 = "0", "0", "0"
                pcall(function()
                    local A = import("AsyncTaskDownloadImage", nil) or import("/Script/UMG.AsyncTaskDownloadImage", nil)
                    if A and A.DownloadImage then a1 = "1" end
                end)
                pcall(function()
                    local m = package.loaded["client.slua.logic.image_download.image_download_mgr"]
                    if not m then local okk, mm = pcall(require, "client.slua.logic.image_download.image_download_mgr") if okk then m = mm end end
                    if m and m.DownloadImageByHttpWrapper then a2 = "1" end
                    if a2 == "0" then
                        local MM = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                        if MM and MM.GetModule and MM.CommonModuleConfig and MM.CommonModuleConfig.image_download_mgr then a2 = "1" end
                    end
                end)
                pcall(function()
                    local u = package.loaded["client.slua_ui_framework.util"]
                    if not u then local okk, uu = pcall(require, "client.slua_ui_framework.util") if okk then u = uu end end
                    if u and u.SetTexture then a3 = "1" end
                end)
                _G.SH_Dbg("imgmod async=" .. a1 .. " mgr=" .. a2 .. " util=" .. a3)
            end)
        end
        local function iconEnabled()
            local cfg = _G.LexusConfig or {}
            return cfg.EspV3_Master and cfg.EspV3_Count
                and not (counterData and counterData.Disposed)
        end
        if not iconEnabled() then return end

        -- Already cached?
        local cached = imageCache[cacheKey]
        if cached and isValidObject(cached) then
            pcall(function()
                imageWidget:SetBrushFromTexture(cached, false)
                imageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            if counterData then
                if cacheKey == "Player" then counterData.PlayerLoaded = true counterData.PlayerRetryCount = 0 counterData.PlayerRetryMaxed = nil end -- [FIXED]
                if cacheKey == "Bot"    then counterData.BotLoaded = true counterData.BotRetryCount = 0 counterData.BotRetryMaxed = nil end -- [FIXED]
            end
            return
        end

        -- Applies a loaded texture and updates cache
        local function applyTexture(tex)
            if not iconEnabled() then return false end
            if not tex or not isValidObject(tex) then
                if not _G["_pngInv"..cacheKey] then _G["_pngInv"..cacheKey] = true _edbg("invalid "..tostring(cacheKey)) end
                return false
            end
            if not isValidObject(imageWidget) then return false end

            imageCache[cacheKey] = tex
            if not _G["_pngOk"..cacheKey] then _G["_pngOk"..cacheKey] = true _edbg("applied "..tostring(cacheKey)) end
            if counterData then
                if cacheKey == "Player" then counterData.PlayerLoaded = true counterData.PlayerRetryCount = 0 counterData.PlayerRetryMaxed = nil end -- [FIXED]
                if cacheKey == "Bot"    then counterData.BotLoaded = true counterData.BotRetryCount = 0 counterData.BotRetryMaxed = nil end -- [FIXED]
            end
            pcall(function()
                imageWidget:SetBrushFromTexture(tex, false)
                imageWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            return true
        end

        -- 1) Try local file paths
        for _, path in ipairs(getAssetSearchPaths(filename)) do
            if fileExists(path) then
                if not _G["_pngLf"..filename] then _G["_pngLf"..filename] = true _edbg("local found "..tostring(filename)) end
                local texture = nil
                pcall(function()
                    local assetUtil = package.loaded["common.asset_util"]
                    if not assetUtil then
                        assetUtil = require("common.asset_util")
                    end
                    if assetUtil and assetUtil.GetAssetSync then
                        texture = assetUtil.GetAssetSync(path)
                    end
                end)
                if not texture then
                    pcall(function()
                        if CGame and CGame.LoadObject then
                            texture = CGame:LoadObject(path)
                        end
                    end)
                end
                if texture and applyTexture(texture) then
                    return
                end
            end
        end
        if not _G["_pngLn"..filename] then _G["_pngLn"..filename] = true _edbg("local miss "..tostring(filename)) end

        -- 2) Try remote download
        local function tryRemote(index)
            if index > #remoteURLs then
                if not _G["_pngFail"..cacheKey] then _G["_pngFail"..cacheKey] = true _edbg("failed "..tostring(cacheKey)) end
                return
            end
            local url = remoteURLs[index]
            local succeeded = false

            if not iconEnabled() then return end
            if not _G["_pngSt"..cacheKey] then _G["_pngSt"..cacheKey] = true _edbg("started "..tostring(cacheKey)) end

            -- 2b) image_download_mgr (game-supported HTTP image pipeline)
            if not succeeded then
                pcall(function()
                    local moduleManager = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                    if not moduleManager then pcall(function() moduleManager = require("GameLua.GameCore.Module.ModuleManager") end) end
                    local mgr = nil
                    if moduleManager and moduleManager.GetModule and moduleManager.CommonModuleConfig then
                        pcall(function() mgr = moduleManager:GetModule(moduleManager.CommonModuleConfig.image_download_mgr) end)
                    end
                    if not mgr then mgr = package.loaded["client.slua.logic.image_download.image_download_mgr"] end
                    if not mgr then pcall(function() mgr = require("client.slua.logic.image_download.image_download_mgr") end) end
                    if mgr and mgr.DownloadImageByHttpWrapper then
                        mgr:DownloadImageByHttpWrapper(url,
                            function(tex)
                                if not succeeded and iconEnabled() and tex then succeeded = applyTexture(tex) end
                            end,
                            function()
                                if not succeeded and iconEnabled() then tryRemote(index + 1) end
                            end)
                    else
                        if not succeeded and iconEnabled() then tryRemote(index + 1) end
                    end
                end)
            end
            local ok = pcall(function()
                local AsyncTask = import("AsyncTaskDownloadImage", nil)
                    or import("/Script/UMG.AsyncTaskDownloadImage", nil)
                if not (AsyncTask and AsyncTask.DownloadImage) then return end
                local task = AsyncTask.DownloadImage(url)
                if not (task and task.OnSuccess) then return end
                task.OnSuccess:Add(function(tex)
                    if not succeeded and iconEnabled() and tex then
                        succeeded = applyTexture(tex)
                    end
                end)
                if task.OnFail then
                    task.OnFail:Add(function()
                        if not succeeded and iconEnabled() then tryRemote(index + 1) end
                    end)
                end
            end)
            -- 2c) slua_ui_framework util
            if not succeeded then
                pcall(function()
                    local util = package.loaded["client.slua_ui_framework.util"]
                    if not util then pcall(function() util = require("client.slua_ui_framework.util") end) end
                    if util and util.SetTexture then
                        util.SetTexture(imageWidget, url, {
                            sync = false,
                            onDownloadSuccess = function(tex)
                                if not succeeded and iconEnabled() and tex then succeeded = applyTexture(tex) end
                            end,
                        })
                    else
                        if not succeeded and iconEnabled() then tryRemote(index + 1) end
                    end
                end)
            end
            -- Missing downloader is nonfatal: text counts still work.
        end
        tryRemote(1)
    end

    -- =========================================================
    -- ESP STATE TABLE
    -- =========================================================
    local ESP = {
        bActive = true,
        ESPCanvas = nil,

        BoxWidgets  = {},
        LineWidgets = {},

        CounterData = {
            ImgPlayer = nil, SlotPlayer    = nil,
            ImgBot    = nil, SlotBot       = nil,
            TxtPlayer = nil, SlotTxtPlayer = nil,
            TxtBot    = nil, SlotTxtBot    = nil,
            LastPlayerCount = -1,
            LastBotCount    = -1,
            PlayerLoaded    = false,
            BotLoaded       = false,
            LastDownloadRetry = 0,
            bCreated = false,
            PlayerRetryCount = 0, BotRetryCount = 0, -- [FIXED]
        },

        HealthColor      = { R = 0.0, G = 1.0, B = 0.0, A = 1.0 },
        HealthBgColor    = { R = 0.0, G = 0.0, B = 0.0, A = 0.85 },
        HealthBarWidth   = 4.0,
        CornerColor      = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 },
        CornerThickness  = 2.0,
        CornerLengthRatio = 0.28,
        SnapLineThickness = 1.5,
        SnapLineOriginY   = 72,

        _CanvasScaleX = 1.0,
        _CanvasScaleY = 1.0,
        _CanvasOffsetX = 0.0,
        _CanvasOffsetY = 0.0,
        _LastCanvas = nil,
        _LastTransformTime = 0,
        _LastHeavyUpdateTime = 0,
        _LastVisCheckTime = 0,
        _VisCheckCache = {},
        -- Device-adaptive governor: 0=Smooth 1=Balanced 2=Performance
        _AdaptiveTier = 0,
        _AvgTickMs = 0,
        _LastTickTime = 0,
        _TierCheckTime = 0,
        _MaxTargets = 30,
        _MaxDist = 500,
    }

    ESP.OwnedWidgets = {}
    local function newWidget(path, parent)
        local widget = CGame:NewObjectFromPath(path, parent)
        if widget then ESP.OwnedWidgets[widget] = true end
        return widget
    end
    local function removeWidget(widget)
        if not widget then return end
        pcall(function()
            if isValidObject(widget) then
                widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                if widget.RemoveFromParent then widget:RemoveFromParent() end
            end
        end)
        ESP.OwnedWidgets[widget] = nil
    end
    local function removeBox(box)
        if not box then return end
        for _, corner in pairs(box.Corners or {}) do removeWidget(corner.widget) end
        for _, name in ipairs({"CornerContainer", "BgWidget", "HealthWidget",
            "WeaponWidget", "FlagWidget", "NameWidget", "DistWidget", "StateWidget"}) do
            removeWidget(box[name])
        end
    end

    -- =========================================================
    -- CANVAS LOOKUP
    -- =========================================================
    local function esp_GetMainCanvas()
        local uiTools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
        if not uiTools then
            pcall(function()
                uiTools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            end)
        end
        if not uiTools then return nil end

        local baseUI = nil
        if uiTools.GetMainControlBaseUI then
            baseUI = uiTools.GetMainControlBaseUI()
        end
        if not isValidObject(baseUI) then return nil end

        local canvas = nil
        if baseUI.CanvasPanel_0 and isValidObject(baseUI.CanvasPanel_0) then
            canvas = baseUI.CanvasPanel_0
        elseif baseUI.CanvasPanel_42 and isValidObject(baseUI.CanvasPanel_42) then
            canvas = baseUI.CanvasPanel_42
        end

        if canvas then
            ESP.ESPCanvas = canvas
        end
        return canvas
    end
    ESP.GetMainCanvas = esp_GetMainCanvas

    -- =========================================================
    -- WIDGET CREATION HELPERS
    -- =========================================================
    -- Adapted from the supplied reference's safeSetColor, with SlateColor fallback.
    -- Do not let an unsupported optional colour setter kill every ESP component.
    local function safeSetColor(widget, color)
        if not widget or not color or not isValidObject(widget) then return false end
        for _, method in ipairs({"SetColorAndOpacity", "SetBrushColor"}) do
            local ok = pcall(function() widget[method](widget, color) end)
            if ok then return true end
        end
        local ok = pcall(function() widget:SetColorAndOpacity(toSlateColor(color)) end)
        if not ok then ESP.LastWarning = "Native widget colour setters rejected a colour" end
        return ok
    end
    local function makeBorder(canvas, color)
        local border = newWidget("/Script/UMG.Border", canvas)
        if not isValidObject(border) then return nil end
        safeSetColor(border, color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local slot = canvas:AddChildToCanvas(border)
        if slot then slot:SetAutoSize(false) end
        return { widget = border, slot = slot }
    end

    local function makeText(canvas, color, size, align)
        local txt = newWidget("/Script/UMG.TextBlock", canvas)
        if not isValidObject(txt) then return nil, nil end

        txt:SetText("")
        size = math.floor(size or 10)

        local font = txt.Font
        if font then
            font.Size = size
            if font.OutlineSettings then
                font.OutlineSettings.OutlineSize = 1
                font.OutlineSettings.OutlineColor = LinearColor(0, 0, 0, 1)
            end
            if txt.SetFont then txt:SetFont(font) else txt.Font = font end
        end
        if txt.SetFontSize then txt:SetFontSize(size) end
        if txt.SetJustification then txt:SetJustification(1) end
        if txt.SetHorizontalAlignment then txt:SetHorizontalAlignment(1) end
        if txt.SetVerticalAlignment then txt:SetVerticalAlignment(1) end
        if txt.SetAutoWrapText then txt:SetAutoWrapText(false) end

        safeSetColor(txt, toSlateColor(color))

        if txt.SetShadowOffset then txt:SetShadowOffset(Vector2D(0, 0)) end
        if txt.SetShadowColorAndOpacity then
            txt:SetShadowColorAndOpacity(LinearColor(0, 0, 0, 0))
        end

        txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

        local slot = canvas:AddChildToCanvas(txt)
        if slot then
            slot:SetAutoSize(true)
            slot:SetZOrder(1000)
            slot:SetAlignment(align or Vector2D(0.5, 0.0))
        end
        return txt, slot
    end

    local function makeImage(canvas, size, align)
        local img = newWidget("/Script/UMG.Image", canvas)
        if not isValidObject(img) then return nil, nil end

        img:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local slot = canvas:AddChildToCanvas(img)
        if slot then
            slot:SetAutoSize(false)
            slot:SetSize(size)
            slot:SetZOrder(1000)
            slot:SetAlignment(align or Vector2D(0.5, 0.0))
        end
        return img, slot
    end

    -- =========================================================
    -- CREATE ESP WIDGET (per-player box)
    -- =========================================================
    local function esp_CreateESPWidget(canvas)
        if not LinearColor or not Vector2D then return nil end

        -- Root container (canvas panel)
        local root = newWidget("/Script/UMG.CanvasPanel", canvas)
        if not isValidObject(root) then return nil end

        local rootSlot = canvas:AddChildToCanvas(root)
        if not rootSlot then return nil end
        rootSlot:SetAutoSize(false)
        rootSlot:SetZOrder(995)
        rootSlot:SetAlignment(Vector2D(0.5, 0.5))

        -- Corner color
        local cc = ESP.CornerColor
        local cornerColor = LinearColor(cc.R, cc.G, cc.B, cc.A)

        -- 8 corner borders
        local corners = {
            TopLeft_H     = makeBorder(root, cornerColor),
            TopLeft_V     = makeBorder(root, cornerColor),
            TopRight_H    = makeBorder(root, cornerColor),
            TopRight_V    = makeBorder(root, cornerColor),
            BottomLeft_H  = makeBorder(root, cornerColor),
            BottomLeft_V  = makeBorder(root, cornerColor),
            BottomRight_H = makeBorder(root, cornerColor),
            BottomRight_V = makeBorder(root, cornerColor),
        }

        -- Health background (Border)
        local bg = newWidget("/Script/UMG.Border", canvas)
        local hb = ESP.HealthBgColor
        safeSetColor(bg, LinearColor(hb.R, hb.G, hb.B, hb.A))
        bg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local bgSlot = canvas:AddChildToCanvas(bg)
        if bgSlot then
            bgSlot:SetAutoSize(false)
            bgSlot:SetZOrder(998)
            bgSlot:SetAlignment(Vector2D(0.5, 1.0))
        end

        -- Health fill (Image)
        local health = newWidget("/Script/UMG.Image", canvas)
        local hc = ESP.HealthColor
        safeSetColor(health, LinearColor(hc.R, hc.G, hc.B, hc.A))
        health:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local healthSlot = canvas:AddChildToCanvas(health)
        if healthSlot then
            healthSlot:SetAutoSize(false)
            healthSlot:SetZOrder(999)
            healthSlot:SetAlignment(Vector2D(0.5, 1.0))
        end

        -- Text lines
        local weapon,  weaponSlot  = makeText(canvas, yellowColor, 10, Vector2D(0.5, 1.0))
        local name,    nameSlot    = makeText(canvas, blueColor,   10, Vector2D(0.5, 0.0))
        local dist,    distSlot    = makeText(canvas, whiteColor,  10, Vector2D(0.5, 0.0))
        local state,   stateSlot   = makeText(canvas, greenColor,  10, Vector2D(0.5, 0.0))

        -- Flag image
        local flag, flagSlot = makeImage(canvas, Vector2D(14, 16), Vector2D(0.5, 1.0))

        return {
            CornerContainer = root,
            CornerSlot      = rootSlot,
            Corners         = corners,

            BgWidget        = bg,
            BgSlot          = bgSlot,

            HealthWidget    = health,
            HealthSlot      = healthSlot,

            WeaponWidget    = weapon,
            WeaponSlot      = weaponSlot,

            FlagWidget      = flag,
            FlagSlot        = flagSlot,

            NameWidget      = name,
            NameSlot        = nameSlot,

            DistWidget      = dist,
            DistSlot        = distSlot,

            StateWidget     = state,
            StateSlot       = stateSlot,

            _cachedWeapon   = "",
            _cachedNation   = nil,
            _cachedName     = "",
            _cachedDist     = "",
            _cachedState    = "",
            _cachedIsCover  = false,
            _cachedIsKnocked = false,
            _lastScanTime   = 0,
            lastW = 0,
            lastH = 0,
            bVisible = true,
        }
    end
    ESP.CreateESPWidget = esp_CreateESPWidget

    -- =========================================================
    -- CORNER DIMENSION UPDATER
    -- =========================================================
    local function esp_UpdateCornerDimensions(widget, width, height)
        -- Skip if virtually unchanged
        if widget.lastW and widget.lastH then
            if math.abs(width - widget.lastW) < 1.5
               and math.abs(height - widget.lastH) < 1.5 then
                return
            end
        end
        widget.lastW = width
        widget.lastH = height

        local thickness = ESP.CornerThickness
        local length = math.max(7,
            math.min(width, height) * ESP.CornerLengthRatio)

        widget.CornerSlot:SetSize(Vector2D(width, height))

        local function place(corner, x, y, w, h)
            if corner and corner.slot then
                corner.slot:SetPosition(Vector2D(x, y))
                corner.slot:SetSize(Vector2D(w, h))
            end
        end

        local c = widget.Corners
        place(c.TopLeft_H,     0,              0,              length,    thickness)
        place(c.TopLeft_V,     0,              0,              thickness, length)
        place(c.TopRight_H,    width - length, 0,              length,    thickness)
        place(c.TopRight_V,    width - thickness, 0,           thickness, length)
        place(c.BottomLeft_H,  0,              height - thickness, length,    thickness)
        place(c.BottomLeft_V,  0,              height - length, thickness, length)
        place(c.BottomRight_H, width - length, height - thickness, length,    thickness)
        place(c.BottomRight_V, width - thickness, height - length, thickness, length)
    end
    ESP.UpdateCornerDimensions = esp_UpdateCornerDimensions

    -- =========================================================
    -- CANVAS TRANSFORM (scale + offset)
    -- =========================================================
    local function esp_UpdateCanvasTransform(playerController)
        if not ESP.ESPCanvas or not isValidObject(ESP.ESPCanvas) then return end

        local ok = false
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local geom = ESP.ESPCanvas:GetCachedGeometry()
            if geom then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(geom, Vector2D(0, 0))
                local p100 = SlateBlueprintLibrary.AbsoluteToLocal(geom, Vector2D(100, 100))
                if p0 and p100 then
                    ESP._CanvasScaleX = (p100.X - p0.X) / 100
                    ESP._CanvasScaleY = (p100.Y - p0.Y) / 100
                    ESP._CanvasOffsetX = p0.X
                    ESP._CanvasOffsetY = p0.Y
                    ok = true
                end
            end
        end

        if not ok and WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
            local scale = tonumber(WidgetLayoutLibrary.GetViewportScale(playerController)) or 1.0
            if scale <= 0 then scale = 1 end
            ESP._CanvasScaleX = 1.0 / scale
            ESP._CanvasScaleY = 1.0 / scale
            ESP._CanvasOffsetX = 0
            ESP._CanvasOffsetY = 0
        end
    end
    ESP.UpdateCanvasTransform = esp_UpdateCanvasTransform

    -- =========================================================
    -- WORLD â†’ CANVAS LOCAL PROJECTION
    -- =========================================================
    local function esp_ProjectWorldToCanvasLocal(playerController, worldPos)
        if not isValidObject(playerController) or not worldPos or not zeroVector then
            return false, 0, 0
        end

        zeroVector.X, zeroVector.Y = 0, 0
        local ok = playerController:ProjectWorldLocationToScreen(worldPos, zeroVector, true)
        if ok == true or ok == 1 then
            if zeroVector.X == zeroVector.X and zeroVector.Y == zeroVector.Y
                and math.abs(zeroVector.X) < math.huge and math.abs(zeroVector.Y) < math.huge then
                local x = zeroVector.X * ESP._CanvasScaleX + ESP._CanvasOffsetX
                local y = zeroVector.Y * ESP._CanvasScaleY + ESP._CanvasOffsetY
                return true, x, y
            end
        end
        return false, 0, 0
    end
    ESP.ProjectWorldToCanvasLocal = esp_ProjectWorldToCanvasLocal

    -- =========================================================
    -- SNAP LINE START POINT (from screen bottom-center)
    -- =========================================================
    local function esp_GetSnapLineStartPos(playerController, canvas)
        local vw, vh, scale = 0, 0, 1.0

        pcall(function()
            if playerController and playerController.GetViewportSize then
                local sz = Vector2D(0, 0)
                playerController:GetViewportSize(sz)
                if sz and sz.X and sz.X > 200 then
                    vw, vh = sz.X, sz.Y
                end
            end
        end)

        if vw <= 200 then
            pcall(function()
                if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                    local sz = WidgetLayoutLibrary.GetViewportSize(playerController)
                    if sz and sz.X and sz.X > 200 then
                        vw, vh = sz.X, sz.Y
                    end
                end
            end)
        end

        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(playerController)
                if type(s) == "number" and s > 0 then
                    scale = s
                end
            end
        end)

        if vw <= 200 then
            vw = 1920 * scale
            vh = 1080 * scale
        end

        local cx = vw / 2.0
        local cy = ESP.SnapLineOriginY * scale
        local x = cx * ESP._CanvasScaleX + ESP._CanvasOffsetX
        local y = cy * ESP._CanvasScaleY + ESP._CanvasOffsetY
        return x, y
    end
    ESP.GetSnapLineStartPos = esp_GetSnapLineStartPos

    -- =========================================================
    -- SNAP LINE WIDGET
    -- =========================================================
    local function esp_CreateSnapLine(canvas)
        if not isValidObject(canvas) then return nil end

        local border = newWidget("/Script/UMG.Border", canvas)
        if not isValidObject(border) then return nil end

        safeSetColor(border, whiteColor)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local pivotApplied = pcall(function()
            border:SetRenderTransformPivot(Vector2D(0.0, 0.5))
        end)
        if not pivotApplied then
            pivotApplied = pcall(function() border.RenderTransformPivot = Vector2D(0.0, 0.5) end)
        end
        -- Default center pivot needs midpoint positioning; otherwise lines orbit the start.
        local centerPivot = not pivotApplied

        local slot = canvas:AddChildToCanvas(border)
        if slot then
            slot:SetAutoSize(false)
            slot:SetZOrder(990)
        end

        return { Widget = border, Slot = slot, bVisible = true, CenterPivot = centerPivot }
    end
    ESP.CreateSnapLine = esp_CreateSnapLine

    local function esp_UpdateSnapLine(pawnKey, tx, ty, ox, oy, color, canvas, thin)
        local line = ESP.LineWidgets[pawnKey]
        if not (line and isValidObject(line.Widget)) then
            line = esp_CreateSnapLine(canvas)
            if not (line and line.Widget and line.Slot) then return end
            ESP.LineWidgets[pawnKey] = line
        end

        if not line.bVisible then
            line.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            line.bVisible = true
        end

        if color then
            pcall(function() safeSetColor(line.Widget, color) end)
        end

        local dx, dy = tx - ox, ty - oy
        local length = math.sqrt(dx * dx + dy * dy)
        local angle
        if math.atan2 then
            angle = math.atan2(dy, dx)
        else
            angle = math.atan(dy, dx) -- Lua 5.3 two-argument atan preserves quadrant
        end
        angle = angle * (180.0 / math.pi)

        -- Door ki line patli (thin): close=1.0 mid=0.8 far=0.6
        local thickness = (ESP.SnapLineThickness or 1.0) * (thin or 1.0)
        local drawX, drawY = ox, oy - thickness * 0.5
        if line.CenterPivot then
            drawX = (ox + tx) * 0.5 - length * 0.5
            drawY = (oy + ty) * 0.5 - thickness * 0.5
        end

        if not line._CachedPosVec then
            line._CachedPosVec  = Vector2D(drawX, drawY)
            line._CachedSizeVec = Vector2D(length, thickness)
        else
            line._CachedPosVec.X  = drawX
            line._CachedPosVec.Y  = drawY
            line._CachedSizeVec.X = length
            line._CachedSizeVec.Y = thickness
        end

        pcall(function()
            line.Slot:SetPosition(line._CachedPosVec)
            line.Slot:SetSize(line._CachedSizeVec)
            line.Widget:SetRenderAngle(angle)
        end)
    end
    ESP.UpdateSnapLine = esp_UpdateSnapLine

    local function esp_HideSnapLine(pawnKey)
        local line = ESP.LineWidgets[pawnKey]
        if line and line.Widget and isValidObject(line.Widget) and line.bVisible then
            line.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            line.bVisible = false
        end
    end
    ESP.HideSnapLine = esp_HideSnapLine

    -- =========================================================
    -- ENEMY COUNTER
    -- =========================================================
    local function esp_CreateEnemyCounter(canvas, layoutX, layoutY)
        local cd = ESP.CounterData
        if cd.Canvas ~= nil and cd.Canvas ~= canvas then -- [FIXED]
            for _, w in pairs({cd.ImgPlayer, cd.ImgBot, cd.TxtPlayer, cd.TxtBot, cd.SqPlayer, cd.SqBot}) do -- [FIXED]
                if w then removeWidget(w) end -- [FIXED]
            end -- [FIXED]
            cd.ImgPlayer, cd.SlotPlayer, cd.ImgBot, cd.SlotBot = nil, nil, nil, nil -- [FIXED]
            cd.TxtPlayer, cd.SlotTxtPlayer, cd.TxtBot, cd.SlotTxtBot = nil, nil, nil, nil -- [FIXED]
            cd.SqPlayer, cd.SqBot = nil, nil -- [FIXED]
            cd.PlayerLoaded, cd.BotLoaded = false, false -- [FIXED]
            cd.PlayerRetryCount, cd.BotRetryCount = 0, 0 -- [FIXED]
            cd.PlayerRetryMaxed, cd.BotRetryMaxed = nil, nil -- [FIXED]
        end -- [FIXED]
        cd.Canvas = canvas -- [FIXED]
        cd.Disposed = nil -- [FIXED]
        if cd.ImgPlayer and isValidObject(cd.ImgPlayer)
           and cd.ImgBot and isValidObject(cd.ImgBot) then
            return true
        end

        local imgPlayer, slotPlayer = makeImage(canvas, Vector2D(65, 36), nil)
        if slotPlayer then
            slotPlayer:SetAlignment(Vector2D(0.0, 0.0))
            slotPlayer:SetPosition(Vector2D(layoutX, layoutY))
            slotPlayer:SetZOrder(1005)
        end

        local imgBot, slotBot = makeImage(canvas, Vector2D(65, 36), nil)
        if slotBot then
            slotBot:SetAlignment(Vector2D(0.0, 0.0))
            slotBot:SetPosition(Vector2D(layoutX + 65, layoutY))
            slotBot:SetZOrder(1005)
        end

        local txtPlayer, slotTxtPlayer = makeText(canvas, whiteColor, 16, Vector2D(0.0, 0.5))
        if slotTxtPlayer then
            slotTxtPlayer:SetPosition(Vector2D(layoutX + 40, layoutY + 18))
            slotTxtPlayer:SetZOrder(1010)
        end

        local txtBot, slotTxtBot = makeText(canvas, whiteColor, 16, Vector2D(0.0, 0.5))
        if slotTxtBot then
            slotTxtBot:SetPosition(Vector2D(layoutX + 65 + 40, layoutY + 18))
            slotTxtBot:SetZOrder(1010)
        end

        -- Kick off icon downloads
        loadWidgetImage(imgPlayer, playerIconURLs, "ic_danger_enemy.png", "Player", cd)
        loadWidgetImage(imgBot,    botIconURLs,    "ic_clear_boot.png",   "Bot",    cd)

        cd.ImgPlayer = imgPlayer; cd.SlotPlayer = slotPlayer
        cd.ImgBot    = imgBot;    cd.SlotBot    = slotBot
        cd.TxtPlayer = txtPlayer; cd.SlotTxtPlayer = slotTxtPlayer
        cd.TxtBot    = txtBot;    cd.SlotTxtBot = slotTxtBot
        cd.bCreated  = true
        return true
    end
    ESP.CreateEnemyCounter = esp_CreateEnemyCounter

    local function esp_UpdateEnemyCounterDisplay(pc, bc, canvas, ox, oy)
        local cd = ESP.CounterData
        local show = _G.LexusConfig and _G.LexusConfig.EspV3_Count
        local hidden = UEnums.ESlateVisibility.Collapsed

        if not show then
            for _, w in pairs({cd.ImgPlayer, cd.ImgBot, cd.TxtPlayer, cd.TxtBot}) do
                if w and isValidObject(w) then
                    w:SetWidgetVisibility(hidden)
                end
            end
            return
        end

        if not esp_CreateEnemyCounter(canvas, ox, oy) then return end

        -- Retry downloads periodically (max 3 per icon) -- [FIXED]
        local now = os.clock()
        if not (cd.PlayerLoaded and cd.BotLoaded)
           and (now - cd.LastDownloadRetry) > 2.0 then
            cd.LastDownloadRetry = now
            if not cd.PlayerLoaded and cd.ImgPlayer then
                cd.PlayerRetryCount = (cd.PlayerRetryCount or 0) + 1 -- [FIXED]
                if cd.PlayerRetryCount <= 3 then -- [FIXED]
                    _edbg("ICON: retry Player " .. tostring(cd.PlayerRetryCount)) -- [FIXED]
                    loadWidgetImage(cd.ImgPlayer, playerIconURLs,
                        "ic_danger_enemy.png", "Player", cd)
                elseif not cd.PlayerRetryMaxed then -- [FIXED]
                    cd.PlayerRetryMaxed = true -- [FIXED]
                    _edbg("ICON: max retries reached Player") -- [FIXED]
                end -- [FIXED]
            end
            if not cd.BotLoaded and cd.ImgBot then
                cd.BotRetryCount = (cd.BotRetryCount or 0) + 1 -- [FIXED]
                if cd.BotRetryCount <= 3 then -- [FIXED]
                    _edbg("ICON: retry Bot " .. tostring(cd.BotRetryCount)) -- [FIXED]
                    loadWidgetImage(cd.ImgBot, botIconURLs,
                        "ic_clear_boot.png", "Bot", cd)
                elseif not cd.BotRetryMaxed then -- [FIXED]
                    cd.BotRetryMaxed = true -- [FIXED]
                    _edbg("ICON: max retries reached Bot") -- [FIXED]
                end -- [FIXED]
            end
        end

        pcall(function()
            if cd.SlotPlayer then
                cd.SlotPlayer:SetSize(Vector2D(65, 36))
                cd.SlotPlayer:SetPosition(Vector2D(ox, oy))
            end
            if cd.SlotBot then
                cd.SlotBot:SetSize(Vector2D(65, 36))
                cd.SlotBot:SetPosition(Vector2D(ox + 65, oy))
            end
            if cd.SlotTxtPlayer then
                cd.SlotTxtPlayer:SetPosition(Vector2D(ox + 40, oy + 18))
            end
            if cd.SlotTxtBot then
                cd.SlotTxtBot:SetPosition(Vector2D(ox + 65 + 40, oy + 18))
            end

            if cd.LastPlayerCount ~= pc and cd.TxtPlayer and isValidObject(cd.TxtPlayer) then
                cd.TxtPlayer:SetText(tostring(pc))
                cd.LastPlayerCount = pc
            end
            if cd.LastBotCount ~= bc and cd.TxtBot and isValidObject(cd.TxtBot) then
                cd.TxtBot:SetText(tostring(bc))
                cd.LastBotCount = bc
            end

            local vis = UEnums.ESlateVisibility.SelfHitTestInvisible
            local hidden = UEnums.ESlateVisibility.Collapsed
            for _, w in pairs({cd.TxtPlayer, cd.TxtBot}) do
                if w and isValidObject(w) then w:SetWidgetVisibility(vis) end
            end
            if cd.ImgPlayer and isValidObject(cd.ImgPlayer) then
                cd.ImgPlayer:SetWidgetVisibility(cd.PlayerLoaded and vis or hidden)
            end
            if cd.ImgBot and isValidObject(cd.ImgBot) then
                cd.ImgBot:SetWidgetVisibility(cd.BotLoaded and vis or hidden)
            end
        end)
    end
    ESP.UpdateEnemyCounterDisplay = esp_UpdateEnemyCounterDisplay

    -- =========================================================
    -- SHOW / HIDE WIDGET
    -- =========================================================
    local function esp_HideWidget(widget)
        if not widget then return end
        widget.bVisible = false
        local vis = UEnums.ESlateVisibility.Collapsed
        for _, key in ipairs({
            "CornerContainer", "BgWidget", "HealthWidget",
            "WeaponWidget", "FlagWidget", "NameWidget",
            "DistWidget", "StateWidget"
        }) do
            local w = widget[key]
            if w and isValidObject(w) then w:SetWidgetVisibility(vis) end
        end
    end
    ESP.HideWidget = esp_HideWidget

    local function esp_ShowWidget(widget)
        if not widget then return end
        widget.bVisible = true
        local vis   = UEnums.ESlateVisibility.SelfHitTestInvisible
        local hide  = UEnums.ESlateVisibility.Collapsed
        local cfg   = _G.LexusConfig or {}

        local function setVis(w, enabled)
            if w and isValidObject(w) then w:SetWidgetVisibility(enabled and vis or hide) end
        end

        setVis(widget.CornerContainer, cfg.EspV3_Box)
        setVis(widget.BgWidget,        cfg.EspV3_Health)
        setVis(widget.HealthWidget,    cfg.EspV3_Health)
        setVis(widget.WeaponWidget,    cfg.EspV3_Weapon)
        setVis(widget.FlagWidget,      cfg.EspV3_Flag)
        setVis(widget.NameWidget,      cfg.EspV3_Name)
        setVis(widget.DistWidget,      cfg.EspV3_Dist)
        setVis(widget.StateWidget,     cfg.EspV3_State)
    end
    ESP.ShowWidget = esp_ShowWidget

    local function esp_ClearESP() -- [FIXED]
        do -- [FIXED]
            local cd0 = ESP.CounterData -- [FIXED]
            local keep = {} -- [FIXED]
            if cd0 then -- [FIXED]
                for _, w in pairs({cd0.ImgPlayer, cd0.ImgBot, cd0.TxtPlayer, cd0.TxtBot, cd0.SqPlayer, cd0.SqBot}) do -- [FIXED]
                    if w then keep[w] = true end -- [FIXED]
                end -- [FIXED]
            end -- [FIXED]
            for widget in pairs(ESP.OwnedWidgets) do -- [FIXED]
                if not keep[widget] then removeWidget(widget) end -- [FIXED]
            end -- [FIXED]
        end -- [FIXED]
        ESP.OwnedWidgets = {}
        ESP.LocalPawn = nil
        ESP._CanvasScaleX, ESP._CanvasScaleY = 1, 1
        ESP._CanvasOffsetX, ESP._CanvasOffsetY = 0, 0
        ESP._LastTransformTime, ESP._LastHeavyUpdateTime, ESP._LastVisCheckTime = -math.huge, -math.huge, -math.huge
        ESP.BoxWidgets  = {}
        ESP.LineWidgets = {}
        do -- [FIXED]
            local cd = ESP.CounterData -- [FIXED]
            if cd then -- [FIXED]
                for _, w in pairs({cd.ImgPlayer, cd.ImgBot, cd.TxtPlayer, cd.TxtBot, cd.SqPlayer, cd.SqBot}) do -- [FIXED]
                    if w and isValidObject(w) then -- [FIXED]
                        pcall(function() w:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) -- [FIXED]
                    end -- [FIXED]
                end -- [FIXED]
                cd.PlayerLoaded = false -- [FIXED]
                cd.BotLoaded = false -- [FIXED]
                cd.PlayerRetryCount = 0 -- [FIXED]
                cd.BotRetryCount = 0 -- [FIXED]
                cd.PlayerRetryMaxed = nil -- [FIXED]
                cd.BotRetryMaxed = nil -- [FIXED]
                cd.LastPlayerCount = -1 -- [FIXED]
                cd.LastBotCount = -1 -- [FIXED]
                cd.LastDownloadRetry = 0 -- [FIXED]
                cd.bCreated = false -- [FIXED]
            end -- [FIXED]
        end -- [FIXED]
        ESP.ESPCanvas   = nil
        ESP._LastCanvas = nil
        ESP._VisCheckCache = {}
    end
    ESP.ClearESP = esp_ClearESP

    -- =========================================================
    -- MAIN TICK: esp_UpdateESP
    -- =========================================================
    local function esp_UpdateESP()
        if not (_G.LexusConfig and _G.LexusConfig.EspV3_Master) then
            esp_ClearESP()
            return
        end

        local canvas = esp_GetMainCanvas()
        if not canvas then esp_ClearESP(); return end

        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
                            or _G.GameplayData
        if not GameplayData then esp_ClearESP(); return end

        local pc = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
        if not isValidObject(pc) then esp_ClearESP(); return end
        local localPawn = pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety()
        if not isValidObject(localPawn) and GameplayData.GetPlayerCharacter then
            localPawn = GameplayData.GetPlayerCharacter()
        end
        if not isValidObject(localPawn) then esp_ClearESP(); return end
        local now = os.clock and os.clock() or 0
        if ESP._LastCanvas ~= canvas or ESP.LocalPawn ~= localPawn then
            esp_ClearESP()
            ESP._LastCanvas = canvas
            ESP.ESPCanvas = canvas
            ESP.LocalPawn = localPawn
        end

        -- Device-adaptive governor: tick cost napo, har 2s me tier decide karo
        -- Tier 0=Smooth (high-end) 1=Balanced 2=Performance (low-end, lag-free)
        local tickMs = 0
        if (ESP._LastTickTime or 0) > 0 then
            tickMs = (now - ESP._LastTickTime) * 1000
            if tickMs < 0 or tickMs > 500 then tickMs = 0 end
            ESP._AvgTickMs = (ESP._AvgTickMs or 0) * 0.9 + tickMs * 0.1
        end
        ESP._LastTickTime = now

        local qMode = (_G.LexusConfig and _G.LexusConfig.EspV3_Quality) or "Auto"
        local tier = ESP._AdaptiveTier or 0
        if qMode == "Smooth" then tier = 0
        elseif qMode == "Balanced" then tier = 1
        elseif qMode == "Performance" then tier = 2
        elseif (now - (ESP._TierCheckTime or 0)) > 2.0 then
            ESP._TierCheckTime = now
            if (ESP._AvgTickMs or 0) > 25 and tier < 2 then tier = tier + 1
            elseif (ESP._AvgTickMs or 0) < 12 and tier > 0 then tier = tier - 1 end
        end
        ESP._AdaptiveTier = tier

        -- Tier ke hisab se intervals + render limits (low-end pe kam kaam = no lag)
        local transformInt, heavyInt, visInt = 0.25, 0.15, 0.12
        ESP._MaxDist, ESP._MaxTargets = 350, 40
        if tier == 1 then
            transformInt, heavyInt, visInt = 0.4, 0.25, 0.2
            ESP._MaxDist, ESP._MaxTargets = 350, 30
        elseif tier == 2 then
            transformInt, heavyInt, visInt = 0.6, 0.4, 0.3
            ESP._MaxDist, ESP._MaxTargets = 350, 20
        end
        -- NOTE: MAX 350m — har tier me 350m tak har bande ki line draw hogi (user demand)

        -- Throttled transforms
        if (now - ESP._LastTransformTime) > transformInt then
            esp_UpdateCanvasTransform(pc)
            ESP._LastTransformTime = now
        end

        local heavyUpdate = (now - ESP._LastHeavyUpdateTime) > heavyInt
        local visCheck    = (now - ESP._LastVisCheckTime)   > visInt
        if heavyUpdate then ESP._LastHeavyUpdateTime = now end
        if visCheck    then ESP._LastVisCheckTime    = now end

        local snapX, snapY = esp_GetSnapLineStartPos(pc, canvas)

        local myTeam = localPawn.TeamID
            or (localPawn.GetTeamID and localPawn:GetTeamID())
            or 0

        local pawns, seenObjects, seenKeys = {}, {}, {}
        local function merge(list)
            if not list then return end
            for _, pawn in pairs(list) do
                if isValidObject(pawn) and not seenObjects[pawn] then
                    local key
                    pcall(function()
                        key = pawn.PlayerKey
                        if not key and pawn.GetPlayerKey then key = pawn:GetPlayerKey() end
                    end)
                    if key == 0 or key == "0" or key == "" then key = nil end
                    if key ~= nil then key = tostring(key) end
                    if not key or not seenKeys[key] then
                        seenObjects[pawn] = true
                        if key then seenKeys[key] = true end
                        pawns[#pawns + 1] = pawn
                    end
                end
            end
        end
        local function collect(object, name)
            if not object then return end
            local ok, result = pcall(function() return object[name](object) end)
            if not ok or result == nil then
                ok, result = pcall(function() return object[name]() end)
            end
            if ok and result then merge(result) end
        end
        collect(Game, "GetAllPlayerPawns")
        collect(GameplayData, "GetAllPlayerCharacters")
        merge(GameplayData.GameCharacters)
        ESP.ActorCount = #pawns

        for _, widget in pairs(ESP.BoxWidgets) do esp_HideWidget(widget) end
        for key in pairs(ESP.LineWidgets) do esp_HideSnapLine(key) end
        local alive = {}
        local playerCount, botCount = 0, 0
        local rendered = 0 -- adaptive cap: is tick me kitne box/line render hue

        for key, pawn in pairs(pawns) do
            if isValidObject(pawn) and pawn ~= localPawn then
                local team = pawn.TeamID
                    or (pawn.GetTeamID and pawn:GetTeamID())
                    or -1

                local hp = pawn.Health or 0
                local aliveCheck = readBool(pawn, "IsAlive", nil)
                if aliveCheck == nil then
                    aliveCheck = not readBool(pawn, "bDead", false)
                        and (hp > 0 or readBool(pawn, "bIsKnocked", false)
                            or readBool(pawn, "IsKnocked", false))
                end

                if aliveCheck and team ~= myTeam then
                    local pawnKey = pawn -- actor identity; array indexes are unstable
                    alive[pawnKey] = true

                    local isBot = pawn.bIsAI or pawn.bIsAIBot or pawn.bIsABot
                    if not isBot and Game and Game.IsAI then
                        isBot = Game:IsAI(pawn)
                    end
                    if isBot then botCount = botCount + 1
                    else           playerCount = playerCount + 1 end

                    -- Adaptive cull: counter me sab count honge, par box/line
                    -- sirf paas walo + limit tak render honge (low-end pe no lag)
                    local pawnDist = -1
                    pcall(function()
                        if localPawn.GetDistanceTo then
                            pawnDist = math.floor(localPawn:GetDistanceTo(pawn) / 100.0)
                        end
                    end)
                    local renderThis = (pawnDist < 0 or pawnDist <= (ESP._MaxDist or 500))
                    if renderThis then
                        if rendered < (ESP._MaxTargets or 30) then
                            rendered = rendered + 1
                        else
                            renderThis = false
                        end
                    end
                    if not renderThis then
                        local oldW = ESP.BoxWidgets[pawnKey]
                        if oldW then esp_HideWidget(oldW) end
                        esp_HideSnapLine(pawnKey)
                    end

                    local loc = pawn.K2_GetActorLocation
                                and pawn:K2_GetActorLocation()
                    if not loc and pawn.RootComponent then
                        loc = pawn.RootComponent:K2_GetComponentLocation()
                    end

                    if renderThis and loc then
                        local mesh = pawn.Mesh
                            or (pawn.GetMesh and pawn:GetMesh())
                            or pawn.CharacterMesh0

                        local headPos, rootPos

                        if mesh and mesh.GetSocketLocation then
                            local h = mesh:GetSocketLocation("Head")
                            if not h or (h.X == 0 and h.Y == 0 and h.Z == 0) then
                                h = mesh:GetSocketLocation("head")
                            end
                            if h and not (h.X == 0 and h.Y == 0 and h.Z == 0) then
                                headPos = Vector(h.X, h.Y, h.Z + 15)
                            end

                            local r = mesh:GetSocketLocation("root")
                            if not r or (r.X == 0 and r.Y == 0 and r.Z == 0) then
                                r = mesh:GetSocketLocation("Root")
                            end
                            if r and not (r.X == 0 and r.Y == 0 and r.Z == 0) then
                                rootPos = r
                            end
                        end

                        -- Pose detection
                        local isProne  = readBool(pawn, "bIsProning", false)
                                         or readBool(pawn, "bIsProne", false)
                                         or readBool(pawn, "IsProne", false)
                                         or pawn.PoseState == 2
                                         or pawn.PoseState == "Prone"
                        local isCrouch = readBool(pawn, "bIsCrouched", false)
                                         or readBool(pawn, "IsCrouched", false)
                                         or pawn.PoseState == 1
                                         or pawn.PoseState == "Crouch"

                        if not headPos or not rootPos then
                            local headOff = isProne and 18 or (isCrouch and 50 or 88)
                            local rootOff = isProne and -22 or (isCrouch and -68 or -90)
                            if not headPos then
                                headPos = Vector(loc.X, loc.Y, loc.Z + headOff)
                            end
                            if not rootPos then
                                rootPos = Vector(loc.X, loc.Y, loc.Z + rootOff)
                            end
                        end

                        local ok1, headX, headY =
                            esp_ProjectWorldToCanvasLocal(pc, headPos)
                        local ok2, rootX, rootY =
                            esp_ProjectWorldToCanvasLocal(pc, rootPos)

                        local widget = ESP.BoxWidgets[pawnKey]
                        if not (widget and isValidObject(widget.CornerContainer)) then
                            widget = esp_CreateESPWidget(canvas)
                            if widget then ESP.BoxWidgets[pawnKey] = widget end
                        end

                        if widget and isValidObject(widget.CornerContainer) then
                            if ok1 and ok2 then
                                -- Geometry
                                local height = math.max(28, math.abs(rootY - headY))
                                local scale = isProne and 1.1 or (isCrouch and 0.7 or 0.55)
                                local width  = math.max(15, height * scale)

                                local cx     = (headX + rootX) * 0.5
                                local cy     = (rootY + headY) * 0.5
                                local top    = cy - height * 0.5
                                local bottom = cy + height * 0.5

                                esp_UpdateCornerDimensions(widget, width, height)
                                widget.CornerSlot:SetPosition(Vector2D(cx, cy))
                                esp_ShowWidget(widget)

                                -- Health bar
                                local barW = ESP.HealthBarWidth or 2.0
                                local barX = (cx - width * 0.5) - 2.5 - barW * 0.5

                                local hpNow = pawn.Health
                                              or (pawn.GetHealth and pawn:GetHealth())
                                              or 100
                                local hpMax = pawn.HealthMax
                                              or (pawn.GetHealthMax and pawn:GetHealthMax())
                                              or 100
                                if hpMax <= 0 then hpMax = 100 end

                                local pct    = math.max(0, math.min(1, hpNow / hpMax))
                                local fillH  = height * pct

                                widget.BgSlot:SetSize(Vector2D(barW, height))
                                widget.BgSlot:SetPosition(Vector2D(barX, bottom))
                                widget.HealthSlot:SetSize(Vector2D(barW, fillH))
                                widget.HealthSlot:SetPosition(Vector2D(barX, bottom))

                                -- Weapon (cached)
                                if _G.LexusConfig.EspV3_Weapon and (heavyUpdate or widget._cachedWeapon == "") then
                                    local weaponName = "Fist"
                                    local w = (pawn.GetCurrentWeapon and pawn:GetCurrentWeapon())
                                          or (pawn.GetCurrentShootWeapon and pawn:GetCurrentShootWeapon())
                                          or (pawn.WeaponManagerComponent
                                              and pawn.WeaponManagerComponent.CurrentWeaponReplicated)

                                    if w and isValidObject(w) then
                                        local raw
                                        if type(w.GetWeaponName) == "function" then
                                            raw = w:GetWeaponName()
                                        end
                                        if not raw then raw = w.WeaponName end
                                        if raw and raw ~= "" then
                                            weaponName = tostring(raw)
                                                :gsub("^BP_", "")
                                                :gsub("_C$", "")
                                                :gsub("_Wrapper$", "")
                                        end
                                    end

                                    if widget._cachedWeapon ~= weaponName then
                                        widget.WeaponWidget:SetText(weaponName)
                                        widget._cachedWeapon = weaponName
                                    end
                                end
                                widget.WeaponSlot:SetPosition(Vector2D(cx, top - 3.5))

                                -- Nation flag (cached)
                                if _G.LexusConfig.EspV3_Flag and (heavyUpdate or not widget._cachedNation) then
                                    local nation = (pawn.PlayerState and pawn.PlayerState.Nation)
                                                or pawn.Nation or ""
                                    nation = tostring(nation)
                                    if nation == "" or nation == "nil" or nation == "0" then
                                        nation = "G1"
                                    end

                                    if widget._cachedNation ~= nation then
                                        local resPath
                                        if CDataTable and CDataTable.GetTableData then
                                            local d = CDataTable.GetTableData("RegionConfig", nation)
                                            if d and d.res_path and d.res_path ~= "" then
                                                resPath = d.res_path
                                            end
                                        end
                                        if not resPath then
                                            resPath = "/Game/UMG/Texture/Atlas/NationalflagUI/Frames/T_icon_flag_iland_png.T_icon_flag_iland_png"
                                        end

                                        if widget.FlagWidget and isValidObject(widget.FlagWidget) then
                                            local applied = false
                                            if widget.FlagWidget.SetBrushResourceFromPathSync then
                                                widget.FlagWidget:SetBrushResourceFromPathSync(resPath, false)
                                                applied = true
                                            end
                                            if not applied and widget.FlagWidget.SetBrushFromPathAsync then
                                                widget.FlagWidget:SetBrushFromPathAsync(resPath, false)
                                                applied = true
                                            end
                                            if not applied then
                                                local util = package.loaded["client.slua_ui_framework.util"]
                                                if util and util.SetTexture then
                                                    util.SetTexture(widget.FlagWidget, resPath, { sync = true })
                                                    applied = true
                                                end
                                            end
                                            if not applied then
                                                local assetUtil = package.loaded["common.asset_util"]
                                                local tex = assetUtil and assetUtil.GetAssetSync
                                                            and assetUtil.GetAssetSync(resPath)
                                                if not tex and CGame and CGame.LoadObject then
                                                    tex = CGame:LoadObject(resPath)
                                                end
                                                if tex and widget.FlagWidget.SetBrushFromTexture then
                                                    widget.FlagWidget:SetBrushFromTexture(tex, false)
                                                end
                                            end
                                        end
                                        widget._cachedNation = nation
                                    end
                                end
                                if widget.FlagSlot then
                                    widget.FlagSlot:SetPosition(Vector2D(cx, top - 22.0))
                                end

                                -- Name (cached)
                                if heavyUpdate or widget._cachedName == "" then
                                    local name
                                    if isBot then
                                        name = "Bot"
                                    else
                                        name = pawn.PlayerName
                                            or pawn.PlayerNamePublic
                                            or (pawn.GetPlayerName and pawn:GetPlayerName())
                                            or "Player"
                                    end
                                    name = tostring(name)
                                    if widget._cachedName ~= name then
                                        widget.NameWidget:SetText(name)
                                        widget._cachedName = name
                                    end
                                end
                                widget.NameSlot:SetPosition(Vector2D(cx, bottom + 4.0))

                                -- Distance
                                local dist = math.floor(localPawn:GetDistanceTo(pawn) / 100.0)
                                local distStr = tostring(dist) .. "m"
                                if widget._cachedDist ~= distStr then
                                    widget.DistWidget:SetText(distStr)
                                    widget._cachedDist = distStr
                                end
                                widget.DistSlot:SetPosition(Vector2D(cx, bottom + 20.5))

                                -- Visibility (throttled)
                                if visCheck or ESP._VisCheckCache[pawnKey] == nil then
                                    local vis = pc.LineOfSightTo and pc:LineOfSightTo(pawn) or false
                                    ESP._VisCheckCache[pawnKey] = vis
                                end
                                local visible = ESP._VisCheckCache[pawnKey]

                                -- State (cached)
                                if heavyUpdate or widget._cachedState == "" then
                                    local isKnocked = readBool(pawn, "bIsKnocked", false)
                                        or readBool(pawn, "IsKnocked", false)

                                    local stateText, stateColor
                                    if isKnocked then
                                        stateText, stateColor = "Knocked", redSlateColor
                                    elseif not visible then
                                        stateText, stateColor = "Cover", redSlateColor
                                    else
                                        stateText, stateColor = "Open", greenSlateColor
                                    end

                                    if widget._cachedState ~= stateText then
                                        widget.StateWidget:SetText(stateText)
                                        safeSetColor(widget.StateWidget, stateColor)
                                        widget._cachedState = stateText
                                    end
                                end
                                widget.StateSlot:SetPosition(Vector2D(cx, bottom + 37.0))

                                -- Snap line: 250m tak HAR bande pe draw, jitna door utni halki-patli
                                -- 50m=dark Full | 100m=0.8 | 150m=0.65 | 200m=0.5 | 250m=0.35 faintest
                                if _G.LexusConfig.EspV3_Line then
                                    local lineColor = visible and greenColor or redColor
                                    local thin, alpha, band = 1.0, 1.0, "n"
                                    if dist >= 200 then band, thin, alpha = "x", 0.6, 0.35
                                    elseif dist >= 150 then band, thin, alpha = "f", 0.7, 0.5
                                    elseif dist >= 100 then band, thin, alpha = "m", 0.8, 0.65
                                    elseif dist >= 50 then band, thin, alpha = "q", 0.9, 0.8 end
                                    if band ~= "n" then
                                        -- Color sirf tab banao jab band/visible badle (har tick garbage nahi)
                                        local fkey = (visible and "v" or "h") .. band
                                        if widget._LineFadeKey ~= fkey then
                                            widget._LineFadeKey = fkey
                                            widget._LineFadeColor = nil
                                            pcall(function()
                                                if LinearColor then
                                                    if visible then
                                                        widget._LineFadeColor = LinearColor(0.0, 1.0, 0.05, alpha)
                                                    else
                                                        widget._LineFadeColor = LinearColor(1.0, 0.15, 0.15, alpha)
                                                    end
                                                end
                                            end)
                                        end
                                        if widget._LineFadeColor then
                                            lineColor = widget._LineFadeColor
                                        end
                                    elseif widget._LineFadeKey ~= nil then
                                        widget._LineFadeKey = nil
                                        widget._LineFadeColor = nil
                                    end
                                    esp_UpdateSnapLine(pawnKey, cx, top,
                                        snapX, snapY, lineColor, canvas, thin)
                                else
                                    esp_HideSnapLine(pawnKey)
                                end
                            else
                                esp_HideWidget(widget)
                                esp_HideSnapLine(pawnKey)
                            end
                        end
                    end
                end
            end
        end

        -- Hide widgets for dead/removed pawns
        for key, w in pairs(ESP.BoxWidgets) do
            if not alive[key] then
                removeBox(w)
                ESP.BoxWidgets[key] = nil
                ESP._VisCheckCache[key] = nil
            end
        end
        for key, _ in pairs(ESP.LineWidgets) do
            if not alive[key] then
                removeWidget(ESP.LineWidgets[key].Widget)
                ESP.LineWidgets[key] = nil
                ESP._VisCheckCache[key] = nil
            end
        end

        -- Enemy counter
        local counterY = snapY - counterTextSize - 2
        if counterY < 10 then counterY = 48 end
        -- Dono icons ka total width = 130, isliye center se 65 left shift
        esp_UpdateEnemyCounterDisplay(playerCount, botCount, canvas, snapX - 65, counterY)
    end
    ESP.UpdateESP = esp_UpdateESP

    return ESP
end

return LoadESPV3System
end)()
local B = {Renderer=nil, Status=0, LastError=nil, Disposed=false, RetryAt=0}
local defaults = {
    EspV3_Master=false, EspV3_Count=true, EspV3_Box=true, EspV3_Line=true,
    EspV3_Health=true, EspV3_Name=true, EspV3_Dist=true, EspV3_Weapon=true,
    EspV3_Flag=true, EspV3_State=true,
}
local function boolean(v)
    if v==true or v==1 or v=='true' or v=='1' then return true end
    if v==false or v==0 or v=='false' or v=='0' then return false end
end
local function config()
    _G.LexusConfig = _G.LexusConfig or {}
    local c=_G.LexusConfig
    for key,default in pairs(defaults) do
        local v=boolean(c[key]); if v==nil then v=default end; c[key]=v
    end
    return c
end
local function save() if _G.SaveModSettings then pcall(_G.SaveModSettings) end end
local notifier
local allowed=function() return true end
function B.SetAllowed(fn) allowed=fn end
function B.SetNotifier(fn) notifier=fn end
local function status(code)
    B.Status=code
    config().EspV3_RuntimeStatus=({[0]='OFF',[1]='WAITING',[2]='READY',[3]='ERROR',[4]='BLOCKED'})[code]
end
local function report(phase,message)
    message=phase..': '..tostring(message)
    config().EspV3_LastError=message
    config().EspV3_DiagnosticBuild='R4'
    local changed=B.LastError~=message
    B.LastError=message
    status(3)
    if changed then
        if print then print('[ESP V3 R4] '..message) end
        if notifier then pcall(notifier,'ESP V3 R4: '..message) end
        save() -- Exact error survives leaving the menu, even if notifications fail.
    end
end
local function clear()
    if B.Renderer and B.Renderer.ClearESP then
        local ok,err=pcall(B.Renderer.ClearESP)
        if not ok then report('cleanup',err) end
    end
end
function B.Stop()
    B.TimerGeneration=(B.TimerGeneration or 0)+1
    B.TimerPending=false
    clear(); status(0)
end
function B.Dispose() B.Disposed=true; B.Stop(); B.Renderer=nil end
function B.Get(key) return config()[key] end
function B.Update()
    if B.Disposed then return false end
    if not config().EspV3_Master then
        if B.Status~=0 then B.Stop() end
        return false
    end
    if not allowed() then
        clear(); status(4)
        return false
    end
    local now=os.clock()
    if now<B.RetryAt then return false end
    if not B.Renderer then
        local ok,renderer=pcall(initializeRenderer)
        if not ok or type(renderer)~='table' then
            B.RetryAt=now+3
            report('initialize',renderer or 'No renderer returned')
            return false
        end
        B.Renderer=renderer
    end
    local ok,err=pcall(B.Renderer.UpdateESP)
    if not ok then
        clear()
        B.RetryAt=now+3
        report('render',err)
        return false
    end
    status(B.Renderer.LocalPawn and 2 or 1)
    return true
end
-- Supervised by the already-working base loop; never starts native rendering in a menu callback.
function B.Pump()
    if B.Disposed then return false end
    if not config().EspV3_Master or not allowed() then
        if B.TimerPending then
            B.TimerGeneration=(B.TimerGeneration or 0)+1
            B.TimerPending=false
        end
        return B.Update()
    end
    local now=os.clock()
    if B.TimerPending and now-(B.LastTimerBeat or now)<1.0 then return true end
    -- A missing/stalled scheduler falls back to the base loop rather than killing V3.
    B.TimerGeneration=(B.TimerGeneration or 0)+1
    local generation=B.TimerGeneration
    B.TimerPending=false
    B.Update()
    local ok,ticker=pcall(require,'common.time_ticker')
    if not ok or not ticker or type(ticker.AddTimerOnce)~='function' then return false end
    local tick
    tick=function()
        if B.Disposed or B.TimerGeneration~=generation then return end
        B.TimerPending=false
        B.LastTimerBeat=os.clock()
        B.Update()
        if B.Disposed or not config().EspV3_Master or not allowed() then return end
        local scheduled=pcall(ticker.AddTimerOnce,0.05,tick)
        B.TimerPending=scheduled
    end
    B.LastTimerBeat=now
    local scheduled=pcall(ticker.AddTimerOnce,0.05,tick)
    B.TimerPending=scheduled
    return scheduled
end
function B.Start()
    if B.Disposed then return false end
    if config().EspV3_Master then status(1) end
    return true
end
function B.Set(key,value)
    if B.Disposed or defaults[key]==nil then return false end
    local normalized=boolean(value)
    if normalized==nil then report('menu','Unsupported value '..tostring(value)); return false end
    config()[key]=normalized
    if key=='EspV3_Master' then
        B.RetryAt=0
        if normalized then B.Start() else B.Stop() end
    elseif B.Renderer then
        local renderer=B.Renderer
        local ok,err=pcall(function()
            for _,widget in pairs(renderer.BoxWidgets) do
                if widget.bVisible then renderer.ShowWidget(widget) end
            end
            if key=='EspV3_Line' and not normalized then
                for actor in pairs(renderer.LineWidgets) do renderer.HideSnapLine(actor) end
            end
            if key=='EspV3_Count' and not normalized then
                -- The disabled branch hides existing counter widgets without creating any.
                renderer.UpdateEnemyCounterDisplay(0,0,nil,0,0)
            end
        end)
        if not ok then report('toggle visibility',err) end
    end
    save()
    return true -- accepted setting, not a claim of successful rendering
end
function B.OnEndPlay(character)
    local pawn=B.Renderer and B.Renderer.LocalPawn
    if pawn and (pawn==character or pawn==character.Object) then
        clear(); status(config().EspV3_Master and 1 or 0)
    end
end
local previous=_G.ESPV3Bridge
if previous and type(previous.Dispose)=='function' then pcall(previous.Dispose) end
_G.ESPV3Bridge=B
config().EspV3_DiagnosticBuild='R4'
status(config().EspV3_Master and 1 or 0)
return B

end)()
ESPV3Bridge.SetNotifier(function(msg)
    pcall(function()
        local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt", "a")
        if _f then _f:write("espR4 " .. tostring(msg) .. string.char(10)) _f:close() end
    end)
end)

    _G._espV3Gen = 0
    _G.StartESPV3 = function()
        _G._espV3Gen = (_G._espV3Gen or 0) + 1
        local gen = _G._espV3Gen
        pcall(function()
            local function EspV3Tick()
                if gen ~= _G._espV3Gen then return end
                pcall(function()
                    local tt = require("common.time_ticker")
                    if tt and tt.AddTimerOnce then tt.AddTimerOnce(0.05, EspV3Tick) end
                end)
                if _G.ESPV3Bridge and _G.ESPV3Bridge.Pump then
                    local _ok, _err = pcall(_G.ESPV3Bridge.Pump)
                    if not _ok then
                        _G._espV3Err = (_G._espV3Err or 0) + 1
                        if _G._espV3Err <= 3 then
                            pcall(function()
                                local _f1 = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt", "a")
                                if _f1 then _f1:write("tickerr " .. tostring(_err) .. string.char(10)) _f1:close() end
                            end)
                        end
                    end
                end
            end
            local how = "none"
            local tt0 = nil
            pcall(function() tt0 = require("common.time_ticker") end)
            if tt0 and tt0.AddTimerOnce then
                tt0.AddTimerOnce(0.05, EspV3Tick)
                how = "tt"
                _G._espV3Timer = true
            elseif _G.Game and _G.Game.AddGameTimer then
                _G._espV3Timer = _G.Game:AddGameTimer(0.07, true, EspV3Tick)
            elseif slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if Valid(pc) and type(pc.AddGameTimer) == "function" then
                    _G._espV3Timer = pc:AddGameTimer(0.07, true, EspV3Tick)
                end
            end
            pcall(function()
                local _f2 = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/espv3_dbg.txt", "a")
                if _f2 then _f2:write("timer " .. tostring(how) .. string.char(10)) _f2:close() end
            end)
        end)
    end
    pcall(function() if _G.StartESPV3 then _G.StartESPV3() end end)
local _cached_linear_color = nil
local _cached_skeletal_mesh = nil
local _cached_gameplay_data = nil

local function getCachedLinearColor()
    if _cached_linear_color == nil then _cached_linear_color = import("LinearColor") or _G.FLinearColor end
    return _cached_linear_color
end

local function getCachedSkeletalMesh()
    if _cached_skeletal_mesh == nil then _cached_skeletal_mesh = import("SkeletalMeshComponent") end
    return _cached_skeletal_mesh
end

local function getCachedGameplayData()
    if _cached_gameplay_data == nil then
        local ok, mod = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if ok then _cached_gameplay_data = mod end
    end
    return _cached_gameplay_data
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 0.5) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            local isPendingKill = false
            pcall(function() if type(cachedMesh.IsPendingKill) == "function" then isPendingKill = cachedMesh:IsPendingKill() end end)
            if Valid(cachedMesh) and not isPendingKill then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end
    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = getCachedSkeletalMesh()
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    if markData then markData.CachedMeshes = meshes; markData.CachedMeshTime = curTime end
    return meshes
end

local function InitFakeHWID()
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        local chars = "0123456789ABCDEF"
                        local hwid = ""
                        for i = 1, 32 do
                            local idx = math.random(1, #chars)
                            hwid = hwid .. chars:sub(idx, idx)
                            if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                        end
                        _G.FakeHWID_String = hwid
                    end
                    return _G.FakeHWID_String
                end
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
            Notify("Fake HWID Hook Active")
        end
    end)
end

-- ====================================================================
-- SKIN SYSTEM: Helper Functions
-- ====================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

function _G.InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end

-- ====================================================================
-- SKIN SYSTEM: DATA TABLES
-- ====================================================================
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0}
}

_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}

_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end

local _SKIN_BASE_PATH    = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
local _SKIN_ATTACH_PATH  = _SKIN_BASE_PATH .. "attachments.txt"
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}

local ATTACH_NAME_MAP = {
    ["Red Dot Sight"]          = "RedDot",
    ["Holographic Sight"]      = "Holo",
    ["2x Scope"]               = "Scope2x",
    ["3x Scope"]               = "Scope3x",
    ["4x Scope"]               = "Scope4x",
    ["6x Scope"]               = "Scope6x",
    ["8x Scope"]               = "Scope8x",
    ["Canted Sight"]           = "CantedSight",
    ["Flash Hider"]            = "FlashHider",
    ["Compensator"]            = "Compensator",
    ["Suppressor"]             = "Suppressor",
    ["Extended Mag"]           = "ExtMag",
    ["Quickdraw Mag"]          = "QuickMag",
    ["Extended Quickdraw Mag"] = "ExtQuickMag",
    ["Angled Foregrip"]        = "AngledGrip",
    ["Vertical Foregrip"]      = "VerticalGrip",
    ["Thumb Grip"]             = "ThumbGrip",
    ["Half Grip"]              = "HalfGrip",
    ["Light Grip"]             = "LightGrip",
    ["Laser Sight"]            = "LaserSight",
    ["Tactical Stock"]         = "TactStock",
    ["Stock"]                  = "MicroStock",
    ["Cheek Pad"]              = "CheekPad",
}

local _attachFileCache = nil

local function _parseAttachmentsFile()
    local result = {}
    pcall(function()
        local f = io.open(_SKIN_ATTACH_PATH, "r")
        if not f then return end
        local content = f:read("*all")
        f:close()
        local curSkin = nil
        for line in content:gmatch("[^\r\n]+") do
            local firstNum = line:match("^(%d+)%s*|")
            if firstNum then
                local num = tonumber(firstNum)
                if num and num > 1100000000 then
                    curSkin = num
                    result[curSkin] = result[curSkin] or {}
                elseif num and curSkin then
                    local attachName = line:match("^%d+%s*|%s*%x+%s*|%s*(.-)%s*$")
                    if not attachName then attachName = line:match("^%d+%s*|%s*(.-)%s*$") end
                    if attachName and attachName ~= "" then
                        local key = ATTACH_NAME_MAP[attachName]
                        if key then result[curSkin][key] = num end
                    end
                end
            elseif line:find("^#%-%-%-%-") and line:find("skin") then
                curSkin = nil
            end
        end
    end)
    return result
end

_G.GetAttachForSkin = function(skinId, key)
    if not skinId or skinId == 0 or not key then return nil end
    if not _attachFileCache then _attachFileCache = _parseAttachmentsFile() end
    local t = _attachFileCache[skinId]
    if not t then return nil end
    local v = t[key]
    return (v and v > 0) and v or nil
end

_G.GetAttachFileCache = function()
    if not _attachFileCache then _attachFileCache = _parseAttachmentsFile() end
    return _attachFileCache
end

_G.download_item = function(i)
    if not i then return end
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PC = require("client.slua.logic.download.puffer_const")
        if PM.GetState(PC.ENUM_DownloadType.ODPAK, {i}) ~= PC.ENUM_DownloadState.Done then
            PM.Download(PC.ENUM_DownloadType.ODPAK, {i})
        end
    end)
end

_G.muzzles = {
    id_flash_hider = { 201010, 201005, 201004 },
    id_compensator = { 201009, 201003, 201002 },
    id_suppressor  = { 201011, 201006, 201007 }
}
_G.foregrips = {
    id_Angledforegrip = 202001,
    id_thumb_grip     = 202006,
    id_vertical_grip  = 202002,
    id_light_grip     = 202004,
    id_half_grip      = 202005,
    id_ergonomic_grip = 202051,
    id_laser_sight    = 202007
}
_G.magazines = {
    id_expanded_mag       = { 204011, 204007, 204004 },
    id_quick_mag          = { 204012, 204008, 204005 },
    id_expanded_quick_mag = { 204013, 204009, 204006 }
}
_G.scopes = {
    id_reddot = 203001,
    id_holo   = 203002,
    id_2x     = 203003,
    id_3x     = 203014,
    id_4x     = 203004,
    id_6x     = 203015,
    id_8x     = 203005
}
_G.stock = {
    id_microStock = 205001,
    id_tactical   = 205002,
    id_bulletloop = 204014,
    id_CheekPad   = 205003
}

_G.ItemUpgradeSystem = nil
pcall(function()
    local MM  = require("client.module_framework.ModuleManager")
    local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
    if IUS then
        IUS:DefineAndResetData()
        IUS:OnInitialize()
        _G.ItemUpgradeSystem = IUS
    end
end)

_G.get_group_id = function(itemId)
    if not _G.ItemUpgradeSystem or not itemId then return nil end
    local cfg = _G.ItemUpgradeSystem:GetUpgradeCfg(itemId)
    return cfg and cfg.GroupID or nil
end

_G.InitParts = function(groupId, itemId)
    if not itemId then return _G.g_parts end
    if _G.g_parts[itemId] and next(_G.g_parts[itemId]) then return _G.g_parts end
    _G.g_parts[itemId] = {}
    if not _G.ItemUpgradeSystem then return _G.g_parts end
    if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
        groupId = _G.ItemUpgradeSystem:GetNormalGroupID(groupId or _G.get_group_id(itemId))
    else
        groupId = groupId or _G.get_group_id(itemId)
    end
    if not groupId then return _G.g_parts end
    local cfg = rawGetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
    if cfg then
        for _, info in pairs(cfg) do
            local partId = info.PartId
            if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                if switched and switched ~= partId then partId = switched end
            end
            local item = rawGetTableData("Item", partId)
            if item and item.ItemName then
                _G.g_parts[itemId][item.ItemName] = partId
            end
        end
    end
    return _G.g_parts
end

_G.GetRawAttachMap = function(skinid)
    if not skinid or skinid <= 0 then return {} end
    if _G.skinAttachCache[skinid] then return _G.skinAttachCache[skinid] end
    local UAvatarUtils = import("AvatarUtils")
    if not UAvatarUtils then return {} end
    local list = UAvatarUtils.GetWeaponAvatarDefaultAttachmentSkin(skinid, {}, false) or {}
    _G.skinAttachCache[skinid] = list
    return list
end

_G.GetSlotFromSkinID = function(skinid, slot)
    if not skinid or not slot then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local attachmentTypeMap = {
        [1] = {291004,291102,291001,291006,291005,291002,293003,293004,293009,293007,293005,293006,295001,295002,291007,291003,292002,292003,291011,291008},
        [2] = {205005,205102,205007,205009,205006},
        [3] = {203008,203009,203006,203022,203010}
    }
    local targetIDs = attachmentTypeMap[slot]
    if not targetIDs then return 0 end
    for _, targetID in ipairs(targetIDs) do
        for attachID, attachSkinID in pairs(list) do
            if attachID == targetID then return attachSkinID end
        end
    end
    return 0
end

_G.AutoDetectAttach = function(skinid, base_id)
    if not skinid or not base_id then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local v = list[base_id]
    return (v and v > 0) and v or 0
end

_G.get_muzzleid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.muzzles[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_flash_hider") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "FlashHider") or (p and p["Flash Hider"]) or (auto > 0 and auto) or current_id
    elseif is_in("id_compensator") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Compensator") or (p and p["Compensator"]) or (auto > 0 and auto) or current_id
    elseif is_in("id_suppressor") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Suppressor") or (p and p["Suppressor"]) or (auto > 0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_forgripid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.foregrips.id_Angledforegrip then
        current_id = _G.GetAttachForSkin(avatarid, "AngledGrip") or (p and p["Angled Foregrip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_thumb_grip then
        current_id = _G.GetAttachForSkin(avatarid, "ThumbGrip") or (p and p["Thumb Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_vertical_grip then
        current_id = _G.GetAttachForSkin(avatarid, "VerticalGrip") or (p and p["Vertical Foregrip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_light_grip then
        current_id = _G.GetAttachForSkin(avatarid, "LightGrip") or (p and p["Light Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_half_grip then
        current_id = _G.GetAttachForSkin(avatarid, "HalfGrip") or (p and p["Half Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_ergonomic_grip then
        current_id = (p and p["Ergonomic Grip"]) or (auto > 0 and auto) or current_id
    elseif current_id == _G.foregrips.id_laser_sight then
        current_id = _G.GetAttachForSkin(avatarid, "LaserSight") or (p and p["Laser Sight"]) or (auto > 0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_magazinesid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.magazines[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_expanded_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtMag") or (p and p["Extended Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    elseif is_in("id_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "QuickMag") or (p and p["Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    elseif is_in("id_expanded_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtQuickMag") or (p and p["Extended Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid, 1) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 1)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_scopeid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.scopes.id_reddot then
        current_id = _G.GetAttachForSkin(avatarid, "RedDot") or (p and p["Red Dot Sight"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_holo then
        current_id = _G.GetAttachForSkin(avatarid, "Holo") or (p and p["Holographic Sight"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_2x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope2x") or (p and p["2x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_3x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope3x") or (p and p["3x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_4x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope4x") or (p and p["4x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_6x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope6x") or (p and p["6x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    elseif current_id == _G.scopes.id_8x then
        current_id = _G.GetAttachForSkin(avatarid, "Scope8x") or (p and p["8x Scope"]) or _G.GetSlotFromSkinID(avatarid, 3) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 3)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.get_stockid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    if current_id == _G.stock.id_microStock then
        current_id = _G.GetAttachForSkin(avatarid, "MicroStock") or (p and p["Stock"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_tactical then
        current_id = _G.GetAttachForSkin(avatarid, "TactStock") or (p and p["Tactical Stock"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_bulletloop then
        current_id = (p and p["Bullet Loop"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    elseif current_id == _G.stock.id_CheekPad then
        current_id = _G.GetAttachForSkin(avatarid, "CheekPad") or (p and p["Cheek Pad"]) or _G.GetSlotFromSkinID(avatarid, 2) or (auto > 0 and auto) or current_id
    else
        local fb = _G.GetSlotFromSkinID(avatarid, 2)
        if fb and fb > 0 then current_id = fb end
    end
    return current_id, (initial_id ~= current_id)
end

_G.apply_attachment = function(CurWeapon, avatarid)
    local array = CurWeapon.synData
    for AttachIdx = 0, 4 do
        local Data = array:Get(AttachIdx)
        local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
        if itemid and itemid > 0 and itemid < 10000000 then
            local isrefresh = false
            if AttachIdx == 0 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_muzzleid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 1 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_forgripid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 2 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_magazinesid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 3 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_stockid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 4 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(slua.IndexReference(Data, "defineID").TypeSpecificID, avatarid)
                array:Set(AttachIdx, Data)
            else
                break
            end
            if isrefresh then
                _G.download_item(slua.IndexReference(Data, "defineID").TypeSpecificID)
                CurWeapon:DelayHandleAvatarMeshChanged()
            end
        end
    end
end

_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}

_G.OutfitSkins = {
    Suit = {1406971,1406469,1405870,1407811,1407103,1408045,1408038,1407219,1407990,1405628,1407920,1407916,1407895,1405760,1407870,1407856,1407812,1407758,1407789,1407682,1407696,1407695,1407632,1407631,1407667,1407618,1407573,1407572,1407559,1407558,1407550,1407523,1407718,1407512,1407471,1407470,1406985,1407353,1407366,1407330,1407487,1410668,1407276,1407275,1407142,1407141,1407140,1406897,1406891,1407187,1405802,1405192,1405334,1400687,1405340,1405623,1405132,1405436,1405435,1405434,1405433,1405208,1407916,1407917,1407918,1407921,1407921,1407926,1407901,1407902,1407903,1407904,1407822,1407823,1407824,1407825,1407807,1407808,1407845,1407846,1407847,1407848,1407794,1411037,1407795,1411038,1407796,1411039},
    Pants = {1404002,1404050,1404425,1404495,1400650,1404522,1404441,1404152,1404196,1404134,1404137,1404164,1404191,1404466,1400052,404035,1404181,404084,1404516},
    Hair = {40605010,40605011,40605012,1410480,1410085,1410299,1402834,441400152,1400150,1402582,1410289,1402218,1402223,1402283,1400426},
    Bag = {
        {501001, 501002, 501003}, {1501003699, 1501002174, 1501003174}, {1501001220, 1501002220, 1501003220},
        {1501001051, 1501002051, 1501003051}, {1501001443, 1501002443, 1501003443}, {1501001265, 1501002265, 1501003265},
        {1501001321, 1501002321, 1501003321}, {1501001277, 1501002277, 1501003277}, {1501001550, 1501002550, 1501003550},
        {1501001592, 1501002592, 1501003592}, {1501001608, 1501002608, 1501003608}, {1501001024, 1501002024, 1501003024},
        {1501001019, 1501002019, 1501003019}, {1501001179, 1501002179, 1501003179}, {1501001194, 1501002194, 1501003194},
        {1501001346, 1501002346, 1501003346}
    },
    Helmet = {
        {502001, 502002, 502003}, {1502001014, 1502002014, 1502003014}, {1502001349, 1502002349, 1502003349},
        {1502001012, 1502002012, 1502003012}, {1502001009, 1502002009, 1502003009}, {1502001397, 1502002397, 1502003397},
        {1502001390, 1502002390, 1502003390}, {1502001381, 1502002381, 1502003381}, {1502001358, 1502002358, 1502003358},
        {1502001350, 1502002350, 1502003350}, {1502001342, 1502002342, 1502003342}
    },
    Pet = {50000,50001,50002,50003,50004,50005,50006,50021,50022,50038,50039,50040}
}

_G.skinIdMappings = {
    [101004]={101004, 1101004246,1101004226,1101004236,1101004062,1101004078,1101004086,1101004201,1101004218},
    [101001]={101001,1101001276,1101001089,1101001213,1101001172,1101001127,1101001230,1101001241},                    
    [101003]={101003,1101003227,1103003208,1101003195,1101003187,1101003098,1101003166,1101003218},                    
    [102002]={102002,1102002136,1102002043,1102002061,1102002424},                                          
    [101008]={101008,1101008146,1101008154,1101008079,1101008126,1101008104,1101008146,1101008061,1101008116},                    
    [101006]={101006,1101006085,1101006061,1101006074,1101006043,1101006032,1101006084},
    [102001]={102001, 1102001120}, -- UZI Băng Giá
    [101005]={101005, 1101005098}, -- Groza Godzilla Bốc Lửa
    [104003]={104003, 1104003037}, -- S12K Nguyên Tử
    [104004]={104004, 1104004035, 1104004041}, -- DBS Quái Thú & Sandsinger
    [101101]={101101, 1101101007}, --asm
    [101007]={101007, 1101007071,1101007062,1101007046,1101007078,1101007072},  -- QBZ
    [101012]={101012, 1101012033},  -- Honey Badger
    [101002]={101002, 1101002081,1101002056,1101002029,1101002149},  -- M16A4
    [101102]={101102, 1101102049,1101102056,1101102025,1101102017,1101102007,1101102032},  -- ACE32
    
    [103001]={103001, 1103001202,1103001191,1103001179,1103001146,1103001101,1103001079,1103001202},  -- Kar98k
    [103002]={103002, 1103002113,1103002098,1103002087,1103002060,1103002059,1103002030},  -- M24
    [103003]={103003, 1103003087,1103003079,1103003069,1103003062,1103003055,1103003051,1103003042,1103003030,1103003022,1103003092},  -- AWM
    
}

_G.VehicleSkins = { 
    [1961001] = { 1961151,1961152,1961153,1961147,1961148,1961149,1961144,1961145,1961137,1961138,1961139,1961066,1961067,1961065,1961062,1961063,1961064,1961054,1961055,1961056,1961057,1961051,1961052,1961053,1961048,1961049,1961050,1961044,1961045,1961046,1961047,1961041,1961042,1961043,1961038,1961039,1961040,1961033,1961034,1961035,1961029,1961030,1961031,1961032,1961007,1961010,1961012,1961013,1961014,1961015,1961140,1961141,1961142,1961143,1991023,1991024 }, --cople rb
    [1903001] = { 1903228,1903220,1903221,1903223,1903218,1903219,1903213,1903212,1903202,1908094,1908095,1903193,1903192,1903191,19030790,19030791,19030800,19030801,1903074,1903075,1903076,1903071,1903072,1903073,1903216,1903217,1991001,1991002,1991003,1991004,1903088,1903089,1903090,1903023 }, --dacia
    [1915004] = { 1915021, 1915022, 1915008, 1915009, 1914011 }, -- Mirado open top        
    [1908001] = { 1908108,1908109,19080951,19081080,1908084,1908085,1908075,1908077,1908078,1908070,1908069,1908066,1908086,1908088,1908089,1908018 },  --uaz 
    [1907002] = { 1907058, 1907054, 1907059, 1907053, 1907063, 1907072, 1907040, 1907041, 1907027, 1907047, 1907021} -- Buggy 
}
_G.CustSlotType = { ClothesEquipemtSlot=5, BackpackEquipemtSlot=8, HelmetEquipemtSlot=9, ParachuteEquipemtSlot=11, GlideEquipemtSlot=15 }

-- ====================================================================
-- SKIN SYSTEM: LOGIC FUNCTIONS
-- ====================================================================
local function DownloadGameItem(id)
    local puffer_manager = require('client.slua.logic.download.puffer.puffer_manager')
    local puffer_const = require('client.slua.logic.download.puffer_const')
    if not puffer_manager or not puffer_const then return end
    local state = puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, {id})
    if state ~= puffer_const.ENUM_DownloadState.Done and state ~= puffer_const.ENUM_DownloadState.Downloading then
        puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, {id})
    end
end

_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        if not _G.skinIdCache2[targetSkinId] then
            if _G.download_item then pcall(_G.download_item, targetSkinId) end
            _G.skinIdCache2[targetSkinId] = true
        end
        return targetSkinId
    end
    return weaponID
end

_G.equip_character_avatar = function(Character)
    if not Character or not slua.isValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = import("BackpackUtils")
    local SlotSyncData = Character.AvatarComponent2.NetAvatarData and Character.AvatarComponent2.NetAvatarData.SlotSyncData
    if not SlotSyncData or not slua.isValid(SlotSyncData) or not BackpackUtils then return end
    
    local function EquipAvatar(ApplyDataIdx, mappedSkin, ApplyEquipSlot, isLevelDependent, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return end
        local slotData = SlotSyncData:Get(ApplyDataIdx)
        if slotData and slotData.SlotID == ApplyEquipSlot then
            local applyItemId = mappedSkin
            if isLevelDependent and type(mappedSkin) == "table" then
                local level = levelFunc(slotData.AdditionalItemID) or 1
                if level < 1 then level = 1 end
                if level > 3 then level = 3 end
                applyItemId = mappedSkin[level] or mappedSkin[1]
            end

            if not applyItemId or applyItemId == 0 or slotData.ItemId == applyItemId then return end

            if not _G.skinIdCache[applyItemId] then
                if _G.download_item then pcall(_G.download_item, applyItemId) end
                _G.skinIdCache[applyItemId] = true
            end

            slotData.ItemId = applyItemId
            SlotSyncData:Set(ApplyDataIdx, slotData)
            Character.AvatarComponent2:OnRep_BodySlotStateChanged()
        end
    end

    local hasGliderSlot = false
    for i = 0, SlotSyncData:Num() - 1 do
        local slotData = SlotSyncData:Get(i)
        if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then 
            hasGliderSlot = true
            break 
        end
    end
    if not hasGliderSlot then SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end

    for i = 0, SlotSyncData:Num() - 1 do
        EquipAvatar(i, _G.OutfitMap.Suit or 0, _G.CustSlotType.ClothesEquipemtSlot, false)
        EquipAvatar(i, _G.OutfitMap.Pants or 0, 6, false)
        EquipAvatar(i, _G.OutfitMap.Hair or 0, 7, false)
        EquipAvatar(i, _G.OutfitMap.Bag, _G.CustSlotType.BackpackEquipemtSlot, true, BackpackUtils.GetEquipmentBagLevel)
        EquipAvatar(i, _G.OutfitMap.Helmet, _G.CustSlotType.HelmetEquipemtSlot, true, BackpackUtils.GetEquipmentHelmetLevel)
        EquipAvatar(i, _G.OutfitMap.Parachute or 0, _G.CustSlotType.ParachuteEquipemtSlot, false)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end
        
        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) and slua.isValid(Weapon.synData) then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local isModified = false
                
                local SkinData = Weapon.synData:Get(7) 
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    SkinData.defineID.TypeSpecificID = SkinID
                    Weapon.synData:Set(7, SkinData)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    if not _G.skinIdCache[SkinID] then 
                        _G.download_item(SkinID)
                        _G.skinIdCache[SkinID] = true 
                    end
                    isModified = true
                end
                
                if SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do 
                        local attachData = Weapon.synData:Get(AttachIdx)
                        if attachData then
                            local defineIDRef = slua.IndexReference(attachData, "defineID")
                            if defineIDRef then
                                local attachmentId = defineIDRef.TypeSpecificID
                                if attachmentId and attachmentId > 0 then
                                    local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                    if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                        local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                        if targetAttachId ~= attachmentId then
                                            attachData.defineID.TypeSpecificID = targetAttachId
                                            Weapon.synData:Set(AttachIdx, attachData)
                                            if not _G.skinIdCache2[targetAttachId] then 
                                                if _G.download_item then pcall(_G.download_item, targetAttachId) end
                                                _G.skinIdCache2[targetAttachId] = true 
                                            end
                                            isModified = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if _G.apply_attachment and SkinID >= 10000000 then
                    pcall(function() _G.apply_attachment(Weapon, SkinID) end)
                end
                
                if isModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

-- ====== NO RECOIL SYSTEM ======
_G.recoilOriginalCache = _G.recoilOriginalCache or setmetatable({}, { __mode = "k" })
_G.RECOIL_FIELDS = { "RecoilKick", "RecoilKickADS", "AnimationKick", "GameDeviationFactor", "RecoilModifierStand", "RecoilModifierCrouch", "RecoilModifierProne", "GameDeviationAccuracy", "ShotGunHorizontalSpread", "ShotGunVerticalSpread", "DeviationMultiplier", "VerticalRecoil", "VerticalKick", "RecoilVertical" }
_G.RECOIL_TARGET_VALUES = { RecoilKick=0.01, RecoilKickADS=0.01, AnimationKick=0.01, GameDeviationFactor=0.01, RecoilModifierStand=0.01, RecoilModifierCrouch=0.01, RecoilModifierProne=0.01, GameDeviationAccuracy=0.01, ShotGunHorizontalSpread=0.01, ShotGunVerticalSpread=0.01, DeviationMultiplier=0.01, VerticalRecoil=0.01, VerticalKick=0.01, RecoilVertical=0.01 }
_G.RECOIL_INFO_FIELDS = { "VerticalRecoilMin", "VerticalRecoilMax", "RecoilSpeedVertical", "RecoilSpeedHorizontal", "VerticalRecoveryMax", "VerticalRecoil", "RecoilVertical", "VerticalKick", "VerticalKickMin", "VerticalKickMax", "PitchRecoilMin", "PitchRecoilMax", "RecoilPitchMin", "RecoilPitchMax" }
_G.RECOIL_INFO_TARGET = { VerticalRecoilMin=0.01, VerticalRecoilMax=0.01, RecoilSpeedVertical=0.01, RecoilSpeedHorizontal=0.01, VerticalRecoveryMax=0.01, VerticalRecoil=0.01, RecoilVertical=0.01, VerticalKick=0.01, VerticalKickMin=0.01, VerticalKickMax=0.01, PitchRecoilMin=0.01, PitchRecoilMax=0.01, RecoilPitchMin=0.01, RecoilPitchMax=0.01 }
-- Shake wale fields kabhi zero NAHI honge (less-recoil feel: scope halka hilta rahega)
_G.RECOIL_SHAKE_FIELDS = { "CameraShakeScale", "AimCameraShakeScale", "ShootCameraShakeScale", "FireCameraShakeScale" }

_G.ApplyNoRecoil = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not wm then return end
        local weapon = wm.CurrentWeaponReplicated
        if not weapon then return end
        local entity = weapon.ShootWeaponEntityComp
        if not Valid(entity) then return end
        if not _G.LexusConfig.NoRecoilEnabled then
            if _G.recoilOriginalCache[entity] then
                local saved = _G.recoilOriginalCache[entity]
                for k, v in pairs(saved) do
                    if k == "RecoilInfo" then
                        if entity.RecoilInfo then for rk, rv in pairs(v) do entity.RecoilInfo[rk] = rv end end
                    elseif k == "ShootCameraShakeScale" then
                        if entity.ShootCameraShake then entity.ShootCameraShake.Scale = v end
                    elseif k == "Shake" then
                        for rk, rv in pairs(v) do
                            pcall(function() entity[rk] = rv end)
                        end
                    else entity[k] = v end
                end
                _G.recoilOriginalCache[entity] = nil
            end
            return
        end
        if not _G.recoilOriginalCache[entity] then
            local saved = { RecoilInfo = {}, Shake = {} }
            for _, f in ipairs(_G.RECOIL_FIELDS) do if entity[f] ~= nil then saved[f] = entity[f] end end
            if entity.RecoilInfo then for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do if entity.RecoilInfo[f] ~= nil then saved.RecoilInfo[f] = entity.RecoilInfo[f] end end end
            if entity.ShootCameraShake then saved.ShootCameraShakeScale = entity.ShootCameraShake.Scale end
            for _, f in ipairs(_G.RECOIL_SHAKE_FIELDS or {}) do
                if entity[f] ~= nil then saved.Shake[f] = entity[f] end
            end
            _G.recoilOriginalCache[entity] = saved
        end
        local orig = _G.recoilOriginalCache[entity]
        local slider = (_G.LexusConfig.RecoilReduction or 100) / 100
        if slider > 1 then slider = 1 end
        for _, f in ipairs(_G.RECOIL_FIELDS) do
            if entity[f] ~= nil and orig[f] ~= nil and _G.RECOIL_TARGET_VALUES[f] then
                entity[f] = orig[f] + (_G.RECOIL_TARGET_VALUES[f] - orig[f]) * slider
            end
        end
        if entity.RecoilInfo then
            for _, f in ipairs(_G.RECOIL_INFO_FIELDS) do
                if entity.RecoilInfo[f] ~= nil and orig.RecoilInfo[f] ~= nil and _G.RECOIL_INFO_TARGET[f] then
                    entity.RecoilInfo[f] = orig.RecoilInfo[f] + (_G.RECOIL_INFO_TARGET[f] - orig.RecoilInfo[f]) * slider
                end
            end
        end
        -- SHAKE PRESERVE (less-recoil feel): scope halka hilta rahega, shake zero nahi hoga
        -- (purane version ne Scale change kiya ho to original wapas karo)
        if entity.ShootCameraShake and orig.ShootCameraShakeScale ~= nil then
            pcall(function()
                if entity.ShootCameraShake.Scale ~= orig.ShootCameraShakeScale then
                    entity.ShootCameraShake.Scale = orig.ShootCameraShakeScale
                end
            end)
        end
        if orig.Shake then
            for k, v in pairs(orig.Shake) do
                if entity[k] ~= nil and entity[k] ~= v then
                    pcall(function() entity[k] = v end)
                end
            end
        end
    end)
end

-- ====== AUTO HEAD / AIMBOT (Scope-Aware) ======
_G.ApplyAutoHead = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local localChar = pc:GetPlayerCharacterSafety()
        if not Valid(localChar) then return end
        local localLoc = nil
        pcall(function() localLoc = localChar:K2_GetActorLocation() end)
        if not localLoc then return end
        local myTeamID = localChar.TeamID

        local isScoped = false
        pcall(function()
            local cam = localChar.ThirdPersonCameraComponent
            if Valid(cam) and cam.FieldOfView then
                isScoped = cam.FieldOfView < 60
            end
        end)

        local maxDist = isScoped and 500 or 250
        local closestEnemy = nil
        local closestDist = 999999
        local allChars = GameplayData.GetAllPlayerCharacters and GameplayData.GetAllPlayerCharacters() or {}
        for _, enemy in pairs(allChars) do
            if Valid(enemy) and enemy ~= localChar and enemy.TeamID ~= myTeamID then
                local bDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bDead = enemy.bIsDead end
                end)
                if not bDead then
                    local eLoc = nil
                    pcall(function() eLoc = enemy:K2_GetActorLocation() end)
                    if eLoc then
                        local dx = (eLoc.X or 0) - (localLoc.X or 0)
                        local dy = (eLoc.Y or 0) - (localLoc.Y or 0)
                        local dz = (eLoc.Z or 0) - (localLoc.Z or 0)
                        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                        if dist < closestDist then
                            closestDist = dist
                            closestEnemy = enemy
                        end
                    end
                end
            end
        end
        if closestEnemy and closestDist <= maxDist then
            local targetLoc = nil
            pcall(function()
                local mesh = closestEnemy.Mesh
                if Valid(mesh) and type(mesh.GetSocketLocation) == "function" then
                    if isScoped then
                        targetLoc = mesh:GetSocketLocation("head")
                    else
                        targetLoc = mesh:GetSocketLocation("spine_02")
                        if not targetLoc then targetLoc = closestEnemy:K2_GetActorLocation() end
                        if targetLoc then targetLoc.Z = targetLoc.Z + 100 end
                    end
                end
            end)
            if not targetLoc then
                pcall(function() targetLoc = closestEnemy:K2_GetActorLocation() end)
                if targetLoc then targetLoc.Z = targetLoc.Z + (isScoped and 180 or 100) end
            end
            if targetLoc then
                local myCam = localChar.ThirdPersonCameraComponent
                if Valid(myCam) then
                    local camLoc = nil
                    pcall(function() camLoc = myCam:K2_GetComponentLocation() end)
                    if camLoc then
                        local dirX = (targetLoc.X or 0) - (camLoc.X or 0)
                        local dirY = (targetLoc.Y or 0) - (camLoc.Y or 0)
                        local dirZ = (targetLoc.Z or 0) - (camLoc.Z or 0)
                        local len = math.sqrt(dirX*dirX + dirY*dirY + dirZ*dirZ)
                        if len > 0 then
                            local rot = nil
                            pcall(function()
                                local FRotator = import("Rotator")
                                local pitch = math.deg(math.asin(dirZ / len))
                                local yaw = math.deg(math.atan2(dirY, dirX))
                                if isScoped then
                                    rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
                                else
                                    local curRot = pc:GetControlRotation()
                                    if curRot then
                                        local curPitch = curRot.Pitch or 0
                                        local curYaw = curRot.Yaw or 0
                                        local blend = 0.35
                                        local newPitch = curPitch + (-pitch - curPitch) * blend
                                        local newYaw = curYaw + (yaw - curYaw) * blend
                                        rot = FRotator and FRotator(newPitch, newYaw, 0) or {Pitch = newPitch, Yaw = newYaw, Roll = 0}
                                    else
                                        rot = FRotator and FRotator(-pitch, yaw, 0) or {Pitch = -pitch, Yaw = yaw, Roll = 0}
                                    end
                                end
                            end)
                            if rot then
                                pcall(function() pc:SetControlRotation(rot) end)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ====== WEAPON AIMBOT (AutoAimingConfig + Head Bones) ======
_G.ApplyWeaponAimbot = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if slua.isValid(entity) and entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 90
                    cfg.RangeRate = 90
                    cfg.SpeedRate = 1
                    cfg.RangeRateSight = 1
                    cfg.SpeedRateSight = 2
                    cfg.CrouchRate = 5
                    cfg.ProneRate = 5
                    cfg.DyingRate = 0
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end
        local aimComp = char.BP_AutoAimingComponent_C or char.BP_AutoAimingComponent
        if slua.isValid(aimComp) and aimComp.Bones then
            aimComp.Bones = {"head", "head", "head"}
        end
    end)
end

_G.RestoreWeaponAimbot = function()
    pcall(function()
        local GameplayData = getCachedGameplayData()
        if not GameplayData or not GameplayData.GetPlayerController then return end
        local pc = GameplayData.GetPlayerController()
        if not Valid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not Valid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if slua.isValid(entity) and entity.AutoAimingConfig then
            for _, range in ipairs({"OuterRange", "InnerRange"}) do
                local cfg = entity.AutoAimingConfig[range]
                if cfg then
                    cfg.Speed = 10
                    cfg.RangeRate = 2
                    cfg.SpeedRate = 4
                    cfg.RangeRateSight = 2
                    cfg.SpeedRateSight = 4
                    cfg.CrouchRate = 2
                    cfg.ProneRate = 2
                    cfg.DyingRate = 2
                end
            end
            entity.AutoAimingConfig = entity.AutoAimingConfig
        end
    end)
end

-- ====== MAGIC BULLET (ENLARGED HITBOXES + FORCE HEAD BONE) ======
-- ON: enemy hitbox bada + head bone force + BigHead damage. OFF: timer stop
-- (hitbox enlarge asset-level hai, game restart tak rehta hai - ye normal hai).
_G.MagicBulletConfig = _G.MagicBulletConfig or { Enable = false }
_G._MagicBulletTimer = _G._MagicBulletTimer or nil

local function EnableMagicBullet()
    pcall(function()
        local allChars = Game:GetAllPlayerPawns() or {}
        for _, c in pairs(allChars) do
            if slua.isValid(c) then
                local mesh = c.Mesh
                if slua.isValid(mesh) then
                    local physAsset = mesh.PhysicsAssetOverride
                    if not slua.isValid(physAsset) and slua.isValid(mesh.SkeletalMesh) then
                        physAsset = mesh.SkeletalMesh.PhysicsAsset
                    end
                    if slua.isValid(physAsset) and physAsset.SkeletalBodySetups then
                        _G._MBones = _G._MBones or {}
                        local assetName = (physAsset.GetName and physAsset:GetName()) or tostring(physAsset)
                        if not _G._MBones[assetName] then
                            local mb = { -- LOW profile (ban-safe): chhota expansion
                                ["head"] = 80, ["neck_01"] = 60, ["pelvis"] = 60,
                                ["spine_01"] = 60, ["spine_02"] = 60, ["spine_03"] = 60,
                                ["upperarm_l"] = 60, ["upperarm_r"] = 60,
                                ["lowerarm_l"] = 50, ["lowerarm_r"] = 50,
                                ["hand_l"] = 40, ["hand_r"] = 40,
                                ["thigh_l"] = 60, ["thigh_r"] = 60,
                                ["calf_l"] = 50, ["calf_r"] = 50,
                                ["foot_l"] = 40, ["foot_r"] = 40,
                            }
                            local setups = physAsset.SkeletalBodySetups
                            for i = 1, 80 do
                                local bs = nil
                                pcall(function() bs = (type(setups.Get) == "function") and setups:Get(i-1) or setups[i] end)
                                if not bs or not slua.isValid(bs) then break end
                                local bn = tostring(bs.BoneName):lower()
                                local pct = nil
                                for pat, val in pairs(mb) do
                                    if string.find(bn, pat) then pct = val; break end
                                end
                                if pct then
                                    local sc = 1.0 + pct / 100.0
                                    local ag = bs.AggGeom
                                    pcall(function()
                                        local bx = (ag and ag.BoxElems) or bs.BoxElems
                                        if bx then
                                            local b = (type(bx.Get) == "function") and bx:Get(0) or bx[1]
                                            if b then
                                                b.X = (b.X or 30) * sc
                                                b.Y = (b.Y or 30) * sc
                                                b.Z = (b.Z or 60) * sc
                                                if type(bx.Set) == "function" then bx:Set(0, b) else bx[1] = b end
                                                if ag then bs.AggGeom = ag else bs.BoxElems = bx end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sp = (ag and ag.SphylElems) or bs.SphylElems
                                        if sp then
                                            local s = (type(sp.Get) == "function") and sp:Get(0) or sp[1]
                                            if s then
                                                if s.Radius then s.Radius = s.Radius * sc end
                                                if s.Length then s.Length = s.Length * sc end
                                                if type(sp.Set) == "function" then sp:Set(0, s) else sp[1] = s end
                                                if ag then bs.AggGeom = ag else bs.SphylElems = sp end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sr = (ag and ag.SphereElems) or bs.SphereElems
                                        if sr then
                                            local r = (type(sr.Get) == "function") and sr:Get(0) or sr[1]
                                            if r and r.Radius then
                                                r.Radius = r.Radius * sc
                                                if type(sr.Set) == "function" then sr:Set(0, r) else sr[1] = r end
                                                if ag then bs.AggGeom = ag else bs.SphereElems = sr end
                                            end
                                        end
                                    end)
                                end
                            end
                            _G._MBones[assetName] = true
                            if mesh.RecreatePhysicsState then mesh:RecreatePhysicsState() end
                        end
                    end
                end
            end
        end
    end)
end

local function ForceHeadBone()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end

        local self = pc:GetPlayerCharacterSafety()
        if not slua.isValid(self) then return end

        local autoComp = self.AutoAimComp
        if autoComp then
            if autoComp.Bones then
                autoComp.Bones = {"Head", "Head", "Head"}
                if autoComp.Bones.Set then
                    autoComp.Bones:Set(0, "Head")
                    autoComp.Bones:Set(1, "Head")
                    autoComp.Bones:Set(2, "Head")
                else
                    autoComp.Bones[0] = "Head"
                    autoComp.Bones[1] = "Head"
                    autoComp.Bones[2] = "Head"
                end
            end
        end

        local bpAuto = self.BP_AutoAimingComponent_C or self.BP_AutoAimingComponent or self.AutoAimingComponent
        if slua.isValid(bpAuto) then
            if bpAuto.Bones then
                if bpAuto.Bones.Set then
                    bpAuto.Bones:Set(0, "Head")
                    bpAuto.Bones:Set(1, "Head")
                    bpAuto.Bones:Set(2, "Head")
                else
                    bpAuto.Bones[0] = "Head"
                    bpAuto.Bones[1] = "Head"
                    bpAuto.Bones[2] = "Head"
                end
            end
            if bpAuto.AimOffsetBone then bpAuto.AimOffsetBone = "Head" end
            if bpAuto.TargetBone then bpAuto.TargetBone = "Head" end
        end

        if self.HiggsBoson then
            if self.HiggsBoson.AimBone then self.HiggsBoson.AimBone = "Head" end
        end
    end)
end

local function OverrideHitBodyType()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        _G.GetHitBodyType = function(ImpactResult, InImpactVec) return EAvatarDamagePosition.BigHead end
        _G.GetHitBodyTypeByHitPos = function(InImpactVec) return EAvatarDamagePosition.BigHead end
    end)
end

_G.ApplyMagicBullet = function()
    pcall(EnableMagicBullet)
    pcall(ForceHeadBone)
    pcall(OverrideHitBodyType)
end

_G.StartMagicBullet = function()
    _G.MagicBulletConfig.Enable = true
    _G.ApplyMagicBullet()
    if _G._MagicBulletTimer then return end
    pcall(function()
        local function tick()
            if not _G.MagicBulletConfig or not _G.MagicBulletConfig.Enable then return end
            _G.ApplyMagicBullet()
        end
        if _G.Game and _G.Game.AddGameTimer then
            _G._MagicBulletTimer = _G.Game:AddGameTimer(1.0, true, tick)
        else
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) and pc.AddGameTimer then
                _G._MagicBulletTimer = pc:AddGameTimer(1.0, true, tick)
            end
        end
    end)
end

_G.StopMagicBullet = function()
    _G.MagicBulletConfig.Enable = false
    if _G._MagicBulletTimer then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(_G._MagicBulletTimer) end
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) and pc.RemoveGameTimer then
                pc:RemoveGameTimer(_G._MagicBulletTimer)
            end
        end)
        _G._MagicBulletTimer = nil
    end
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    pcall(function()
        local Vehicle = PlayerCharacter:GetCurrentVehicle()
        if not slua.isValid(Vehicle) then 
            _G.LastVehicleEntity = nil
            return 
        end
        
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then
            return
        end

        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
        if not slua.isValid(VehicleAvatar) then return end

        local defId = tostring(VehicleAvatar:GetDefaultAvatarID() or Vehicle.VehicleID or "")
        local currentId = tostring(Vehicle:GetAvatarId() or "")
        local applySkinId = 0
        
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if defId:find(tostring(baseMapId)) or currentId:find(tostring(baseMapId)) then 
                applySkinId = targetSkin
                break 
            end
        end

        if applySkinId and applySkinId > 0 then
            _G.skinIdCache = _G.skinIdCache or {}
            if not _G.skinIdCache[applySkinId] then 
                if _G.download_item then pcall(_G.download_item, applySkinId) end
                _G.skinIdCache[applySkinId] = true 
            end

            VehicleAvatar.curSwitchEffectId = 7303001
            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(applySkinId, true) end
            
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end

_G.HandlePetLogic = function()
    pcall(function()
        local petSkin = _G.OutfitMap.Pet
        if not petSkin or petSkin == 0 or petSkin == 50000 or petSkin == _G.LastAppliedPet then return end
        
        _G.skinIdCache = _G.skinIdCache or {}
        if not _G.skinIdCache[petSkin] then 
            if _G.download_item then pcall(_G.download_item, petSkin) end
            _G.skinIdCache[petSkin] = true 
        end
        
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local logic_pet = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if logic_pet then
                if logic_pet.SetCurPetID then logic_pet:SetCurPetID(petSkin) end
                if logic_pet.EquipPet then logic_pet:EquipPet(petSkin) end
            end
        end
        _G.LastAppliedPet = petSkin
    end)
end

_G.ForceRefreshSkinMaps = function()
    pcall(function()
        if not _G.LexusState or not _G.LexusState.CustomTextData then return end
        local cData = _G.LexusState.CustomTextData

        if _G.OutfitSkins then
            if cData.SkinSuit and _G.OutfitSkins.Suit[cData.SkinSuit] then _G.OutfitMap.Suit = _G.OutfitSkins.Suit[cData.SkinSuit] end
            if cData.SkinBag and _G.OutfitSkins.Bag[cData.SkinBag] then _G.OutfitMap.Bag = _G.OutfitSkins.Bag[cData.SkinBag] end
            if cData.SkinHelmet and _G.OutfitSkins.Helmet[cData.SkinHelmet] then _G.OutfitMap.Helmet = _G.OutfitSkins.Helmet[cData.SkinHelmet] end
        end

        if _G.skinIdMappings then
            if cData.SkinM416 and _G.skinIdMappings[101004] and _G.skinIdMappings[101004][cData.SkinM416] then _G.WeaponSkinMap[101004] = _G.skinIdMappings[101004][cData.SkinM416] end
            if cData.SkinAKM and _G.skinIdMappings[101001] and _G.skinIdMappings[101001][cData.SkinAKM] then _G.WeaponSkinMap[101001] = _G.skinIdMappings[101001][cData.SkinAKM] end
            if cData.SkinSCAR and _G.skinIdMappings[101003] and _G.skinIdMappings[101003][cData.SkinSCAR] then _G.WeaponSkinMap[101003] = _G.skinIdMappings[101003][cData.SkinSCAR] end
            if cData.SkinM762 and _G.skinIdMappings[101008] and _G.skinIdMappings[101008][cData.SkinM762] then _G.WeaponSkinMap[101008] = _G.skinIdMappings[101008][cData.SkinM762] end
            if cData.SkinAUG and _G.skinIdMappings[101006] and _G.skinIdMappings[101006][cData.SkinAUG] then _G.WeaponSkinMap[101006] = _G.skinIdMappings[101006][cData.SkinAUG] end
            if cData.SkinUMP and _G.skinIdMappings[102002] and _G.skinIdMappings[102002][cData.SkinUMP] then _G.WeaponSkinMap[102002] = _G.skinIdMappings[102002][cData.SkinUMP] end
            
            if cData.SkinUZI and _G.skinIdMappings[102001] and _G.skinIdMappings[102001][cData.SkinUZI] then _G.WeaponSkinMap[102001] = _G.skinIdMappings[102001][cData.SkinUZI] end
            if cData.SkinGroza and _G.skinIdMappings[101005] and _G.skinIdMappings[101005][cData.SkinGroza] then _G.WeaponSkinMap[101005] = _G.skinIdMappings[101005][cData.SkinGroza] end
            if cData.SkinS12K and _G.skinIdMappings[104003] and _G.skinIdMappings[104003][cData.SkinS12K] then _G.WeaponSkinMap[104003] = _G.skinIdMappings[104003][cData.SkinS12K] end
            if cData.SkinDBS and _G.skinIdMappings[104004] and _G.skinIdMappings[104004][cData.SkinDBS] then _G.WeaponSkinMap[104004] = _G.skinIdMappings[104004][cData.SkinDBS] end
            if cData.SkinASM and _G.skinIdMappings[101101] and _G.skinIdMappings[101101][cData.SkinASM] then _G.WeaponSkinMap[101101] = _G.skinIdMappings[101101][cData.SkinASM] end
        end

        if _G.VehicleSkins then
            if cData.SkinDacia and _G.VehicleSkins[1903001] and _G.VehicleSkins[1903001][cData.SkinDacia] then _G.VehicleSkinMap[1903001] = _G.VehicleSkins[1903001][cData.SkinDacia] end
            if cData.SkinUAZ and _G.VehicleSkins[1908001] and _G.VehicleSkins[1908001][cData.SkinUAZ] then _G.VehicleSkinMap[1908001] = _G.VehicleSkins[1908001][cData.SkinUAZ] end
            if cData.SkinCoupe and _G.VehicleSkins[1961001] and _G.VehicleSkins[1961001][cData.SkinCoupe] then _G.VehicleSkinMap[1961001] = _G.VehicleSkins[1961001][cData.SkinCoupe] end
            if cData.SkinBuggy and _G.VehicleSkins[1907002] and _G.VehicleSkins[1907002][cData.SkinBuggy] then _G.VehicleSkinMap[1907002] = _G.VehicleSkins[1907002][cData.SkinBuggy] end
            if cData.SkinMirado and _G.VehicleSkins[1915004] and _G.VehicleSkins[1915004][cData.SkinMirado] then _G.VehicleSkinMap[1915004] = _G.VehicleSkins[1915004][cData.SkinMirado] end
            if cData.SkinQBZ and _G.skinIdMappings[101007] and _G.skinIdMappings[101007][cData.SkinQBZ] then _G.WeaponSkinMap[101007] = _G.skinIdMappings[101007][cData.SkinQBZ] end
if cData.SkinHoney and _G.skinIdMappings[101012] and _G.skinIdMappings[101012][cData.SkinHoney] then _G.WeaponSkinMap[101012] = _G.skinIdMappings[101012][cData.SkinHoney] end
if cData.SkinM16A4 and _G.skinIdMappings[101002] and _G.skinIdMappings[101002][cData.SkinM16A4] then _G.WeaponSkinMap[101002] = _G.skinIdMappings[101002][cData.SkinM16A4] end
if cData.SkinACE32 and _G.skinIdMappings[101102] and _G.skinIdMappings[101102][cData.SkinACE32] then _G.WeaponSkinMap[101102] = _G.skinIdMappings[101102][cData.SkinACE32] end
if cData.SkinKar98k and _G.skinIdMappings[103001] and _G.skinIdMappings[103001][cData.SkinKar98k] then _G.WeaponSkinMap[103001] = _G.skinIdMappings[103001][cData.SkinKar98k] end
if cData.SkinM24 and _G.skinIdMappings[103002] and _G.skinIdMappings[103002][cData.SkinM24] then _G.WeaponSkinMap[103002] = _G.skinIdMappings[103002][cData.SkinM24] end
if cData.SkinAWM and _G.skinIdMappings[103003] and _G.skinIdMappings[103003][cData.SkinAWM] then _G.WeaponSkinMap[103003] = _G.skinIdMappings[103003][cData.SkinAWM] end
        end
    end)
end

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 100

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox then return end
    if _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray then
        _G.CachedActorArray = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray)
    
    for _, deadBoxActor in pairs(deadBoxes) do
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            if damageCauser and damageCauser.PlayerKey == PlayerController.PlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    local currentBoxSkinId = 0
                    if PlayerCharacter.CurrentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                        currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                    else
                        local currentWeapon = PlayerCharacter:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) and currentWeapon.synData then
                            local weaponSkinData = currentWeapon.synData:Get(7)
                            if weaponSkinData and weaponSkinData.defineID then
                                currentBoxSkinId = weaponSkinData.defineID.TypeSpecificID
                            end
                        end
                    end
                    
                    if currentBoxSkinId ~= 0 then
                        pcall(function()
                            DeadBoxAvatarComponent:ResetItemAvatar()
                            DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                            DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                        end)
                    end
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

_G.TDFTDeKillCounts = _G.TDFTDeKillCounts or {}
local CACHED_LinearColor = import("LinearColor")
local CACHED_GoldColor = CACHED_LinearColor and CACHED_LinearColor(1.0, 0.8, 0.0, 1.0) or nil
local CACHED_UI_Manager = nil

_G.ForceEnableKillCounterUI = function()
    pcall(function()
        local KillCounterUISubsystem = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"] or require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUISubsystem and KillCounterUISubsystem.__inner_impl and not _G.KCUISystemHacked2 then
            local kcImpl = KillCounterUISubsystem.__inner_impl
            kcImpl.CheckSupportKCUI = function() return true end
            kcImpl.CheckNeedMainKillCounterUI = function(self, PlayerWeapon, PlayerID)
                if slua.isValid(PlayerWeapon) then
                    local WeaponID = PlayerWeapon:GetWeaponID()
                    self:UpdateMainKillCounterUI(true, WeaponID, _G.get_skin_id(WeaponID) or WeaponID)
                else self:UpdateMainKillCounterUI(false) end
            end
            local originalUpdateMainKillCounterUI = kcImpl.UpdateMainKillCounterUI
            kcImpl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                if bShow then AvatarID = _G.get_skin_id(WeaponID) or AvatarID end
                if originalUpdateMainKillCounterUI then originalUpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID) end
            end
            _G.KCUISystemHacked2 = true
        end

        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager and not _G.KCLogicHacked2 then
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if LogicKillCounter then
                LogicKillCounter.CheckSupportKC = function() return true end
                LogicKillCounter.CheckSupportKillCounterAvatar = function() return true end
                LogicKillCounter.CheckHasWeaponKillCounter = function() return true end
                LogicKillCounter.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                LogicKillCounter.GetEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetMyEquipedKillCounterId = function() return 2100004 end
                LogicKillCounter.GetOneWeaponKillCountInBattle = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                LogicKillCounter.GetWeaponKillCountByUid = function(self, uid, weaponId) return _G.TDFTDeKillCounts[weaponId] or 0 end
                _G.KCLogicHacked2 = true
            end
        end

        local killInfoPath = "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"
        local KillInfo = package.loaded[killInfoPath] or require(killInfoPath)
        
        if KillInfo and KillInfo.__inner_impl and not _G.KillInfoCounterHacked then
            local originalFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local LocalPlayer = require("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) and DamageRecordData.Causer == LocalPlayer:GetPlayerNameSafety() then 
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id(weaponID)
                            if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                            if _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit end
                            
                            if CACHED_GoldColor then
                                DamageRecordData.IsUseColor, DamageRecordData.UseColor = true, CACHED_GoldColor
                            end
                            
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.TDFTDeKillCounts[weaponID] = (_G.TDFTDeKillCounts[weaponID] or 0) + 1
                                _G.NeedCheckDeadBoxTimer = 50 
                                
                                if not CACHED_UI_Manager then CACHED_UI_Manager = require("client.slua_ui_framework.manager") end
                                local uiMainKillCounter = CACHED_UI_Manager.GetUI(CACHED_UI_Manager.UI_Config_InGame.MainKillCounter)
                                
                                if uiMainKillCounter and uiMainKillCounter.UpdateWeaponID then
                                    local mainAvatarID = skinID or currentWeapon:GetWeaponMainAvatarID()
                                    uiMainKillCounter:UpdateWeaponID(weaponID, mainAvatarID)
                                    local kcModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                                    local kcItemID = kcModule:GetEquipedKillCounterId(0, mainAvatarID)
                                    uiMainKillCounter:SetKillCounterItemShowWithNum(kcItemID, _G.TDFTDeKillCounts[weaponID], mainAvatarID)
                                end
                            end
                        end
                    end
                end)
                if originalFileItem then return originalFileItem(self, DamageRecordData) end
            end
            _G.KillInfoCounterHacked = true
        end

        local SwitchWeaponSlotMode2 = package.loaded["GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2"] or require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SwitchWeaponSlotMode2 and SwitchWeaponSlotMode2.__inner_impl and not _G.SlotBaseHacked then
            SwitchWeaponSlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if slua.isValid(self.KillCounterImg) then 
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible) 
                end
            end
            _G.SlotBaseHacked = true
        end
    end)
end

function _G.InitializeSkinModSystem()
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"] or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPutonEquipment = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if attachIndex then
                    local holdingWeaponSkinID = self.GetCurHoldingWeaponSkinID and self:GetCurHoldingWeaponSkinID()
                    if holdingWeaponSkinID and holdingWeaponSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[holdingWeaponSkinID] then
                        local vipAttachID = _G.VIP_Attachments[holdingWeaponSkinID][attachIndex]
                        if vipAttachID and vipAttachID > 0 then
                            if self.HandleDownload then self:HandleDownload(vipAttachID, nil, nil, false) end
                            itemID = vipAttachID
                        end
                    end
                end
                if originalPutonEquipment then return originalPutonEquipment(self, itemID, tAvatarCustom, tExtraData) end
            end

            local originalCharEquipWeaponByResId = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local retValue = originalCharEquipWeaponByResId and originalCharEquipWeaponByResId(self, resID, isUse, isAsync, SocketName) or nil
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return retValue
            end
            _G.LobbyBypassHacked = true
        end
    end)
    
    pcall(function()
        local Common_Items_UIBP = package.loaded["client.slua.component.item.ItemChildren.Common_Items_UIBP"] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if Common_Items_UIBP and not _G.IconBaloHacked then
        local originalInitView = Common_Items_UIBP.InitView
            Common_Items_UIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displayResId = nil
                
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then displayResId = skinID end
                end
                
                local attachIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displayResId and attachIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    local LocalPlayer = GameplayData and GameplayData.GetPlayerCharacter()
                    if slua.isValid(LocalPlayer) then
                        local currentWeapon = LocalPlayer:GetCurrentWeapon()
                        if slua.isValid(currentWeapon) then
                            local weaponID = currentWeapon:GetWeaponID()
                            local finalSkinID = _G.get_skin_id(weaponID) or weaponID
                            if finalSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[finalSkinID] then
                                local vipAttachID = _G.VIP_Attachments[finalSkinID][attachIndex]
                                if vipAttachID and vipAttachID > 0 then displayResId = vipAttachID end
                            end
                        end
                    end
                end
                
                if displayResId then
                    tExtraData.displayResId = displayResId
                    if not _G.skinIdCache2[displayResId] then
                        if _G.download_item then pcall(_G.download_item, displayResId) end
                        _G.skinIdCache2[displayResId] = true
                    end
                end
                if originalInitView then return originalInitView(self, nItemId, nCount, nValidTime, tExtraData) end
            end
            _G.IconBaloHacked = true
        end
    end)
end
-- ===== COPIED SKIN SYSTEM END =====
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
    SkinSuit=1, SkinBag=1, SkinHelmet=1,
    SkinM416=1, SkinAKM=1, SkinSCAR=1, SkinM762=1, SkinAUG=1, SkinUMP=1, SkinUZI=1,
    SkinGroza=1, SkinS12K=1, SkinDBS=1, SkinASM=1, SkinQBZ=1, SkinHoney=1, SkinM16A4=1,
    SkinACE32=1, SkinKar98k=1, SkinM24=1, SkinAWM=1,
    SkinDacia=1, SkinUAZ=1, SkinCoupe=1, SkinBuggy=1, SkinMirado=1,
}
pcall(function()
    if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
end)

pcall(function() if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end end)

_G.BRSkinUpdate = function()
    pcall(function()
        local GDP = GameplayData
        local localPlayer = GDP and GDP.GetLocalCharacter and GDP.GetLocalCharacter()
        if not Valid(localPlayer) then return end
        local PC = nil
        pcall(function() if slua_GameFrontendHUD then PC = slua_GameFrontendHUD:GetPlayerController() end end)

        -- KILL COUNTER UI hack (self-guards via KillInfoCounterHacked)
        pcall(function()
            if not _G.KillInfoCounterHacked and _G.ForceEnableKillCounterUI then _G.ForceEnableKillCounterUI() end
        end)

        -- DEAD BOX skin
        pcall(function() if _G.DeadBox_TemperRequest and PC then _G.DeadBox_TemperRequest(PC) end end)

        -- AUTO REPORT (Reports enemies, skips teammates)
        pcall(function()
            if _G.AutoReportConfig and _G.AutoReportConfig.Enable and _G.AutoReportTick then
                _G.AutoReportTick()
            end
        end)

        -- FPS re-assert (engine sometimes resets the limiter)
        pcall(function()
            if _G.MemoryConfig and _G.MemoryConfig.UnlockFPS and _G.ApplyMemoryFeature then
                _G.ApplyMemoryFeature("FPS", true)
            end
        end)

        if _G.LexusConfig.ModSkin then
            if not _G.TDSkinLoopStarted then
                if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
                if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
                _G.TDSkinLoopStarted = true
            end
            _G.LexusState.SkinWasApplied = true
            local curTime = os.clock()
            if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 1.5 then
                _G.LastSkinUpdateTime = curTime
                pcall(function()
                    local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                    if isAlive then
                        if _G.equip_character_avatar then _G.equip_character_avatar(localPlayer) end
                        if _G.ApplyWeaponSkins then _G.ApplyWeaponSkins(localPlayer) end
                        if _G.ApplyVehicleSkins then _G.ApplyVehicleSkins(localPlayer) end
                        if _G.HandlePetLogic then _G.HandlePetLogic(localPlayer) end
                    end
                end)
            end
            if _G.LexusState.DirtyConfig then
                if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end
                _G.LexusState.DirtyConfig = false
            end
        else
            if _G.LexusState.SkinWasApplied then
                _G.OutfitMap = {}
                _G.WeaponSkinMap = {}
                _G.VehicleSkinMap = {}
                pcall(function()
                    local WeaponManager = localPlayer:GetWeaponManager()
                    if Valid(WeaponManager) then
                        for slot = 1, 3 do
                            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
                            if Valid(Weapon) and Valid(Weapon.synData) then
                                local WeaponID = Weapon:GetWeaponID()
                                local SkinData = Weapon.synData:Get(7)
                                if SkinData and SkinData.defineID then
                                    SkinData.defineID.TypeSpecificID = WeaponID
                                    Weapon.synData:Set(7, SkinData)
                                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                                end
                            end
                        end
                    end
                    local Vehicle = localPlayer:GetCurrentVehicle()
                    if Valid(Vehicle) then
                        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP or Vehicle:GetAvatarComponent()
                        if Valid(VehicleAvatar) and type(VehicleAvatar.GetDefaultAvatarID) == "function" then
                            local defId = VehicleAvatar:GetDefaultAvatarID()
                            if VehicleAvatar.ChangeItemAvatar then VehicleAvatar:ChangeItemAvatar(defId, true) end
                        end
                    end
                    if localPlayer.AvatarComponent2 and type(localPlayer.AvatarComponent2.OnRep_BodySlotStateChanged) == "function" then
                        localPlayer.AvatarComponent2:OnRep_BodySlotStateChanged()
                    end
                end)
                _G.LexusState.SkinWasApplied = false
            end
            _G.TDSkinLoopStarted = false
        end
    end)
end

-- ===== KILL BROADCAST SKIN INJECT HOOK (by @XThrlen) =====
if not _G.SH_KillBroadcastHacked then
    pcall(function()
        local BattleKillBroadcastSubSystem = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
        if BattleKillBroadcastSubSystem then
            local O_CopyKillOrPutDownMessageDataUserDataToLuaTable = BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable
            BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                local msgData = O_CopyKillOrPutDownMessageDataUserDataToLuaTable(self, messageData)
                if msgData and msgData.bIamCauser then
                    local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
                    if uCharacter and slua.isValid(uCharacter) then
                        if msgData.DamageType == UEnums.DamageType.VehicleDamage then
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID ~= 0 then
                                local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                ExpandData.CauserVehicleSkinID = carSkinID
                                ExpandData.CauserWeaponAvatarID = carSkinID
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        else
                            local currWeapon = uCharacter:GetCurrentWeapon()
                            if currWeapon and slua.isValid(currWeapon) then
                                local synData = currWeapon.synData
                                if synData and slua.isValid(synData) then
                                    local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                    if weaponDefineID and slua.isValid(weaponDefineID) then
                                        local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                        ExpandData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                                    end
                                end
                            end
                        end
                    end
                end
                return msgData
            end
            _G.SH_KillBroadcastHacked = true
        end
    end)
end
-- ===== KILL BROADCAST SKIN INJECT HOOK END =====


-- ======  AUTO-FEEDBACK (win screenshot + Telegram, English rank) ======
-- Relay (worker) se jata hai - token lua me nahi hai.
-- ======  AUTO-FEEDBACK (win screenshot + Telegram, English rank) ======
-- RDX port: TestMode ON, rank English, sendPhoto via configured bot.
local AutoFeedback = {
	Config = {
		ServerURL = "https://ahmediqh.x10.mx/uploads/rahaf.php", -- Cloudflare feedback relay (LIVE)
		TestMode = false -- m_normal: sirf asli win par
	},
	Hooked = false
}

local function Log(message)
	print(string.format("[ABU RAHAF VIP] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
end

local function Notify(message)
	if _G.SRCHUBNotify then
		pcall(_G.SRCHUBNotify, message)
	end
end

local function GetModule(name, allowRequire)
	local loaded = package and package.loaded and package.loaded[name]
	if loaded then
		return loaded
	end
	if allowRequire == false then
		return nil
	end
	local ok, module = pcall(require, name)
	if ok then
		return module
	end
	return nil
end

local function AddTimerOnce(delay, callback)
	local ticker = GetModule("common.time_ticker")
	if ticker and type(ticker.AddTimerOnce) == "function" then
		ticker.AddTimerOnce(delay, callback)
		return true
	end
	return false
end

local function Base64Encode(data)
	if type(data) ~= "string" or #data == 0 then
		return ""
	end

	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	local outputIndex = 0
	local index = 1

	while index <= #data - 2 do
		local a, b, c = string.byte(data, index, index + 2)
		local value = a * 65536 + b * 256 + c
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte(alphabet, value % 64 + 1)
		)
		index = index + 3
	end

	local remaining = #data - index + 1
	if remaining == 2 then
		local a, b = string.byte(data, index, index + 1)
		local value = a * 65536 + b * 256
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte("=")
		)
	elseif remaining == 1 then
		local value = string.byte(data, index) * 65536
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte("="),
			string.byte("=")
		)
	end

	return table.concat(output)
end

local function UrlEncode(value)
	if value == nil then
		return nil
	end
	value = tostring(value):gsub("\n", "\r\n")
	value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
		return string.format("%%%02X", string.byte(character))
	end)
	value = value:gsub(" ", "+")
	return value
end

local function ReadFile(path)
	local file = io.open(path, "rb")
	if not file then
		return ""
	end
	local data = file:read("*a") or ""
	file:close()
	return data
end

local function RemoveFile(path)
	pcall(os.remove, path)
end

-- RDX: English rank (same rating thresholds)
local function GetRankName(rank)
	rank = tonumber(rank) or 0
	if rank < 1700 then
		return "Bronze"
	elseif rank < 2200 then
		return "Silver"
	elseif rank < 2700 then
		return "Gold"
	elseif rank < 3200 then
		return "Platinum"
	elseif rank < 3700 then
		return "Diamond"
	elseif rank < 4200 then
		return "Crown"
	elseif rank < 4700 then
		return "Ace"
	elseif rank < 5200 then
		return "Ace Master"
	elseif rank < 5600 then
		return "Ace Dominator"
	end
	return "Conqueror"
end

local FeedbackCaptionTemplate = "<tg-emoji emoji-id=\"5807868868886009920\">CROWN</tg-emoji> <b>JOIN @abu_rhofen</b>\n" .. "<tg-emoji emoji-id=\"6008118472066732010\">FIRE</tg-emoji> <b>AUTO FEEDBACK GROUP VIP</b>\n" .. "<tg-emoji emoji-id=\"5985616167740379273\">TIME</tg-emoji> <b>Time: %s</b>\n" .. "<tg-emoji emoji-id=\"5814550759961793482\">USER</tg-emoji> <b>Player name: %s</b>\n" .. "<tg-emoji emoji-id=\"6008090211181923982\">KEY</tg-emoji> <b>UID: %s</b>\n" .. "<tg-emoji emoji-id=\"5873121512445187130\">SKULL</tg-emoji> <b>Kills: %d</b>\n" .. "<tg-emoji emoji-id=\"5807461353799030682\">CROWN</tg-emoji> <b>Rank: %s</b>\n" .. "<tg-emoji emoji-id=\"5890944389773005080\">MSG</tg-emoji> <b>TELEGRAM: @abu_rhofen</b>"

function AutoFeedback.SendFeedback(path, kills, rank, segment)
	Log("Preparing to send feedback. Screenshot: " .. tostring(path))
	local ok, err = pcall(function()
		local tok, chat = nil, nil
		pcall(function()
			if _G.TelegramFeedback then tok = _G.TelegramFeedback.BotToken chat = _G.TelegramFeedback.ChatID end
		end)
		local uid = "unknown"
		if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
			uid = tostring(_G.DataMgr.roleData.uid)
		elseif _G._NTH_UK then
			uid = tostring(_G._NTH_UK)
		end
		kills = tonumber(kills) or 0
		rank = tonumber(rank) or 0
		segment = tonumber(segment) or 0
		local maskedName = "*****"
		local maskedUid = "***"
		if uid ~= "unknown" and #uid > 5 then
			maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
		end
		local caption = string.format(
			FeedbackCaptionTemplate,
			os.date("%H:%M:%S %d/%m/%Y"),
			maskedName,
			maskedUid,
			kills,
			GetRankName(rank)
		)
		local http = nil
		pcall(function() http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager) end)
		if (not http or type(http.Post) ~= "function") then
			local hm = GetModule("client.slua.logic.http.http_manager")
			if hm and type(hm.Post) == "function" then http = hm end
		end
		if not http then Log("HTTP manager is unavailable.") RemoveFile(path) return end
		local imageData = ReadFile(path)
		local function sendDirect()
			if not tok or tok == "" or tok == "PASTE_BOT_TOKEN_HERE" then Log("Telegram token missing.") RemoveFile(path) return end
			if not chat or chat == "" or chat == "PASTE_CHAT_ID_HERE" then Log("Telegram chat missing.") RemoveFile(path) return end
			if imageData and #imageData > 0 then
				local boundary = "----RDXNTHBOUNDARY"
				local body = "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"chat_id\"\r\n\r\n" .. tostring(chat) .. "\r\n"
					.. "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"parse_mode\"\r\n\r\nHTML\r\n"
					.. "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"caption\"\r\n\r\n" .. caption .. "\r\n"
					.. "--" .. boundary .. "\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"win.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n" .. imageData .. "\r\n"
					.. "--" .. boundary .. "--\r\n"
				http:Post("https://api.telegram.org/bot" .. tok .. "/sendPhoto",
					{["Content-Type"] = "multipart/form-data; boundary=" .. boundary},
					body, nil,
					function(success, _, response, errorMessage)
						if success then Notify("[ABU RAHAF] Sent! (Kills: " .. tostring(kills) .. ")")
						else Notify("[ABU RAHAF] Photo fail, text fallback...") RemoveFile(path)
							local tb = "chat_id=" .. tostring(chat) .. "&parse_mode=HTML&text=" .. UrlEncode(caption)
							http:Post("https://api.telegram.org/bot" .. tok .. "/sendMessage",
								{["Content-Type"] = "application/x-www-form-urlencoded"},
								tb, nil, function(s2) RemoveFile(path) end, 15)
						end
					end, 60)
			else
				local tb = "chat_id=" .. tostring(chat) .. "&parse_mode=HTML&text=" .. UrlEncode(caption)
				http:Post("https://api.telegram.org/bot" .. tok .. "/sendMessage",
					{["Content-Type"] = "application/x-www-form-urlencoded"},
					tb, nil, function(s2) RemoveFile(path) end, 15)
			end
		end
		local relay = AutoFeedback.Config.ServerURL
		if relay and relay ~= "" and not string.find(relay, "YOURDOMAIN", 1, true) then
			Notify("[ABU RAHAF] Sending via VPS...")
			local enc = ""
			if imageData and #imageData > 0 then
				enc = Base64Encode(imageData)
				enc = enc:gsub("%+", "%%2B")
				enc = enc:gsub("/", "%%2F")
				enc = enc:gsub("=", "%%3D")
			end
			local rbody = "base64_image=" .. enc .. "&caption=" .. UrlEncode(caption)
			http:Post(relay,
				{["Content-Type"] = "application/x-www-form-urlencoded"},
				rbody, nil,
				function(s, _, resp)
					if s and resp and tostring(resp):find('"status":%s*true') then
						Notify("[ABU RAHAF] Sent via VPS!")
						RemoveFile(path)
					else
						sendDirect()
					end
				end, 60)
		else
			sendDirect()
		end
	end)
	if not ok then
		Log("SendFeedback Error: " .. tostring(err))
	end
end
local HudNames = {
	"BattleChat_UIBP",
	"Chat_UIBP",
	"ChatMsg_UIBP",
	"TeamAvatar_UIBP",
	"Team_UIBP",
	"VoiceChat_UIBP",
	"MiniMap_UIBP",
	"Bag_UIBP",
	"PickUp_UIBP",
	"PickUpList_UIBP",
	"SystemChat_UIBP",
	"InGameChat_UIBP",
	"InGameChatPanel_UIBP",
	"KillFeed_UIBP",
	"Elimination_UIBP",
	"ChatHUD_UIBP",
	"ChatPanel_UIBP",
	"MainHUD_UIBP",
	"BattleHUD_UIBP"
}

local function GetRankAndSegment()
	local rank = 0
	local segment = 0

	pcall(function()
		local battleResult = _G.BP_STRUCT_BattleResultData
		local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
		if rating then
			rank = tonumber(rating.rank_rating) or 0
			segment = tonumber(rating.new_segment) or 0
		end

		if rank == 0 then
			local funcUtil = GetModule("common.func_util")
			local roleData = _G.DataMgr and _G.DataMgr.roleData
			if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function"
				and roleData and roleData.allzoneSegment then
				segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
			end

			if roleData and roleData.segment_rating then
				for _, value in pairs(roleData.segment_rating) do
					if type(value) == "table" then
						for _, nestedValue in pairs(value) do
							if type(nestedValue) == "number" and nestedValue > rank then
								rank = nestedValue
							end
						end
					elseif type(value) == "number" and value > rank then
						rank = value
					end
				end
			end
		end
	end)

	return rank, segment
end

local function CreateHudController()
	local hidden = {}

	local function SetHidden(hide)
		local UIManager = _G.UIManager
		if not UIManager then
			return
		end

		if hide then
			for _, name in ipairs(HudNames) do
				local config
				if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
					config = UIManager.UI_Config_InGame[name]
				elseif UIManager.UI_Config and UIManager.UI_Config[name] then
					config = UIManager.UI_Config[name]
				end

				if config then
					local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
					if view then
						pcall(function()
							if type(view.SetVisibility) == "function" then
								view:SetVisibility(2)
							elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then
								view.UIRoot:SetVisibility(2)
							elseif type(UIManager.HideUI) == "function" then
								UIManager.HideUI(config)
							elseif type(UIManager.CloseUI) == "function" then
								UIManager.CloseUI(config)
							end
						end)
						table.insert(hidden, {config = config, view = view})
					end
				end
			end
			return
		end

		for _, item in ipairs(hidden) do
			pcall(function()
				if item.view and type(item.view.SetVisibility) == "function" then
					item.view:SetVisibility(0)
				elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then
					item.view.UIRoot:SetVisibility(0)
				elseif type(UIManager.ShowUI) == "function" then
					UIManager.ShowUI(item.config)
				end
			end)
		end
		hidden = {}
	end

	return SetHidden
end

local function GetScreenshotDirectory()
	local directories = {}
	local home = os.getenv("HOME")
	if home and home ~= "" then
		table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/")
	end

	local packages = {
		"com.tencent.ig",
		"com.vng.pubgmobile",
		"com.pubg.krmobile",
		"com.rekoo.pubgm",
		"com.pubg.imobile"
	}
	for _, packageName in ipairs(packages) do
		table.insert(
			directories,
			"/storage/emulated/0/Android/data/" .. packageName
				.. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/"
		)
	end

	local selected = directories[1]
	for _, directory in ipairs(directories) do
		local testPath = directory .. "t.tmp"
		local file = io.open(testPath, "w")
		if file then
			file:close()
			os.remove(testPath)
			selected = directory
			break
		end
	end
	return selected
end

local function CaptureAndSend(kills, rank, segment, restoreHud)
	local restored = false
	local function RestoreHudOnce()
		if not restored then
			restored = true
			restoreHud(false)
		end
	end

	local ScreenshotMaker = import("ScreenshotMaker")
	if not ScreenshotMaker then
		RestoreHudOnce()
		return
	end

	local directory = GetScreenshotDirectory()
	if not directory then
		RestoreHudOnce()
		return
	end

	local path = directory .. string.format("nthwin_%s.jpg", os.time())
	local uiUtil = GetModule("client.common.ui_util")
	local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
	local enginePreTick = gameInstance and gameInstance.EnginePreTick
	if not enginePreTick or type(enginePreTick.Add) ~= "function" then
		RestoreHudOnce()
		return
	end

	local ticker = GetModule("common.time_ticker")
	if not ticker or type(ticker.AddTimerOnce) ~= "function" then
		RestoreHudOnce()
		return
	end

	enginePreTick:Add(function()
		local actualPath = ScreenshotMaker.MakePictureByName(path, true)
		if type(enginePreTick.Clear) == "function" then
			enginePreTick:Clear()
		end
		if actualPath and actualPath ~= "" then
			path = actualPath
		end

		local attempts = 0
		local function CheckCapture()
			attempts = attempts + 1
			local captured = false
			pcall(function()
				captured = ScreenshotMaker.HasCaptured(path)
			end)

			if captured then
				RestoreHudOnce()
				Log("HasCaptured=true. Flushing to disk via ResizePicture...")
				pcall(ScreenshotMaker.ResizePicture, path, 0.6, path)
				ticker.AddTimerOnce(2.0, function()
					if #ReadFile(path) > 0 then
						AutoFeedback.SendFeedback(path, kills, rank, segment)
					else
						Notify("[ABU RAHAF] Lỗi đọc ảnh iOS!")
					end
				end)
			elseif attempts < 15 then
				ticker.AddTimerOnce(1, CheckCapture)
			else
				RestoreHudOnce()
				Notify("[ABU RAHAF] Chụp ảnh thất bại!")
			end
		end

		ticker.AddTimerOnce(1, CheckCapture)
	end)
end

function AutoFeedback.ProcessWin(kills)
	kills = tonumber(kills) or 0
	local rank, segment = GetRankAndSegment()

	if rank < 2200 or kills <= 5 then
		Log(string.format(
			"Bỏ qua feedback: Rank %d, Kill %d (Yêu cầu Rank >= 2200 VÀ Kill > 5)",
			rank,
			kills
		))
		return
	end

	Notify("[ABU RAHAF] Chúc mừng TUẤT đã TOP 1...")
	local setHudHidden = CreateHudController()
	setHudHidden(true)

	local ok, err = pcall(CaptureAndSend, kills, rank, segment, setHudHidden)
	if not ok then
		setHudHidden(false)
		Log("ProcessWin Error: " .. tostring(err))
	end
end

local function GetWinnerKills()
	local kills = 0
	pcall(function()
		local likeUtil = GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
		if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
			local playerState = likeUtil.GetMyPlayerState()
			if playerState and playerState.Kills then
				kills = tonumber(playerState.Kills) or 0
			end
		end

		if kills == 0 then
			local resultLogic = GetModule(
				"GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic",
				false
			)
			if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
				local result = resultLogic:GetBattleResultData()
				if result and result.BP_mykill then
					kills = tonumber(result.BP_mykill) or 0
				end
			end
		end
	end)
	return kills
end

local function TryInstallHook()
	pcall(function()
		local UIManager = _G.UIManager
		if not UIManager or not UIManager.ShowUI or UIManager.__SRCHUBHooked then
			return
		end

		Log("Hooking UIManager.ShowUI for in-game Winner UI...")
		local originalShowUI = UIManager.ShowUI
		UIManager.ShowUI = function(config, params, ...)
			local result = originalShowUI(config, params, ...)
			pcall(function()
				local inGameConfig = UIManager.UI_Config_InGame
				local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
				local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
				if not winnerConfig or config ~= winnerConfig or not isWinner then
					return
				end

				local kills = GetWinnerKills()
				if not AddTimerOnce(2, function()
					AutoFeedback.ProcessWin(kills)
				end) then
					AutoFeedback.ProcessWin(kills)
				end
			end)
			return result
		end

		UIManager.__SRCHUBHooked = true
		AutoFeedback.Hooked = true
		Log("UIManager Hook installed successfully.")
	end)
end

function AutoFeedback.Install()
	Log("Installing ABU RAHAFsystem (Telegram)...")

	if AutoFeedback.Config.TestMode then
		pcall(function()
			AddTimerOnce(5.0, function()
				AutoFeedback.ProcessWin()
			end)
		end)
	end

	pcall(function()
		local ticker = GetModule("common.time_ticker")
		if ticker and type(ticker.AddTimer) == "function" then
			ticker.AddTimer(3.0, TryInstallHook)
		else
			TryInstallHook()
		end
	end)
end

AutoFeedback.Base64Encode = Base64Encode
AutoFeedback.UrlEncode = UrlEncode
AutoFeedback.GetRankName = GetRankName
_G.AKMOD_AutoFeedbackRecovered = AutoFeedback

AutoFeedback.Install()


-- ====== END  AUTO-FEEDBACK ======
-- ====== AUTO REPORT SYSTEM (Reports all enemies, skips teammates) ======
_G.AutoReportConfig = _G.AutoReportConfig or {
    Enable = false,
    ReportReason = 1,
    ReportDelay = 3.0,
    BotsOnly = false,
    AutoScreenshot = true,
    _lastReportTime = 0,
    _reportedPlayers = {},
    _cachedReportModule = nil,
    _reportQueue = {},
}
-- BAN-SAFE LOCK: Auto Report + Auto Screenshot hamesha OFF (ban risk, menu se hataya)
_G.AutoReportConfig.Enable = false
_G.AutoReportConfig.AutoScreenshot = false

_G.AutoReportReasons = {
    [1] = "Cheating",
    [2] = "Hacking",
    [3] = "Abusing",
    [4] = "Griefing",
    [5] = "Team Killing",
}

_G.AutoReportPlayer = function(targetPlayer)
    if not _G.AutoReportConfig.Enable then return end
    if not targetPlayer or not slua.isValid(targetPlayer) then return end
    if not targetPlayer:IsAlive() then return end

    local localPlayer = nil
    pcall(function() localPlayer = GameplayData.GetLocalCharacter() end)
    if not Valid(localPlayer) then return end

    local myTeam = nil
    pcall(function() myTeam = localPlayer:GetTeamID() end)
    local targetTeam = nil
    pcall(function() targetTeam = targetPlayer:GetTeamID() end)

    if myTeam and targetTeam and myTeam == targetTeam then return end

    local targetKey = nil
    pcall(function() targetKey = targetPlayer:GetPlayerKey() end)
    if not targetKey then
        pcall(function() targetKey = targetPlayer.PlayerKey end)
    end
    if not targetKey then return end

    if _G.AutoReportConfig._reportedPlayers[targetKey] then return end

    local targetName = nil
    pcall(function() targetName = targetPlayer:GetPlayerNameSafety() end)
    if not targetName then
        pcall(function()
            local PS = targetPlayer:GetPlayerState()
            if Valid(PS) and PS.GetPlayerName then
                targetName = PS:GetPlayerName()
            end
        end)
    end
    if not targetName or targetName == "" or targetName == "Unknown" then return end

    local reason = _G.AutoReportReasons[_G.AutoReportConfig.ReportReason] or "Cheating"
    _G.AutoReportConfig._reportedPlayers[targetKey] = true
    _G.AutoReportConfig._reportQueue[#_G.AutoReportConfig._reportQueue + 1] = {key = targetKey, reason = reason, name = targetName}
end

_G._ProcessReportQueue = function()
    local queue = _G.AutoReportConfig._reportQueue
    if not queue or #queue == 0 then return end

    local curTime = os.clock()
    if (curTime - _G.AutoReportConfig._lastReportTime) < 0.5 then return end

    local entry = table.remove(queue, 1)
    if not entry then return end

    pcall(function()
        if not _G.AutoReportConfig._cachedReportModule then
            _G.AutoReportConfig._cachedReportModule = require("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
        end
        local mod = _G.AutoReportConfig._cachedReportModule
        if mod and mod.ReportPlayer then
            mod:ReportPlayer(entry.key, entry.reason)
            _G.AutoReportConfig._lastReportTime = curTime
        end
    end)
end

_G.AutoReportTick = function()
    if not _G.AutoReportConfig.Enable then return end

    _G._ProcessReportQueue()

    local localPlayer = nil
    pcall(function() localPlayer = GameplayData.GetLocalCharacter() end)
    if not Valid(localPlayer) then return end

    local allCharacters = {}
    pcall(function()
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters()
        end
    end)

    local aliveEnemies = 0
    for _, actor in pairs(allCharacters) do
        if Valid(actor) and actor ~= localPlayer and actor:IsAlive() then
            local isTeammate = false
            pcall(function()
                local myTeam = localPlayer:GetTeamID()
                local tTeam = actor:GetTeamID()
                if myTeam and tTeam and myTeam == tTeam then isTeammate = true end
            end)
            if not isTeammate then
                aliveEnemies = aliveEnemies + 1
                _G.AutoReportPlayer(actor)
                if (os.clock() - _G._AutoReportTickStart or 0) > 0.05 then break end
            end
        end
    end

    if aliveEnemies == 0 and _G.AutoReportConfig.AutoScreenshot then
        if not _G._AutoReportSSSent then
            _G._AutoReportSSSent = true
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                local world = slua.getWorld()
                if KSL and world then
                    KSL.ExecuteConsoleCommand(world, "HighResShot 1920x1080")
                end
            end)
        end
    end

    if aliveEnemies > 0 then
        _G._AutoReportSSSent = false
    end
end

_G.BRStartSkinLoop = function()
    _G.__BR_SkinTimer = nil
    pcall(function()
        if _G.Game and _G.Game.AddGameTimer then
            _G.__BR_SkinTimer = _G.Game:AddGameTimer(0.5, true, _G.BRSkinUpdate)
        elseif slua_GameFrontendHUD then
            local pc = slua_GameFrontendHUD:GetPlayerController()
            if Valid(pc) and type(pc.AddGameTimer) == "function" then
                _G.__BR_SkinTimer = pc:AddGameTimer(0.5, true, _G.BRSkinUpdate)
            end
        end
    end)
end
_G.BRStartSkinLoop()
    -- Sh MENU MODULE - OPTIMIZED FOR NO LAG (ZERO REPETITION)
    -- ============================================================
    local MY_TAB_VER = 18

    if not _G.__MyTabInstalled then
    _G.__MyTabInstalled = true

    local LOC = {
        MY_TAB             = 9990001,
        TAB_AIMBOT         = 9990011,
        TAB_MEMORY         = 9990014,
        TAB_SKIN           = 9990015,
        TAB_OUTFIT         = 9990018,
        TAB_GUNS           = 9990019,
        TAB_GEAR           = 9990020,
        TAB_VEH            = 9990021,
        TAB_SKINPAGE       = 9990022,
        TITLE_SKIN         = 9990016,

        BTN_ESP_ENABLE     = 9990100,
        TITLE_ESP          = 9990101,
        TITLE_CHAMS        = 9990130,
        BTN_CHAMS_ENABLE   = 9990102,
        BTN_ESP_LINES      = 9990103,
        BTN_ESP_FOV_CIRCLE = 9990110,
        BTN_ESP_ARROWS     = 9990111,
        BTN_ESP_BOX        = 9990112,
        BTN_CHAMS_VIS      = 9990104,
        BTN_CHAMS_OCC      = 9990105,
        BTN_NEW_WALLHACK   = 9990120,
        BTN_NEW_WH_VIS     = 9990121,
        BTN_NEW_WH_OCC     = 9990122,
        BTN_BLUE_FRAME     = 9990123,
        BTN_FAKE_HWID      = 9990106,
        
        TAB_BAN            = 9990017,
        BTN_CAR_FLY        = 9990107,
        BTN_CAR_FLY_SPEED  = 9990108,
        BTN_FAST_CAR       = 9990109,
        BTN_FORCE_TPP      = 9990114,
        BTN_MAGIC_BULLET   = 9990113,
        BTN_BAT_POWER      = 9990115,

        BTN_AIMBOT_ENABLE  = 9990030,
        BTN_AIMBOT_NORMAL = 9990036,
        BTN_AIMBOT_FOV     = 9990031,
        BTN_AIMBOT_DIST    = 9990032,
        BTN_AIMBOT_SPEED   = 9990033,
        BTN_AIMBOT_KNOCK   = 9990034,
        BTN_AIMBOT_BOT     = 9990035,
        BTN_AIMBOT_TARGET  = 9990037,
        BTN_AIMBOT_WALL    = 9990038,
        BTN_AIMBOT_INSCOPE = 9990039,
        BTN_AIMBOT_LONGRANGE = 9990042,
        BTN_AIMBOT_LONGRECOIL = 9990043,
        BTN_AIMBOT_BONE    = 9990041,
        BTN_LOBBY_SKIN     = 9990040,
        
        BTN_MEM_GRASS      = 9990080,
        BTN_MEM_TREES      = 9990081,
        BTN_MEM_FOG        = 9990082,
        BTN_MEM_BLACKSKY   = 9990083,
        BTN_MEM_FPS        = 9990084,
        BTN_MEM_IPAD       = 9990085,
        BTN_MEM_IPAD_FOV   = 9990086,
        BTN_MEM_SMALLSCOPE     = 9990088,
        BTN_MEM_SMALLSCOPE_FOV = 9990089,
        
        BTN_MEM_CROSSHAIR  = 9990087,
        
        BTN_AUTO_REPORT       = 9990090,
        BTN_AUTO_REPORT_REASON = 9990091,
        BTN_AUTO_REPORT_DELAY  = 9990092,
        
        OPT_ON             = 9990060,
        OPT_OFF            = 9990061,
        
        TITLE_AIMING       = 9990062,
        TITLE_SETTINGS     = 9990063,
    }

    local LOC_STR = {
        [LOC.MY_TAB]            = "VIP MENU",
        [LOC.TAB_AIMBOT]        = "AIMBOT",
        [LOC.TAB_MEMORY]        = "MEMORY",
        [LOC.TAB_SKIN]          = "SKIN",
        [LOC.TAB_OUTFIT]        = "OUTFIT",
        [LOC.TAB_GUNS]          = "GUNS",
        [LOC.TAB_GEAR]          = "GEAR",
        [LOC.TAB_VEH]           = "VEHICLE",
        [LOC.TAB_SKINPAGE]      = "SKIN",
        [LOC.TAB_BAN]           = "BAN FEATURES",
        [LOC.BTN_CAR_FLY]       = "Car Fly",
        [LOC.BTN_CAR_FLY_SPEED] = "Car Fly Speed",
        [LOC.BTN_FAST_CAR]      = "Fast Car",
        [LOC.BTN_FORCE_TPP]     = "Force TPP (FPP Match)",
        [LOC.BTN_MAGIC_BULLET]  = "Magic Bullet (Head Snap)",
        [LOC.BTN_BAT_POWER]     = "BAT New Power (Fly 10x)",
        [LOC.TITLE_SKIN]        = "SKIN CONTROL",

        [LOC.BTN_ESP_ENABLE]    = "ESP Enable",
        [LOC.TITLE_ESP]         = "ESP Control",
        [LOC.TITLE_CHAMS]       = "Chams & Wallhack",
        [LOC.BTN_CHAMS_ENABLE]  = "Chams (Color)",
        [LOC.BTN_ESP_LINES]     = "ESP Lines",
        [LOC.BTN_ESP_FOV_CIRCLE] = "FOV Circle",
        [LOC.BTN_ESP_ARROWS]     = "Offscreen Arrows",
        [LOC.BTN_ESP_BOX]        = "Box ESP",
        [LOC.BTN_CHAMS_VIS]     = "Chams Front Color (1R 2B 3G 4Y 5O 6P)",
        [LOC.BTN_CHAMS_OCC]     = "Chams Wall Color (1R 2B 3G 4Y 5O 6P)",
        [LOC.BTN_NEW_WALLHACK]  = "NEW WALLHACK (PBC)",
        [LOC.BTN_NEW_WH_VIS]    = "Wallhack Visible Color (1Green 2Lime 3Orange 4Red 5Blue 6Gray 7Teal)",
        [LOC.BTN_NEW_WH_OCC]    = "Wallhack Wall Color (1Green 2Lime 3Orange 4Red 5Blue 6Gray 7Teal)",
        [LOC.BTN_BLUE_FRAME]    = "BLUE FRAME ESP (OB Head)",
        [LOC.BTN_FAKE_HWID]     = "Fake HWID (Anti-Ban)",
        
        [LOC.BTN_AIMBOT_ENABLE] = "Aimbot Enable",
        [LOC.BTN_AIMBOT_NORMAL] = "Normal Aimbot",
        [LOC.BTN_AIMBOT_FOV]    = "Aimbot FOV",
        [LOC.BTN_AIMBOT_DIST]   = "Aimbot Max Dist",
        [LOC.BTN_AIMBOT_SPEED]  = "Aimbot Smooth Speed",
        [LOC.BTN_AIMBOT_KNOCK]  = "Ignore Knocked",
        [LOC.BTN_AIMBOT_BOT]    = "Ignore Bots",
        [LOC.BTN_AIMBOT_TARGET] = "Target Mode (1Near 2LowHP)",
        [LOC.BTN_AIMBOT_WALL]   = "Wall Target (Through Wall)",
        [LOC.BTN_AIMBOT_INSCOPE] = "In Scope Aimbot (10-100m)",
        [LOC.BTN_AIMBOT_LONGRANGE] = "Long Range Aimbot (300m+)",
        [LOC.BTN_AIMBOT_LONGRECOIL] = "Long Range Recoil (0 Off)",
        [LOC.BTN_AIMBOT_BONE]    = "Aim Bone",
        [LOC.BTN_LOBBY_SKIN]     = "Show (LOBBY SKIN)",
        
        [LOC.BTN_MEM_GRASS]     = "Remove Grass",
        [LOC.BTN_MEM_TREES]     = "Remove Trees",
        [LOC.BTN_MEM_FOG]       = "Remove Fog",
        [LOC.BTN_MEM_BLACKSKY]  = "Black Sky",
        [LOC.BTN_MEM_FPS]       = "Unlock 165 FPS",
        [LOC.BTN_MEM_IPAD]      = "iPad View",
        [LOC.BTN_MEM_IPAD_FOV]  = "iPad FOV",
        [LOC.BTN_MEM_SMALLSCOPE]     = "Small Scope (iPad Style)",
        [LOC.BTN_MEM_SMALLSCOPE_FOV] = "Small Scope FOV",
        
        [LOC.BTN_MEM_CROSSHAIR]  = "Small Crosshair",
        
        [LOC.BTN_AUTO_REPORT]    = "Auto Report Enemies",
        [LOC.BTN_AUTO_REPORT_REASON] = "Report Reason",
        [LOC.BTN_AUTO_REPORT_DELAY]  = "Report Delay",
        
        [LOC.OPT_ON]            = "ON",
        [LOC.OPT_OFF]           = "OFF",
        
        [LOC.TITLE_AIMING]      = "Aimbot Configuration",
        [LOC.TITLE_SETTINGS]    = "Memory Hacks",
    }

    _G.MemoryConfig = _G.MemoryConfig or {
        RemoveGrass = false,
        RemoveTrees = false,
        RemoveFog   = false,
        BlackSky    = false,
        UnlockFPS   = false,
        IpadView    = false,
        IpadFOV     = 120,
        _IpadWasActive = false,
        SmallCrosshair = false,
        _CrosshairWasActive = false,
        SmallScope = false,
        SmallScopeFOV = 75,
    }

    local function ResolveLoc(id)
        return LOC_STR[id]
    end

    local function LOG(msg)
        pcall(print, "[Sh Menu] " .. tostring(msg))
    end

    LOG("Sh Menu v" .. MY_TAB_VER .. " loading...")

    local function ApplyMemoryFeature(feature, state)
        pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if not gi then
            gi = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
        end
        if not gi then return end

        if feature == "Grass" then
            if state then
            gi:ExecuteCMD("grass.DensityScale", "0")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
            else
            gi:ExecuteCMD("grass.DensityScale", "1")
            gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
            end
        elseif feature == "Trees" then
            if state then
            gi:ExecuteCMD("foliage.DensityScale", "0")
            gi:ExecuteCMD("r.Foliage.DensityScale", "0")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
            gi:ExecuteCMD("r.DisableTreeRender", "1")
            else
            gi:ExecuteCMD("foliage.DensityScale", "1")
            gi:ExecuteCMD("r.Foliage.DensityScale", "1")
            gi:ExecuteCMD("foliage.MinimumScreenSize", "0")
            gi:ExecuteCMD("r.DisableTreeRender", "0")
            end
        elseif feature == "Fog" then
            if state then
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "0")
            gi:ExecuteCMD("r.VolumetricFog", "0")
            else
            gi:ExecuteCMD("r.SkyAtmosphere", "1")
            gi:ExecuteCMD("r.Fog", "1")
            gi:ExecuteCMD("r.VolumetricFog", "1")
            end
        elseif feature == "BlackSky" then
            if state then
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
            else
            gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0")
            end
        elseif feature == "FPS" then
            local SettingCfg = require("client.logic.setting.setting_config")
            local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
            
            if state then
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
            end
            gi:ExecuteCMD("t.MaxFPS", "165")
            gi:ExecuteCMD("r.FrameRateLimit", "165")
            else
            if SettingCfg then
                if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 90 end
                if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 90 end
            end
            if GraphicSettingDB then
                if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 90 end
            end
            gi:ExecuteCMD("t.MaxFPS", "90")
            gi:ExecuteCMD("r.FrameRateLimit", "90")
            end
        end
        end)
    end

    _G.ApplyMemoryFeature = ApplyMemoryFeature

    local function RefreshAllMemoryFeatures()
        if not _G.MemoryConfig then return end
        ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
        ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
        ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
        ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
        ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
    end
    _G.RefreshAllMemoryFeatures = RefreshAllMemoryFeatures

    RefreshAllMemoryFeatures()

    local function HookLoc(tbl, fname)
        if type(tbl) ~= "table" then return end
        if tbl["__mytab_hooked_" .. fname] then return end
        
        local orig = tbl[fname]
        if type(orig) ~= "function" then return end
        
        tbl["__mytab_hooked_" .. fname] = true
        tbl["__mytab_" .. fname] = orig
        
        tbl[fname] = function(...)
        local arg1 = select(1, ...)
        local id = arg1
        if type(arg1) == "table" and arg1 == tbl then
            id = select(2, ...)
        end
        
        local s = ResolveLoc(id)
        if s then return s end
        return orig(...)
        end
    end

    local function InstallLocHooks()
        local LocUtil = _G.LocUtil
        if not LocUtil then
        local ok, lu = pcall(require, "common.loc_util")
        if ok and lu then LocUtil = lu end
        end
        if type(LocUtil) == "table" then
        HookLoc(LocUtil, "GetLocalizeResStr")
        HookLoc(LocUtil, "GetLocalizeResStrV2")
        HookLoc(LocUtil, "TryGetLocalizeResStr")
        HookLoc(LocUtil, "ResolveText")
        end
        local DataMgr = _G.DataMgr
        if not DataMgr then
        local ok2, dm = pcall(require, "client.logic.data.data_mgr")
        if ok2 and dm then DataMgr = dm end
        end
        if type(DataMgr) == "table" then
        HookLoc(DataMgr, "GetMsgByID")
        HookLoc(DataMgr, "GetFormatMsgByID")
        end
    end

    InstallLocHooks()

    pcall(function()
        if type(slua) == "table" and type(slua.AddTickerDelegate) == "function" then
        local tries = 0
        slua.AddTickerDelegate(function()
            tries = tries + 1
            InstallLocHooks()
            return tries < 5
        end, 1.0)
        end
    end)

    local MY_TAB_DEFINE = {
        Key  = "MyTab",
        Text = LOC.MY_TAB,
    }

    -- SKIN ka alag page-tab (VIP MENU jaisa top-level tab)
    local SKIN_TAB_DEFINE = {
        Key  = "SkinTab",
        Text = LOC.TAB_SKINPAGE,
    }

    local function GetMyTabDefine()
        if MY_TAB_DEFINE.Category then return MY_TAB_DEFINE end
        pcall(TrySHSkinPatch) -- naam+icon patch rows banne se PEHLE lage
        local cfg = UIManager and UIManager.UI_Config
        if not cfg then return MY_TAB_DEFINE end

        local SwitcherUI = cfg.Setting_Option_Switcher
        if not SwitcherUI then return MY_TAB_DEFINE end

        local TitleUI   = cfg.Setting_Title
        local SliderUI  = cfg.Setting_Option_Slider
        local SpacerUI  = cfg.Setting_Spacer

        local function MakeSwitcher(key, textId, getCb, setCb)
        return {
            Key          = "MyTab_" .. key,
            UI           = SwitcherUI,
            Text         = textId,
            SwitcherText = { LOC.OPT_ON, LOC.OPT_OFF },
            GetFunc = function(item)
            local index = getCb()
            if type(item) == "table" then item.CurrentIndex = index end
            return index
            end,
            SetFunc = function(item, index)
            setCb(index)
            if type(item) == "table" then
                item.CurrentIndex = index
                item.SelectedIndex = index
                item.Value = index
                pcall(function()
                if item.SetSelectedIndex then item:SetSelectedIndex(index) end
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            return true
            end,
        }
        end

        local function MakeBoneSwitcher(key, textId, getCb, setCb)
        return {
            Key          = "MyTab_" .. key,
            UI           = SwitcherUI,
            Text         = textId,
            SwitcherText = { "Head", "Chest", "Pelvis" },
            GetFunc = function(item)
            local index = getCb()
            if type(item) == "table" then item.CurrentIndex = index end
            return index
            end,
            SetFunc = function(item, index)
            setCb(index)
            if type(item) == "table" then
                item.CurrentIndex = index
                item.SelectedIndex = index
                item.Value = index
                pcall(function()
                if item.SetSelectedIndex then item:SetSelectedIndex(index) end
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            return true
            end,
        }
        end

        local function MakeSlider(key, textId, minVal, maxVal, getCb, setCb)
        return {
            Key      = "MyTab_" .. key,
            UI       = SliderUI,
            Text     = textId,
            Min      = minVal,
            Max      = maxVal,
            GetFunc  = function(item)
            local val = getCb()
            if type(item) == "table" then item.Value = val end
            return val
            end,
            SetFunc  = function(item, val)
            setCb(val)
            if type(item) == "table" then
                item.Value = val
                pcall(function()
                if item.UpdateView then item:UpdateView() end
                if item.RefreshUI then item:RefreshUI() end
                end)
            end
            end,
        }
        end

        local function skinSlider(key, label, minVal, maxVal, field, mapTbl, mapKey)
            return MakeSlider(key, label, minVal, maxVal,
                function()
                    if not _G.LexusState.CustomTextData then return 1 end
                    return _G.LexusState.CustomTextData[field] or 1
                end,
                function(val)
                    local v = math.floor(val)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData[field] = v
                    if mapTbl and mapKey and _G[mapTbl] and _G[mapTbl][mapKey] then
                        local entry = _G[mapTbl][mapKey]
                        if entry and entry[v] then
                            if mapTbl == "OutfitSkins" then
                                _G.OutfitMap = _G.OutfitMap or {}
                                _G.OutfitMap[field:gsub("^Skin", "")] = entry[v]
                            elseif mapTbl == "VehicleSkins" then
                                _G.VehicleSkinMap[mapKey] = entry[v]
                            else
                                _G.WeaponSkinMap[mapKey] = entry[v]
                            end
                        end
                    end
                    _G.LexusState.DirtyConfig = true
                end
            )
        end

        -- ============================================================
        -- SH IMAGE-GRID SKIN BUILDER (image jaisa: Close + icon + naam)
        -- Har row = Setting_Option_ImageSwitcher (Close + max 4 skins).
        -- Value system: SwitcherValue = {0, fullIdx...}, 0 = Close.
        -- GetFunc(key)->member, SetFunc(key, member) — Switcher convention.
        -- Naam/icon game data se live (CDataTable/ui_util), cache samet.
        -- ============================================================
        local ImageSwitcherUI = cfg.Setting_Option_ImageSwitcher or SwitcherUI
        local _SKIN_WHITE_IMG = "/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White"
        _G._SH_SkinNameCache = _G._SH_SkinNameCache or {}
        _G._SH_SkinIconCache = _G._SH_SkinIconCache or {}
        _G._SH_SkinRows = _G._SH_SkinRows or {}

        local function _SH_SkinItemData(id)
            id = math.floor(tonumber(id) or 0)
            if id <= 0 then return nil end
            local d = nil
            pcall(function()
                if type(_G.SKIN_MOD_ORIG_GETTABLEDATA) == "function" then
                    d = _G.SKIN_MOD_ORIG_GETTABLEDATA("Item", id)
                end
            end)
            if type(d) ~= "table" then
                pcall(function()
                    d = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("Item", id) or nil
                end)
            end
            return d
        end

        -- Generic icon scan: known fields pehle, phir poori row me "/Game/" path
        -- (har item type: outfit/gun/helmet/bag/vehicle ke liye safe)
        local function _SH_ScanIcon(dd)
            if type(dd) ~= "table" then return nil end
            local found = nil
            pcall(function()
                for _, f in ipairs({"ItemSmallIcon", "ItemSmallIcon2", "ItemBigIcon", "SpecialIcon"}) do
                    local v = dd[f]
                    if type(v) == "string" and v ~= "" then found = v return end
                end
                local anyPath = nil
                for _, v in pairs(dd) do
                    if type(v) == "string" and #v > 6 and v:sub(1, 6) == "/Game/" then
                        if v:find("Icon") then found = v return end
                        if not anyPath then anyPath = v end
                    end
                end
                found = found or anyPath
            end)
            return found
        end

        local function _SH_SkinIcon(id)
            id = math.floor(tonumber(id) or 0)
            if id <= 0 then return _SKIN_WHITE_IMG end
            local c = _G._SH_SkinIconCache[id]
            if c then return c end
            local path = _SH_ScanIcon(_SH_SkinItemData(id))
            if not path then
                pcall(function()
                    local ui_util = require("client.common.ui_util")
                    if ui_util and ui_util.GetItemSmallIcon then
                        path = select(1, ui_util.GetItemSmallIcon(id, nil))
                    end
                end)
            end
            if type(path) ~= "string" or path == "" then
                return _SKIN_WHITE_IMG -- FAIL CACHE NAHI: agle menu-open par retry hoga
            end
            _G._SH_SkinIconCache[id] = path
            return path
        end

        local function _SH_SkinName(id, fb)
            id = math.floor(tonumber(id) or 0)
            if id <= 0 then return fb or "Close" end
            local c = _G._SH_SkinNameCache[id]
            if c then return c end
            local name = nil
            pcall(function()
                local DU = require("client.slua.logic.common.Logic_DetailUtils")
                if DU and DU.GetItemName then name = DU.GetItemName(id) end
            end)
            if type(name) ~= "string" or name == "" then
                pcall(function()
                    local dd = _SH_SkinItemData(id)
                    if type(dd) == "table" then name = dd.ItemName or dd.Name or nil end
                end)
            end
            if tonumber(name) then
                pcall(function()
                    local ui_util = require("client.common.ui_util")
                    if ui_util and ui_util.GetLocalizationString then
                        local s = ui_util.GetLocalizationString(tonumber(name))
                        if type(s) == "string" and s ~= "" then name = s end
                    end
                end)
                if tonumber(name) then name = nil end
            end
            if type(name) ~= "string" or name == "" then name = fb or ("Skin " .. tostring(id)) end
            _G._SH_SkinNameCache[id] = name
            return name
        end

        -- Core row factory. fullList = array (ids ya {l1,l2,l3} tables).
        -- indices = is row me dikhne wale full-index (max 4 + Close).
        local function skinImageRow(key, label, fullList, indices, idOf, curIdx, commit)
            fullList = fullList or {}
            local vals, texts, imgs, rids = {0}, {"Close"}, {_SKIN_WHITE_IMG}, {0}
            for _, fi in ipairs(indices or {}) do
                local e = fullList[fi]
                if e ~= nil then
                    local rid = 0
                    pcall(function() rid = math.floor(tonumber(idOf(e)) or 0) end)
                    vals[#vals + 1] = fi
                    rids[#rids + 1] = rid
                    texts[#texts + 1] = _SH_SkinName(rid, label .. " " .. tostring(fi))
                    imgs[#imgs + 1] = _SH_SkinIcon(rid)
                end
            end
            _G._SH_SkinRows["MyTab_" .. key] = { vals = vals, texts = texts, itemIds = rids, label = label }
            return {
                Key = "MyTab_" .. key,
                UI = ImageSwitcherUI,
                Text = label,
                SwitcherValue = vals,
                SwitcherText = texts,
                SwitcherImage = imgs,
                _SH_ItemIds = rids,
                UseImageSwitcher = true,
                GetFunc = function(k)
                    local ci = 0
                    pcall(function() ci = math.floor(tonumber(curIdx()) or 0) end)
                    for _, v in ipairs(vals) do if v == ci then return ci end end
                    return 0
                end,
                SetFunc = function(k, v)
                    v = math.floor(tonumber(v) or 0)
                    local ok2 = (v == 0)
                    if not ok2 then
                        for _, vv in ipairs(vals) do if vv == v then ok2 = true break end end
                    end
                    if not ok2 then v = 0 end
                    pcall(function() commit(v, fullList[v]) end)
                    _G.LexusState.DirtyConfig = true
                    pcall(function() if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end end)
                    return true
                end,
            }
        end

        local function outfitRow(key, label, idxs)
            local list = _G.OutfitSkins and _G.OutfitSkins.Suit or {}
            return skinImageRow(key, label, list, idxs,
                function(e) return e end,
                function()
                    local cur = _G.OutfitMap and _G.OutfitMap.Suit or 0
                    for i, id in ipairs(list) do if id == cur then return i end end
                    return 0
                end,
                function(fi, e)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData.SkinSuit = fi
                    _G.OutfitMap = _G.OutfitMap or {}
                    _G.OutfitMap.Suit = (fi > 0) and e or nil
                end)
        end

        local function gunRow(key, label, gunId, field, idxs)
            local list = (_G.skinIdMappings and _G.skinIdMappings[gunId]) or {}
            return skinImageRow(key, label, list, idxs,
                function(e) return e end,
                function()
                    local cur = (_G.WeaponSkinMap and _G.WeaponSkinMap[gunId]) or 0
                    for i, id in ipairs(list) do if id == cur then return i end end
                    return 0
                end,
                function(fi, e)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData[field] = fi
                    _G.WeaponSkinMap = _G.WeaponSkinMap or {}
                    _G.WeaponSkinMap[gunId] = (fi > 0) and e or nil
                end)
        end

        local function gearRow(key, label, list, field, mapKey, idxs)
            list = list or {}
            return skinImageRow(key, label, list, idxs,
                function(e)
                    if type(e) == "table" then return e[3] or e[1] or 0 end
                    return e
                end,
                function()
                    local cur = _G.OutfitMap and _G.OutfitMap[mapKey]
                    for i, e in ipairs(list) do
                        if e == cur then return i end
                        if type(e) == "table" and type(cur) == "table"
                            and (e[3] or e[1]) == (cur[3] or cur[1]) then return i end
                    end
                    return 0
                end,
                function(fi, e)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData[field] = fi
                    _G.OutfitMap = _G.OutfitMap or {}
                    _G.OutfitMap[mapKey] = (fi > 0) and e or nil
                end)
        end

        local function vehRow(key, label, vid, field, idxs)
            local list = (_G.VehicleSkins and _G.VehicleSkins[vid]) or {}
            return skinImageRow(key, label, list, idxs,
                function(e) return e end,
                function()
                    local cur = (_G.VehicleSkinMap and _G.VehicleSkinMap[vid]) or 0
                    for i, id in ipairs(list) do if id == cur then return i end end
                    return 0
                end,
                function(fi, e)
                    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                    _G.LexusState.CustomTextData[field] = fi
                    _G.VehicleSkinMap = _G.VehicleSkinMap or {}
                    _G.VehicleSkinMap[vid] = (fi > 0) and e or nil
                end)
        end

        -- ============================================================
        -- IMAGE-SWITCHER TEXT+ICON FIX (naam gayab + toote icon ka ilaj)
        -- Engine SetupOptionItemWidget Text par GetLocalizeResStr lagata hai
        -- (raw naam "" ho jata hai) aur icon ko streaming queue nahi milti.
        -- Ye patch: naam direct set + engine loader se live widget me icon.
        -- Non-skin rows untouched (unke liye sirf original chalta hai).
        -- ============================================================
        local function InitSHSkinImagePatch()
            local ok, ImageSwitcher = pcall(require, "client.slua.umg.NewSetting.Item.Setting_Option_ImageSwitcher")
            if not ok or type(ImageSwitcher) ~= "table" then return false end
            local impl = rawget(ImageSwitcher, "__inner_impl") or ImageSwitcher
            if type(impl) ~= "table" then return false end
            if impl.__SH_SkinTextFix then return true end
            local origSetup = impl.SetupOptionItemWidget
            if type(origSetup) ~= "function" then return false end
            local setOk = pcall(rawset, impl, "SetupOptionItemWidget", function(self, ...)
                pcall(origSetup, self, ...)
                pcall(function()
                    local D = self and self.Data
                    if type(D) ~= "table" then return end
                    local sel = self.UIRoot and self.UIRoot.Selector
                    if not sel or type(sel.GetChildAt) ~= "function" then return end
                    local st = D.SwitcherText
                    if type(st) ~= "table" then return end
                    local si = D.SwitcherImage
                    local ids = D._SH_ItemIds
                    local ui_util = nil
                    pcall(function() ui_util = require("client.common.ui_util") end)
                    local LU = _G.LocUtil
                    for idx = 0, #st - 1 do
                        local child = sel:GetChildAt(idx)
                        if slua.isValid(child) then
                            if child.Text then
                                local t = st[idx + 1]
                                if type(t) == "number" then
                                    local s = nil
                                    pcall(function()
                                        if LU and LU.GetLocalizeResStr then s = LU.GetLocalizeResStr(t) end
                                    end)
                                    if type(s) == "string" and s ~= "" then t = s else t = tostring(t) end
                                end
                                if t == nil then t = "" end
                                pcall(child.Text.SetText, child.Text, tostring(t))
                            end
                            if child.Image_Content and type(ids) == "table"
                                and tonumber(ids[idx + 1]) and tonumber(ids[idx + 1]) > 0 then
                                pcall(function()
                                    local iid = math.floor(tonumber(ids[idx + 1]))
                                    if ui_util and ui_util.GetItemSmallIcon then
                                        -- live widget do: missing pak auto-stream + auto brush
                                        local path = ui_util.GetItemSmallIcon(iid, child.Image_Content)
                                        if type(path) == "string" and path ~= ""
                                            and child.Image_Content.SetBrushFromPathAsync then
                                            child.Image_Content:SetBrushFromPathAsync(path, false)
                                        end
                                    elseif type(si) == "table" and si[idx + 1]
                                        and child.Image_Content.SetBrushFromPathAsync then
                                        child.Image_Content:SetBrushFromPathAsync(si[idx + 1], false)
                                    end
                                end)
                            end
                        end
                    end
                end)
            end)
            if setOk then
                pcall(rawset, impl, "__SH_SkinTextFix", true)
                return true
            end
            return false
        end

        _G._SH_SkinPatchTries = _G._SH_SkinPatchTries or 0
        local function TrySHSkinPatch()
            if (_G._SH_SkinPatchTries or 0) > 6 then return end
            _G._SH_SkinPatchTries = (_G._SH_SkinPatchTries or 0) + 1
            local ok, done = pcall(InitSHSkinImagePatch)
            if not (ok and done) then
                pcall(function()
                    local tt = require("common.time_ticker")
                    if tt and tt.AddTimerOnce then tt.AddTimerOnce(1.0, TrySHSkinPatch) end
                end)
            end
        end

        -- FLOATING MENU mirror: har menu item auto-register (koi duplication nahi)
        _G._FM_ITEMS = {}
        local _origMSW, _origMSL, _origMBSW = MakeSwitcher, MakeSlider, MakeBoneSwitcher
        MakeSwitcher = function(key, textId, getCb, setCb)
            local _ocb = setCb
            setCb = function(...) _ocb(...) end
            local it = _origMSW(key, textId, getCb, setCb)
            pcall(function() table.insert(_G._FM_ITEMS, {kind = "switch", key = key, textId = textId, get = getCb, set = setCb}) end)
            return it
        end
        MakeSlider = function(key, textId, minVal, maxVal, getCb, setCb)
            local _ocb2 = setCb
            setCb = function(...) _ocb2(...) end
            local it = _origMSL(key, textId, minVal, maxVal, getCb, setCb)
            pcall(function() table.insert(_G._FM_ITEMS, {kind = "slider", key = key, textId = textId, minV = minVal, maxV = maxVal, get = getCb, set = setCb}) end)
            return it
        end
        MakeBoneSwitcher = function(key, textId, getCb, setCb)
            local _ocb3 = setCb
            setCb = function(...) _ocb3(...) end
            local it = _origMBSW(key, textId, getCb, setCb)
            pcall(function() table.insert(_G._FM_ITEMS, {kind = "bone", key = key, textId = textId, get = getCb, set = setCb}) end)
            return it
        end
        local function MakeStack(sections)
        local stack = {}
        for secIdx, sec in ipairs(sections) do
            if secIdx > 1 and SpacerUI then
            stack[#stack + 1] = {
                Key  = "MyTab_spacer_" .. tostring(#stack),
                UI   = SpacerUI,
            }
            end
            if TitleUI and sec.title then
            stack[#stack + 1] = {
                Key  = "MyTab_title_" .. tostring(secIdx),
                UI   = TitleUI,
                Text = sec.title,
            }
            end
            for _, item in ipairs(sec.items or {}) do
            stack[#stack + 1] = item
            end
        end
        return stack
        end

        local tab1Section1 = {
        MakeSwitcher("aim_enable", LOC.BTN_AIMBOT_ENABLE, 
            function() return (_G.AimbotConfig and _G.AimbotConfig.Enable) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.Enable = (idx == 1) end end
        ),

        }

        local tab1Section2 = {
        MakeSlider("aim_fov", LOC.BTN_AIMBOT_FOV, 1, 300,
            function() return _G.AimbotConfig and _G.AimbotConfig.FOV or 30 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.FOV = val end end
        ),
        MakeSlider("aim_dist", LOC.BTN_AIMBOT_DIST, 1, 1000,
            function() return _G.AimbotConfig and _G.AimbotConfig.Distance or 250 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Distance = val end end
        ),
        MakeSlider("aim_speed", LOC.BTN_AIMBOT_SPEED, 1, 100,
            function() return _G.AimbotConfig and _G.AimbotConfig.Speed or 50 end,
            function(val) if _G.AimbotConfig then _G.AimbotConfig.Speed = val end end
        ),
        MakeSwitcher("aim_knock", LOC.BTN_AIMBOT_KNOCK,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreKnock) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreKnock = (idx == 1) end end
        ),
        MakeSwitcher("aim_bot", LOC.BTN_AIMBOT_BOT,
            function() return (_G.AimbotConfig and _G.AimbotConfig.IgnoreBot) and 1 or 2 end,
            function(idx) if _G.AimbotConfig then _G.AimbotConfig.IgnoreBot = (idx == 1) end end
        ),
        MakeSwitcher("no_recoil", "No Recoil (Shake ON)",
            function() return (_G.LexusConfig and _G.LexusConfig.NoRecoilEnabled) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.NoRecoilEnabled = (idx == 1)
                if _G.ApplyNoRecoil then pcall(_G.ApplyNoRecoil) end
            end
        ),




        -- LOCKED OFF: Long Range Recoil slider hataya (hamesha 0, upar force-locked)
        MakeBoneSwitcher("aim_bone", LOC.BTN_AIMBOT_BONE,
            function()
                local bone = _G.AimbotConfig and _G.AimbotConfig.Bone or "spine_03"
                if bone == "head" then return 1
                elseif bone == "pelvis" then return 3
                else return 2 end
            end,
            function(idx)
                if _G.AimbotConfig then
                    if idx == 1 then _G.AimbotConfig.Bone = "head"
                    elseif idx == 3 then _G.AimbotConfig.Bone = "pelvis"
                    else _G.AimbotConfig.Bone = "spine_03" end
                end
            end
        ),
        }

        local tab2Section1 = {
        MakeSwitcher("mem_grass", LOC.BTN_MEM_GRASS,
            function() return (_G.MemoryConfig.RemoveGrass and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveGrass = (idx == 1) 
                ApplyMemoryFeature("Grass", _G.MemoryConfig.RemoveGrass)
            end
        ),
        MakeSwitcher("mem_trees", LOC.BTN_MEM_TREES,
            function() return (_G.MemoryConfig.RemoveTrees and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveTrees = (idx == 1) 
                ApplyMemoryFeature("Trees", _G.MemoryConfig.RemoveTrees)
            end
        ),
        MakeSwitcher("mem_fog", LOC.BTN_MEM_FOG,
            function() return (_G.MemoryConfig.RemoveFog and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.RemoveFog = (idx == 1) 
                ApplyMemoryFeature("Fog", _G.MemoryConfig.RemoveFog)
            end
        ),
        MakeSwitcher("mem_blacksky", LOC.BTN_MEM_BLACKSKY,
            function() return (_G.MemoryConfig.BlackSky and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.BlackSky = (idx == 1) 
                ApplyMemoryFeature("BlackSky", _G.MemoryConfig.BlackSky)
            end
        ),
        MakeSwitcher("mem_fps", LOC.BTN_MEM_FPS,
            function() return (_G.MemoryConfig.UnlockFPS and 1 or 2) end,
            function(idx) 
                _G.MemoryConfig.UnlockFPS = (idx == 1) 
                ApplyMemoryFeature("FPS", _G.MemoryConfig.UnlockFPS)
            end
        ),
        MakeSwitcher("mem_crosshair", LOC.BTN_MEM_CROSSHAIR,
            function() return (_G.MemoryConfig.SmallCrosshair and 1 or 2) end,
            function(idx) _G.MemoryConfig.SmallCrosshair = (idx == 1) end
        ),
        MakeSwitcher("mem_ipad", LOC.BTN_MEM_IPAD,
            function() return (_G.MemoryConfig.IpadView and 1 or 2) end,
            function(idx) _G.MemoryConfig.IpadView = (idx == 1) end
        ),
        MakeSlider("mem_ipad_fov", LOC.BTN_MEM_IPAD_FOV, 60, 160,
            function() return _G.MemoryConfig.IpadFOV or 120 end,
            function(val) _G.MemoryConfig.IpadFOV = val end
        ),
        MakeSwitcher("mem_smallscope", LOC.BTN_MEM_SMALLSCOPE,
            function() return (_G.MemoryConfig and _G.MemoryConfig.SmallScope) and 1 or 2 end,
            function(idx) if not _G.MemoryConfig then _G.MemoryConfig = {} end _G.MemoryConfig.SmallScope = (idx == 1) end
        ),
        MakeSlider("mem_smallscope_fov", LOC.BTN_MEM_SMALLSCOPE_FOV, 1, 120,
            function() return (_G.MemoryConfig and _G.MemoryConfig.SmallScopeFOV) or 75 end,
            function(val) if not _G.MemoryConfig then _G.MemoryConfig = {} end _G.MemoryConfig.SmallScopeFOV = val end
        ),

        }

        local tabEspSection = {

        MakeSwitcher("blue_frame", LOC.BTN_BLUE_FRAME,
            function() return (_G.BlueFrameConfig and _G.BlueFrameConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.BlueFrameConfig then _G.BlueFrameConfig = {} end
                _G.BlueFrameConfig.Enable = (idx == 1)
                if idx == 1 then _G.BlueFrameStart() else _G.BlueFrameStop() end
            end
        ),


        MakeSwitcher("espv3_master", "ESP V3 Master",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Master) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Master = (idx == 1)
                if idx == 1 and _G.StartESPV3 then pcall(_G.StartESPV3) end
            end
        ),
        MakeSwitcher("espv3_count", "ESP V3 Player/Bot Counter",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Count ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Count = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_box", "ESP V3 Box",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Box ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Box = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_line", "ESP V3 Snapline",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Line ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Line = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_health", "ESP V3 Health Bar",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Health ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Health = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_name", "ESP V3 Player Name",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Name ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Name = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_dist", "ESP V3 Distance",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Dist ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Dist = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_weapon", "ESP V3 Weapon",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Weapon ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Weapon = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_flag", "ESP V3 Country Flag",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_Flag ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_Flag = (idx == 1)
            end
        ),
        MakeSwitcher("espv3_state", "ESP V3 Player State",
            function() return (_G.LexusConfig and _G.LexusConfig.EspV3_State ~= false) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.EspV3_State = (idx == 1)
            end
        ),


        MakeSwitcher("fake_hwid", LOC.BTN_FAKE_HWID,
            function() return (_G.BRFakeHWID and _G.BRFakeHWID.Enable) and 1 or 2 end,
            function(idx)
                _G.BRFakeHWID.Enable = (idx == 1)
                if _G.BRFakeHWID.Enable then
                    _G.FakeHWID_String = nil
                end
                BRFakeHWID_Notify("Fake HWID " .. (_G.BRFakeHWID.Enable and "ON" or "OFF"))
            end
        )
        }

        local tabChamsSection = {
        MakeSwitcher("chams_enable", LOC.BTN_CHAMS_ENABLE,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.Enable) and 1 or 2 end,
            function(idx)
                _G.BRChamsConfig.Enable = (idx == 1)
                if idx == 1 then _G.BRStartChams() else _G.BRStopChams() end
            end
        ),
        MakeSlider("chams_vis", LOC.BTN_CHAMS_VIS, 1, 6,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.VisColor) or 3 end,
            function(val) if _G.BRChamsConfig then _G.BRChamsConfig.VisColor = math.floor(val) end end
        ),
        MakeSlider("chams_occ", LOC.BTN_CHAMS_OCC, 1, 6,
            function() return (_G.BRChamsConfig and _G.BRChamsConfig.OccColor) or 1 end,
            function(val) if _G.BRChamsConfig then _G.BRChamsConfig.OccColor = math.floor(val) end end
        ),
        MakeSwitcher("new_wallhack", LOC.BTN_NEW_WALLHACK,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable) and 1 or 2 end,
            function(idx)
                if not _G.PBCWallhackConfig then _G.PBCWallhackConfig = {} end
                _G.PBCWallhackConfig.Enable = (idx == 1)
                if idx == 1 then _G.PBCStartWallhack() else _G.PBCStopWallhack() end
            end
        ),
        MakeSlider("new_wh_vis", LOC.BTN_NEW_WH_VIS, 1, 7,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.VisColor) or 1 end,
            function(val) if _G.PBCWallhackConfig then _G.PBCWallhackConfig.VisColor = math.floor(val) end end
        ),
        MakeSlider("new_wh_occ", LOC.BTN_NEW_WH_OCC, 1, 7,
            function() return (_G.PBCWallhackConfig and _G.PBCWallhackConfig.OccColor) or 4 end,
            function(val) if _G.PBCWallhackConfig then _G.PBCWallhackConfig.OccColor = math.floor(val) end end
        ),

        }

        -- BAN TAB REMOVED: force_tpp / magic_bullet / auto_report pura hataya (ban risk)
        local tabBanSection = {
        }
        -- Force OFF + running loops roko (menu hata diya to dobara ON ho hi nahi sakta)
        pcall(function()
            _G.ForceTPP_Enable = false
            if _G.HRD_StopForceTPP then _G.HRD_StopForceTPP() end
            if _G.MagicBulletConfig then _G.MagicBulletConfig.Enable = false end
            if _G.StopMagicBullet then _G.StopMagicBullet() end
            if _G.AutoReportConfig then
                _G.AutoReportConfig.Enable = false
                _G.AutoReportConfig.AutoScreenshot = false
            end
        end)

        -- IMAGE-GRID SKIN LISTS (slider hatao, Close+icon+naam rows)
        local function skinHead(key, text)
            return { Key = "MyTab_" .. key, UI = TitleUI, Text = text }
        end

        -- CLEAR-ALL button-row: hamesha OFF dikhta hai, ON dabate hi tab reset
        local function skinClearRow(key, label, clearFn)
            return MakeSwitcher(key, label,
                function() return 2 end,
                function(idx)
                    if idx == 1 then
                        pcall(clearFn)
                        _G.LexusState.DirtyConfig = true
                        pcall(function() if _G.ForceRefreshSkinMaps then _G.ForceRefreshSkinMaps() end end)
                    end
                end)
        end

        local tabSkinOutfit = {
        skinHead("h_skinmaster", "SKIN CONTROL"),
        MakeSwitcher("skin_mod", "MOD SKIN ON/OFF",
            function() return (_G.LexusConfig and _G.LexusConfig.ModSkin) and 1 or 2 end,
            function(idx)
                if not _G.LexusConfig then _G.LexusConfig = {} end
                _G.LexusConfig.ModSkin = (idx == 1)
                if _G.BRStartSkinLoop then _G.BRStartSkinLoop() end
            end
        ),
        skinHead("h_outfit", "Outfit Sets (One per row, auto-applies)"),
        outfitRow("skin_outfit_g1", "Outfit Sets-Group1", {1, 2, 3, 4}),
        outfitRow("skin_outfit_g2", "Outfit Sets-Group2", {5, 6, 7, 8}),
        outfitRow("skin_outfit_g3", "Outfit Sets-Group3", {9, 10, 11, 12}),
        outfitRow("skin_outfit_g4", "Outfit Sets-Group4", {13, 14, 15, 16}),
        outfitRow("skin_outfit_g5", "Outfit Sets-Group5", {17, 18, 19, 20}),
        skinClearRow("skin_clear_outfit", "CLEAR OUTFIT - Tap ON",
            function()
                _G.OutfitMap = _G.OutfitMap or {}
                _G.OutfitMap.Suit = nil
                _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                _G.LexusState.CustomTextData.SkinSuit = 0
            end),
        }

        local _GUN_DEFS = {
            {"m416", "M416", 101004, "SkinM416"}, {"akm", "AKM", 101001, "SkinAKM"},
            {"scar", "SCAR-L", 101003, "SkinSCAR"}, {"m762", "M762", 101008, "SkinM762"},
            {"aug", "AUG", 101006, "SkinAUG"}, {"ump", "UMP", 102002, "SkinUMP"},
            {"uzi", "UZI", 102001, "SkinUZI"}, {"groza", "Groza", 101005, "SkinGroza"},
            {"s12k", "S12K", 104003, "SkinS12K"}, {"dbs", "DBS", 104004, "SkinDBS"},
            {"asm", "ASM Gen8", 101101, "SkinASM"}, {"qbz", "QBZ", 101007, "SkinQBZ"},
            {"honey", "Honey Badger", 101012, "SkinHoney"}, {"m16a4", "M16A4", 101002, "SkinM16A4"},
            {"ace32", "ACE32", 101102, "SkinACE32"}, {"kar98k", "Kar98k", 103001, "SkinKar98k"},
            {"m24", "M24", 103002, "SkinM24"}, {"awm", "AWM", 103003, "SkinAWM"},
        }
        local tabSkinGuns = {
        skinHead("h_guns", "Gun Skins (Tap to apply, Close = stock)"),
        }
        pcall(function()
            for _, gd in ipairs(_GUN_DEFS) do
                local key, label, gunId, field = gd[1], gd[2], gd[3], gd[4]
                local list = (_G.skinIdMappings and _G.skinIdMappings[gunId]) or {}
                if #list > 1 then
                    local skinsOnly = {}
                    for i = 2, #list do skinsOnly[#skinsOnly + 1] = i end
                    local row = 0
                    for i = 1, #skinsOnly, 4 do
                        row = row + 1
                        local idxs = {}
                        for k = i, math.min(i + 3, #skinsOnly) do idxs[#idxs + 1] = skinsOnly[k] end
                        local rlabel = label
                        if #skinsOnly > 4 then
                            rlabel = label .. " " .. tostring(i) .. "-" .. tostring(math.min(i + 3, #skinsOnly))
                        end
                        tabSkinGuns[#tabSkinGuns + 1] = gunRow("skin_" .. key .. "_r" .. row, rlabel, gunId, field, idxs)
                    end
                end
            end
        end)
        tabSkinGuns[#tabSkinGuns + 1] = skinClearRow("skin_clear_guns", "CLEAR GUNS - Tap ON",
            function()
                _G.WeaponSkinMap = _G.WeaponSkinMap or {}
                _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                if _GUN_DEFS then
                    for _, gd in ipairs(_GUN_DEFS) do
                        _G.WeaponSkinMap[gd[3]] = nil
                        _G.LexusState.CustomTextData[gd[4]] = 0
                    end
                end
            end)

        local tabSkinGear = {
        skinHead("h_gear", "Helmet & Backpack (Tap to apply)"),
        }
        pcall(function()
            local helmets = (_G.OutfitSkins and _G.OutfitSkins.Helmet) or {}
            local hrow = 0
            for i = 1, #helmets, 4 do
                hrow = hrow + 1
                local idxs = {}
                for k = i, math.min(i + 3, #helmets) do idxs[#idxs + 1] = k end
                tabSkinGear[#tabSkinGear + 1] = gearRow("skin_helmet_r" .. hrow,
                    "Helmet " .. tostring(i) .. "-" .. tostring(math.min(i + 3, #helmets)),
                    helmets, "SkinHelmet", "Helmet", idxs)
            end
            local bags = (_G.OutfitSkins and _G.OutfitSkins.Bag) or {}
            local brow = 0
            for i = 1, #bags, 4 do
                brow = brow + 1
                local idxs = {}
                for k = i, math.min(i + 3, #bags) do idxs[#idxs + 1] = k end
                tabSkinGear[#tabSkinGear + 1] = gearRow("skin_bag_r" .. brow,
                    "Backpack " .. tostring(i) .. "-" .. tostring(math.min(i + 3, #bags)),
                    bags, "SkinBag", "Bag", idxs)
            end
        end)
        tabSkinGear[#tabSkinGear + 1] = MakeSwitcher("skin_deadbox", "DeadBox Skin",
            function() return (_G.LexusConfig and _G.LexusConfig.SkinDeadBox) and 1 or 2 end,
            function(idx) if not _G.LexusConfig then _G.LexusConfig = {} end _G.LexusConfig.SkinDeadBox = (idx == 1) end
        )
        tabSkinGear[#tabSkinGear + 1] = MakeSwitcher("skin_attach", "Attachment Skin",
            function() return (_G.LexusConfig and _G.LexusConfig.SkinAttachment) and 1 or 2 end,
            function(idx) if not _G.LexusConfig then _G.LexusConfig = {} end _G.LexusConfig.SkinAttachment = (idx == 1) end
        )
        tabSkinGear[#tabSkinGear + 1] = skinClearRow("skin_clear_gear", "CLEAR GEAR - Tap ON",
            function()
                _G.OutfitMap = _G.OutfitMap or {}
                _G.OutfitMap.Helmet = nil
                _G.OutfitMap.Bag = nil
                _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                _G.LexusState.CustomTextData.SkinHelmet = 0
                _G.LexusState.CustomTextData.SkinBag = 0
            end)

        local _VEH_DEFS = {
            {"dacia", "Dacia", 1903001, "SkinDacia", 12}, {"uaz", "UAZ", 1908001, "SkinUAZ", 12},
            {"coupe", "CoupeRB", 1961001, "SkinCoupe", 12}, {"buggy", "Buggy", 1907002, "SkinBuggy", 11},
            {"mirado", "Mirado", 1915004, "SkinMirado", 5},
        }
        local tabSkinVeh = {
        skinHead("h_veh", "Vehicle Skins (Top skins, Tap to apply)"),
        }
        pcall(function()
            for _, vd in ipairs(_VEH_DEFS) do
                local key, label, vid, field, topN = vd[1], vd[2], vd[3], vd[4], vd[5]
                local list = (_G.VehicleSkins and _G.VehicleSkins[vid]) or {}
                local n = math.min(topN, #list)
                if n > 0 then
                    local row = 0
                    for i = 1, n, 4 do
                        row = row + 1
                        local idxs = {}
                        for k = i, math.min(i + 3, n) do idxs[#idxs + 1] = k end
                        local rlabel = label
                        if n > 4 then
                            rlabel = label .. " " .. tostring(i) .. "-" .. tostring(math.min(i + 3, n))
                        end
                        tabSkinVeh[#tabSkinVeh + 1] = vehRow("skin_" .. key .. "_r" .. row, rlabel, vid, field, idxs)
                    end
                end
            end
        end)
        tabSkinVeh[#tabSkinVeh + 1] = skinClearRow("skin_clear_veh", "CLEAR VEHICLES - Tap ON",
            function()
                _G.VehicleSkinMap = _G.VehicleSkinMap or {}
                _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                if _VEH_DEFS then
                    for _, vd in ipairs(_VEH_DEFS) do
                        _G.VehicleSkinMap[vd[3]] = nil
                        _G.LexusState.CustomTextData[vd[4]] = 0
                    end
                end
            end)

        MY_TAB_DEFINE.Category = {
        {
            Key   = "MyTab_TAB1",
            Text  = LOC.TAB_AIMBOT,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_AIMING,   items = tab1Section1 },
            { title = LOC.TITLE_SETTINGS, items = tab1Section2 },
            }),
        },
        {
            Key   = "MyTab_TAB2",
            Text  = LOC.TAB_MEMORY,
            UIKey = "Setting_Page_Game",
            Stack = MakeStack({
            { title = LOC.TITLE_SETTINGS, items = tab2Section1 },
            { title = LOC.TITLE_ESP,     items = tabEspSection },
            { title = LOC.TITLE_CHAMS,   items = tabChamsSection },
            }),
        },
        }

        -- SKIN page ke 4 sub-tabs (VIP MENU se alag top-level page)
        if not SKIN_TAB_DEFINE.Category then
            SKIN_TAB_DEFINE.Category = {
            {
                Key   = "SkinTab_OUTFIT",
                Text  = LOC.TAB_OUTFIT,
                UIKey = "Setting_Page_Game",
                Stack = MakeStack({
                { items = tabSkinOutfit },
                }),
            },
            {
                Key   = "SkinTab_GUNS",
                Text  = LOC.TAB_GUNS,
                UIKey = "Setting_Page_Game",
                Stack = MakeStack({
                { items = tabSkinGuns },
                }),
            },
            {
                Key   = "SkinTab_GEAR",
                Text  = LOC.TAB_GEAR,
                UIKey = "Setting_Page_Game",
                Stack = MakeStack({
                { items = tabSkinGear },
                }),
            },
            {
                Key   = "SkinTab_VEH",
                Text  = LOC.TAB_VEH,
                UIKey = "Setting_Page_Game",
                Stack = MakeStack({
                { items = tabSkinVeh },
                }),
            },
            }
        end

        LOG("GetMyTabDefine: built successfully.")
        return MY_TAB_DEFINE
    end

    local function GetSkinTabDefine()
        GetMyTabDefine()
        return SKIN_TAB_DEFINE
    end

    local function HasMyTab(catalog)
        if type(catalog) ~= "table" then return false end
        local hasMy, hasSkin = false, false
        for _, item in ipairs(catalog) do
        if type(item) == "table" and item.Key == "MyTab" then hasMy = true end
        if type(item) == "table" and item.Key == "SkinTab" then hasSkin = true end
        end
        return hasMy and hasSkin
    end

    local function InjectMyTab(catalog)
        if type(catalog) ~= "table" then return end
        if HasMyTab(catalog) then return end
        GetMyTabDefine()
        GetSkinTabDefine()
        table.insert(catalog, 1, MY_TAB_DEFINE)
        table.insert(catalog, 2, SKIN_TAB_DEFINE)
        LOG("InjectMyTab: inserted VIP MENU at 1 + SKIN at 2")
    end

    if type(UIManager) == "table" and type(UIManager.ShowUI) == "function" then
        if UIManager.__mytab_ShowUI then
        UIManager.ShowUI = UIManager.__mytab_ShowUI
        UIManager.__mytab_ShowUI = nil
        end
        UIManager.__mytab_ShowUI = UIManager.ShowUI
        
        UIManager.ShowUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local catArg = select(args_start + 1, ...)
            if type(catArg) == "table" then InjectMyTab(catArg) end
        end
        return UIManager.__mytab_ShowUI(...)
        end
        LOG("UIManager.ShowUI hooked")
    end

    local SettingMainPath = "client.slua.umg.NewSetting.Main.setting_main_base"
    local okSM, SettingMain = pcall(require, SettingMainPath)
    if okSM and SettingMain then
        if SettingMain.__mytab_OnSelectTab_Page then
        SettingMain.OnSelectTab_Page = SettingMain.__mytab_OnSelectTab_Page
        SettingMain.__mytab_OnSelectTab_Page = nil
        end
        SettingMain.__mytab_OnSelectTab_Page = SettingMain.OnSelectTab_Page
        SettingMain.OnSelectTab_Page = function(self, ItemIndex)
        local pageData = self.AvailablePageList and self.AvailablePageList[ItemIndex]
        if pageData and (pageData.Key == "MyTab" or pageData.Key == "SkinTab") then
            if self._PageUI then
            pcall(function() self._PageUI:CloseSelf() end)
            self._PageUI = nil
            end
            if self._CategoryUI then
            pcall(function() self._CategoryUI:CloseSelf() end)
            self._CategoryUI = nil
            end

            local def = GetMyTabDefine()
            if pageData.Key == "SkinTab" then def = GetSkinTabDefine() end
            if not def.Category then return end

            self._CurrentPage = pageData
            self._AvailableCategoryList = def.Category

            -- Try to ensure enough tab buttons exist
            pcall(function()
                local catCount = #def.Category
                self.UIRoot.HorizontalSelector_Category:SetNum(catCount)
            end)
            for i, catData in ipairs(def.Category) do
            pcall(function()
                local Child = self.UIRoot.HorizontalSelector_Category:GetChildAt(i - 1)
                if Child and slua.isValid(Child) and Child.TextBlock_Name then
                    Child.TextBlock_Name:SetText(ResolveLoc(catData.Text) or tostring(catData.Text))
                end
            end)
            end

            self:SetWidgetVisible(self.UIRoot.Border_Header, true)
            pcall(function()
            self:PlayUserWidgetAnimation(self.UIRoot.Fadein_Page, 0, 1, 0, 1)
            end)

            self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(-1)
            self.UIRoot.HorizontalSelector_Category:SetSelectedIndex(1)
            return true
        end
        return SettingMain.__mytab_OnSelectTab_Page(self, ItemIndex)
        end
        LOG("OnSelectTab_Page hooked")

        if SettingMain.__mytab_OnSelectTab_Category then
        SettingMain.OnSelectTab_Category = SettingMain.__mytab_OnSelectTab_Category
        SettingMain.__mytab_OnSelectTab_Category = nil
        end
        SettingMain.__mytab_OnSelectTab_Category = SettingMain.OnSelectTab_Category
        SettingMain.OnSelectTab_Category = function(self, ItemIndex)
        local curPage = self._CurrentPage
        if curPage and (curPage.Key == "MyTab" or curPage.Key == "SkinTab") then
            local lastIndex = self.UIRoot.HorizontalSelector_Category:GetSelectedIndex()
            if lastIndex > 0 and self._CategoryUI then
            pcall(function() self._CategoryUI:CloseSelf() end)
            self._CategoryUI = nil
            end

            local catData = self._AvailableCategoryList and self._AvailableCategoryList[ItemIndex]
            if catData then
            if catData.UIKey and catData.Stack then
                self._CategoryUI = self:CreateChildWindow(
                self.UIRoot.StackRoot,
                UIManager.UI_Config[catData.UIKey],
                catData.Stack
                )
            elseif catData.Stack then
                self._CategoryUI = self:CreateChildWindow(
                self.UIRoot.StackRoot,
                UIManager.UI_Config.Setting_StackContainer,
                catData.Stack
                )
            end
            end

            pcall(function()
            self:PlayUserWidgetAnimation(self.UIRoot.Fadein_Category, 0, 1, 0, 1)
            end)
            return true
        end
        return SettingMain.__mytab_OnSelectTab_Category(self, ItemIndex)
        end
        LOG("OnSelectTab_Category hooked")
    end

    if type(UIManager) == "table" and type(UIManager.HideUI) == "function" then
        if UIManager.__mytab_HideUI then
        UIManager.HideUI = UIManager.__mytab_HideUI
        UIManager.__mytab_HideUI = nil
        end
        UIManager.__mytab_HideUI = UIManager.HideUI
        UIManager.HideUI = function(...)
        local uiKey = select(1, ...)
        local arg1 = uiKey
        local args_start = 1
        if type(arg1) == "table" and arg1 == UIManager then
            uiKey = select(2, ...)
            args_start = 2
        end
        
        local cfg = UIManager.UI_Config
        if cfg and uiKey == cfg.setting_main then
            local ui = UIManager.GetUI and UIManager.GetUI(cfg.setting_main)
            if ui then ui.__mytabInstalled = nil end
        end
        return UIManager.__mytab_HideUI(...)
        end
    end

    LOG("Sh Menu v" .. MY_TAB_VER .. " globally installed.")
    end

    -- ============================================================
    -- LIGHT REATTACH (har match me full re-exec KI JAGAH yahi chalega)
    -- Poora 9000-line chunk dobara compile/execute NAHI hota = no stuck.
    -- Sirf dead timers naye PC par lagte hain + canvas refresh. ~10x halka.
    -- NOTE: lua update ho to game restart chahiye (pehle se aisa hi tha).
    -- ============================================================
    _G.SH_Reattach = function()
        if _G._LICENSE_OK ~= true then return end
        -- ESP V3 + aimbot timers: naya match/character to dead handle hatao, phir start
        _G._espV3Timer = nil
        _G._aimbotTimer = nil
        pcall(function() if _G.StartESPV3 then _G.StartESPV3() end end)
        pcall(function() if _G.StartAimbotLoop then _G.StartAimbotLoop() end end)



        pcall(function()
            if _G.BRChamsConfig and _G.BRChamsConfig.Enable and _G.BRStartChams then
                if _G.BRStopChams then _G.BRStopChams() end
                _G._chamsTimer = nil
                _G.BRStartChams()
            end
        end)
        pcall(function()
            if _G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable and _G.PBCStartWallhack then
                if _G.PBCStopWallhack then _G.PBCStopWallhack() end
                _G.PBCStartWallhack()
            end
        end)
        pcall(function()
            if _G.BlueFrameConfig and _G.BlueFrameConfig.Enable and _G.BlueFrameStart then
                if _G.BlueFrameStop then _G.BlueFrameStop() end
                _G.BlueFrameStart()
            end
        end)
        pcall(function()
            if _G.CarFlyConfig and _G.CarFlyConfig.Enable and _G.CarFlyConfig.Start then
                if _G.CarFlyConfig.Stop then _G.CarFlyConfig.Stop() end
                _G.CarFlyConfig.Start()
            end
        end)
        pcall(function()
            if _G.FastCarEnabled and _G.StartFastCar then
                if _G.StopFastCar then _G.StopFastCar() end
                _G.StartFastCar()
            end
        end)
        pcall(function()
            if _G.MagicBulletConfig and _G.MagicBulletConfig.Enable and _G.StartMagicBullet then
                if _G.StopMagicBullet then _G.StopMagicBullet() end
                _G.StartMagicBullet()
            end
        end)
        pcall(function()
            if _G.BatPowerConfig and _G.BatPowerConfig.Enable and _G.ReapplyBatPower then
                _G.ReapplyBatPower()
            end
        end)
        pcall(function()
            if _G.RefreshAllMemoryFeatures then _G.RefreshAllMemoryFeatures() end
        end)
    end

    -- Auto-restart features that were enabled in previous match
    -- (timers die when old PlayerController is destroyed between matches)
    -- Must be OUTSIDE __MyTabInstalled block so it runs every script load
    pcall(function()
        if _G.BRChamsConfig and _G.BRChamsConfig.Enable then
            _G._chamsTimer = nil  -- Force clear dead timer reference
            if _G.BRStopChams then _G.BRStopChams() end
            _G.BRStartChams()
        end
    end)
    pcall(function()
        if _G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable then
            if _G.PBCStopWallhack then _G.PBCStopWallhack() end
            _G.PBCStartWallhack()
        end
    end)
    pcall(function()
        if _G.BlueFrameConfig and _G.BlueFrameConfig.Enable then
            if _G.BlueFrameStop then _G.BlueFrameStop() end
            _G.BlueFrameStart()
        end
    end)
    pcall(function()
        if _G.CarFlyConfig and _G.CarFlyConfig.Enable then
            if _G.CarFlyConfig.Stop then _G.CarFlyConfig.Stop() end
            _G.CarFlyConfig.Start()
        end
    end)
    pcall(function()
        if _G.FastCarEnabled then
            if _G.StopFastCar then _G.StopFastCar() end
            _G.StartFastCar()
        end
    end)
    pcall(function()
        if _G.MagicBulletConfig and _G.MagicBulletConfig.Enable then
            if _G.StopMagicBullet then _G.StopMagicBullet() end
            _G.MagicBulletConfig.Enable = true
            if _G.StartMagicBullet then _G.StartMagicBullet() end
        end
    end)
    pcall(function()
        if _G.BatPowerConfig and _G.BatPowerConfig.Enable then
            if _G.ReapplyBatPower then _G.ReapplyBatPower() end
        end
    end)
    pcall(function()
        if _G.RefreshAllMemoryFeatures then
            _G.RefreshAllMemoryFeatures()
        end
    end)

    -- ============================================================
    -- LIBANOGS BAN HOOK - Anti-Detection bypass
    -- ============================================================
    do
        local _libanogs_OrigBan = nil
        local function InitBanHook()
            pcall(function()
                local KSL = import("KismetSystemLibrary")
                if not KSL then return end
                local world = slua.getWorld()
                if not world then return end

                KSL.ExecuteConsoleCommand(world, "LoadLibrary libanogs.so")

                local libanogs = nil
                pcall(function() libanogs = slua.loadLibrary("libanogs.so") end)
                if not libanogs then
                    pcall(function() libanogs = import("libanogs.so") end)
                end

                if not libanogs then
                    LOG("[BanHook] libanogs.so not available, trying string scan")
                end

                _G._BanHookActive = true
                _G._OrigBanString = nil

                local function CheckBanString(s)
                    if type(s) ~= "string" then return s end
                    if string.find(s, "Anti%-Detection") or string.find(s, "10 Years") then
                        LOG("[BanHook] Ban string detected: " .. string.sub(s, 1, 50))
                        local safeStr = "Data/file/%%"
                        _G._OrigBanString = s
                        return safeStr
                    end
                    return s
                end
                _G.CheckBanString = CheckBanString

                if libanogs then
                    local banFuncNames = {"Ban", "BanPlayer", "BanUser", "ReportBan"}
                    for _, fname in ipairs(banFuncNames) do
                        if libanogs[fname] and type(libanogs[fname]) == "function" then
                            local orig = libanogs[fname]
                            libanogs[fname] = function(...)
                                local args = {...}
                                for i, arg in ipairs(args) do
                                    if type(arg) == "string" then
                                        args[i] = CheckBanString(arg)
                                    end
                                end
                                return orig(table.unpack(args))
                            end
                            LOG("[BanHook] Hooked " .. fname .. " in libanogs.so")
                        end
                    end
                end

                if KSL.GetDeviceId then
                    local origDeviceId = KSL.GetDeviceId
                    KSL.GetDeviceId = function(...)
                        local result = origDeviceId(...)
                        if _G.BRFakeHWID and _G.BRFakeHWID.Enable then
                            if not _G.FakeHWID_String then
                                local chars = "0123456789ABCDEF"
                                local hwid = ""
                                for i = 1, 32 do
                                    local idx = math.random(1, #chars)
                                    hwid = hwid .. chars:sub(idx, idx)
                                    if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                                end
                                _G.FakeHWID_String = hwid
                            end
                            return _G.FakeHWID_String
                        end
                        return result
                    end
                    LOG("[BanHook] DeviceId hook active")
                end

                if KSL.GetDeviceIdOS then
                    local origDeviceIdOS = KSL.GetDeviceIdOS
                    KSL.GetDeviceIdOS = function(...)
                        local result = origDeviceIdOS(...)
                        if _G.BRFakeHWID and _G.BRFakeHWID.Enable then
                            if not _G.FakeHWID_String then
                                local chars = "0123456789ABCDEF"
                                local hwid = ""
                                for i = 1, 32 do
                                    local idx = math.random(1, #chars)
                                    hwid = hwid .. chars:sub(idx, idx)
                                    if i == 8 or i == 12 or i == 16 or i == 20 then hwid = hwid .. "-" end
                                end
                                _G.FakeHWID_String = hwid
                            end
                            return _G.FakeHWID_String
                        end
                        return result
                    end
                    LOG("[BanHook] DeviceIdOS hook active")
                end

                LOG("[BanHook] Anti-Detection bypass active")
            end)
        end

        -- SLIM BYPASS: libanogs hook disabled (ACE lib tampering = instant flag)
        _G._BanHookActive = false
    end

    -- ============================================================
    -- FLOATING MOD MENU (screen overlay: icon + ON/OFF + hide)
    -- Menu makers se auto-mirror hota hai (_G._FM_ITEMS).
    -- ============================================================
    _G._FM_OPEN = _G._FM_OPEN or false
    _G._FM_CAT = _G._FM_CAT or "AIM"

    local function _FM_BindClick(b, fn)
        if not (b and slua.isValid(b)) then return end
        pcall(function() if b.OnClicked and b.OnClicked.Add then b.OnClicked:Add(function() fn() end) end end)
        pcall(function() if b.OnClicked and b.OnClicked.Add then b.OnClicked:Add(b, function() fn() end) end end)
        pcall(function() if slua.addDelegate then slua.addDelegate(b.OnClicked, function() fn() end) end end)
    end

    local function _FM_Text(root, txt, size, color, x, y, z)
        local w = nil
        pcall(function() w = CGame:NewObjectFromPath("/Script/UMG.TextBlock", root) end)
        if not (w and slua.isValid(w)) then return nil end
        pcall(function()
            w:SetText(tostring(txt))
            local FLinearColor = import("LinearColor")
            local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
            if FSlateColor then w:SetColorAndOpacity(FSlateColor(color)) else w:SetColorAndOpacity(color) end
            if w.Font then local f = w.Font f.Size = size w.Font = f end
            w:SetWidgetVisibility(UEnums.ESlateVisibility.HitTestInvisible)
        end)
        pcall(function()
            local FVector2D = import("Vector2D")
            local s = root:AddChildToCanvas(w)
            if s then s:SetAutoSize(true) s:SetAlignment(FVector2D(0.5, 0.5)) s:SetPosition(FVector2D(x, y)) s:SetZOrder(z or 10002) end
        end)
        return w
    end

    local function _FM_Border(root, color, x, y, w, h, z)
        local b = nil
        pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Border", root) end)
        if not (b and slua.isValid(b)) then return nil end
        pcall(function()
            b:SetBrushColor(color)
            b:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        pcall(function()
            local FVector2D = import("Vector2D")
            local s = root:AddChildToCanvas(b)
            if s then s:SetAlignment(FVector2D(0.5, 0.5)) s:SetPosition(FVector2D(x, y)) s:SetSize(FVector2D(w, h)) s:SetZOrder(z or 10001) end
        end)
        return b
    end

    local function _FM_Button(root, label, size, color, x, y, w, h, fn)
        local b = nil
        pcall(function() b = CGame:NewObjectFromPath("/Script/UMG.Button", root) end)
        if not (b and slua.isValid(b)) then return nil end
        pcall(function()
            local FVector2D = import("Vector2D")
            local bs = root:AddChildToCanvas(b)
            if bs then bs:SetAlignment(FVector2D(0.5, 0.5)) bs:SetPosition(FVector2D(x, y)) bs:SetSize(FVector2D(w, h)) bs:SetZOrder(10003) end
        end)
        pcall(function()
            local l = CGame:NewObjectFromPath("/Script/UMG.TextBlock", b)
            if l and slua.isValid(l) then
                l:SetText(tostring(label))
                local FLinearColor = import("LinearColor")
                local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
                local lc = FLinearColor(color[1], color[2], color[3], 1)
                if FSlateColor then l:SetColorAndOpacity(FSlateColor(lc)) else l:SetColorAndOpacity(lc) end
                if l.Font then local f2 = l.Font f2.Size = size l.Font = f2 end
                l:SetWidgetVisibility(UEnums.ESlateVisibility.HitTestInvisible)
                if b.AddChild then b:AddChild(l) end
            end
        end)
        _FM_BindClick(b, fn)
        return b
    end

    local function _FM_CatOf(key)
        key = tostring(key or "")
        if key:sub(1, 4) == "aim_" then return "AIM" end
        if key:sub(1, 4) == "mem_" then return "MEM" end
        if key:sub(1, 4) == "esp_" or key:sub(1, 6) == "chams_" or key:sub(1, 7) == "new_wh_" or key == "blue_frame" or key == "fake_hwid" then return "ESP" end
        if key:sub(1, 5) == "skin_" then return "SKIN" end
        return "BAN"
    end

    local function _FM_Label(it)
        local s = nil
        pcall(function()
            if type(it.textId) == "number" and LOC_STR then s = LOC_STR[it.textId] end
        end)
        if not s or s == "" then
            s = type(it.textId) == "string" and it.textId or tostring(it.key or "???")
        end
        return s
    end

    local function _FM_Destroy()
        pcall(function()
            if _G._FM_ROOT and slua.isValid(_G._FM_ROOT) then
                _G._FM_ROOT:RemoveFromParent()
                if _G._FM_ROOT.ConditionalBeginDestroy then _G._FM_ROOT:ConditionalBeginDestroy() end
            end
        end)
        _G._FM_ROOT = nil
    end

    function _G.FM_Show(character)
        pcall(function()
            -- purana match ka stale root hatao
            if _G._FM_ROOT and not slua.isValid(_G._FM_ROOT) then
                _G._FM_ROOT = nil
                _G._FM_PANEL = nil
                _G._FM_TIMER = nil
            end
            local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            local MainUI = InGameUITools.GetMainControlBaseUI()
            if not (MainUI and slua.isValid(MainUI)) then
                if character and character.AddGameTimer then
                    _G._FM_RETRY = (_G._FM_RETRY or 0) + 1
                    if _G._FM_RETRY < 25 and not _G._FM_TIMER then
                        _G._FM_TIMER = character:AddGameTimer(1.0, true, function()
                            if _G._FM_ROOT and slua.isValid(_G._FM_ROOT) then
                                if character.RemoveGameTimer and _G._FM_TIMER then pcall(function() character:RemoveGameTimer(_G._FM_TIMER) end) end
                                _G._FM_TIMER = nil
                                return
                            end
                            local n = _G._FM_RETRY or 0
                            if n >= 25 then
                                if character.RemoveGameTimer and _G._FM_TIMER then pcall(function() character:RemoveGameTimer(_G._FM_TIMER) end) end
                                _G._FM_TIMER = nil
                                return
                            end
                            _G.FM_Show(character)
                        end)
                    end
                end
                return
            end
            _G._FM_RETRY = 0
            if _G._FM_ROOT and slua.isValid(_G._FM_ROOT) then return end
            local Parent = (MainUI.CanvasPanel_0 and slua.isValid(MainUI.CanvasPanel_0)) and MainUI.CanvasPanel_0 or nil
            if not (Parent and slua.isValid(Parent)) then return end
            local FVector2D = import("Vector2D")
            local FLinearColor = import("LinearColor")
            local vw, vh = 1920, 1080
            pcall(function()
                local ui_util = require("client.common.ui_util")
                local vs = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize()
                if vs and vs.X and vs.X > 0 then vw, vh = vs.X, vs.Y end
            end)
            local S = math.min(vw / 1920, vh / 1080)
            if not S or S <= 0 then S = 1 end
            local red = FLinearColor(1.0, 0.12, 0.12, 1.0)
            local white = FLinearColor(1.0, 1.0, 1.0, 1.0)
            local grey = FLinearColor(0.7, 0.72, 0.75, 1.0)
            local cardC = FLinearColor(0.05, 0.02, 0.02, 0.96)
            local root = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", Parent)
            if not (root and slua.isValid(root)) then return end
            _G._FM_ROOT = root
            _G._FM_S = S
            _G._FM_VW, _G._FM_VH = vw, vh
            local rs = Parent:AddChildToCanvas(root)
            if rs then pcall(function() rs:SetPosition(FVector2D(0, 0)) rs:SetSize(FVector2D(vw, vh)) rs:SetZOrder(10000) end) end
            -- floating icon (top-right)
            local ix, iy = vw - 70 * S, 110 * S
            _FM_Border(root, red, ix, iy, 60 * S + 6, 60 * S + 6, 10001)
            _FM_Button(root, "SH", math.floor(22 * S), {1, 1, 1}, ix, iy, 60 * S, 60 * S, function()
                _G._FM_OPEN = not _G._FM_OPEN
                pcall(function() if _G.FM_Build then _G.FM_Build() end end)
            end)
            pcall(function() if _G.FM_Build then _G.FM_Build() end end)
        end)
    end

    function _G.FM_Build()
        pcall(function()
            local root = _G._FM_ROOT
            if not (root and slua.isValid(root)) then return end
            local S = _G._FM_S or 1
            local vw, vh = _G._FM_VW or 1920, _G._FM_VH or 1080
            local FVector2D = import("Vector2D")
            local FLinearColor = import("LinearColor")
            local red = FLinearColor(1.0, 0.12, 0.12, 1.0)
            local white = FLinearColor(1.0, 1.0, 1.0, 1.0)
            local grey = FLinearColor(0.7, 0.72, 0.75, 1.0)
            local green = FLinearColor(0.15, 0.9, 0.4, 1.0)
            local cardC = FLinearColor(0.05, 0.02, 0.02, 0.96)
            -- purana panel hatao
            pcall(function()
                if _G._FM_PANEL and slua.isValid(_G._FM_PANEL) then
                    _G._FM_PANEL:RemoveFromParent()
                    if _G._FM_PANEL.ConditionalBeginDestroy then _G._FM_PANEL:ConditionalBeginDestroy() end
                end
            end)
            _G._FM_PANEL = nil
            if not _G._FM_OPEN then return end
            local panel = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", root)
            if not (panel and slua.isValid(panel)) then return end
            _G._FM_PANEL = panel
            local cx = vw * 0.5
            local topY = vh * 0.12
            -- rows filter
            local rows = {}
            for _, it in ipairs(_G._FM_ITEMS or {}) do
                if _FM_CatOf(it.key) == (_G._FM_CAT or "AIM") then rows[#rows + 1] = it end
            end
            local rowH = 42 * S
            local panelW = 620 * S
            local headH = 96 * S
            local panelH = headH + #rows * rowH + 20 * S
            local cy = topY + panelH * 0.5
            if cy + panelH * 0.5 > vh then cy = vh - panelH * 0.5 - 10 * S end
            _FM_Border(panel, cardC, cx, cy, panelW, panelH, 10001)
            -- red frame
            _FM_Border(panel, red, cx, cy - panelH * 0.5, panelW, math.max(3, math.floor(4 * S)), 10002)
            _FM_Border(panel, red, cx, cy + panelH * 0.5, panelW, math.max(3, math.floor(4 * S)), 10002)
            _FM_Text(panel, "SH MENU", math.floor(24 * S), red, cx, topY + 24 * S, 10004)
            -- category buttons + X
            local cats = {"AIM", "MEM", "ESP", "SKIN", "BAN"}
            local bw = (panelW - 90 * S) / 5
            for i, c in ipairs(cats) do
                local bx = cx - panelW * 0.5 + 45 * S + (i - 0.5) * bw
                local on = (_G._FM_CAT == c)
                _FM_Button(panel, c, math.floor(15 * S), on and {1, 0.15, 0.15} or {1, 1, 1}, bx, topY + 58 * S, bw - 6 * S, 30 * S, function()
                    _G._FM_CAT = c
                    pcall(function() if _G.FM_Build then _G.FM_Build() end end)
                end)
            end
            _FM_Button(panel, "X", math.floor(16 * S), {1, 0.3, 0.3}, cx + panelW * 0.5 - 28 * S, topY + 24 * S, 34 * S, 30 * S, function()
                _G._FM_OPEN = false
                pcall(function() if _G.FM_Build then _G.FM_Build() end end)
            end)
            -- rows
            local ry = topY + headH
            for _, it in ipairs(rows) do
                local label = _FM_Label(it)
                if #label > 34 then label = label:sub(1, 32) .. ".." end
                _FM_Text(panel, label, math.floor(15 * S), white, cx - panelW * 0.5 + 10 * S + 130 * S, ry, 10004)
                -- NOTE: TextBlock left-align nahi, center anchor par offset text hai
                local st = nil
                pcall(function() if it.get then st = it.get() end end)
                if it.kind == "switch" then
                    local on = (st == 1)
                    _FM_Button(panel, on and "ON" or "OFF", math.floor(15 * S), on and {0.15, 0.9, 0.4} or {1, 1, 1}, cx + panelW * 0.5 - 70 * S, ry, 100 * S, 32 * S, function()
                        pcall(function() if it.set then it.set(on and 2 or 1) end end)
                        pcall(function() if _G.FM_Build then _G.FM_Build() end end)
                    end)
                elseif it.kind == "bone" then
                    local names = {"Head", "Chest", "Pelvis"}
                    local cur = names[tonumber(st) or 2] or "Chest"
                    _FM_Button(panel, cur, math.floor(14 * S), {1, 0.85, 0.3}, cx + panelW * 0.5 - 70 * S, ry, 100 * S, 32 * S, function()
                        local nx = ((tonumber(st) or 2) % 3) + 1
                        pcall(function() if it.set then it.set(nx) end end)
                        pcall(function() if _G.FM_Build then _G.FM_Build() end end)
                    end)
                elseif it.kind == "slider" then
                    local mn, mx = tonumber(it.minV) or 0, tonumber(it.maxV) or 100
                    local vv = tonumber(st) or mn
                    local step = math.max(1, math.floor((mx - mn) / 20))
                    _FM_Button(panel, "-", math.floor(16 * S), {1, 1, 1}, cx + panelW * 0.5 - 158 * S, ry, 34 * S, 32 * S, function()
                        local nv = math.max(mn, vv - step)
                        pcall(function() if it.set then it.set(nv) end end)
                        pcall(function() if _G.FM_Build then _G.FM_Build() end end)
                    end)
                    _FM_Text(panel, tostring(math.floor(vv)), math.floor(15 * S), grey, cx + panelW * 0.5 - 105 * S, ry, 10004)
                    _FM_Button(panel, "+", math.floor(16 * S), {1, 1, 1}, cx + panelW * 0.5 - 52 * S, ry, 34 * S, 32 * S, function()
                        local nv = math.min(mx, vv + step)
                        pcall(function() if it.set then it.set(nv) end end)
                        pcall(function() if _G.FM_Build then _G.FM_Build() end end)
                    end)
                end
                ry = ry + rowH
            end
        end)
    end

    -- FLOATING MENU trigger (retry samet, MainUI late aata hai)
    pcall(function()
        if _G.RefreshAllMemoryFeatures then pcall(_G.RefreshAllMemoryFeatures) end
        pcall(function() if _G.BRChamsConfig and _G.BRChamsConfig.Enable and _G.BRStartChams then _G.BRStartChams() end end)
        pcall(function() if _G.PBCWallhackConfig and _G.PBCWallhackConfig.Enable and _G.PBCStartWallhack then _G.PBCStartWallhack() end end)
        pcall(function() if _G.BlueFrameConfig and _G.BlueFrameConfig.Enable and _G.BlueFrameStart then _G.BlueFrameStart() end end)
        pcall(function() if _G.ForceTPP_Enable and _G.HRD_StartForceTPP then _G.HRD_StartForceTPP() end end)
        pcall(function() if _G.MagicBulletConfig and _G.MagicBulletConfig.Enable and _G.StartMagicBullet then _G.StartMagicBullet() end end)
        pcall(function() if _G.LexusConfig and _G.LexusConfig.ModSkin and _G.BRStartSkinLoop then _G.BRStartSkinLoop() end end)
    end)
    -- KILLSWITCH (safe): HawkEye/ban/inspect signal -> features STOP + tmp traces wipe.
    -- keys.txt / uid.txt ko HAATH NAHI (wo chahiye).
    _G._KILLSWITCH = _G._KILLSWITCH or false
    local function SH_DoKillswitch(src)
        if _G._KILLSWITCH then return end
        _G._KILLSWITCH = true
        pcall(function() if _G.AimbotConfig then _G.AimbotConfig.Enable = false end end)
        pcall(function() if _G.BRStopChams then _G.BRStopChams() end end)
        pcall(function() if _G.PBCStopWallhack then _G.PBCStopWallhack() end end)
        pcall(function() if _G.BlueFrameStop then _G.BlueFrameStop() end end)
        pcall(function() if _G.StopMagicBullet then _G.StopMagicBullet() end end)
        pcall(function() if _G.StopFastCar then _G.StopFastCar() end end)
        pcall(function() if _G.HRD_StopForceTPP then _G.HRD_StopForceTPP() end end)
        for _, fn in ipairs({"BRStartChams", "PBCStartWallhack", "BlueFrameStart", "StartMagicBullet", "StartFastCar", "HRD_StartForceTPP", "BRStartSkinLoop"}) do
            pcall(function()
                if _G[fn] then _G[fn] = function() end end
            end)
        end
        pcall(function()
            local dir = "/storage/emulated/0/Android/data/com.pubg.imobile/files/"
            os.remove(dir .. "tlog_cache.dat")
            os.remove(dir .. "reports_log.txt")
        end)
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then Msg.Show(4, "SAFE MODE", "Abnormal signal (" .. tostring(src) .. ") - features stopped.") end
        end)
    end
    _G.SH_DoKillswitch = SH_DoKillswitch
    pcall(function()
        if EventSystem and EventSystem.postEvent and not _G._KS_HOOKED then
            _G._KS_HOOKED = true
            local oPE = EventSystem.postEvent
            EventSystem.postEvent = function(self, et, eid, ...)
                pcall(function()
                    local s = string.lower(tostring(et or "") .. " " .. tostring(eid or ""))
                    if string.find(s, "hawk", 1, true) or string.find(s, "inspect", 1, true)
                        or string.find(s, "forbid_voice", 1, true) or string.find(s, "unconscious_ban", 1, true)
                        or string.find(s, "warning_tips", 1, true) then
                        SH_DoKillswitch(tostring(eid))
                    end
                end)
                return oPE(self, et, eid, ...)
            end
        end
    end)
    -- ════════════════════════════════════════════════════════
    -- BGMI LOADING SCREEN — XThrlen BANNER
    -- ════════════════════════════════════════════════════════

    _G.LoadingScreenConfig = _G.LoadingScreenConfig or {
        Enable = true,
        ImageURL     = "https://cdn.jsdelivr.net/gh/victortipvala-sys/esp-icons@main/loading_banner.png",
        ImageURL_CDN = "https://raw.githubusercontent.com/victortipvala-sys/esp-icons/main/loading_banner.png",
        Position = "FullScreen",
        SizeX = 1920,
        SizeY = 1080,
        ShowDuration = 15,
        DelayBeforeShow = 1.5,
        Opacity = 1.0,
        ZOrder = 9999,
        AutoStart = true,
    }

    _G.LoadingScreenState = _G.LoadingScreenState or { Widget = nil, Slot = nil, Timer = nil, RetryCount = 0, Shown = false }

    function _G.LS_Show()
        if not _G.LoadingScreenConfig or not _G.LoadingScreenConfig.Enable then return end
        if _G.LoadingScreenState.Shown then return end
        pcall(function()
            local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
            if not InGameUITools then return end
            local MainUI = InGameUITools.GetMainControlBaseUI()
            if not (MainUI and slua.isValid(MainUI)) then
                _G.LoadingScreenState.RetryCount = _G.LoadingScreenState.RetryCount + 1
                if _G.LoadingScreenState.RetryCount < 40 then
                    pcall(function()
                        if _G.Game and _G.Game.AddGameTimer then
                            _G.Game:AddGameTimer(0.25, false, _G.LS_Show)
                        end
                    end)
                end
                return
            end
            _G.LoadingScreenState.RetryCount = 0
            local Parent = MainUI.CanvasPanel_0
            if not (Parent and slua.isValid(Parent)) then Parent = MainUI.CanvasPanel_42 end
            if not (Parent and slua.isValid(Parent)) then return end
            local FVector2D = import("Vector2D")
            local FLinearColor = import("LinearColor")
            local EVis = UEnums.ESlateVisibility
            local vw, vh = 1920, 1080
            pcall(function()
                local ui_util = require("client.common.ui_util")
                local vs = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize()
                if vs and vs.X and vs.X > 0 then vw, vh = vs.X, vs.Y end
            end)
            local img = CGame:NewObjectFromPath("/Script/UMG.Image", Parent)
            if not (img and slua.isValid(img)) then return end
            img:SetWidgetVisibility(EVis.SelfHitTestInvisible)
            local slot = Parent:AddChildToCanvas(img)
            if slot then
                slot:SetAutoSize(false)
                slot:SetSize(FVector2D(vw, vh))
                slot:SetPosition(FVector2D(vw * 0.5, vh * 0.5))
                slot:SetAlignment(FVector2D(0.5, 0.5))
                slot:SetZOrder(_G.LoadingScreenConfig.ZOrder or 9999)
            end
            _G.LoadingScreenState.Widget = img
            _G.LoadingScreenState.Slot = slot
            _G.LoadingScreenState.Shown = true
            local function applyTex(tex)
                if not (tex and slua.isValid(tex)) then return end
                if not (img and slua.isValid(img)) then return end
                pcall(function()
                    img:SetBrushFromTexture(tex, false)
                    img:SetColorAndOpacity(FLinearColor(1, 1, 1, _G.LoadingScreenConfig.Opacity))
                end)
            end
            pcall(function()
                local MM = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                if not MM then pcall(function() MM = require("GameLua.GameCore.Module.ModuleManager") end) end
                local mgr = nil
                if MM and MM.GetModule and MM.CommonModuleConfig then
                    pcall(function() mgr = MM:GetModule(MM.CommonModuleConfig.image_download_mgr) end)
                end
                if not mgr then pcall(function() mgr = require("client.slua.logic.image_download.image_download_mgr") end) end
                if mgr and mgr.DownloadImageByHttpWrapper then
                    mgr:DownloadImageByHttpWrapper(_G.LoadingScreenConfig.ImageURL, applyTex, function()
                        pcall(function()
                            if mgr and mgr.DownloadImageByHttpWrapper then
                                mgr:DownloadImageByHttpWrapper(_G.LoadingScreenConfig.ImageURL_CDN, applyTex, nil)
                            end
                        end)
                    end)
                end
            end)
            if _G.LoadingScreenConfig.ShowDuration > 0 then
                pcall(function()
                    if _G.Game and _G.Game.AddGameTimer then
                        _G.LoadingScreenState.Timer = _G.Game:AddGameTimer(_G.LoadingScreenConfig.ShowDuration, false, _G.LS_Hide)
                    end
                end)
            end
        end)
    end

    function _G.LS_Hide()
        pcall(function()
            if _G.LoadingScreenState.Widget and slua.isValid(_G.LoadingScreenState.Widget) then
                _G.LoadingScreenState.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
        end)
        _G.LoadingScreenState.Widget = nil
        _G.LoadingScreenState.Slot = nil
        _G.LoadingScreenState.Shown = false
    end

    if _G.LoadingScreenConfig.AutoStart then
        pcall(function()
            local delay = _G.LoadingScreenConfig.DelayBeforeShow or 1.5
            if _G.Game and _G.Game.AddGameTimer then
                _G.Game:AddGameTimer(delay, false, _G.LS_Show)
            elseif slua_GameFrontendHUD then
                local pc = slua_GameFrontendHUD:GetPlayerController()
                if pc and slua.isValid(pc) and pc.AddGameTimer then
                    pc:AddGameTimer(delay, false, _G.LS_Show)
                end
            end
        end)
    end

    do
    -- ========================================================================
    -- AUTO FEEDBACK (Top-1 win screenshot -> VIP server) - ALWAYS ON
    -- Source: auto feadvack\a.lua (as-is, sirf do-block me wrapped)
    -- ========================================================================
    local AutoFeedback = {
        Config = {
            ServerURL = "https://ahmediqh.x10.mx/uploads/rahaf.php",
            TestMode = true
        },
        Hooked = false
    }

    local function FB_Log(message)
        print(string.format("[ABU RAHAF] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
    end

    local function FB_Notify(message)
        if _G.SRCHUBNotify then
            pcall(_G.SRCHUBNotify, message)
        end
    end

    local function FB_GetModule(name, allowRequire)
        local loaded = package and package.loaded and package.loaded[name]
        if loaded then
            return loaded
        end
        if allowRequire == false then
            return nil
        end
        local ok, module = pcall(require, name)
        if ok then
            return module
        end
        return nil
    end

    local function FB_AddTimerOnce(delay, callback)
        local ticker = FB_GetModule("common.time_ticker")
        if ticker and type(ticker.AddTimerOnce) == "function" then
            ticker.AddTimerOnce(delay, callback)
            return true
        end
        return false
    end

    local function FB_Base64Encode(data)
        if type(data) ~= "string" or #data == 0 then
            return ""
        end
        local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        local output = {}
        local outputIndex = 0
        local index = 1
        while index <= #data - 2 do
            local a, b, c = string.byte(data, index, index + 2)
            local value = a * 65536 + b * 256 + c
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte(alphabet, math.floor(value / 64) % 64 + 1),
                string.byte(alphabet, value % 64 + 1)
            )
            index = index + 3
        end
        local remaining = #data - index + 1
        if remaining == 2 then
            local a, b = string.byte(data, index, index + 1)
            local value = a * 65536 + b * 256
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte(alphabet, math.floor(value / 64) % 64 + 1),
                string.byte("=")
            )
        elseif remaining == 1 then
            local value = string.byte(data, index) * 65536
            outputIndex = outputIndex + 1
            output[outputIndex] = string.char(
                string.byte(alphabet, math.floor(value / 262144) + 1),
                string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
                string.byte("="),
                string.byte("=")
            )
        end
        return table.concat(output)
    end

    local function FB_UrlEncode(value)
        if value == nil then
            return nil
        end
        value = tostring(value):gsub("\n", "\r\n")
        value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
            return string.format("%%%02X", string.byte(character))
        end)
        value = value:gsub(" ", "+")
        return value
    end

    local function FB_ReadFile(path)
        local file = io.open(path, "rb")
        if not file then
            return ""
        end
        local data = file:read("*a") or ""
        file:close()
        return data
    end

    local function FB_RemoveFile(path)
        pcall(os.remove, path)
    end

    local function FB_GetRankName(rank)
        if rank < 1700 then return "Bronze"
        elseif rank < 2200 then return "Silver"
        elseif rank < 2700 then return "Gold"
        elseif rank < 3200 then return "Platinum"
        elseif rank < 3700 then return "Diamond"
        elseif rank < 4200 then return "Crown"
        elseif rank < 4700 then return "Ace"
        elseif rank < 5200 then return "Ace Master"
        elseif rank < 5600 then return "Ace Dominator" end
        return "Conqueror"
    end

    local FB_CaptionTemplate = "<tg-emoji emoji-id=\"5807868868886009920\">👑</tg-emoji> <b>JOIN @a_9rk</b> <tg-emoji emoji-id=\"5807868868886009920\">👑</tg-emoji>\n" ..
        "<tg-emoji emoji-id=\"6008118472066732010\">🔥</tg-emoji> <b>AUTO FEEDBACK GROUP VIP</b> <tg-emoji emoji-id=\"6008118472066732010\">🔥</tg-emoji>\n" ..
        "<tg-emoji emoji-id=\"5985616167740379273\">⏰</tg-emoji> <b>Time: %s</b>\n" ..
        "<tg-emoji emoji-id=\"5814550759961793482\">👤</tg-emoji> <b>Player name: %s</b>\n" ..
        "<tg-emoji emoji-id=\"6008090211181923982\">🔑</tg-emoji> <b>UID: %s</b>\n" ..
        "<tg-emoji emoji-id=\"5873121512445187130\">💀</tg-emoji> <b>Kills: %d</b>\n" ..
        "<tg-emoji emoji-id=\"5807461353799030682\">👑</tg-emoji> <b>Rank: %s</b>\n" ..
        "<tg-emoji emoji-id=\"5890944389773005080\">💬</tg-emoji> <b>OWNER: XThrlen + SRC HUB</b>"

    function AutoFeedback.SendFeedback(path, kills, rank, segment)
        FB_Log("Preparing to send feedback. Screenshot: " .. tostring(path))
        local ok, err = pcall(function()
            local httpManager = FB_GetModule("client.slua.logic.http.http_manager")
            if not httpManager or type(httpManager.Post) ~= "function" then
                FB_Log("HTTP manager is unavailable.")
                return
            end
            local attempts = 0
            local function TrySend()
                local imageData = FB_ReadFile(path)
                if #imageData > 0 then
                    local uid = "unknown"
                    if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
                        uid = tostring(_G.DataMgr.roleData.uid)
                    elseif _G._KONG_UK then
                        uid = tostring(_G._KONG_UK)
                    end
                    kills = tonumber(kills) or 0
                    rank = tonumber(rank) or 0
                    segment = tonumber(segment) or 0
                    local maskedUid = "***"
                    if uid ~= "unknown" and #uid > 5 then
                        maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
                    end
                    local caption = string.format(
                        FB_CaptionTemplate,
                        os.date("%H:%M:%S %d/%m/%Y"),
                        "*****",
                        maskedUid,
                        kills,
                        FB_GetRankName(rank)
                    )
                    local encodedImage = FB_Base64Encode(imageData)
                    encodedImage = encodedImage:gsub("%+", "%%2B")
                    encodedImage = encodedImage:gsub("/", "%%2F")
                    encodedImage = encodedImage:gsub("=", "%%3D")
                    FB_Notify("[ABU RAHAF] Uploading Top 1 screenshot to VIP Server...")
                    local body = "base64_image=" .. encodedImage
                        .. "&caption=" .. FB_UrlEncode(caption)
                    httpManager:Post(
                        AutoFeedback.Config.ServerURL,
                        {["Content-Type"] = "application/x-www-form-urlencoded"},
                        body,
                        nil,
                        function(success, _, response, errorMessage)
                            if success and response and tostring(response):find('"status":%s*true') then
                                FB_Notify("[ABU RAHAF] Successfully sent! (Kills: " .. tostring(kills) .. ")")
                            else
                                local detail = tostring(response or errorMessage):sub(1, 40)
                                FB_Notify("[ABU RAHAF] VIP Server error: " .. detail)
                            end
                            FB_RemoveFile(path)
                        end,
                        60
                    )
                    return
                end
                attempts = attempts + 1
                if attempts < 5 and FB_AddTimerOnce(1.0, TrySend) then
                    return
                end
                FB_Notify("[ABU RAHAF] Screenshot capture failed!")
                FB_RemoveFile(path)
            end
            TrySend()
        end)
        if not ok then
            FB_Log("SendFeedback Error: " .. tostring(err))
        end
    end

    local FB_HudNames = {
        "BattleChat_UIBP", "Chat_UIBP", "ChatMsg_UIBP", "TeamAvatar_UIBP",
        "Team_UIBP", "VoiceChat_UIBP", "MiniMap_UIBP", "Bag_UIBP",
        "PickUp_UIBP", "PickUpList_UIBP", "SystemChat_UIBP", "InGameChat_UIBP",
        "InGameChatPanel_UIBP", "KillFeed_UIBP", "Elimination_UIBP", "ChatHUD_UIBP",
        "ChatPanel_UIBP", "MainHUD_UIBP", "BattleHUD_UIBP"
    }

    local function FB_GetRankAndSegment()
        local rank = 0
        local segment = 0
        pcall(function()
            local battleResult = _G.BP_STRUCT_BattleResultData
            local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
            if rating then
                rank = tonumber(rating.rank_rating) or 0
                segment = tonumber(rating.new_segment) or 0
            end
            if rank == 0 then
                local funcUtil = FB_GetModule("common.func_util")
                local roleData = _G.DataMgr and _G.DataMgr.roleData
                if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function"
                    and roleData and roleData.allzoneSegment then
                    segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
                end
                if roleData and roleData.segment_rating then
                    for _, value in pairs(roleData.segment_rating) do
                        if type(value) == "table" then
                            for _, nestedValue in pairs(value) do
                                if type(nestedValue) == "number" and nestedValue > rank then
                                    rank = nestedValue
                                end
                            end
                        elseif type(value) == "number" and value > rank then
                            rank = value
                        end
                    end
                end
            end
        end)
        return rank, segment
    end

    local function FB_CreateHudController()
        local hidden = {}
        local function SetHidden(hide)
            local UIManager = _G.UIManager
            if not UIManager then return end
            if hide then
                for _, name in ipairs(FB_HudNames) do
                    local config
                    if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
                        config = UIManager.UI_Config_InGame[name]
                    elseif UIManager.UI_Config and UIManager.UI_Config[name] then
                        config = UIManager.UI_Config[name]
                    end
                    if config then
                        local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
                        if view then
                            pcall(function()
                                if type(view.SetVisibility) == "function" then
                                    view:SetVisibility(2)
                                elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then
                                    view.UIRoot:SetVisibility(2)
                                elseif type(UIManager.HideUI) == "function" then
                                    UIManager.HideUI(config)
                                elseif type(UIManager.CloseUI) == "function" then
                                    UIManager.CloseUI(config)
                                end
                            end)
                            table.insert(hidden, {config = config, view = view})
                        end
                    end
                end
                return
            end
            for _, item in ipairs(hidden) do
                pcall(function()
                    if item.view and type(item.view.SetVisibility) == "function" then
                        item.view:SetVisibility(0)
                    elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then
                        item.view.UIRoot:SetVisibility(0)
                    elseif type(UIManager.ShowUI) == "function" then
                        UIManager.ShowUI(item.config)
                    end
                end)
            end
            hidden = {}
        end
        return SetHidden
    end

    local function FB_GetScreenshotDirectory()
        local directories = {}
        local home = os.getenv("HOME")
        if home and home ~= "" then
            table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/")
        end
        local packages = {
            "com.tencent.ig", "com.vng.pubgmobile", "com.pubg.krmobile",
            "com.rekoo.pubgm", "com.pubg.imobile"
        }
        for _, packageName in ipairs(packages) do
            table.insert(directories,
                "/storage/emulated/0/Android/data/" .. packageName
                    .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/")
        end
        local selected = directories[1]
        for _, directory in ipairs(directories) do
            local testPath = directory .. "t.tmp"
            local file = io.open(testPath, "w")
            if file then
                file:close()
                os.remove(testPath)
                selected = directory
                break
            end
        end
        return selected
    end

    local function FB_CaptureAndSend(kills, rank, segment, restoreHud)
        local restored = false
        local function RestoreHudOnce()
            if not restored then
                restored = true
                restoreHud(false)
            end
        end
        local ScreenshotMaker = import("ScreenshotMaker")
        if not ScreenshotMaker then
            RestoreHudOnce()
            return
        end
        local directory = FB_GetScreenshotDirectory()
        if not directory then
            RestoreHudOnce()
            return
        end
        local path = directory .. string.format("kongwin_%s.jpg", os.time())
        local uiUtil = FB_GetModule("client.common.ui_util")
        local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
        local enginePreTick = gameInstance and gameInstance.EnginePreTick
        if not enginePreTick or type(enginePreTick.Add) ~= "function" then
            RestoreHudOnce()
            return
        end
        local ticker = FB_GetModule("common.time_ticker")
        if not ticker or type(ticker.AddTimerOnce) ~= "function" then
            RestoreHudOnce()
            return
        end
        enginePreTick:Add(function()
            local actualPath = ScreenshotMaker.MakePictureByName(path, true)
            if type(enginePreTick.Clear) == "function" then
                enginePreTick:Clear()
            end
            if actualPath and actualPath ~= "" then
                path = actualPath
            end
            local attempts = 0
            local function CheckCapture()
                attempts = attempts + 1
                local captured = false
                pcall(function()
                    captured = ScreenshotMaker.HasCaptured(path)
                end)
                if captured then
                    RestoreHudOnce()
                    FB_Log("HasCaptured=true. Flushing to disk via ResizePicture...")
                    pcall(ScreenshotMaker.ResizePicture, path, 0.9, path)
                    ticker.AddTimerOnce(2.0, function()
                        if #FB_ReadFile(path) > 0 then
                            AutoFeedback.SendFeedback(path, kills, rank, segment)
                        else
                            FB_Notify("[ABU RAHAF] iOS image read error!")
                        end
                    end)
                elseif attempts < 15 then
                    ticker.AddTimerOnce(1, CheckCapture)
                else
                    RestoreHudOnce()
                    FB_Notify("[ABU RAHAF] Screenshot capture failed!")
                end
            end
            ticker.AddTimerOnce(1, CheckCapture)
        end)
    end

    function AutoFeedback.ProcessWin(kills)
        kills = tonumber(kills) or 0
        local rank, segment = FB_GetRankAndSegment()
        if rank < 2200 or kills <= 5 then
            FB_Log(string.format(
                "Skipping feedback: Rank %d, Kill %d (Requires Rank >= 2200 AND Kill > 5)",
                rank, kills))
            return
        end
        FB_Notify("[ABU RAHAF] Congratulations on getting TOP 1!")
        local setHudHidden = FB_CreateHudController()
        setHudHidden(true)
        local ok, err = pcall(FB_CaptureAndSend, kills, rank, segment, setHudHidden)
        if not ok then
            setHudHidden(false)
            FB_Log("ProcessWin Error: " .. tostring(err))
        end
    end

    local function FB_GetWinnerKills()
        local kills = 0
        pcall(function()
            local likeUtil = FB_GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
            if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
                local playerState = likeUtil.GetMyPlayerState()
                if playerState and playerState.Kills then
                    kills = tonumber(playerState.Kills) or 0
                end
            end
            if kills == 0 then
                local resultLogic = FB_GetModule(
                    "GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic",
                    false)
                if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
                    local result = resultLogic:GetBattleResultData()
                    if result and result.BP_mykill then
                        kills = tonumber(result.BP_mykill) or 0
                    end
                end
            end
        end)
        return kills
    end

    local function FB_TryInstallHook()
        pcall(function()
            local UIManager = _G.UIManager
            if not UIManager or not UIManager.ShowUI or UIManager.__SRCHUBHooked then
                return
            end
            FB_Log("Hooking UIManager.ShowUI for in-game Winner UI...")
            local originalShowUI = UIManager.ShowUI
            UIManager.ShowUI = function(config, params, ...)
                local result = originalShowUI(config, params, ...)
                pcall(function()
                    local inGameConfig = UIManager.UI_Config_InGame
                    local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
                    local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
                    if not winnerConfig or config ~= winnerConfig or not isWinner then
                        return
                    end
                    local kills = FB_GetWinnerKills()
                    if not FB_AddTimerOnce(2, function()
                        AutoFeedback.ProcessWin(kills)
                    end) then
                        AutoFeedback.ProcessWin(kills)
                    end
                end)
                return result
            end
            UIManager.__SRCHUBHooked = true
            AutoFeedback.Hooked = true
            FB_Log("UIManager Hook installed successfully.")
        end)
    end

    function AutoFeedback.Install()
        FB_Log("Installing ABU RAHAFsystem (Telegram)...")
        if AutoFeedback.Config.TestMode then
            pcall(function()
                FB_AddTimerOnce(5.0, function()
                    AutoFeedback.ProcessWin()
                end)
            end)
        end
        pcall(function()
            local ticker = FB_GetModule("common.time_ticker")
            if ticker and type(ticker.AddTimer) == "function" then
                ticker.AddTimer(3.0, FB_TryInstallHook)
            else
                FB_TryInstallHook()
            end
        end)
    end

    AutoFeedback.Base64Encode = FB_Base64Encode
    AutoFeedback.UrlEncode = FB_UrlEncode
    AutoFeedback.GetRankName = FB_GetRankName
    _G.WEOW_AutoFeedbackRecovered = AutoFeedback

    AutoFeedback.Install()
    end -- auto feedback block

    pcall(function() if _G.FM_Show then _G.FM_Show(self) end end)

end


-- turant load: define ke baad auto call
pcall(function()
  if type(_G.StartAdvancedSystems)=="function" then
    local ok, err = pcall(_G.StartAdvancedSystems, nil)
    print("[SH] StartAdvancedSystems auto-run:", ok, tostring(err))
  else
    print("[SH] ERROR: StartAdvancedSystems nahi mila")
  end
end)
-- next match me: _G.SH_Reattach()

-- إضافة تحديث واجهة الترخيص
local okTicker, ticker = pcall(require, "common.time_ticker")
if okTicker and ticker and ticker.AddTimer then
    ticker.AddTimer(0.1, function()
        if _G.LunarLoginRuntime and _G.LunarLoginRuntime.NeedsUpdate then
            pcall(_G.LunarLoginRuntime.Update)
        end
    end)
end
