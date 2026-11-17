-- UnstuckSkips Forever : partage des morts entre joueurs
-- Les morts (ou l'on meurt -> ou l'on reapparait) circulent sur un canal de discussion cache,
-- comme le font deja les addons MostlyNotBroken (SnuggleUp Forever) sur WoW Forever.
--  * rien a faire pour le joueur : envoi automatique, quelques minutes apres la mort,
--    hors combat et hors instance, 1 message par seconde au plus ;
--  * aucun nom n'est stocke : seulement positions, continent, faction, zone, sous-zone, date ;
--  * a la connexion, l'addon redemande les morts recentes aux joueurs en ligne (resynchronisation) ;
--  * /usf share : couper / remettre le partage.
-- Format : D|2|f|c|X|Y|rX|rY|zone|t|sous-zone (f = A/H, c = continent, X/Y = mort, rX/rY = reapparition)
--          (v1 : sans la sous-zone ; les deux sont lus)
--          R|depuis|max   (demande des morts plus recentes que `depuis` ; max > 30 = collecteur)
--          U|1|f|c|X|Y|rX|rY|zone|t|sous-zone : deblocage (position avant deconnexion -> position a la reconnexion)
--          (les anciennes versions ignorent les messages U)
--  * mode collecteur (/usf collector) : a chaque connexion, demande TOUT ce que les joueurs en ligne
--    ont en stock (jusqu'a 600 morts chacun), au lieu des 30 plus recentes.
local ADDON, ns = ...

local PREFIX = "USFDeaths1"
local CHANNEL_NAME = "UnstuckSkipsForever"
local SEND_GAP = 1.1
local SEND_DELAY_MIN, SEND_DELAY_MAX = 120, 300 -- secondes avant d'envoyer sa propre mort
local MAX_STORED = 6000
local MAX_STORED_U = 3000
local MAX_SYNC_U = 200
local MAX_SYNC_REPLY = 40
local MAX_COLLECTOR_REPLY = 600
local PROTO = 2

local Share = {}
ns.Share = Share

local function DB() return ns.DB() end

local function Enabled() return DB().share ~= false end

---------------------------------------------------------------------------
-- Stockage (sans nom de joueur)
---------------------------------------------------------------------------
local function Key(r)
    return string.format("%d:%s:%d:%d:%d:%d", r.c, r.f, r.X, r.Y, r.rX, r.rY)
end

local function Store(r)
    local db = DB()
    db.shared = db.shared or {}
    db.sharedOrder = db.sharedOrder or {}
    local k = Key(r)
    if db.shared[k] then return false end
    db.shared[k] = {c = r.c, f = r.f, X = r.X, Y = r.Y, rX = r.rX, rY = r.rY, z = r.z, t = r.t, s = r.s}
    table.insert(db.sharedOrder, k)
    while #db.sharedOrder > MAX_STORED do
        db.shared[table.remove(db.sharedOrder, 1)] = nil
    end
    if ns.OnSharedDeath then ns.OnSharedDeath(db.shared[k]) end
    return true
end
Share.Store = Store

-- deblocages (meme forme qu'une mort : X/Y = avant la deconnexion, rX/rY = a la reconnexion)
local function StoreU(r)
    local db = DB()
    db.sharedU = db.sharedU or {}
    db.sharedUOrder = db.sharedUOrder or {}
    local k = Key(r)
    if db.sharedU[k] then return false end
    db.sharedU[k] = {c = r.c, f = r.f, X = r.X, Y = r.Y, rX = r.rX, rY = r.rY, z = r.z, t = r.t, s = r.s}
    table.insert(db.sharedUOrder, k)
    while #db.sharedUOrder > MAX_STORED_U do
        db.sharedU[table.remove(db.sharedUOrder, 1)] = nil
    end
    return true
end
Share.StoreU = StoreU

local function Newest()
    local t = 0
    for _, r in pairs(DB().shared or {}) do if (r.t or 0) > t then t = r.t end end
    return t
end

---------------------------------------------------------------------------
-- Canal cache
---------------------------------------------------------------------------
local function HideChannel()
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then
            if ChatFrame_RemoveChannel then
                pcall(ChatFrame_RemoveChannel, frame, CHANNEL_NAME)
            elseif ChatFrameUtil and ChatFrameUtil.RemoveChannel then
                pcall(ChatFrameUtil.RemoveChannel, frame, CHANNEL_NAME)
            end
        end
    end
end

function Share:ChannelID()
    if not GetChannelName then return nil end
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then return id end
end

function Share:JoinChannel()
    if not Enabled() or not JoinTemporaryChannel then return end
    if not self:ChannelID() then pcall(JoinTemporaryChannel, CHANNEL_NAME) end
    C_Timer.After(1, HideChannel)
    C_Timer.After(5, HideChannel)
end

function Share:LeaveChannel()
    if LeaveChannelByName and self:ChannelID() then pcall(LeaveChannelByName, CHANNEL_NAME) end
end

---------------------------------------------------------------------------
-- Envoi (file d'attente, 1 message / 1,1 s, jamais en combat ni en instance)
---------------------------------------------------------------------------
local queue, pumping, refused = {}, false, false

local function CanSend()
    if refused or not Enabled() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance and IsInInstance() then return false end
    return Share:ChannelID() ~= nil
end

local function Pump()
    if #queue == 0 then pumping = false return end
    if not CanSend() then C_Timer.After(10, Pump) return end
    local text = table.remove(queue, 1)
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, "CHANNEL", Share:ChannelID())
    -- 4 = type de discussion refuse par ce client : on arrete pour la session
    if ok and res == 4 then refused = true; queue = {}; pumping = false return end
    C_Timer.After(SEND_GAP, Pump)
end

local function Send(text)
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage or refused or not Enabled() then return end
    queue[#queue + 1] = text
    if #queue > MAX_COLLECTOR_REPLY + 50 then table.remove(queue, 1) end
    if not pumping then pumping = true; C_Timer.After(0.1, Pump) end
end

local function CleanSub(sub)
    if type(sub) ~= "string" then return "" end
    sub = sub:gsub("[|\r\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #sub > 40 then
        sub = sub:sub(1, 40)
        while #sub > 0 do
            local b = sub:byte(#sub)
            if b >= 0x80 and b < 0xC0 then sub = sub:sub(1, -2)
            elseif b >= 0xC0 then sub = sub:sub(1, -2) break
            else break end
        end
    end
    return sub
end

local function Encode(r)
    return string.format("D|%d|%s|%d|%d|%d|%d|%d|%d|%d|%s", PROTO, r.f, r.c, r.X, r.Y, r.rX, r.rY, r.z or 0, r.t or 0,
                         CleanSub(r.s))
end

local function EncodeU(r)
    return string.format("U|1|%s|%d|%d|%d|%d|%d|%d|%d|%s", r.f, r.c, r.X, r.Y, r.rX, r.rY, r.z or 0, r.t or 0, CleanSub(r.s))
end

-- appele par Core quand le personnage a ete deplace pendant qu'il etait deconnecte
function Share:QueueOwnUnstuck(r)
    r.s = CleanSub(r.s)
    StoreU(r)
    if not Enabled() then return end
    C_Timer.After(SEND_DELAY_MIN + math.random() * (SEND_DELAY_MAX - SEND_DELAY_MIN), function()
        Send(EncodeU(r))
    end)
end

-- appele par Core a chaque mort enregistree (la sienne)
function Share:QueueOwnDeath(d)
    if not d or not d.X or not d.respawnX or d.cont == nil or d.respawnCont ~= d.cont then return end
    local r = {
        f = (d.faction == "Horde") and "H" or "A", c = d.cont,
        X = math.floor(d.X + 0.5), Y = math.floor(d.Y + 0.5),
        rX = math.floor(d.respawnX + 0.5), rY = math.floor(d.respawnY + 0.5),
        z = d.zoneMap or 0, t = GetServerTime and GetServerTime() or time(), s = CleanSub(d.subzoneText),
    }
    Store(r)
    if not Enabled() then return end
    -- envoi differe : on ne partage jamais la mort au moment ou elle a lieu
    C_Timer.After(SEND_DELAY_MIN + math.random() * (SEND_DELAY_MAX - SEND_DELAY_MIN), function()
        Send(Encode(r))
    end)
end

---------------------------------------------------------------------------
-- Reception
---------------------------------------------------------------------------
local lastSyncReply = 0
local lastForeignDeath = 0 -- derniere mort recue d'un autre joueur : sert a ne pas repondre en double

function Share:OnMessage(text, sender)
    if not Enabled() then return end
    local me = UnitName("player")
    if sender and Ambiguate and Ambiguate(sender, "short") == me then return end
    local kind, rest = text:match("^(%a)|(.*)$")
    if kind == "D" then
        lastForeignDeath = GetTime()
        local v, f, c, X, Y, rX, rY, z, t = rest:match("^(%d+)|([AH])|(%d)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%d+)|(%d+)")
        if not v then return end
        c = tonumber(c)
        if c ~= 0 and c ~= 1 then return end
        local sub = rest:match("^%d+|[AH]|%d|%-?%d+|%-?%d+|%-?%d+|%-?%d+|%d+|%d+|(.*)$")
        local r = {f = f, c = c, X = tonumber(X), Y = tonumber(Y), rX = tonumber(rX), rY = tonumber(rY),
                   z = tonumber(z), t = tonumber(t), s = CleanSub(sub)}
        -- garde-fous : reapparition a moins de 4 km de la mort, coordonnees plausibles
        if math.abs(r.X) > 20000 or math.abs(r.Y) > 20000 then return end
        if (r.X - r.rX) ^ 2 + (r.Y - r.rY) ^ 2 > 4000 ^ 2 then return end
        local isNew = Store(r)
        -- /usf watch : affiche en direct chaque mort recue (sans nom)
        if DB().watch and isNew then
            print(string.format("|cff4dccffUSF watch|r %s %s · zone %d %s · (%d, %d) -> (%d, %d)%s",
                r.f == "H" and "Horde" or "Alliance", r.c == 0 and "EK" or "Kalimdor", r.z or 0,
                (r.s and r.s ~= "") and ("/ " .. r.s) or "", r.X, r.Y, r.rX, r.rY, ""))
        end
    elseif kind == "U" then
        local v, f, c, X, Y, rX, rY, z, t = rest:match("^(%d+)|([AH])|(%d)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%-?%d+)|(%d+)|(%d+)")
        if not v then return end
        c = tonumber(c)
        if c ~= 0 and c ~= 1 then return end
        local sub = rest:match("^%d+|[AH]|%d|%-?%d+|%-?%d+|%-?%d+|%-?%d+|%d+|%d+|(.*)$")
        local r = {f = f, c = c, X = tonumber(X), Y = tonumber(Y), rX = tonumber(rX), rY = tonumber(rY),
                   z = tonumber(z), t = tonumber(t), s = CleanSub(sub)}
        if math.abs(r.X) > 20000 or math.abs(r.Y) > 20000 or math.abs(r.rX) > 20000 or math.abs(r.rY) > 20000 then return end
        local isNew = StoreU(r)
        if DB().watch and isNew then
            print(string.format("|cffffcc4dUSF watch|r deblocage %s %s · zone %d %s · (%d, %d) -> (%d, %d)",
                r.f == "H" and "Horde" or "Alliance", r.c == 0 and "EK" or "Kalimdor", r.z or 0,
                (r.s and r.s ~= "") and ("/ " .. r.s) or "", r.X, r.Y, r.rX, r.rY))
        end
    elseif kind == "R" then

        -- un joueur qui se connecte demande les morts recentes : reponse limitee, avec un delai
        -- aleatoire, au plus une fois par minute
        local since, want = rest:match("^(%d+)|?(%d*)")
        since, want = tonumber(since) or 0, tonumber(want) or 0
        local limit = want > MAX_SYNC_REPLY and math.min(want, MAX_COLLECTOR_REPLY) or MAX_SYNC_REPLY
        if GetTime() - lastSyncReply < 60 then return end
        local list = {}
        for _, r in pairs(DB().shared or {}) do
            if (r.t or 0) > since then table.insert(list, r) end
        end
        local hasU = next(DB().sharedU or {}) ~= nil
        if #list == 0 and not hasU then return end
        lastSyncReply = GetTime()
        table.sort(list, function(a, b) return (a.t or 0) > (b.t or 0) end)
        C_Timer.After(1 + math.random() * 6, function()
            -- un autre joueur est deja en train de repondre : inutile d'envoyer les memes morts
            if GetTime() - lastForeignDeath < 3 then return end
            for i = 1, math.min(limit, #list) do Send(Encode(list[i])) end
            -- deblocages aussi (les anciennes versions les ignorent)
            local ul = {}
            for _, r in pairs(DB().sharedU or {}) do
                if (r.t or 0) > since then table.insert(ul, r) end
            end
            table.sort(ul, function(a, b) return (a.t or 0) > (b.t or 0) end)
            for i = 1, math.min(MAX_SYNC_U, #ul) do Send(EncodeU(ul[i])) end
        end)
    end
end

function Share:RequestSync()
    if not Enabled() then return end
    if DB().collector then
        -- collecteur : tout le stock des joueurs en ligne
        Send(string.format("R|%d|%d", 0, MAX_COLLECTOR_REPLY))
        return
    end
    -- depuis la plus recente connue, moins 1 jour pour rattraper les trous
    local since = math.max(0, Newest() - 86400)
    Send(string.format("R|%d|%d", since, 0))
end

function Share:CountU()
    local n = 0
    for _ in pairs(DB().sharedU or {}) do n = n + 1 end
    return n
end

function Share:Count()
    local n = 0
    for _ in pairs(DB().shared or {}) do n = n + 1 end
    return n
end

---------------------------------------------------------------------------
-- Branchement
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
pcall(f.RegisterEvent, f, "CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        C_Timer.After(10, function() Share:JoinChannel() end) -- apres les canaux du jeu
        C_Timer.After(30, function() Share:RequestSync() end)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, _, sender = ...
        if prefix == PREFIX and type(text) == "string" then
            pcall(Share.OnMessage, Share, text, sender)
        end
    end
end)
