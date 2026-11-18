-- UnstuckSkips Forever
-- Fork d'UnstuckSkips (aaronma37/yazpad, cloudbells, SeargentFish - licence MIT) adapte a WoW Forever.
-- * UnstuckSkips (rouge) : identique a l'original (donnees Classic : cimetieres + entrees d'instances,
--   partitions de Voronoi = point le plus proche).
-- * DeathSkips (blanc) : regle observee sur Forever (analyse des death skips des guides RXP Forever) :
--     1. cimetiere de la ZONE ou l'on meurt ; 2. pas les cimetieres de l'autre faction ;
--     3. cimetieres de zone de depart seulement pres de la zone de depart ;
--     4. zones sans cimetiere : cimetiere attitre (Alterac Mountains -> Southshore / Tarren Mill) ;
--     5. parmi les cimetieres retenus, le plus proche.
--   Le continent est decoupe en cases (~35 m), le jeu donne la zone de chaque case, on applique la regle,
--   puis les frontieres sont transformees en lignes droites (meme rendu que les partitions d'UnstuckSkips).
local ADDON, ns = ...

local fmt = string.format
local VERSION = 14 -- v14 : grille officielle des sous-zones (fichiers de terrain), lignes construites hors du jeu ; v13 : tout en dur (morts choisies dans Data/evidence.lua), plus rien de calcule chez les joueurs ; v12 : aucun cimetiere de l'autre faction, chaque zone tracee relie son esprit guerisseur ; v11 : la mort reelle la plus proche decide (toutes, pas seulement les contradictoires) ; v10 : correction des faux cercles (morts sur la carte du continent) ; v9 : croix limitees aux cimetieres de sa faction ; v8 : les morts qui contredisent la regle corrigent les lignes (350 m) ; v7 : cimetieres appris (zones Forever), Red Cloud Mesa elargi ; v6 : cimetieres Classic absents de Forever remplaces ; v5 : table serveur des liens cimetiere/zone (Classic) + ajustements Forever
local CELL_YARDS = 35
local SIMPLIFY = 1.2 -- tolerance du lissage, en cases
local CONTINENTS = {[1414] = 1, [1415] = 0}
local CONT_MAP = {[0] = 1415, [1] = 1414}
local AZEROTH = 947

local COLORS = {
    unstuck = {1, 0, 0, 0.6},
    death = {1, 1, 1, 0.8},
}

local function Print(msg, ...) print(fmt("|cff3be07aDeathskip|r: " .. msg, ...)) end
-- textes : francais si le client est en francais, anglais sinon
local FR = GetLocale() == "frFR"
local function T(fr, en) return FR and fr or en end

local function DB()
    UnstuckSkipsForeverDB = UnstuckSkipsForeverDB or {}
    local db = UnstuckSkipsForeverDB
    db.cache = db.cache or {}
    -- bulle masquee par defaut (/usf notifier pour la reafficher)
    -- reglages par defaut choisis par Bellucci (seulement si le joueur ne les a jamais changes)
    if db.markStyle == nil then db.markStyle = "healer" end   -- icone d'esprit guerisseur
    if db.markSize == nil then db.markSize = 11 end           -- petite
    if db.markNames == nil then db.markNames = true end       -- noms des cimetieres sur les cartes de zone
    if db.exactBorders == nil then db.exactBorders = true end -- bordures exactes (cases de 33 m) par defaut
    if db.showDashed == nil then db.showDashed = false end    -- bordures sans effet (pointilles) masquees par defaut
    -- encadre Deathskips a l'ecran : desactive par defaut depuis 0.4.8 (une fois pour tous, comme l'ancien defaut)
    -- encadre Deathskips a l'ecran : de nouveau affiche par defaut depuis 0.4.11 (une fois pour tous), avec une croix
    if not db.hudDefaultOn2 then db.showNotifier = true; db.hudDefaultOn2 = true end
    return db
end
ns.DB = DB

-- Morts qui font la regle : Data/evidence.lua, choisies par nous (tools/make_evidence_data.py), identiques
-- pour tous. Les morts recues en direct ne changent jamais la regle : en mode /usf dev on les voit seulement
-- (points bleus), et la carte est calculee en jeu a partir de evidence.lua = apercu exact de ce qui sera livre.
local exporting = false
local function Deaths() return ns.EVIDENCE or {} end
local function DevMode() return DB().dev and not exporting end

local vec = CreateVector2D(0, 0)

---------------------------------------------------------------------------
-- Cimetieres
-- La regle est celle du serveur WoW : a la mort, cimetiere LE PLUS PROCHE PARMI CEUX LIES A LA
-- ZONE ou l'on meurt (table game_graveyard_zone : cimetiere, zone, faction). Les liens sont ceux de
-- Classic 1.12 (Data/graveyard_links.lua), avec deux ajustements constates sur Forever :
--   * cimetieres de ville : seulement pour les morts dans la ville ;
--   * cimetieres de zone de depart : seulement pres de la zone de depart.
-- Les morts reelles partagees (points bleus) priment sur la regle la ou elles existent.
---------------------------------------------------------------------------
local FACTION_ID = {Alliance = 469, Horde = 67}
local STARTERS = {aldrassil = 600, anvilmar = 500, northshire = 450, deathknell = 450,
                  ["valley of trials"] = 450, ["red cloud mesa"] = 1200}
-- cimetiere de ville -> areaId de la ville
local CITY_ONLY = {["gates of ironforge"] = 1537, ["dun morogh, ironforge"] = 1537, ["elwynn forest, stormwind"] = 1519}

-- cimetieres connus pour nommer un point de reapparition (base Forever de RXPGuides si presente)
local function RawGraveyards(contID)
    local rxp = _G.RXP and _G.RXP.SpiritHealerWorld
    if rxp and rxp[contID] then
        local res = {}
        for _, g in ipairs(rxp[contID]) do
            if g.wx and g.wy then table.insert(res, {name = g.name or "?", X = g.wx, Y = g.wy}) end
        end
        return res, "RXP"
    end
    local res = {}
    for _, g in pairs(ns.GY or {}) do
        if g.c == contID then table.insert(res, {name = g.n, X = g.X, Y = g.Y}) end
    end
    return res, "links"
end

-- cimetieres de la table des liens, pour la regle
local function Graveyards(contID)
    local res = {}
    for id, g in pairs(ns.GY or {}) do
        if g.c == contID then
            local lname = strlower(g.n)
            local starter, cityArea
            for k, r in pairs(STARTERS) do if lname:find(k, 1, true) then starter = r end end
            for k, z in pairs(CITY_ONLY) do if lname:find(k, 1, true) then cityArea = z end end
            table.insert(res, {id = id, name = g.n, lname = lname, X = g.X, Y = g.Y, starter = starter, cityArea = cityArea})
        end
    end
    table.sort(res, function(x, y) return x.id < y.id end)
    return res, "links"
end

---------------------------------------------------------------------------
-- Zones et conversions
---------------------------------------------------------------------------
local zoneOf = {}
local function ZoneAt(contMap, u, v)
    if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
    local info = C_Map.GetMapInfoAtPosition(contMap, u, v)
    if not info then return nil end
    local id = info.mapID
    if zoneOf[id] == nil then
        local cur, guard = info, 0
        while cur and cur.parentMapID and cur.parentMapID ~= contMap and guard < 5 do
            local parent = C_Map.GetMapInfo(cur.parentMapID)
            if not parent or parent.mapType == Enum.UIMapType.Continent then break end
            cur, guard = parent, guard + 1
        end
        zoneOf[id] = cur and cur.mapID or false
    end
    return zoneOf[id] or nil
end

local function MapToWorld(mapID, u, v)
    vec:SetXY(u, v)
    local contID, pos = C_Map.GetWorldPosFromMapPos(mapID, vec)
    if pos then return pos.x, pos.y, contID end
end

-- monde -> carte, par les coins de la carte (lineaire). Pas C_Map.GetMapPosFromWorldPos : pour un point hors de
-- la carte demandee, il renvoie sa position sur une AUTRE carte (ex. Dustwallow sur la carte de Felwood).
local corners = {}
local function WorldToMap(contID, X, Y, mapID)
    local c = corners[mapID]
    if c == nil then
        local x0, y0, c0 = MapToWorld(mapID, 0, 0)
        local x1, y1 = MapToWorld(mapID, 1, 1)
        c = (x0 and x1 and x1 ~= x0 and y1 ~= y0) and {x0, y0, x1, y1, c0} or false
        corners[mapID] = c
    end
    if not c or c[5] ~= contID then return nil end
    return (Y - c[2]) / (c[4] - c[2]), (X - c[1]) / (c[3] - c[1])
end

---------------------------------------------------------------------------
-- Regle : cimetieres lies a la zone, le plus proche
---------------------------------------------------------------------------
-- byZone[uiMapID] = liste des cimetieres (index dans gys) lies a cette zone pour cette faction
local function Prepare(contID, faction)
    faction = faction or UnitFactionGroup("player")
    local fid = FACTION_ID[faction] or 0
    local gys = Graveyards(contID)
    local index = {}
    for i, g in ipairs(gys) do index[g.id] = i end
    -- cimetiere reserve a l'autre faction : tous ses liens sont pour l'autre faction (aucun neutre, aucun a moi)
    local okFor, seen = {}, {}
    for _, links in pairs(ns.GYLINKS or {}) do
        for _, l in ipairs(links) do
            seen[l[1]] = true
            if l[2] == 0 or l[2] == fid then okFor[l[1]] = true end
        end
    end
    for _, g in ipairs(gys) do
        if seen[g.id] and not okFor[g.id] then g.foreign = true end
    end
    local byZone = {}
    for uiMap, area in pairs(ns.UIMAP_AREA or {}) do
        local list = {}
        for _, l in ipairs((ns.GYLINKS or {})[area] or {}) do
            local i = index[l[1]]
            if i and (l[2] == 0 or l[2] == fid) then table.insert(list, i) end
        end
        if #list > 0 then byZone[uiMap] = list end
    end
    -- Zones ajoutees par Forever (absentes de la table Classic) : cimetieres appris des morts partagees.
    -- Un point de reapparition = un cimetiere ; sa faction = celle des joueurs qui y sont reapparus.
    local letter = (faction == "Horde") and "H" or "A"
    local learned = {}  -- uiMap -> { {X, Y, factions}, ... }
    local function learn(z, X, Y, f)
        if byZone[z] then return end -- zone deja couverte par la table
        local lst = learned[z] or {}
        learned[z] = lst
        for _, g in ipairs(lst) do
            if (g[1] - X) ^ 2 + (g[2] - Y) ^ 2 < 60 ^ 2 then
                if not g[3]:find(f, 1, true) then g[3] = g[3] .. f end
                return
            end
        end
        table.insert(lst, {X, Y, f})
    end
    for z, lst in pairs(ns.LEARNED or {}) do
        for _, g in ipairs(lst) do
            if g[1] == contID then learn(z, g[2], g[3], g[4]) end
        end
    end
    for _, r in pairs(Deaths()) do
        if r.c == contID and r.z and r.z > 0 and r.z ~= 1414 and r.z ~= 1415 and r.rX then
            learn(r.z, r.rX, r.rY, r.f or "A")
        end
    end
    for z, lst in pairs(learned) do
        local mine = {}
        for _, g in ipairs(lst) do
            local isMine = g[3]:find(letter, 1, true) ~= nil
            table.insert(gys, {id = "L" .. z .. ":" .. math.floor(g[1]) .. ":" .. math.floor(g[2]),
                               name = T("Cimetière appris", "Learned graveyard"), lname = "learned", X = g[1], Y = g[2],
                               foreign = not isMine})
            if isMine then table.insert(mine, #gys) end
        end
        -- seulement les cimetieres ou des joueurs de ma faction sont reapparus
        if #mine > 0 then byZone[z] = mine end
    end
    return gys, byZone
end

local function Choose(gys, byZone, zone, X, Y)
    local area = zone and ns.UIMAP_AREA and ns.UIMAP_AREA[zone]
    local function nearestOf(list, relaxed)
        local best, bestD
        for _, i in ipairs(list) do
            local g = gys[i]
            local d = (g.X - X) ^ 2 + (g.Y - Y) ^ 2
            local okCity = not g.cityArea or g.cityArea == area or relaxed
            local okStart = not g.starter or d <= g.starter ^ 2 or relaxed
            if not g.foreign and okCity and okStart and (not bestD or d < bestD) then best, bestD = i, d end
        end
        return best
    end
    local list = zone and byZone[zone]
    if list then
        local pick = nearestOf(list, false)
        if pick then return pick end
    end
    -- zone sans lien connu (ou seulement des cimetieres de ville / de depart) : le plus proche
    local all = {}
    for i = 1, #gys do all[i] = i end
    return nearestOf(all, false) or nearestOf(all, true)
end

-- Morts reelles qui CONTREDISENT la regle (le joueur est reapparu ailleurs que prevu) : autour de chacune
-- (CONTRA_YARDS), c'est le vrai cimetiere qui compte, sur la carte comme dans la prediction. C'est ce qui
-- corrige les liens que la regle ne peut pas deviner (ex. The Zoram Strand -> Twilight Vale).
-- Les morts conformes a la regle ne changent rien : les bonnes frontieres ne bougent pas.
local CONTRA_YARDS = 350
local CONTRA_CELL = 400
local function Contradictions(contID, faction, gys, byZone)
    local letter = (faction == "Horde") and "H" or "A"
    local hash, n = {}, 0
    for _, r in pairs(Deaths()) do
        -- seulement les morts enregistrees sur une vraie carte de zone (pas la carte du continent)
        if r.c == contID and r.f == letter and r.rX and r.z and r.z ~= 1414 and r.z ~= 1415 and r.z > 0 then
            -- cimetiere reel = celui de la liste le plus proche du point de reapparition
            local real, bestD
            for i, g in ipairs(gys) do
                local d = (g.X - r.rX) ^ 2 + (g.Y - r.rY) ^ 2
                if not bestD or d < bestD then real, bestD = i, d end
            end
            if real and bestD < 150 ^ 2 then
                local rule = Choose(gys, byZone, r.z, r.X, r.Y)
                -- on compare des positions (un meme cimetiere peut exister en double dans la liste)
                local same = rule and (gys[rule].X - gys[real].X) ^ 2 + (gys[rule].Y - gys[real].Y) ^ 2 < 100 ^ 2
                -- TOUTES les morts reelles comptent (la plus proche decide) : une mort conforme a la regle
                -- empeche le cercle d'une mort voisine d'une autre sous-zone de deborder chez elle
                -- (ex. Valley of Trials -> Valley of Trials, a 300 m de The Merchant Coast -> Ratchet).
                -- Seules les morts contradictoires comptent pour la signature et les traits bleus.
                local hx, hy = math.floor(r.X / CONTRA_CELL), math.floor(r.Y / CONTRA_CELL)
                local k = hx .. ":" .. hy
                hash[k] = hash[k] or {}
                table.insert(hash[k], {r.X, r.Y, real, not same})
                if not same then n = n + 1 end
            end
        end
    end
    return {hash = hash, n = n}
end
ns.Contradictions = Contradictions

-- cimetiere impose par une mort contradictoire proche (la plus proche, a moins de CONTRA_YARDS), sinon nil
local function ContraAt(contra, X, Y)
    if not contra or not next(contra.hash) then return nil end
    local hx, hy = math.floor(X / CONTRA_CELL), math.floor(Y / CONTRA_CELL)
    local best, bestD
    for dx = -1, 1 do
        for dy = -1, 1 do
            for _, e in ipairs(contra.hash[(hx + dx) .. ":" .. (hy + dy)] or {}) do
                local d = (e[1] - X) ^ 2 + (e[2] - Y) ^ 2
                if d <= CONTRA_YARDS ^ 2 and (not bestD or d < bestD) then best, bestD = e[3], d end
            end
        end
    end
    return best
end
ns.ContraAt = ContraAt

-- Sur Forever, le cimetiere depend de la SOUS-ZONE (comme le serveur moderne : une sous-zone peut avoir
-- sa propre liste de cimetieres, sinon c'est celle de la zone). Le jeu donne la sous-zone du joueur
-- (GetSubZoneText) : on apprend des morts partagees "zone + sous-zone -> cimetiere" et on s'en sert
-- pour la prediction a l'endroit ou l'on se trouve. (Constate : Barrens / The Merchant Coast -> Ratchet,
-- mais Barrens sans sous-zone, a 100 m du cimetiere de Ratchet -> The Crossroads.)
local function SubzoneTable(contID, faction, gys)
    local letter = (faction == "Horde") and "H" or "A"
    local t = {}
    for _, r in pairs(Deaths()) do
        if r.c == contID and r.f == letter and r.s and r.s ~= "" and r.z and r.z ~= 1414 and r.z ~= 1415 and r.rX then
            local real, bestD
            for i, g in ipairs(gys) do
                local d = (g.X - r.rX) ^ 2 + (g.Y - r.rY) ^ 2
                if not bestD or d < bestD then real, bestD = i, d end
            end
            if real and bestD < 150 ^ 2 then
                local k = r.z .. "|" .. r.s
                t[k] = t[k] or {}
                t[k][real] = (t[k][real] or 0) + 1
            end
        end
    end
    return t
end

-- cimetiere appris pour cette zone + sous-zone (le plus observe), sinon nil
local function SubzoneAt(st, zone, sub)
    if not st or not zone or type(sub) ~= "string" or sub == "" then return nil end
    local votes = st[zone .. "|" .. sub]
    if not votes then return nil end
    local best, n = nil, 0
    for gi, v in pairs(votes) do if v > n then best, n = gi, v end end
    return best
end

---------------------------------------------------------------------------
-- Calcul des lignes DeathSkips (grille -> frontieres -> polylignes -> lignes droites)
---------------------------------------------------------------------------
local function Simplify(pts, tol)
    local n = #pts
    if n <= 2 then return pts end
    local keep = {[1] = true, [n] = true}
    local stack = {{1, n}}
    local tol2 = tol * tol
    while #stack > 0 do
        local seg = table.remove(stack)
        local a, b = seg[1], seg[2]
        local ax, ay, bx, by = pts[a][1], pts[a][2], pts[b][1], pts[b][2]
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local maxD, idx = -1, nil
        for k = a + 1, b - 1 do
            local px, py = pts[k][1], pts[k][2]
            local d
            if len2 == 0 then
                d = (px - ax) ^ 2 + (py - ay) ^ 2
            else
                local t = ((px - ax) * dx + (py - ay) * dy) / len2
                local qx, qy = ax + t * dx, ay + t * dy
                d = (px - qx) ^ 2 + (py - qy) ^ 2
            end
            if d > maxD then maxD, idx = d, k end
        end
        if idx and maxD > tol2 then
            keep[idx] = true
            table.insert(stack, {a, idx})
            table.insert(stack, {idx, b})
        end
    end
    local out = {}
    for k = 1, n do if keep[k] then table.insert(out, pts[k]) end end
    return out
end

local building = {}

local function Build(contID, onDone, faction, sink)
    faction = faction or UnitFactionGroup("player")
    local contMap = CONT_MAP[contID]
    local x0, y0 = MapToWorld(contMap, 0, 0)
    local x1, y1 = MapToWorld(contMap, 1, 1)
    if not x0 or not x1 then
        if sink then sink(nil, "coordonnées de carte indisponibles") end
        return
    end
    local N = math.max(150, math.min(800, math.floor(math.abs(y1 - y0) / CELL_YARDS)))
    local M = math.max(150, math.min(800, math.floor(math.abs(x1 - x0) / CELL_YARDS)))
    local gys, byZone = Prepare(contID, faction)
    local contra = Contradictions(contID, faction, gys, byZone)
    local co = coroutine.create(function()
        local cells, n = {}, 0
        for j = 0, M - 1 do
            local v = (j + 0.5) / M
            for i = 0, N - 1 do
                local u = (i + 0.5) / N
                local zone = ZoneAt(contMap, u, v)
                local gi = 0
                if zone then
                    local X, Y = MapToWorld(contMap, u, v)
                    gi = X and (ContraAt(contra, X, Y) or Choose(gys, byZone, zone, X, Y)) or 0
                end
                cells[j * N + i] = gi
                n = n + 1
                if n % 3000 == 0 then coroutine.yield() end
            end
        end
        -- trous : la carte du continent ne couvre pas les cretes et montagnes entre zones
        -- (le jeu y repond "aucune zone"). Ces cases prennent le cimetiere de la zone la plus
        -- proche, jusqu'a FILL_CELLS cases, pour que les lignes traversent les cretes.
        local FILL_CELLS = 12
        local qi, qd, head = {}, {}, 1
        for idx = 0, N * M - 1 do
            if cells[idx] > 0 then qi[#qi + 1] = idx; qd[#qd + 1] = 0 end
        end
        local steps = 0
        while head <= #qi do
            local idx, d = qi[head], qd[head]
            head = head + 1
            if d < FILL_CELLS then
                local i, j = idx % N, math.floor(idx / N)
                local g = cells[idx]
                if i > 0 and cells[idx - 1] == 0 then cells[idx - 1] = g; qi[#qi + 1] = idx - 1; qd[#qd + 1] = d + 1 end
                if i < N - 1 and cells[idx + 1] == 0 then cells[idx + 1] = g; qi[#qi + 1] = idx + 1; qd[#qd + 1] = d + 1 end
                if j > 0 and cells[idx - N] == 0 then cells[idx - N] = g; qi[#qi + 1] = idx - N; qd[#qd + 1] = d + 1 end
                if j < M - 1 and cells[idx + N] == 0 then cells[idx + N] = g; qi[#qi + 1] = idx + N; qd[#qd + 1] = d + 1 end
            end
            steps = steps + 1
            if steps % 20000 == 0 then coroutine.yield() end
        end
        qi, qd = nil, nil
        -- aretes de frontiere entre sommets de la grille (sommet = i + j*(N+1))
        local W = N + 1
        local ea, eb, adj = {}, {}, {}
        local function addEdge(va, vb)
            local e = #ea + 1
            ea[e], eb[e] = va, vb
            adj[va] = adj[va] or {}; table.insert(adj[va], e)
            adj[vb] = adj[vb] or {}; table.insert(adj[vb], e)
        end
        for j = 0, M - 1 do
            for i = 0, N - 1 do
                local a = cells[j * N + i]
                if a > 0 then
                    if i < N - 1 then
                        local b = cells[j * N + i + 1]
                        if b > 0 and b ~= a then addEdge((i + 1) + j * W, (i + 1) + (j + 1) * W) end
                    end
                    if j < M - 1 then
                        local b = cells[(j + 1) * N + i]
                        if b > 0 and b ~= a then addEdge(i + (j + 1) * W, (i + 1) + (j + 1) * W) end
                    end
                end
            end
            if j % 40 == 0 then coroutine.yield() end
        end
        -- chainage en polylignes
        local used, polys = {}, {}
        local function walk(v0, e0)
            local pts = {{v0 % W, math.floor(v0 / W)}}
            local v, e = v0, e0
            while e and not used[e] do
                used[e] = true
                local w = (ea[e] == v) and eb[e] or ea[e]
                table.insert(pts, {w % W, math.floor(w / W)})
                v, e = w, nil
                local list = adj[v]
                if list and #list == 2 then
                    for _, f in ipairs(list) do if not used[f] then e = f end end
                end
            end
            return pts
        end
        for v, list in pairs(adj) do
            if #list ~= 2 then
                for _, e in ipairs(list) do
                    if not used[e] then table.insert(polys, walk(v, e)) end
                end
            end
        end
        for e = 1, #ea do
            if not used[e] then table.insert(polys, walk(ea[e], e)) end
        end
        coroutine.yield()
        -- lissage + conversion en coordonnees monde
        local segs = {}
        for k, pts in ipairs(polys) do
            local s = Simplify(pts, SIMPLIFY)
            for m = 1, #s - 1 do
                local X1, Y1 = MapToWorld(contMap, s[m][1] / N, s[m][2] / M)
                local X2, Y2 = MapToWorld(contMap, s[m + 1][1] / N, s[m + 1][2] / M)
                if X1 and X2 then
                    table.insert(segs, {math.floor(X1 * 10 + 0.5) / 10, math.floor(Y1 * 10 + 0.5) / 10,
                                        math.floor(X2 * 10 + 0.5) / 10, math.floor(Y2 * 10 + 0.5) / 10})
                end
            end
            if k % 200 == 0 then coroutine.yield() end
        end
        -- croix seulement sur les cimetieres que cette faction peut vraiment atteindre (ceux d'au moins une case)
        local used = {}
        for idx = 0, N * M - 1 do
            local gi = cells[idx]
            if gi and gi > 0 then used[gi] = true end
        end
        local gyOut = {}
        for i, g in ipairs(gys) do
            if used[i] then table.insert(gyOut, {g.X, g.Y, g.name}) end
        end
        -- chaque zone tracee (cases contigues menant au meme cimetiere) : son point le plus interieur,
        -- relie a son esprit guerisseur quand celui-ci est hors de la zone -> {X, Y, gX, gY, nom}
        local dist, q, h = {}, {}, 1
        for idx = 0, N * M - 1 do
            local g = cells[idx]
            if g > 0 then
                local i, j = idx % N, math.floor(idx / N)
                if i == 0 or i == N - 1 or j == 0 or j == M - 1 or cells[idx - 1] ~= g or cells[idx + 1] ~= g
                   or cells[idx - N] ~= g or cells[idx + N] ~= g then
                    dist[idx] = 0; q[#q + 1] = idx
                end
            end
            if idx % 20000 == 0 then coroutine.yield() end
        end
        while h <= #q do
            local idx = q[h]; h = h + 1
            local g, d = cells[idx], dist[idx] + 1
            for _, o in ipairs({idx - 1, idx + 1, idx - N, idx + N}) do
                if cells[o] == g and not dist[o] then dist[o] = d; q[#q + 1] = o end
            end
            if h % 20000 == 0 then coroutine.yield() end
        end
        q = nil
        local comp, arrows, MIN_CELLS = {}, {}, 40
        for start = 0, N * M - 1 do
            local g = cells[start]
            if g > 0 and not comp[start] then
                local stack, size, best = {start}, 0, start
                comp[start] = true
                local gu, gv = WorldToMap(contID, gys[g].X, gys[g].Y, contMap)
                local gcell = gu and (math.floor(gv * M) * N + math.floor(gu * N)) or -1
                local inside = false
                while #stack > 0 do
                    local idx = table.remove(stack)
                    size = size + 1
                    if idx == gcell then inside = true end
                    if (dist[idx] or 0) > (dist[best] or 0) then best = idx end
                    local i = idx % N
                    for _, o in ipairs({i > 0 and idx - 1 or -1, i < N - 1 and idx + 1 or -1, idx - N, idx + N}) do
                        if o >= 0 and o < N * M and cells[o] == g and not comp[o] then comp[o] = true; stack[#stack + 1] = o end
                    end
                    if size % 20000 == 0 then coroutine.yield() end
                end
                if size >= MIN_CELLS and not inside then
                    local X, Y = MapToWorld(contMap, (best % N + 0.5) / N, (math.floor(best / N) + 0.5) / M)
                    if X then
                        table.insert(arrows, {math.floor(X + 0.5), math.floor(Y + 0.5), gys[g].X, gys[g].Y, gys[g].name})
                    end
                end
            end
        end
        dist, comp = nil, nil
        local result = {key = ns.CacheKey(contID, faction), segs = segs, gys = gyOut, arrows = arrows}
        if sink then sink(result) else DB().cache[contID] = result end
    end)
    local ticker
    ticker = C_Timer.NewTicker(0.01, function()
        local ok, err = coroutine.resume(co)
        if not ok then
            ticker:Cancel()
            building[contID] = nil
            Print(T("erreur de calcul : %s", "computation error: %s"), tostring(err))
            if sink then sink(nil, err) end
        elseif coroutine.status(co) == "dead" then
            ticker:Cancel()
            building[contID] = nil
            if onDone then onDone() end
        end
    end)
end

-- Signature de ce qui change les lignes : morts qui contredisent la regle + cimetieres appris.
-- Recalculee seulement quand le nombre de morts partagees change ; les lignes ne sont redessinees
-- que si une mort CHANGE quelque chose (pas a chaque mort conforme a la regle).
local sigMemo = {}
local function DeathSignature(contID, faction)
    local d = 0
    for _, r in pairs(Deaths()) do if r.c == contID then d = d + 1 end end
    local k = contID .. ":" .. faction .. ":" .. (DevMode() and "dev" or "ev")
    local m = sigMemo[k]
    if m and m.d == d then return m.sig end
    local gys, byZone = Prepare(contID, faction)
    local contra = Contradictions(contID, faction, gys, byZone)
    local learned = 0
    for _, g in ipairs(gys) do if g.lname == "learned" then learned = learned + 1 end end
    local sig = contra.n .. "c" .. learned .. "l"
    sigMemo[k] = {d = d, sig = sig}
    return sig
end

function ns.CacheKey(contID, faction)
    faction = faction or UnitFactionGroup("player") or "?"
    local n = 0
    for _ in pairs(ns.GY or {}) do n = n + 1 end
    return fmt("v%d:%s:links:%d:%s", VERSION, faction, n, DeathSignature(contID, faction))
end

-- lignes calculees une fois en jeu (/usf export) puis livrees en dur dans Data/forever_deathskips.lua
local function StaticData(contID, faction)
    local st = ns.forever_deathskips
    faction = faction or UnitFactionGroup("player")
    if not st or st.version ~= VERSION or not st.data or not st.data[faction] then return nil end
    local d = st.data[faction][contID]
    if not (d and d.gys) then return nil end
    return d
end

-- cimetiere de la case (33 m) ou se trouve X, Y : grille construite hors du jeu (Data/forever_grid.lua)
local TILE = 1600 / 3
local rowCache = {}
-- valeur de la case (33 m) ou se trouve X, Y dans une grille RLE (rows[ligne] = "valeur:longueur,...")
local function RLEAt(rows, cacheKey, X, Y)
    if not (rows and X) then return nil end
    local r = math.floor((32 - X / TILE) * 16)
    local k = math.floor((32 - Y / TILE) * 16)
    local key = cacheKey .. ":" .. r
    local row = rowCache[key]
    if row == nil then
        row = false
        if rows[r] then
            row = {}
            local col = 0
            for part in rows[r]:gmatch("[^,]+") do
                local v, n = part:match("^(%d+):(%d+)$")
                if not v then v, n = part, 1 end
                v, n = tonumber(v), tonumber(n)
                row[#row + 1] = {col, col + n - 1, v}
                col = col + n
            end
        end
        rowCache[key] = row
    end
    if not row then return nil end
    for _, run in ipairs(row) do
        if k >= run[1] and k <= run[2] then return run[3] end
    end
end

local function GridGY(contID, X, Y, faction)
    faction = faction or UnitFactionGroup("player")
    local grid, st = ns.forever_grid, StaticData(contID, faction)
    if not (grid and grid.version == VERSION and grid.data[faction] and st) then return nil end
    local v = RLEAt(grid.data[faction][contID], faction .. contID, X, Y)
    local gy = v and v > 0 and st.gys[v]
    return gy and {name = gy[3], X = gy[1], Y = gy[2]} or nil
end
ns.GridGY = GridGY

-- sous-zone officielle (areaId) de la case, et son nom dans la langue du jeu
local function GridArea(contID, X, Y)
    local grid = ns.forever_grid
    if not (grid and grid.version == VERSION and grid.areas) then return nil end
    local a = RLEAt(grid.areas[contID], "area" .. contID, X, Y)
    if not a or a == 0 then return nil end
    local name = C_Map.GetAreaInfo and C_Map.GetAreaInfo(a)
    return a, name
end
ns.GridArea = GridArea

local function DeathData(contID, onReady)
    -- joueurs : uniquement les lignes livrees avec l'addon, jamais de calcul
    do return StaticData(contID), "static" end
    local c = DB().cache[contID]
    if c and c.key == ns.CacheKey(contID) then return c end
    if not building[contID] then
        building[contID] = true
        Build(contID, onReady)
    end
end

---------------------------------------------------------------------------
-- Dessin (meme style que l'original : lignes fines + croix)
---------------------------------------------------------------------------
local canvas = WorldMapFrame:GetCanvas()
local overlay = CreateFrame("Frame", nil, canvas)
overlay:SetAllPoints(canvas)
overlay:SetFrameLevel(15000)
local status = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
status:SetPoint("TOP", 0, -50)

local pools = {unstuck = {lines = {}, marks = {}}, death = {lines = {}, marks = {}}, dots = {lines = {}, marks = {}},
               arrows = {lines = {}, marks = {}}}
COLORS.arrows = {1, 0.85, 0.3, 0.55}
pools.subz = {lines = {}, marks = {}}
COLORS.subz = {1, 1, 1, 0.75}
COLORS.subzd = {1, 1, 1, 0.5}
pools.splits = {lines = {}, marks = {}}
pools.names = {lines = {}, marks = {}}
pools.subzd = {lines = {}, marks = {}}
COLORS.splits = {1, 0.12, 0.12, 0.95}   -- rouge : une meme aire partagee entre deux cimetieres

-- Morts reelles proches (moins de EVIDENCE_YARDS, meme continent et faction) : cimetiere majoritaire.
-- Elles priment sur la regle : la carte se corrige toute seule avec les donnees des joueurs.
local EVIDENCE_YARDS = 45
local gyNameCache = {}
local function RespawnGraveyard(c, rX, rY)
    local key = c .. ":" .. rX .. ":" .. rY
    if gyNameCache[key] ~= nil then return gyNameCache[key] or nil end
    local raw = RawGraveyards(c)
    local best, bestD
    for _, g in ipairs(raw) do
        local d = (g.X - rX) ^ 2 + (g.Y - rY) ^ 2
        if not bestD or d < bestD then best, bestD = g, d end
    end
    local name = (best and bestD < 250 ^ 2) and best.name or false
    gyNameCache[key] = name
    return name or nil
end

function ns.Evidence(contID, X, Y, faction)
    local f = (faction or UnitFactionGroup("player")) == "Horde" and "H" or "A"
    local votes, total = {}, 0
    for _, r in pairs(Deaths()) do
        if r.c == contID and r.f == f and (r.X - X) ^ 2 + (r.Y - Y) ^ 2 <= EVIDENCE_YARDS ^ 2 then
            local g = RespawnGraveyard(r.c, r.rX, r.rY)
            if g then votes[g] = (votes[g] or 0) + 1; total = total + 1 end
        end
    end
    local best, n = nil, 0
    for g, v in pairs(votes) do if v > n then best, n = g, v end end
    return best, n, total
end
ns.OnSharedDeath = function() end

local function PoolLine(kind, i)
    local p = pools[kind].lines
    if not p[i] then
        local l = overlay:CreateLine(nil, "OVERLAY")
        l:SetTexture("interface/buttons/white8x8")
        l:SetThickness(pools[kind].thick or 2)
        l:SetVertexColor(unpack(COLORS[kind]))
        p[i] = l
    end
    return p[i]
end

-- esprits guerisseurs : style, taille, couleur (options)
local MARK_COLORS = {red = {1, 0.15, 0.15}, white = {1, 1, 1}, yellow = {1, 0.85, 0.1}, green = {0.3, 1, 0.3}, blue = {0.3, 0.75, 1}}
local function StyleMark(t)
    local db = DB()
    local size = db.markSize or 11
    local atlasOK = db.markStyle == "healer" and t.SetAtlas and C_Texture and C_Texture.GetAtlasInfo
                    and C_Texture.GetAtlasInfo("poi-graveyard-neutral")
    if atlasOK then
        t:SetAtlas("poi-graveyard-neutral")
        t:SetVertexColor(1, 1, 1, 1)
        t:SetSize(size * 1.4, size * 1.4)
    else
        t:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\icon_x_white.tga")
        t:SetTexCoord(0, 1, 0, 1)
        local c = MARK_COLORS[db.markColor or "red"] or MARK_COLORS.red
        t:SetVertexColor(c[1], c[2], c[3], 1)
        t:SetSize(size, size)
    end
end

local function PoolMark(kind, i)
    local p = pools[kind].marks
    if not p[i] then
        local t = overlay:CreateTexture(nil, "OVERLAY", nil, 4)
        if kind == "death" then
            StyleMark(t)
        else
            t:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\icon_x.blp")
            t:SetSize(15, 15)
            t:SetVertexColor(unpack(COLORS.unstuck))
        end
        p[i] = t
    end
    return p[i]
end
local function RestyleMarks()
    for _, t in ipairs(pools.death.marks) do StyleMark(t) end
end

-- noms des esprits guerisseurs (cartes de zone)
local function PoolName(i)
    local p = pools.names.marks
    if not p[i] then
        local fs = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
        p[i] = fs
    end
    return p[i]
end

local function PoolDot(i)
    local p = pools.dots.marks
    if not p[i] then
        local t = overlay:CreateTexture(nil, "OVERLAY", nil, 5)
        t:SetTexture("interface/buttons/white8x8")
        t:SetSize(4, 4)
        t:SetVertexColor(0.3, 0.8, 1, 0.9)
        p[i] = t
    end
    return p[i]
end

-- on ne cache que les elements en trop (ceux du dessin precedent qui ne servent plus)
local function Finish(kind, nLines, nMarks)
    local p = pools[kind]
    for i = nLines + 1, (p.usedL or 0) do p.lines[i]:Hide() end
    for i = nMarks + 1, (p.usedM or 0) do p.marks[i]:Hide() end
    p.usedL, p.usedM = nLines, nMarks
end
local function HideKind(kind) Finish(kind, 0, 0) end

-- decoupe [a,b] dans le carre [0,1] (Liang-Barsky), sans creer de table
local function edge(pp, q, t0, t1)
    if pp == 0 then
        if q < 0 then return nil end
        return t0, t1
    end
    local t = q / pp
    if pp < 0 then
        if t > t1 then return nil end
        if t > t0 then t0 = t end
    else
        if t < t0 then return nil end
        if t < t1 then t1 = t end
    end
    return t0, t1
end
local function Clip(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local t0, t1 = edge(-dx, ax, 0, 1);      if not t0 then return nil end
    t0, t1 = edge(dx, 1 - ax, t0, t1);       if not t0 then return nil end
    t0, t1 = edge(-dy, ay, t0, t1);          if not t0 then return nil end
    t0, t1 = edge(dy, 1 - ay, t0, t1);       if not t0 then return nil end
    return ax + t0 * dx, ay + t0 * dy, ax + t1 * dx, ay + t1 * dy
end

-- positions normalisees (0..1, deja decoupees) par calque, carte et jeu de donnees : calculees une seule fois
local EMPTY = {}
local normCache = {}
local function Normalized(kind, contID, mapID, segs, marks)
    local byKind = normCache[kind]
    if not byKind then byKind = {}; normCache[kind] = byKind end
    local key = mapID .. tostring(segs) .. tostring(marks)
    local c = byKind[key]
    if c then return c end
    local L, M = {}, {}
    for _, sg in ipairs(segs) do
        local ax, ay = WorldToMap(contID, sg[1], sg[2], mapID)
        local bx, by = WorldToMap(contID, sg[3], sg[4], mapID)
        if ax and bx then
            local cx, cy, ex, ey = Clip(ax, ay, bx, by)
            if cx then
                local n = #L
                L[n + 1], L[n + 2], L[n + 3], L[n + 4] = cx, cy, ex, ey
            end
        end
    end
    for _, g in ipairs(marks) do
        local x, y = WorldToMap(contID, g[1], g[2], mapID)
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            M[#M + 1], M[#M + 2] = x, y
        end
    end
    c = {L, M}
    byKind[key] = c
    return c
end

local function DrawSet(kind, contID, mapID, segs, marks, thick)
    local c = Normalized(kind, contID, mapID, segs or EMPTY, marks or EMPTY)
    local p = pools[kind]
    if thick and p.thick ~= thick then
        p.thick = thick
        for _, l in ipairs(p.lines) do l:SetThickness(thick) end
    end
    local w, h = overlay:GetSize()
    local L, M = c[1], c[2]
    local n = 0
    for i = 1, #L, 4 do
        n = n + 1
        local l = PoolLine(kind, n)
        l:SetStartPoint("TOPLEFT", overlay, L[i] * w, -L[i + 1] * h)
        l:SetEndPoint("TOPLEFT", overlay, L[i + 2] * w, -L[i + 3] * h)
        l:Show()
    end
    local k = 0
    for i = 1, #M, 2 do
        k = k + 1
        local t = PoolMark(kind, k)
        t:ClearAllPoints()
        t:SetPoint("CENTER", overlay, "TOPLEFT", M[i] * w, -M[i + 1] * h)
        t:Show()
    end
    Finish(kind, n, k)
end

local DASH, GAPLEN = 6, 5
local function DrawDashed(kind, contID, mapID, segs, thick)
    local c = Normalized(kind, contID, mapID, segs or EMPTY, EMPTY)
    local p = pools[kind]
    if thick and p.thick ~= thick then
        p.thick = thick
        for _, l in ipairs(p.lines) do l:SetThickness(thick) end
    end
    local w, h = overlay:GetSize()
    local L = c[1]
    local n = 0
    for i = 1, #L, 4 do
        local ax, ay, bx, by = L[i] * w, -L[i + 1] * h, L[i + 2] * w, -L[i + 3] * h
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            local ux, uy = dx / len, dy / len
            local t = 0
            while t < len do
                local e = math.min(t + DASH, len)
                n = n + 1
                local l = PoolLine(kind, n)
                l:SetStartPoint("TOPLEFT", overlay, ax + ux * t, ay + uy * t)
                l:SetEndPoint("TOPLEFT", overlay, ax + ux * e, ay + uy * e)
                l:Show()
                t = t + DASH + GAPLEN
            end
        end
    end
    Finish(kind, n, 0)
end

-- donnees UnstuckSkips d'origine : partitions {Y1,X1,Y2,X2}, cibles {Y,X,nom}
local function UnstuckData(contID)
    local parts = contID == 0 and ns.eastern_kingdom_partitions or ns.kalimdor_partitions
    local locs = contID == 0 and ns.eastern_kingdom_locs or ns.kalimdor_locs
    local segs, marks = {}, {}
    for _, p in ipairs(parts or {}) do table.insert(segs, {p[2], p[1], p[4], p[3]}) end
    for _, l in ipairs(locs or {}) do table.insert(marks, {l[2], l[1], l[3]}) end
    return segs, marks
end
local unstuckCache = {}

-- factions affichees : option viewFaction (Alliance, Horde, both) ; par defaut la sienne
-- choix RELATIF (compte entier, valable pour tous les persos) : nil = ma faction, "other" = l'autre, "both" = les deux
local function ViewFactions()
    local v = DB().viewFaction
    local mine = UnitFactionGroup("player") or "Alliance"
    if v == "both" then return {"Alliance", "Horde"} end
    if v == "other" then return {mine == "Horde" and "Alliance" or "Horde"} end
    return {mine}
end
-- faction affichee sous forme absolue (pour les boutons des options)
local function ViewSelection()
    local l = ViewFactions()
    return #l == 2 and "both" or l[1]
end
-- bordures exactes (escaliers des cases de 33 m) : Data/forever_exact.lua, option exactBorders
local function ExactData(contID, faction)
    local ex = ns.forever_exact
    if not (ex and ex.version == VERSION and ex.data and ex.data[faction]) then return nil end
    return ex.data[faction][contID]
end
local exactMerged = {}
local function WithExact(d, contID, faction)
    if not (d and DB().exactBorders) then return d end
    local x = ExactData(contID, faction)
    if not x then return d end
    local key = contID .. ":" .. faction
    local m = exactMerged[key]
    if not m or m.base ~= d then
        -- rouge (partage au plus proche) : la vraie frontiere est la mediatrice entre les deux cimetieres, une ligne
        -- droite (le serveur mesure la distance depuis la position exacte) -> lignes lissees, pas les escaliers.
        -- blanc (bords de sous-zones) : escaliers exacts des cases
        m = {base = d, gys = d.gys, splits = d.splits, solid = x.solid, dash = x.dash}
        exactMerged[key] = m
    end
    return m
end

local combined = {}
local function ViewData(contID)
    local list = ViewFactions()
    if #list == 1 then return WithExact(StaticData(contID, list[1]), contID, list[1]) end
    local key = contID .. ":both" .. (DB().exactBorders and ":x" or "")
    if combined[key] then return combined[key] end
    local a, h = WithExact(StaticData(contID, "Alliance"), contID, "Alliance"), WithExact(StaticData(contID, "Horde"), contID, "Horde")
    if not (a and h) then return a or h end
    local gys, seen, splits, solid, dash = {}, {}, {}, {}, {}
    for _, d in ipairs({a, h}) do
        for _, g in ipairs(d.gys) do
            local k = math.floor(g[1] / 20) .. ":" .. math.floor(g[2] / 20)
            if not seen[k] then seen[k] = true; gys[#gys + 1] = g end
        end
        for _, sg in ipairs(d.splits or EMPTY) do splits[#splits + 1] = sg end
        for _, sg in ipairs(d.solid or EMPTY) do solid[#solid + 1] = sg end
        for _, sg in ipairs(d.dash or EMPTY) do dash[#dash + 1] = sg end
    end
    combined[key] = {gys = gys, splits = splits, solid = solid, dash = dash}
    return combined[key]
end

local Redraw
local lastKey
local used = {}
local function HideUnused()
    for kind in pairs(pools) do
        if not used[kind] then HideKind(kind) end
    end
end
function Redraw()
    if not WorldMapFrame:IsShown() then return end   -- carte fermee : rien (le calque est cache avec elle)
    local db = DB()
    local mapID = WorldMapFrame:GetMapID()
    local contID = mapID and mapID ~= AZEROTH and select(3, MapToWorld(mapID, 0.5, 0.5))
    wipe(used)
    if contID ~= 0 and contID ~= 1 then
        status:SetText("")
        HideUnused()
        lastKey = nil
        return
    end
    -- rien n'a change (meme carte, meme taille, memes options) : rien a faire
    local w, h = overlay:GetSize()
    local key = table.concat({mapID, math.floor(w + 0.5), math.floor(h + 0.5), tostring(db.unstuck), tostring(db.death),
                              tostring(db.showSubzones), tostring(db.showSplits), tostring(db.showDashed), tostring(db.exactBorders), tostring(db.showMarkers),
                              tostring(db.showDeaths), #Deaths(),
                              tostring(db.markStyle), tostring(db.markSize), tostring(db.markColor), tostring(db.markNames),
                              UnitFactionGroup("player") or "", tostring(db.viewFaction)}, ":")
    if key == lastKey then return end
    lastKey = key
    status:SetText("")
    local zoneMap = not CONTINENTS[mapID]
    if db.unstuck then
        unstuckCache[contID] = unstuckCache[contID] or {UnstuckData(contID)}
        DrawSet("unstuck", contID, mapID, unstuckCache[contID][1], unstuckCache[contID][2])
        used.unstuck = true
    end
    if db.death then
        local data = ViewData(contID)
        if data then
            -- sous-zones officielles (cartes de zone ; sur le continent, ~3000 traits ralentiraient le zoom)
            -- plein : le cimetiere change de part et d'autre ; pointilles : frontiere sans effet sur le cimetiere
            if zoneMap and db.showSubzones ~= false then
                DrawSet("subz", contID, mapID, data.solid or EMPTY, EMPTY, 1.5)
                used.subz = true
                if db.showDashed ~= false then   -- bordures sans effet (option, affichees par defaut)
                    DrawDashed("subzd", contID, mapID, data.dash or EMPTY, 0.8)
                    used.subzd = true
                end
            end
            -- partage a l'interieur d'une meme aire (zone nue servie par plusieurs cimetieres : le plus proche), en rouge
            if db.showSplits ~= false and data.splits then
                DrawSet("splits", contID, mapID, data.splits, EMPTY, zoneMap and 2.6 or 1.6)
                used.splits = true
            end
            -- croix : cimetieres que ma faction peut atteindre
            if db.showMarkers ~= false then
                DrawSet("death", contID, mapID, EMPTY, data.gys)
                used.death = true
                -- noms sous les croix (cartes de zone seulement)
                if db.markNames and zoneMap then
                    local k = 0
                    for _, g in ipairs(data.gys) do
                        local x, y = WorldToMap(contID, g[1], g[2], mapID)
                        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                            k = k + 1
                            local fs = PoolName(k)
                            fs:SetText(g[3]:match(",%s*(.+)$") or g[3])
                            fs:ClearAllPoints()
                            fs:SetPoint("TOP", overlay, "TOPLEFT", x * w, -y * h - (db.markSize or 11) * 0.6)
                            fs:Show()
                        end
                    end
                    Finish("names", 0, k)
                    used.names = true
                end
            end
            -- morts reelles (points bleus) : celles livrees avec l'addon (Data/evidence.lua), les memes pour tous ;
            -- pas celles recues en direct sur ce PC. Seulement si l'option est cochee (desactivee par defaut)
            if db.showDeaths then
                local f = UnitFactionGroup("player") == "Horde" and "H" or "A"
                local k = 0
                for _, r in ipairs(Deaths()) do
                    if r.c == contID and r.f == f and k < 2500 then
                        local x, y = WorldToMap(contID, r.X, r.Y, mapID)
                        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                            k = k + 1
                            local t = PoolDot(k)
                            t:ClearAllPoints()
                            t:SetPoint("CENTER", overlay, "TOPLEFT", x * w, -y * h)
                            t:Show()
                        end
                    end
                end
                Finish("dots", 0, k)
                used.dots = true
            end
        else
            status:SetText(T("Deathskip : pas de données pour cette version.",
                             "Deathskip: no data for this version."))
        end
    end
    HideUnused()
end

-- un seul redessin par image, meme si plusieurs evenements arrivent ensemble (ouverture : OnShow + OnMapChanged...)
local redrawPending = false
local function RequestRedraw()
    if redrawPending then return end
    redrawPending = true
    C_Timer.After(0, function() redrawPending = false; Redraw() end)
end
hooksecurefunc(WorldMapFrame, "OnMapChanged", RequestRedraw)
WorldMapFrame:HookScript("OnShow", RequestRedraw)
canvas:HookScript("OnSizeChanged", RequestRedraw)

---------------------------------------------------------------------------
-- Boutons sur la carte (comme l'original)
---------------------------------------------------------------------------
local function MakeToggle(yOff, key, showText, hideText)
    local b = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
    b:SetSize(130, 20)
    b:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -60, yOff)
    b:SetFrameStrata("DIALOG")
    b:SetFrameLevel(500)
    local function label() b:SetText(DB()[key] and hideText or showText) end
    b:SetScript("OnClick", function()
        DB()[key] = not DB()[key]
        label()
        Redraw()
    end)
    b.Label = label
    return b
end
-- (les anciens boutons Show/Hide sont remplaces par le menu de la carte, en fin de fichier)
local mapMenuRefresh = function() end
local unstuckBtn = {Label = function() mapMenuRefresh() end}
local deathBtn = unstuckBtn

---------------------------------------------------------------------------
-- Indicateur (comme l'original + cible DeathSkip Forever)
---------------------------------------------------------------------------
local notifier = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
notifier:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -412, -30)   -- position par defaut (choisie par Bellucci)
notifier:Hide()
notifier:SetSize(190, 46)
notifier:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
notifier:SetBackdropColor(0, 0, 0, 0.7)
notifier:SetBackdropBorderColor(0.45, 0.45, 0.45, 0.9)
notifier:SetMovable(true)
notifier:EnableMouse(true)
notifier:SetClampedToScreen(true)
notifier:SetScript("OnMouseDown", function(self) self:StartMoving() end)
notifier:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    DB().pos = {p, rp, x, y}
end)
-- logo de l'addon + "Deathskips", et dessous le cimetiere en vert
local hudIcon = notifier:CreateTexture(nil, "ARTWORK")
hudIcon:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\icon.tga")
hudIcon:SetSize(32, 32)
hudIcon:SetPoint("LEFT", 7, 0)
local hudTitle = notifier:CreateFontString(nil, "ARTWORK", "GameFontNormal")
hudTitle:SetPoint("TOPLEFT", hudIcon, "TOPRIGHT", 8, -1)
hudTitle:SetText("Deathskips")
local tDeath = notifier:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
tDeath:SetPoint("TOPLEFT", hudTitle, "BOTTOMLEFT", 0, -3)
tDeath:SetTextColor(0.5, 1, 0.5)
tDeath:SetJustifyH("LEFT")
local tUnstuck = {SetText = function() end}   -- (l'ancien indicateur UnstuckSkip n'est plus affiche)
-- icone "deathskip" de RestedXP (meme texture, meme decoupe selon la version du client que RXPGuides)
local DEATH_ICON
do
    local build = select(4, GetBuildInfo()) or 0
    if build > 50000 or (WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) then
        DEATH_ICON = "|TInterface/MINIMAP/POIICONS:%d:%d:0:0:128:128:72:81:0:4|t"
    elseif build > 30000 then
        DEATH_ICON = "|TInterface/MINIMAP/POIICONS:%d:%d:0:0:128:128:72:81:0:9|t"
    else
        DEATH_ICON = "|TInterface/MINIMAP/POIICONS:%d:%d:0:0:128:128:112:128:0:16|t"
    end
end
ns.DeathIcon = function(size) return fmt(DEATH_ICON, size, size) end
-- croix pour fermer l'encadre (on le remet par le menu de la carte, les options ou /usf notifier)
local hudClose = CreateFrame("Button", nil, notifier, "UIPanelCloseButton")
hudClose:SetSize(20, 20)
hudClose:SetPoint("TOPRIGHT", notifier, "TOPRIGHT", 1, 1)
hudClose:SetScript("OnClick", function()
    DB().showNotifier = false
    notifier:Hide()
    print(fmt("|cff3be07aDeathskip|r: %s", T("encadré masqué. Pour le remettre : menu Deathskip de la carte, ou /usf notifier.",
                                             "box hidden. To show it again: Deathskip menu on the world map, or /usf notifier.")))
    if mapMenuRefresh then mapMenuRefresh() end
end)
hudClose:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(T("Masquer l'encadré", "Hide this box"))
    GameTooltip:Show()
end)
hudClose:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function FitHud()
    notifier:SetWidth(math.max(150, 7 + 32 + 8 + math.max(hudTitle:GetStringWidth(), tDeath:GetStringWidth()) + 26))
end

local function PlayerWorld()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local contID, wp = C_Map.GetWorldPosFromMapPos(map, pos)
    if wp then return wp.x, wp.y, contID end
end

local prepared = {}
local function UpdateNotifier()
    local db = DB()
    if not db.showNotifier then notifier:Hide() return end
    notifier:Show()
    local X, Y, contID = PlayerWorld()
    if not X or (contID ~= 0 and contID ~= 1) then
        tDeath:SetText("—"); FitHud()
        return
    end
    -- unstuck : point le plus proche (comme l'original)
    local locs = contID == 0 and ns.eastern_kingdom_locs or ns.kalimdor_locs
    local best, bestD
    for _, v in ipairs(locs or {}) do
        local d = (X - v[2]) ^ 2 + (Y - v[1]) ^ 2
        if not bestD or d < bestD then best, bestD = v[3], d end
    end
    tUnstuck:SetText(best or "—")
    -- death skip Forever : la grille ("Ratchet (The Barrens)") ; mais si le joueur est dans une autre zone que celle
    -- de la carte a cet endroit (tunnels d'Uldaman sous Stonesplinter Valley, Undercity...), le cimetiere observe
    -- pour cette zone (Data/layers.lua)
    do
        local g
        if ns.LAYERS then
            local area = GridArea(contID, X, Y)
            local zm = C_Map.GetBestMapForUnit("player")
            while zm do
                local info = C_Map.GetMapInfo(zm)
                if not info or info.mapType < 3 then zm = nil break end
                if info.mapType == 3 then break end
                zm = info.parentMapID
            end
            local f = UnitFactionGroup("player") == "Horde" and "H" or "A"
            local L = area and zm and ns.LAYERS[f .. ":" .. zm .. ":" .. area]
            if L then
                local name = RespawnGraveyard(L.c, L.rX, L.rY)
                if name then g = {name = name} end
            end
        end
        g = g or GridGY(contID, X, Y)
        local txt = "—"
        if g then
            local zoneName, place = g.name:match("^(.-),%s*(.+)$")
            txt = place and fmt("%s |cff9a9a9a(%s)|r", place, zoneName) or g.name
            txt = ns.DeathIcon(14) .. " " .. txt
        end
        if tDeath:GetText() ~= txt then
            tDeath:SetText(txt)
            FitHud()
        end
        return
    end
    local key = ns.CacheKey(contID)
    if not prepared[contID] or prepared[contID].key ~= key then
        local gys, byZone = Prepare(contID)
        prepared[contID] = {key = key, gys = gys, byZone = byZone,
                            contra = Contradictions(contID, UnitFactionGroup("player"), gys, byZone),
                            subz = SubzoneTable(contID, UnitFactionGroup("player"), gys)}
    end
    local p = prepared[contID]
    local u, v = WorldToMap(contID, X, Y, CONT_MAP[contID])
    local zone = u and ZoneAt(CONT_MAP[contID], u, v)
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local gi = SubzoneAt(p.subz, zone, sub) or ContraAt(p.contra, X, Y) or Choose(p.gys, p.byZone, zone, X, Y)
    local ev, n = ns.Evidence(contID, X, Y)
    if ev then
        tDeath:SetText(fmt("%s |cff4dccff(%d)|r", ev, n))
    else
        tDeath:SetText(gi and p.gys[gi].name or "—")
    end
end

---------------------------------------------------------------------------
-- Journal des morts : position de la mort + prediction, puis point de reapparition reel
-- (lu ensuite dans le fichier SavedVariables pour corriger la regle)
---------------------------------------------------------------------------
local function Predict(contID, X, Y)
    do return GridGY(contID, X, Y) end
    local key = ns.CacheKey(contID)
    if not prepared[contID] or prepared[contID].key ~= key then
        local gys, byZone = Prepare(contID)
        prepared[contID] = {key = key, gys = gys, byZone = byZone,
                            contra = Contradictions(contID, UnitFactionGroup("player"), gys, byZone),
                            subz = SubzoneTable(contID, UnitFactionGroup("player"), gys)}
    end
    local p = prepared[contID]
    local u, v = WorldToMap(contID, X, Y, CONT_MAP[contID])
    local zone = u and ZoneAt(CONT_MAP[contID], u, v)
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local gi = SubzoneAt(p.subz, zone, sub) or ContraAt(p.contra, X, Y) or Choose(p.gys, p.byZone, zone, X, Y)
    return gi and p.gys[gi], zone, p.gys
end

local function Round(n) return n and math.floor(n * 10 + 0.5) / 10 end

local pendingDeath
local function OnDeath()
    local X, Y, contID = PlayerWorld()
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local d = {
        time = date("%Y-%m-%d %H:%M:%S"), faction = UnitFactionGroup("player"), level = UnitLevel("player"),
        cont = contID, X = Round(X), Y = Round(Y), map = map,
        mapX = pos and Round(pos.x * 100), mapY = pos and Round(pos.y * 100),
        zoneText = GetZoneText(), subzoneText = GetSubZoneText(),
    }
    if X and (contID == 0 or contID == 1) then
        local g = Predict(contID, X, Y)
        d.predicted = g and g.name
        d.predictedX, d.predictedY = g and Round(g.X), g and Round(g.Y)
    end
    pendingDeath = d
end

local function OnGhost()
    local d = pendingDeath
    if not d or not UnitIsGhost("player") then return end
    pendingDeath = nil
    local X, Y, contID = PlayerWorld()
    d.respawnX, d.respawnY, d.respawnCont = Round(X), Round(Y), contID
    d.respawnZoneText, d.respawnSubzoneText = GetZoneText(), GetSubZoneText()
    -- cimetiere le plus proche du point de reapparition = cimetiere reel
    if X and (contID == 0 or contID == 1) then
        local raw = RawGraveyards(contID)
        local best, bestD
        for _, g in ipairs(raw) do
            local dd = (g.X - X) ^ 2 + (g.Y - Y) ^ 2
            if not bestD or dd < bestD then best, bestD = g, dd end
        end
        d.actual = best and best.name
        d.actualDist = bestD and Round(math.sqrt(bestD))
    end
    -- juste si meme nom, ou (prediction par la regle) si le cimetiere predit est la ou on reapparait
    d.ok = (d.predicted ~= nil and d.predicted == d.actual) or
               (not d.predictedFromDeaths and d.predictedX ~= nil and X ~= nil and
                   (d.predictedX - X) ^ 2 + (d.predictedY - Y) ^ 2 < 120 ^ 2)
    local db = DB()
    db.deaths = db.deaths or {}
    table.insert(db.deaths, d)
    while #db.deaths > 300 do table.remove(db.deaths, 1) end
    if ns.Share then pcall(ns.Share.QueueOwnDeath, ns.Share, d) end
    if d.actual then
        if d.ok then
            Print(T("mort enregistrée : |cff40ff40prédiction correcte|r (%s).",
                    "death logged: |cff40ff40prediction correct|r (%s)."), d.actual)
        else
            Print(T("mort enregistrée : |cffff4040prédiction fausse|r, prévu %s, réel %s. Merci, c'est noté pour la correction.",
                    "death logged: |cffff4040prediction wrong|r, expected %s, got %s. Thanks, saved for the fix."),
                  tostring(d.predicted), d.actual)
        end
    end
end

---------------------------------------------------------------------------
-- Survol de la carte : "si tu meurs ici -> tel cimetiere (pourquoi)"
---------------------------------------------------------------------------
-- infobulle fixe en haut a gauche de la carte (hors du canevas : pas zoomee avec la carte)
local mapBox = WorldMapFrame.ScrollContainer or WorldMapFrame
local tip = CreateFrame("Frame", nil, mapBox, "BackdropTemplate")
tip:SetFrameStrata("TOOLTIP")
tip:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
tip:SetBackdropColor(0, 0, 0, 0.8)
tip:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
tip:Hide()
local hoverText = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
hoverText:SetFont(STANDARD_TEXT_FONT, 17, "")
local tipFontSize = 17
hoverText:SetSpacing(3)
hoverText:SetJustifyH("LEFT")
hoverText:SetPoint("TOPLEFT", 10, -8)
hoverText:Hide()
local hoverLine = overlay:CreateLine(nil, "OVERLAY", nil, 6)
hoverLine:SetTexture("interface/buttons/white8x8")
hoverLine:SetThickness(2)
hoverLine:SetVertexColor(0.4, 1, 0.4, 0.9)
hoverLine:Hide()
local lastU, lastV, lastMap
hooksecurefunc(hoverText, "Hide", function() hoverLine:Hide(); tip:Hide(); lastU = nil end)
local hoverElapsed = 0
overlay:SetScript("OnUpdate", function(_, elapsed)
    hoverElapsed = hoverElapsed + elapsed
    if hoverElapsed < 0.1 then return end
    hoverElapsed = 0
    local db = DB()
    if not db.death or db.hoverTip == false or not WorldMapFrame:IsShown() or not canvas:IsMouseOver() then hoverText:Hide() return end
    -- taille responsive : proportionnelle a la largeur de la carte (pleine carte ~1500 px = taille choisie)
    local mw = mapBox:GetWidth() or 1500
    local want = math.floor((db.tipSize or 17) * math.max(0.55, math.min(1, mw / 1500)) + 0.5)
    if want ~= tipFontSize then
        tipFontSize = want
        hoverText:SetFont(STANDARD_TEXT_FONT, tipFontSize, "")
        lastU = nil
    end
    local mapID = WorldMapFrame:GetMapID()
    if not mapID or mapID == AZEROTH or not WorldMapFrame.GetNormalizedCursorPosition then hoverText:Hide() return end
    local u, v = WorldMapFrame:GetNormalizedCursorPosition()
    if not u or u < 0 or u > 1 or v < 0 or v > 1 then hoverText:Hide() return end
    if u == lastU and v == lastV and mapID == lastMap then return end
    lastU, lastV, lastMap = u, v, mapID
    local X, Y, contID = MapToWorld(mapID, u, v)
    if not X or (contID ~= 0 and contID ~= 1) then hoverText:Hide() return end
    local mine = UnitFactionGroup("player")
    local facs = ViewFactions()
    local lines, g = {}, nil
    for _, f in ipairs(facs) do
        local gf = GridGY(contID, X, Y, f)
        if gf then
            if not g or f == mine then g = gf end
            -- nom du cimetiere : "Crossroads (Wetlands)" plutot que "Wetlands, Crossroads" (homonymes : Barrens / Wetlands)
            local zoneName, place = gf.name:match("^(.-),%s*(.+)$")
            local gyName = place and fmt("%s |cffaaaaaa(%s)|r", place, zoneName) or gf.name
            if #facs == 1 and f == mine then
                lines[#lines + 1] = fmt("%s %s |cff80ff80%s|r", T("Réapparition :", "Respawn:"), ns.DeathIcon(tipFontSize), gyName)
            else
                local col = f == "Horde" and "ff5555" or "4da6ff"
                lines[#lines + 1] = fmt("|cff%s%s|r%s : %s |cff80ff80%s|r", col, f == "Horde" and "Horde" or "Alliance",
                                        f == mine and T(" (vous)", " (you)") or "", ns.DeathIcon(tipFontSize), gyName)
            end
        end
    end
    if not g then hoverText:Hide() return end
    local w, h = overlay:GetSize()
    local _, subName = GridArea(contID, X, Y)
    hoverText:SetText(fmt("|cffffd100%s|r\n%s", subName or "?", table.concat(lines, "\n")))
    hoverText:Show()
    local pad = math.max(8, tipFontSize * 0.6)
    hoverText:ClearAllPoints()
    hoverText:SetPoint("TOPLEFT", pad * 0.7, -pad * 0.5)
    tip:SetSize(hoverText:GetStringWidth() + pad * 1.4, hoverText:GetStringHeight() + pad)
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", mapBox, "TOPLEFT", 44, -10)
    tip:Show()
    -- trait vert du curseur jusqu'a l'esprit guerisseur ou l'on reapparaitrait
    local gx, gy = WorldToMap(contID, g.X, g.Y, mapID)
    local cx, cy, dx, dy
    if gx then cx, cy, dx, dy = Clip(u, v, gx, gy) end
    if cx and db.hoverLine ~= false then
        hoverLine:SetStartPoint("TOPLEFT", overlay, cx * w, -cy * h)
        hoverLine:SetEndPoint("TOPLEFT", overlay, dx * w, -dy * h)
        hoverLine:Show()
    else
        hoverLine:Hide()
    end
end)

---------------------------------------------------------------------------
-- Init / commandes
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Deblocages : position juste avant la deconnexion -> position a la reconnexion. Si le personnage a ete
-- deplace (service "personnage bloque", logout skip...), c'est enregistre et partage comme une mort.
-- La derniere position est gardee par personnage (cle GUID, seulement sur ce PC, jamais partagee).
---------------------------------------------------------------------------
local UNSTUCK_MIN = 150   -- m : en dessous, ce n'est pas un deplacement
local function SnapPos()
    local X, Y, c = PlayerWorld()
    if not X or (c ~= 0 and c ~= 1) then return nil end
    local inInst = IsInInstance and IsInInstance()
    return {c = c, X = math.floor(X + 0.5), Y = math.floor(Y + 0.5), z = C_Map.GetBestMapForUnit("player") or 0,
            s = GetSubZoneText and GetSubZoneText() or "", t = GetServerTime and GetServerTime() or time(),
            inst = inInst and true or nil, taxi = (UnitOnTaxi and UnitOnTaxi("player")) and true or nil,
            dead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or nil}
end
local function SavePos()
    local guid = UnitGUID and UnitGUID("player")
    local p = guid and SnapPos()
    if not p then return end
    local db = DB()
    db.lastPos = db.lastPos or {}
    db.lastPos[guid] = p
end
local function RecordUnstuck(old, cur, how)
    local db = DB()
    if old.inst or old.taxi or old.dead or cur.inst or cur.dead then return end
    if old.c ~= cur.c then return end
    local d = math.sqrt((old.X - cur.X) ^ 2 + (old.Y - cur.Y) ^ 2)
    if d < UNSTUCK_MIN then return end
    local r = {f = (UnitFactionGroup("player") == "Horde") and "H" or "A", c = old.c, X = old.X, Y = old.Y,
               rX = cur.X, rY = cur.Y, z = old.z or 0, s = old.s or "", t = cur.t}
    db.unstucks = db.unstucks or {}
    table.insert(db.unstucks, {time = date("%Y-%m-%d %H:%M:%S"), c = r.c, X = r.X, Y = r.Y, rX = r.rX, rY = r.rY,
                               z = r.z, s = r.s, offline = (cur.t or 0) - (old.t or 0), dist = math.floor(d), how = how})
    while #db.unstucks > 200 do table.remove(db.unstucks, 1) end
    if ns.Share and ns.Share.QueueOwnUnstuck then ns.Share:QueueOwnUnstuck(r) end
    if db.watch then
        Print(T("déblocage enregistré (%s) : %d m.", "unstuck recorded (%s): %d yd."), how or "?", math.floor(d))
    end
    return true
end
-- hors ligne : derniere position avant la deconnexion -> position a la reconnexion
local function CheckUnstuck()
    local guid = UnitGUID and UnitGUID("player")
    local db = DB()
    local old = guid and db.lastPos and db.lastPos[guid]
    local cur = SnapPos()
    local pending = db.unstuckPending and db.unstuckPending[guid]
    if db.unstuckPending then db.unstuckPending[guid] = nil end
    if not (old and cur) then return end
    -- assistance ouverte moins de 24 h avant : deplacement par le service "Stuck Character"
    local how = (pending and (cur.t or 0) - pending < 86400) and "support" or "logout"
    RecordUnstuck(old, cur, how)
end

-- assistance (Stuck Character service) : le service DECONNECTE le personnage pour le deplacer. A l'ouverture de
-- la fenetre, on note la position et le fait qu'un deblocage est en cours ; la reconnexion fait le reste.
local function OnHelpOpen()
    local guid = UnitGUID and UnitGUID("player")
    if not guid then return end
    pcall(SavePos)
    local db = DB()
    db.unstuckPending = db.unstuckPending or {}
    db.unstuckPending[guid] = GetServerTime and GetServerTime() or time()
    if db.watch then Print(T("assistance ouverte : position notée pour un éventuel déblocage.", "support opened: position noted for a possible unstuck.")) end
end
local hooked = {}
local function HookHelp()
    for _, name in ipairs({"HelpFrame", "HelpBrowser", "HelpFrameContent", "CustomerSupportFrame", "TicketStatusFrame"}) do
        local f = _G[name]
        if f and not hooked[name] and f.HookScript then
            hooked[name] = true
            f:HookScript("OnShow", OnHelpOpen)
        end
    end
end
local posEv = CreateFrame("Frame")
posEv:RegisterEvent("ADDON_LOADED")
posEv:RegisterEvent("PLAYER_ENTERING_WORLD")
posEv:RegisterEvent("PLAYER_LOGOUT")
posEv:RegisterEvent("PLAYER_LEAVING_WORLD")
posEv:SetScript("OnEvent", function(_, event, isLogin)
    if event == "ADDON_LOADED" then
        HookHelp()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        HookHelp()
        if isLogin then C_Timer.After(4, function() pcall(CheckUnstuck) end) end
        if not posEv.ticker then
            -- position gardee a jour (la deconnexion peut arriver sans prevenir)
            posEv.ticker = C_Timer.NewTicker(5, function() if not isLogin or posEv.ready then pcall(SavePos) end end)
            C_Timer.After(6, function() posEv.ready = true end)
        end
    else
        pcall(SavePos)
    end
end)

local deathEv = CreateFrame("Frame")
deathEv:RegisterEvent("PLAYER_DEAD")
deathEv:RegisterEvent("PLAYER_ALIVE")
deathEv:RegisterEvent("PLAYER_ENTERING_WORLD")
deathEv:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        pcall(OnDeath)
    else
        -- la position du fantome peut mettre un instant a se mettre a jour
        C_Timer.After(1.5, function() pcall(OnGhost) end)
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    local db = DB()
    db.death = true   -- plus d'interrupteur general : chaque calque a sa case
    if db.viewFaction == "Alliance" or db.viewFaction == "Horde" then db.viewFaction = nil end
    if db.pos then notifier:ClearAllPoints(); notifier:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4]) end
    unstuckBtn.Label()
    deathBtn.Label()
    C_Timer.NewTicker(0.25, UpdateNotifier)   -- se met a jour en marchant
end)

local function Export()
    local jobs = {{0, "Alliance"}, {1, "Alliance"}, {0, "Horde"}, {1, "Horde"}}
    local out = {version = VERSION, date = date("%Y-%m-%d %H:%M"), data = {Alliance = {}, Horde = {}}}
    local _, source = RawGraveyards(0)
    out.source = source
    local k = 0
    exporting = true
    local function nextJob()
        k = k + 1
        local job = jobs[k]
        if not job then
            exporting = false
            DB().export = out
            Print(T("export terminé. Fais |cffffff00/reload|r (ou déconnecte-toi) pour l'écrire sur le disque.",
                    "export done. Type |cffffff00/reload|r (or log out) to write it to disk."))
            return
        end
        local contID, faction = job[1], job[2]
        Print(T("export %d/4 : %s, %s…", "export %d/4: %s, %s…"), k,
              contID == 0 and T("Royaumes de l'Est", "Eastern Kingdoms") or "Kalimdor", faction)
        Build(contID, nil, faction, function(result, err)
            if result then
                out.data[faction][contID] = result
                Print(T("  %d lignes.", "  %d lines."), #result.segs)
            else
                Print(T("  échec : %s", "  failed: %s"), tostring(err))
            end
            C_Timer.After(0.5, nextJob)
        end)
    end
    nextJob()
end

SLASH_UNSTUCKSKIPSFOREVER1 = "/usf"
SlashCmdList.UNSTUCKSKIPSFOREVER = function(msg)
    msg = strlower(strtrim(msg or ""))
    local db = DB()
    if msg == "recalc" then
        db.cache = {}
        Print(T("lignes DeathSkips recalculées à la prochaine ouverture de la carte.",
                "DeathSkips lines will be recomputed next time you open the map."))
        Redraw()
    elseif msg == "share" or msg == "partage" then
        db.share = (db.share == false)
        if ns.Share then
            if db.share then ns.Share:JoinChannel() else ns.Share:LeaveChannel() end
        end
        Print(db.share and T("partage des morts activé.", "death sharing on.") or T("partage des morts coupé.", "death sharing off."))
    elseif msg == "api" then
        -- cimetieres que le jeu renvoie pour chaque carte (C_DeathInfo.GetGraveyardsForMap) -> fichier sauvegarde
        db.api = {}
        local zones, total = 0, 0
        if C_DeathInfo and C_DeathInfo.GetGraveyardsForMap then
            for m = 1400, 2700 do
                local ok, list = pcall(C_DeathInfo.GetGraveyardsForMap, m)
                if ok and type(list) == "table" and #list > 0 then
                    zones = zones + 1
                    local info = C_Map.GetMapInfo(m)
                    local out = {name = info and info.name or "?", gys = {}}
                    for _, g in ipairs(list) do
                        local x, y
                        if g.position and g.position.GetXY then x, y = g.position:GetXY() end
                        table.insert(out.gys, {id = g.graveyardID, name = g.name, x = x, y = y,
                                               selectable = g.isGraveyardSelectable})
                        total = total + 1
                    end
                    db.api[m] = out
                end
            end
        end
        Print(T("API du jeu : %d zones, %d cimetières enregistrés. Fais /reload pour les écrire sur le disque.",
                "game API: %d zones, %d graveyards saved. Type /reload to write them to disk."), zones, total)
    elseif msg == "watch" then
        db.watch = not db.watch
        Print(db.watch and T("affichage en direct des morts reçues activé.", "live display of received deaths on.")
                       or T("affichage en direct coupé.", "live display off."))
    elseif msg == "collector" or msg == "collecteur" then
        db.collector = not db.collector
        if db.collector and ns.Share then
            ns.Share:JoinChannel()
            C_Timer.After(3, function() ns.Share:RequestSync() end)
        end
        Print(db.collector and T("mode collecteur activé : à chaque connexion, tout le stock des joueurs en ligne est demandé.",
                                 "collector mode on: every login asks online players for everything they have.")
                           or T("mode collecteur coupé.", "collector mode off."))
    elseif msg == "data" then
        Print(T("%d morts réelles connues (les tiennes + celles partagées).", "%d real deaths known (yours + shared)."),
              ns.Share and ns.Share:Count() or 0)
    elseif msg == "support" then
        -- test : simule l'ouverture de l'assistance (position notee, deblocage attendu a la prochaine connexion)
        OnHelpOpen()
        Print("hooks : %s", next(hooked) and table.concat((function() local t = {} for k in pairs(hooked) do t[#t + 1] = k end return t end)(), ", ") or "aucun")
    elseif msg == "deblocages" or msg == "unstucks" then
        local list = db.unstucks or {}
        Print(T("%d déblocage(s) enregistré(s) chez toi, %d connus au total.", "%d unstuck(s) recorded here, %d known in total."),
              #list, ns.Share and ns.Share:CountU() or 0)
        for i = math.max(1, #list - 4), #list do
            local u = list[i]
            Print("%s · %s · zone %d %s · (%d, %d) -> (%d, %d) · %d m", u.time or "?", u.how or "logout", u.z or 0, u.s or "", u.X, u.Y, u.rX, u.rY, u.dist or 0)
        end
    elseif msg == "morts" or msg == "deaths" then
        local list = db.deaths or {}
        if #list == 0 then Print(T("aucune mort enregistrée.", "no deaths logged.")) end
        for i = math.max(1, #list - 4), #list do
            local d = list[i]
            Print(T("%s · %s / %s · prévu %s · réel %s %s", "%s · %s / %s · expected %s · got %s %s"),
                  d.time or "?", d.zoneText or "?", d.subzoneText or "",
                  tostring(d.predicted), tostring(d.actual), d.ok and "|cff40ff40OK|r" or T("|cffff4040FAUX|r", "|cffff4040WRONG|r"))
        end
    elseif msg == "export" then
        Print(T("calcul des 2 continents pour les 2 factions (le jeu peut ramer une minute)…",
                "computing both continents for both factions (the game may lag for a minute)…"))
        Export()
    elseif msg == "dev" or msg == "dots" then
        db.showDeaths = not db.showDeaths
        Print(db.showDeaths and T("morts enregistrées affichées (points bleus).", "recorded deaths shown (blue dots).")
                            or T("morts enregistrées masquées.", "recorded deaths hidden."))
        Redraw()
    elseif msg == "" or msg == "options" or msg == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif msg == "notifier" then
        db.showNotifier = not db.showNotifier
        UpdateNotifier()
    else
        Print(T("/usf (options) · /usf notifier · /usf partage · /usf data · /usf morts · /usf dots",
                "/usf (options) · /usf notifier · /usf share · /usf data · /usf deaths · /usf dots"))
    end
end

---------------------------------------------------------------------------
-- Panneau d'options : Options > AddOns > Deathskip (ou /usf)
---------------------------------------------------------------------------
local function SetShare(on)
    local db = DB()
    db.share = on
    if ns.Share then
        if on then ns.Share:JoinChannel() else ns.Share:LeaveChannel() end
    end
end

local panel = CreateFrame("Frame")
panel.name = "Deathskip"
local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -4)
scroll:SetPoint("BOTTOMRIGHT", -28, 4)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(620, 900)
scroll:SetScrollChild(content)
local checks = {}

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Deathskip")
local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetWidth(560)
sub:SetJustifyH("LEFT")
sub:SetText(T("Sur Forever, la sous-zone où vous mourez décide du cimetière. Survolez la carte pour voir où vous réapparaîtriez.",
              "On Forever, the subzone you die in decides your graveyard. Hover the map to see where you'd respawn."))

local function Header(y, text)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
end

local function Check(y, label, desc, get, set)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, y)
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    if desc then
        local d = cb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        d:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        d:SetText(desc)
    end
    cb.get = get
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        Redraw()
        UpdateNotifier()
        unstuckBtn.Label()
        deathBtn.Label()
    end)
    table.insert(checks, cb)
    return cb
end

local painters = {}
local function Choice(yy, label, opts, key, default, getter, setter)
    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 26, yy - 4)
    fs:SetText(label)
    local btns = {}
    local function paint()
        for _, bt in ipairs(btns) do
            if bt.label then bt:SetText(bt.label()) end
            local cur = getter and getter() or (DB()[key] or (type(default) == "function" and default() or default))
            local on = cur == bt.value
            bt:GetFontString():SetTextColor(1, on and 0.82 or 1, on and 0 or 1)
        end
    end
    local x = 150
    for _, o in ipairs(opts) do
        local bt = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        bt:SetSize(o[3] or 76, 22)
        bt:SetPoint("TOPLEFT", x, yy)
        x = x + (o[3] or 76) + 6
        if type(o[2]) == "function" then bt.label = o[2]; bt:SetText(o[2]()) else bt:SetText(o[2]) end
        bt.value = o[1]
        bt:SetScript("OnClick", function(self)
            if setter then setter(self.value) else DB()[key] = self.value end
            paint()
            RestyleMarks()
            Redraw()
        end)
        btns[#btns + 1] = bt
    end
    painters[#painters + 1] = paint
end

local y = -64
Header(y, T("Faction", "Faction")); y = y - 24
local function FacLabel(f, name)
    return function()
        return name .. ((UnitFactionGroup("player") == f) and T(" (vous)", " (you)") or "")
    end
end
Choice(y, T("Afficher :", "Show:"), {{"Alliance", FacLabel("Alliance", "Alliance"), 120}, {"Horde", FacLabel("Horde", "Horde"), 120},
                                     {"both", T("Les deux", "Both"), 100}}, "viewFaction", nil, ViewSelection,
       function(v)
           local mine = UnitFactionGroup("player")
           DB().viewFaction = (v == "both") and "both" or ((v == mine) and nil or "other")
       end)
y = y - 26
local facNote = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
facNote:SetPoint("TOPLEFT", 150, y)
facNote:SetText(T("cimetières et réapparitions de la faction choisie (survol : une ligne par faction)",
                  "graveyards and respawns of the chosen faction (hover: one line per faction)"))
y = y - 28
Header(y, T("Carte", "Map")); y = y - 22
Check(y, T("Contours des sous-zones", "Subzone borders"), T("plein : le cimetière change ; pointillés : même cimetière", "solid: graveyard changes; dashed: same graveyard"),
      function() return DB().showSubzones ~= false end, function(v) DB().showSubzones = v end); y = y - 28
Check(y, T("Bordures sans effet", "Borders with no effect"), T("pointillés : même cimetière des deux côtés", "dashed: same graveyard on both sides"),
      function() return DB().showDashed ~= false end, function(v) DB().showDashed = v end); y = y - 28
Check(y, T("Bordures exactes", "Exact borders"), T("les cases de 33 m du jeu, au lieu de lignes lissées", "the game's 33-yard squares instead of smoothed lines"),
      function() return DB().exactBorders and true or false end, function(v) DB().exactBorders = v end); y = y - 28
Check(y, T("Partages dans une même zone", "Shared areas"), T("lignes rouges : deux cimetières, le plus proche", "red lines: two graveyards, the nearer one"),
      function() return DB().showSplits ~= false end, function(v) DB().showSplits = v end); y = y - 28
Check(y, T("Anciens deathskips", "Old deathskips"), T("lignes rouges de l'UnstuckSkips Classic", "red lines from Classic UnstuckSkips"),
      function() return DB().unstuck and true or false end, function(v) DB().unstuck = v end); y = y - 36

Header(y, T("Esprits guérisseurs (cimetières)", "Spirit healers (graveyards)")); y = y - 22
Check(y, T("Afficher les cimetières", "Show graveyards"), T("ceux que votre faction peut atteindre", "the ones your faction can reach"),
      function() return DB().showMarkers ~= false end, function(v) DB().showMarkers = v end); y = y - 28
Check(y, T("Noms des cimetières", "Graveyard names"), T("sous les marques, cartes de zone", "under the markers, zone maps"),
      function() return DB().markNames and true or false end, function(v) DB().markNames = v end); y = y - 30
Choice(y, T("Style :", "Style:"), {{"cross", T("Croix", "Cross")}, {"healer", T("Icône", "Icon")}}, "markStyle", "healer"); y = y - 28
Choice(y, T("Taille :", "Size:"), {{11, T("Petite", "Small")}, {15, T("Moyenne", "Medium")}, {21, T("Grande", "Large")},
                                   {28, T("Très grande", "Huge"), 90}}, "markSize", 11); y = y - 28
Choice(y, T("Couleur :", "Color:"), {{"red", T("Rouge", "Red"), 60}, {"white", T("Blanc", "White"), 60}, {"yellow", T("Jaune", "Yellow"), 60},
                                     {"green", T("Vert", "Green"), 60}, {"blue", T("Bleu", "Blue"), 60}}, "markColor", "red"); y = y - 24
local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
note:SetPoint("TOPLEFT", 150, y)
note:SetText(T("(la couleur s'applique au style Croix)", "(color applies to the Cross style)")); y = y - 26

Header(y, T("Survol de la carte", "Map hover")); y = y - 22
Check(y, T("Infobulle", "Tooltip"), T("sous-zone et réapparition, en haut à gauche de la carte", "subzone and respawn, top left of the map"),
      function() return DB().hoverTip ~= false end, function(v) DB().hoverTip = v end); y = y - 28
Check(y, T("Trait vert vers l'esprit guérisseur", "Green line to the spirit healer"), nil,
      function() return DB().hoverLine ~= false end, function(v) DB().hoverLine = v end); y = y - 30

local sizeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
sizeLabel:SetPoint("TOPLEFT", 26, y - 4)
sizeLabel:SetText(T("Taille du texte :", "Text size:"))
local sizeBtns = {}
local function PaintSizes()
    for _, b in ipairs(sizeBtns) do
        b:GetFontString():SetTextColor(1, (DB().tipSize or 17) == b.size and 0.82 or 1, (DB().tipSize or 17) == b.size and 0 or 1)
    end
end
for i, opt in ipairs({{13, T("Petit", "Small")}, {17, T("Moyen", "Medium")}, {21, T("Grand", "Large")}}) do
    local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    b:SetSize(80, 22)
    b:SetPoint("TOPLEFT", 130 + (i - 1) * 86, y)
    b:SetText(opt[2])
    b.size = opt[1]
    b:SetScript("OnClick", function(self) DB().tipSize = self.size; PaintSizes() end)
    table.insert(sizeBtns, b)
end
y = y - 40

Header(y, T("Autres", "Other")); y = y - 22
Check(y, T("Encadré Deathskips à l'écran", "On-screen Deathskips box"), T("cimetière de votre position, en direct ; déplaçable", "graveyard for where you stand, live; drag to move"),
      function() return DB().showNotifier and true or false end, function(v) DB().showNotifier = v end); y = y - 28
Check(y, T("Partager mes morts (anonyme)", "Share my deaths (anonymous)"), T("sert à améliorer les données des prochaines versions", "helps improve the data in future versions"),
      function() return DB().share ~= false end, function(v) SetShare(v) end); y = y - 28
Check(y, T("Afficher les morts enregistrées", "Show recorded deaths"), T("points bleus : morts partagées par les joueurs", "blue dots: deaths shared by players"),
      function() return DB().showDeaths and true or false end, function(v) DB().showDeaths = v end); y = y - 28

panel:SetScript("OnShow", function()
    for _, cb in ipairs(checks) do cb:SetChecked(cb.get()) end
    PaintSizes()
    for _, f in ipairs(painters) do f() end
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
function ns.OpenOptions()
    if InCombatLockdown() then
        Print(T("options indisponibles en combat.", "options unavailable in combat."))
        return
    end
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

---------------------------------------------------------------------------
-- Menu sur la carte : bouton en haut a droite + cases cliquables
---------------------------------------------------------------------------
local menuBtn = CreateFrame("Button", nil, WorldMapFrame, "UIPanelButtonTemplate")
menuBtn:SetSize(160, 22)
menuBtn:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -60, -60)
menuBtn:SetFrameStrata("DIALOG")
menuBtn:SetFrameLevel(500)
menuBtn:SetText("Deathskip")
-- avec l'addon UnstuckSkips original (SeargentFish) : ses boutons "Show UnstuckSkips" / "Show DeathSkips" sont au
-- meme endroit (-60, -60 et -60, -82) ; le notre se met a leur gauche pour ne pas les recouvrir
local function PlaceMenuButton()
    local other = _G.UnstuckSkips_Toggle
    menuBtn:ClearAllPoints()
    if other and other.GetLeft then
        menuBtn:SetPoint("TOPRIGHT", other, "TOPLEFT", -8, 0)
    else
        menuBtn:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -60, -60)
    end
end
PlaceMenuButton()
WorldMapFrame:HookScript("OnShow", PlaceMenuButton)

local menu = CreateFrame("Frame", nil, menuBtn, "BackdropTemplate")
menu:SetPoint("TOPRIGHT", menuBtn, "BOTTOMRIGHT", 0, -2)
menu:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
menu:SetBackdropColor(0, 0, 0, 0.85)
menu:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
menu:SetFrameStrata("DIALOG")
menu:SetFrameLevel(510)
menu:Hide()

local menuItems = {
    {T("Contours des sous-zones", "Subzone borders"), function() return DB().showSubzones ~= false end, function(v) DB().showSubzones = v end},
    {T("Bordures sans effet (pointillés)", "No-effect borders (dashed)"), function() return DB().showDashed ~= false end, function(v) DB().showDashed = v end},
    {T("Bordures exactes (cases)", "Exact borders (squares)"), function() return DB().exactBorders and true or false end, function(v) DB().exactBorders = v end},
    {T("Partages (rouge)", "Shared areas (red)"), function() return DB().showSplits ~= false end, function(v) DB().showSplits = v end},
    {T("Cimetières (croix)", "Graveyards (X)"), function() return DB().showMarkers ~= false end, function(v) DB().showMarkers = v end},
    {T("Noms des cimetières", "Graveyard names"), function() return DB().markNames and true or false end, function(v) DB().markNames = v end},
    {T("Infobulle au survol", "Hover tooltip"), function() return DB().hoverTip ~= false end, function(v) DB().hoverTip = v end},
    {T("Trait vert", "Green line"), function() return DB().hoverLine ~= false end, function(v) DB().hoverLine = v end},
    {T("Anciens deathskips", "Old deathskips"), function() return DB().unstuck and true or false end, function(v) DB().unstuck = v end},
    {T("Morts enregistrées (bleu)", "Recorded deaths (blue)"), function() return DB().showDeaths and true or false end, function(v) DB().showDeaths = v end},
    {T("Encadré à l'écran", "On-screen box"), function() return DB().showNotifier and true or false end, function(v) DB().showNotifier = v; UpdateNotifier() end},
}
local menuChecks = {}
local my = -6
local widest = 0
for _, it in ipairs(menuItems) do
    local cb = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", 6, my)
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(it[1])
    widest = math.max(widest, fs:GetStringWidth())
    cb.get = it[2]
    cb:SetScript("OnClick", function(self)
        it[3](self:GetChecked() and true or false)
        Redraw()
    end)
    table.insert(menuChecks, cb)
    my = my - 24
end
local more = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
more:SetSize(140, 20)
more:SetPoint("TOPLEFT", 10, my - 4)
more:SetText(T("Plus d'options…", "More options…"))
more:SetScript("OnClick", function() menu:Hide(); if ns.OpenOptions then ns.OpenOptions() end end)
menu:SetSize(math.max(170, widest + 44), -my + 34)

mapMenuRefresh = function()
    for _, cb in ipairs(menuChecks) do cb:SetChecked(cb.get()) end
end
menu:SetScript("OnShow", mapMenuRefresh)
menuBtn:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
WorldMapFrame:HookScript("OnHide", function() menu:Hide() end)

---------------------------------------------------------------------------
-- Lecture seule, pour l'addon annexe Deathskip Collector (noms des cimetieres, morts deja dans nos donnees)
---------------------------------------------------------------------------
do
    local evidenceKeys
    _G.DeathskipAPI = {
        version = 1,
        -- derniere version de Deathskip Collector (a monter a chaque version du Collector) : le Collector previent
        -- son utilisateur s'il est en retard. Les joueurs sans Collector ne voient rien.
        LatestCollector = "1.4.1",
        -- nom du cimetiere le plus proche d'un point de reapparition (nil si aucun a moins de 250 m)
        GraveyardName = function(c, X, Y) return RespawnGraveyard(c, X, Y) end,
        -- sous-zone officielle d'un point, dans la langue du jeu (nil hors de la grille)
        SubzoneName = function(c, X, Y) local _, name = GridArea(c, X, Y) return name end,
        -- cimetiere prevu par l'addon a cet endroit pour cette faction ("A" ou "H") : {name, X, Y} ou nil
        Predict = function(c, X, Y, f) return GridGY(c, X, Y, f == "H" and "Horde" or "Alliance") end,
        -- cle "c:f:X:Y:rX:rY" deja dans les morts livrees avec l'addon (Data/evidence.lua)
        IsKnown = function(key)
            if not evidenceKeys then
                evidenceKeys = {}
                for _, r in ipairs(ns.EVIDENCE or {}) do
                    evidenceKeys[fmt("%d:%s:%d:%d:%d:%d", r.c, r.f, r.X, r.Y, r.rX, r.rY)] = true
                end
            end
            return evidenceKeys[key] == true
        end,
    }
end
