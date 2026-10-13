local addonName, ns = ...

---------------------------------------------------------------------------
-- Kit Dock: shared by First Aid Kit, Camping Kit and Fishing Kit.
--
-- Every kit addon ships this same file. The first copy to load (or the
-- newest version) runs; the others just pick it up, so there is nothing
-- separate to install and a single kit on its own behaves exactly as before.
--
-- With two or more kits, their buttons snap to a small gold pin: three sit
-- in a triangle, two side by side (whichever way you dropped them). Opening a
-- docked kit glides it onto the pin and tucks the others in behind it, so
-- its slots fan out exactly as they do on their own. Drag a kit away from
-- the pin to float it; drop it on any other kit (or on the pin) to dock the
-- two together. Positions are only changed out of combat.
--
-- Dropping works the same whatever state the kits are in: the kit you let
-- go of joins whichever kit or pin is under it. Two floating kits dropped
-- together start a dock where they are; a kit dropped on a docked kit joins
-- that dock; an open kit dragged by its button carries its dock along, and
-- pulls in a floating kit it's dropped on. Any kit that was open closes on a
-- merge so you can see the result. A kit dragged to the edge of the screen
-- slides back in far enough for its slots to fit, docked or not.
---------------------------------------------------------------------------

local VERSION = 16
local D = _G.KitDock
if D and (D.version or 0) >= VERSION then
    ns.Dock = D
    return
end
D = D or {}
_G.KitDock = D
ns.Dock = D
D.version = VERSION
D.kits = D.kits or {}
D.media = D.media or ("Interface\\AddOns\\" .. addonName .. "\\media\\")

local ORDER = { "fak", "ck", "fk" }
local SNAP = 105 -- how close (UI units) a kit must come to merge (preview and drop)
-- Docked and closed, each kit shrinks to this size (before the kit's own
-- Size setting), so two or three together take about the room of one --
-- unless "Full-size kits when docked" is on (KitDockDB.fullSize).
local COMPACT = 34

local function DB()
    KitDockDB = KitDockDB or {}
    local db = KitDockDB
    db.docked = db.docked or {}
    db.order = db.order or { "fak", "ck", "fk" }
    if db.triUp == nil then db.triUp = true end
    db.two = db.two or 0
    return db
end
D.DB = DB -- the kits' settings panels bind their docking options to it

local function InList(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
end

-- A kit the player has hidden (from its settings or the shared minimap menu)
-- sits out of the dock entirely.
local function Shown(k)
    local api = D.kits[k]
    return api and not (api.IsHidden and api.IsHidden())
end

local function Count()
    local n = 0
    for k in pairs(D.kits) do if Shown(k) then n = n + 1 end end
    return n
end

local function Installed()
    local n = 0
    for _ in pairs(D.kits) do n = n + 1 end
    return n
end

-- Docking only means something with two or more kits showing.
function D.Active() return Count() >= 2 end

---------------------------------------------------------------------------
-- Kits snapped to a side of the screen. Saved as a list of entries, each
-- { side = "left"|"right"|"top"|"bottom", at = along, keys = { key } }:
-- one kit each, staying where it was put (kits on an edge never merge;
-- they can overlap, and you move them apart yourself). "along" runs down
-- the left and right edges (from the top) and across the top and bottom
-- (from the left), in UIParent units.
---------------------------------------------------------------------------

local function Edges()
    local db = DB()
    db.edges = db.edges or {}
    return db.edges
end

local function EdgeOf(key)
    for _, g in ipairs(Edges()) do
        local i = InList(g.keys, key)
        if i then return g, i end
    end
end

-- Which edge a kit is on, or nil.
function D.EdgeSide(key)
    local g = EdgeOf(key)
    return g and g.side or nil
end

-- Kits on the pin, in their saved order (never ones on an edge).
local function DockedKeys()
    local keys = {}
    if not D.Active() then return keys end
    local db = DB()
    for _, k in ipairs(db.order) do
        if Shown(k) and db.docked[k] ~= false and not EdgeOf(k) then keys[#keys + 1] = k end
    end
    for _, k in ipairs(ORDER) do -- anything missing from a saved order
        if Shown(k) and db.docked[k] ~= false and not EdgeOf(k) and not InList(keys, k) then keys[#keys + 1] = k end
    end
    return keys
end

local function PinDocked(key)
    return InList(DockedKeys(), key) ~= nil
end

-- For the kits: placed by the dock (on the pin or on an edge), not by
-- their own saved spot.
function D.IsDocked(key)
    return PinDocked(key) or EdgeOf(key) ~= nil
end

-- A frame's centre in UIParent units.
local function Center(f)
    local x, y = f:GetCenter()
    if not x then return nil end
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * s, y * s
end

---------------------------------------------------------------------------
-- The pin
---------------------------------------------------------------------------

local function SavePin()
    local x, y = Center(D.pin)
    if x then DB().pin = { x, y } end
end

local function SetPinAt(x, y)
    D.pin:ClearAllPoints()
    D.pin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    DB().pin = { x, y }
end

local function Pin()
    if D.pin then return D.pin end
    local p = CreateFrame("Button", "KitDockPin", UIParent)
    p:SetSize(20, 20)
    p:SetFrameStrata("MEDIUM")
    p:SetFrameLevel(30)
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:RegisterForDrag("LeftButton")
    -- The same gold stud as the shared minimap button. It glows under the
    -- mouse and the cursor turns into the move cursor over it, so it still
    -- reads as "drag me".
    p.tex = p:CreateTexture(nil, "ARTWORK")
    p.tex:SetAllPoints()
    p.tex:SetTexture(D.media .. "pin_dot", nil, nil, "LINEAR")
    p.hl = p:CreateTexture(nil, "HIGHLIGHT")
    p.hl:SetTexture(D.media .. "glow_ring")
    p.hl:SetBlendMode("ADD")
    p.hl:SetPoint("CENTER")
    p.hl:SetSize(30, 30)
    p:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    p:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePin()
    end)
    p:SetScript("OnEnter", function(self)
        if SetCursor then pcall(SetCursor, "UI_MOVE_CURSOR") end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Move kits")
        GameTooltip:AddLine("Drag to move your kits together. Drag a kit away from the pin to float it on its own; drop it near the pin to dock it again.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function()
        if ResetCursor then pcall(ResetCursor) end
        GameTooltip:Hide()
    end)
    p:Hide()
    D.pin = p
    return p
end

-- The pin's saved spot, or under the first docked kit the first time.
local function PlacePin(keys)
    local db = DB()
    if db.pin and db.pin[1] and db.pin[2] then -- (older versions could save it without a y)
        SetPinAt(db.pin[1], db.pin[2])
        return
    end
    local first = keys[1] and D.kits[keys[1]]
    local x, y
    if first then x, y = Center(first.kit) end -- (not "first and Center()": that keeps only x)
    if not (x and y) then x, y = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2 end
    SetPinAt(x, y)
end

---------------------------------------------------------------------------
-- Layout (out of combat only; queued otherwise)
---------------------------------------------------------------------------

local busy = false

---------------------------------------------------------------------------
-- Animation: kits glide and grow (or shrink) into their new spot, and the
-- kits that tuck away fade out (or back in), instead of jumping.
---------------------------------------------------------------------------

local GLIDE = 0.24

local function Anims(kit)
    if kit.dockAG then return end
    local g = kit:CreateAnimationGroup()
    local jump = g:CreateAnimation("Translation") -- back to where it was, unseen
    jump:SetDuration(0.001)
    jump:SetOrder(1)
    local glide = g:CreateAnimation("Translation")
    glide:SetDuration(GLIDE)
    glide:SetSmoothing("IN_OUT")
    glide:SetOrder(2)
    local grow = g:CreateAnimation("Scale")
    grow:SetDuration(GLIDE)
    grow:SetSmoothing("IN_OUT")
    grow:SetOrder(2)
    kit.dockAG, kit.dockJump, kit.dockGlide, kit.dockGrow = g, jump, glide, grow
    local f = kit:CreateAnimationGroup()
    local a = f:CreateAnimation("Alpha")
    a:SetDuration(0.16)
    local sc = f:CreateAnimation("Scale")
    sc:SetDuration(0.16)
    sc:SetSmoothing("OUT")
    f:SetScript("OnFinished", function()
        local done = kit.fadeDone
        kit.fadeDone = nil
        if done then done() end
    end)
    kit.fadeAG, kit.fadeAlpha, kit.fadeScale = f, a, sc
end

-- Fade a kit button out (then run done, which hides it) or back in.
function D.Fade(kit, out, done)
    Anims(kit)
    kit.fadeAG:Stop()
    kit.fadeAlpha:SetFromAlpha(out and 1 or 0)
    kit.fadeAlpha:SetToAlpha(out and 0 or 1)
    local s0, s1 = out and 1 or 0.6, out and 0.6 or 1
    kit.fadeScale:SetScaleFrom(s0, s0)
    kit.fadeScale:SetScaleTo(s1, s1)
    kit.fadeDone = done
    kit.fadeAG:Play()
end

-- After a kit has been moved and resized for real: play it from where it
-- was (x, y and effective scale before) to where it is now.
local function Glide(kit, bx, by, bscale)
    if not bx or not kit:IsShown() then return end
    local nx, ny = kit:GetCenter()
    if not nx then return end
    local eff = kit:GetEffectiveScale()
    local rel = eff / UIParent:GetEffectiveScale()
    local ox, oy = bx * (bscale / eff) - nx, by * (bscale / eff) - ny -- in the kit's own units
    local ratio = bscale / eff
    if math.abs(ox) < 1 and math.abs(oy) < 1 and math.abs(ratio - 1) < 0.01 then return end
    Anims(kit)
    kit.dockAG:Stop()
    kit.dockJump:SetOffset(ox, oy)
    kit.dockGlide:SetOffset(-ox, -oy)
    kit.dockGrow:SetScaleFrom(ratio, ratio)
    kit.dockGrow:SetScaleTo(1, 1)
    kit.dockAG:Play()
end

-- Kit buttons glide by being moved for real, a little each frame, rather
-- than with an animation: a new layout part-way through (the live merge
-- preview makes them often) then starts from wherever the kit actually is
-- on screen, so nothing snaps back to the old spot or jumps ahead.
local tweens = {}
local tweener = CreateFrame("Frame")
tweener:Hide()
D.tweener = tweener -- (for testing)

local function Smooth(t) return t * t * (3 - 2 * t) end

local function TweenApply(kit, tw, k)
    local s = tw.ss + (tw.es - tw.ss) * k
    local x = tw.sx + (tw.ex - tw.sx) * k
    local y = tw.sy + (tw.ey - tw.sy) * k
    kit:SetScale(s)
    local own = s * tw.parentEff / UIParent:GetEffectiveScale() -- UIParent units per kit unit
    kit:ClearAllPoints()
    kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / own, y / own)
end

local function TweenFinish(kit, tw)
    tweens[kit] = nil
    kit:SetScale(tw.es)
    kit:ClearAllPoints()
    kit:SetPoint(tw.p, tw.rel, tw.rp, tw.x, tw.y)
end

-- Stop a kit's glide where it should end (before something else moves it,
-- or when combat starts and frames can't move).
local function StopTween(kit)
    local tw = tweens[kit]
    if tw then TweenFinish(kit, tw) end
end
D.StopTween = StopTween

tweener:SetScript("OnUpdate", function(self, dt)
    local any = false
    for kit, tw in pairs(tweens) do
        tw.t = tw.t + dt
        if tw.t >= GLIDE then
            TweenFinish(kit, tw)
        else
            TweenApply(kit, tw, Smooth(tw.t / GLIDE))
            any = true
        end
    end
    if not any and not next(tweens) then self:Hide() end
end)

-- The kit has just been put where it ends up (anchor and scale); glide it
-- there from bx, by (in its old own units) at old effective scale bscale.
local function KitGlide(kit, bx, by, bscale)
    if not bx or not kit:IsShown() or InCombatLockdown() then return end
    local ui = UIParent:GetEffectiveScale()
    local ex, ey = Center(kit)
    if not ex then return end
    local es = kit:GetScale()
    local parentEff = kit:GetEffectiveScale() / es
    local sx, sy, ss = bx * bscale / ui, by * bscale / ui, bscale / parentEff
    if math.abs(sx - ex) < 0.5 and math.abs(sy - ey) < 0.5 and math.abs(ss - es) < 0.001 then return end
    local p, rel, rp, x, y = kit:GetPoint(1)
    if kit.dockAG then kit.dockAG:Stop() end
    tweens[kit] = { t = 0, sx = sx, sy = sy, ss = ss, ex = ex, ey = ey, es = es, parentEff = parentEff,
        p = p, rel = rel, rp = rp, x = x, y = y }
    TweenApply(kit, tweens[kit], 0)
    tweener:Show()
end

-- The kits use it too (KeepOnScreen, and for their pinned slots), so a free
-- kit nudged in from the edge slides the same way a docked one does.
D.Glide = function(frame, bx, by, bscale)
    for _, api in pairs(D.kits) do
        if api.kit == frame then return KitGlide(frame, bx, by, bscale) end
    end
    return Glide(frame, bx, by, bscale)
end

-- Each kit's own Size setting, times the shrink while docked and closed.
-- Tells the kit (Compact) so it can hide extras that sit around its button.
local function SetCompact(api, on, angle, span)
    local base = api.BaseScale and api.BaseScale() or 1
    local ui = api.UiScale and api.UiScale() or base -- docked size follows the kit's Size, not its button-size slider
    local kit = api.kit
    local scale = (on and not DB().fullSize) and ui * COMPACT / kit:GetWidth() or base
    local rescaled = math.abs(kit:GetScale() - scale) > 0.001
    if rescaled then kit:SetScale(scale) end
    angle, span = on and angle or nil, on and span or nil
    -- A size change needs the refresh too: the pinned slots fan out from the
    -- button's edge, wherever that now is.
    if rescaled or api.compact ~= on or api.compactAngle ~= angle or api.compactSpan ~= span then
        api.compact, api.compactAngle, api.compactSpan = on, angle, span
        -- Its slice of the dock: pinned slots fan out around the outside of
        -- the docked button, within this angle range (degrees, y up).
        if api.Compact then api.Compact(on, angle, span) end
    end
end

-- Tells a kit which edge it's on (or nil), so it lays its slots out in
-- columns (or rows) toward the middle of the screen.
-- The kit's slots glide into (or out of) the edge shape rather than jump:
-- BeginMove / EndMove around it, which nest inside a layout's own pair.
local function SetEdge(api, side)
    if api.edgeSide ~= side then
        api.edgeSide = side
        if api.Edge then
            if api.BeginMove then api.BeginMove() end
            api.Edge(side)
            if api.EndMove then api.EndMove() end
        end
    end
end

-- Docked, closed and shrunk (the kit hides its timers and small buttons).
function D.IsCompact(key)
    local api = D.kits[key]
    return api and api.compact or false
end

-- How big a docked kit is on screen (UIParent units) in a dock of n.
local function DockedSize(api, n, open)
    local kit = api.kit
    if n > 1 and not open and not DB().fullSize then
        return (api.UiScale and api.UiScale() or 1) * COMPACT
    end
    return kit:GetWidth() * (api.BaseScale and api.BaseScale() or 1)
end

-- Lay a kit's slots out for an edge, for the kits to call: cols is a list of
-- columns from the edge inward, each a list of { frame, size } (sizes in
-- the slots' own units), half is the kit button's half-size in those units.
-- divAfter puts a gap for a divider after that column. Returns each frame's
-- offset from the kit's centre, the divider's spot { x, y, len, vertical }
-- (or nil), and how long the longest column is (along the edge).
-- Left and right edges run their columns top to bottom; top and bottom
-- edges run their rows left to right.
local EDGE_VEC = { left = { 1, 0, 0, -1 }, right = { -1, 0, 0, -1 }, top = { 0, -1, 1, 0 }, bottom = { 0, 1, 1, 0 } }
function D.EdgeArrange(side, half, cols, divAfter)
    local v = EDGE_VEC[side] or EDGE_VEC.left
    local GAP, COLGAP = 6, 10
    local pos, cur, ext, divOut = {}, half + 10, 0, nil
    for ci, col in ipairs(cols) do
        if #col > 0 then
            local w, L = 0, -GAP
            for _, it in ipairs(col) do w = math.max(w, it.size) L = L + it.size + GAP end
            local mid, a = cur + w / 2, -L / 2
            for _, it in ipairs(col) do
                local m = a + it.size / 2
                pos[it.frame] = { v[1] * mid + v[3] * m, v[2] * mid + v[4] * m }
                a = a + it.size + GAP
            end
            ext = math.max(ext, L)
            cur = cur + w + COLGAP
            if divAfter == ci then
                divOut = cur + 1
                cur = cur + 12
            end
        end
    end
    local div
    if divOut and cur > divOut + 12 then -- only between two columns that are there
        div = { v[1] * divOut, v[2] * divOut, ext + 16, side == "left" or side == "right" }
    end
    return pos, div, ext
end

local EDGE_REACH = 70 -- a kit's centre this close (UI units) to a screen edge snaps it there
local EDGE_INSET = 4  -- gap between the screen edge and the kit button

local function Screen() return UIParent:GetWidth(), UIParent:GetHeight() end
local function AlongLen(side)
    local W, H = Screen()
    return (side == "left" or side == "right") and H or W
end
local function AlongOf(side, x, y)
    local W, H = Screen()
    if side == "left" or side == "right" then return H - y end
    return x
end
-- The kit button's half-size on screen at its own (not docked) size.
local function KitHalf(api)
    local kit = api.kit
    local base = api.BaseScale and api.BaseScale() or kit:GetScale()
    return kit:GetWidth() * base * (kit:GetEffectiveScale() / kit:GetScale()) / UIParent:GetEffectiveScale() / 2
end
-- Where a kit's centre goes for a spot along an edge (UI units).
local function EdgePos(side, half, a)
    local W, H = Screen()
    local d = EDGE_INSET + half
    if side == "left" then return d, H - a end
    if side == "right" then return W - d, H - a end
    if side == "top" then return a, H - d end
    return a, d
end
-- The edge a point is close enough to snap to, if any.
local function NearEdge(x, y)
    local W, H = Screen()
    local best, bd = nil, EDGE_REACH
    for side, d in pairs({ left = x, right = W - x, top = H - y, bottom = y }) do
        if d < bd then best, bd = side, d end
    end
    return best
end
-- How much room along the edge a kit takes (its strip closed, its columns
-- open), from the kit, or just its button.
local function EdgeExt(key, side, open)
    local api = D.kits[key]
    local e = api.EdgeExtent and api.EdgeExtent(side, open)
    return math.max(e or 0, KitHalf(api) * 2)
end
-- Where an edge entry's kits sit along the edge (their middles), kept on
-- screen with what's showing (open, or closed with whatever's pinned) --
-- that nudge is only for now, not saved. Also returns the span they take.
-- An entry saves its kit's middle (at), so pinning or unpinning a slot
-- grows or shrinks the strip around the kit without moving it. Entries
-- saved before that (start: where the first kit's strip began, possibly
-- several kits in a row) are worked out the old way.
local function GroupCenters(g, openKey)
    local c, ext, keys = {}, {}, {}
    for _, k in ipairs(g.keys) do if D.kits[k] and Shown(k) then keys[#keys + 1] = k end end
    if #keys == 0 then
        local a = g.at or g.start or 0
        return c, a, a, keys
    end
    if g.at then
        for _, k in ipairs(keys) do c[k] = g.at end
    else
        local a = g.start or 0
        for _, k in ipairs(keys) do
            local e = EdgeExt(k, g.side, false)
            c[k] = a + e / 2
            a = a + e
        end
    end
    for _, k in ipairs(keys) do ext[k] = EdgeExt(k, g.side, k == openKey) end
    local lo, hi = math.huge, -math.huge
    for _, k in ipairs(keys) do
        lo = math.min(lo, c[k] - ext[k] / 2)
        hi = math.max(hi, c[k] + ext[k] / 2)
    end
    local L, M = AlongLen(g.side), 8
    local sh = hi > L - M and (L - M) - hi or 0
    if lo + sh < M then sh = M - lo end
    for _, k in ipairs(keys) do c[k] = c[k] + sh end
    return c, lo + sh, hi + sh, keys
end

-- Take a kit off its edge.
local function LeaveEdge(key)
    local g, i = EdgeOf(key)
    if not g then return end
    table.remove(g.keys, i)
    if #g.keys == 0 then
        local groups = Edges()
        table.remove(groups, InList(groups, g))
    end
end

-- Put a kit on an edge at (x, y), right there, on its own. Kits on an edge
-- don't merge: dropped on or next to another, it just sits there too.
local function JoinEdge(key, side, x, y)
    LeaveEdge(key)
    DB().docked[key] = false
    local a = AlongOf(side, x, y)
    local ext = EdgeExt(key, side, false)
    local L = AlongLen(side)
    table.insert(Edges(), { side = side, at = math.max(8 + ext / 2, math.min(L - 8 - ext / 2, a)), keys = { key } })
end

-- Older saved entries: several kits sharing a spot are split up, and a
-- saved strip start becomes the kit's middle, each kit staying where it was.
local function SplitEdges()
    local groups = Edges()
    for gi = #groups, 1, -1 do
        local g = groups[gi]
        if #g.keys > 1 or not g.at then
            local c = GroupCenters(g, nil)
            -- (only kits loaded and showing have a spot worked out; wait for the rest)
            local ready = true
            for _, k in ipairs(g.keys) do if not c[k] then ready = false end end
            if ready then
                table.remove(groups, gi)
                for _, k in ipairs(g.keys) do
                    table.insert(groups, { side = g.side, at = c[k], keys = { k } })
                end
            end
        end
    end
end

D.NearEdge = NearEdge

-- While a kit (or the pin) is dragged within reach of a screen edge, a
-- short stretch of that edge lights up where it would land: a bright gold
-- line on the edge itself, fading out at the ends. It follows along as you
-- drag. EdgeGlow(nil) clears it.
local GLOW_LEN = 180  -- how long the lit stretch is
local GLOW_CAP = 50   -- of that, how much fades out at each end
local GLOW_THICK = 3
local LINE_A = 0.95
local function Fade(t, vertical, fromA, toA)
    local r, g, b = 1, 0.82, 0.2
    if CreateColor and pcall(t.SetGradient, t, vertical and "VERTICAL" or "HORIZONTAL",
        CreateColor(r, g, b, fromA), CreateColor(r, g, b, toA)) then
        return
    end
    if t.SetGradientAlpha and pcall(t.SetGradientAlpha, t, vertical and "VERTICAL" or "HORIZONTAL",
        r, g, b, fromA, r, g, b, toA) then
        return
    end
    t:SetColorTexture(r, g, b, (fromA + toA) / 2) -- no gradients here: a plain, dimmer end
end
local function GlowTex(f)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 1)
    t:SetBlendMode("ADD")
    return t
end
-- The line in three parts along the edge: a middle at full strength and
-- two ends fading out (HORIZONTAL gradients run left to right, VERTICAL
-- bottom to top).
local function ShapeGlow(f, side)
    local vert = side == "left" or side == "right" -- the edge runs up and down
    f:SetSize(vert and GLOW_THICK or GLOW_LEN, vert and GLOW_LEN or GLOW_THICK)
    for _, t in ipairs(f.pieces) do t:ClearAllPoints() end
    local lo, hi = vert and "BOTTOM" or "LEFT", vert and "TOP" or "RIGHT"
    local function Along(d) return vert and 0 or d, vert and d or 0 end
    local function Span(t, relA, offA, relB, offB)
        t:SetPoint(lo, f, relA, Along(offA))
        t:SetPoint(hi, f, relB, Along(offB))
        if vert then t:SetWidth(GLOW_THICK) else t:SetHeight(GLOW_THICK) end
    end
    Span(f.line, lo, GLOW_CAP, hi, -GLOW_CAP)
    f.line:SetColorTexture(1, 0.82, 0.2, LINE_A)
    Span(f.lineLo, lo, 0, lo, GLOW_CAP)
    Span(f.lineHi, hi, -GLOW_CAP, hi, 0)
    Fade(f.lineLo, vert, 0, LINE_A)
    Fade(f.lineHi, vert, LINE_A, 0)
end
function D.EdgeGlow(side, x, y)
    local f = D.glow
    if not side or not x then
        if f then f:Hide() end
        return
    end
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetFrameStrata("HIGH")
        f:EnableMouse(false)
        f.line, f.lineLo, f.lineHi = GlowTex(f), GlowTex(f), GlowTex(f)
        f.pieces = { f.line, f.lineLo, f.lineHi }
        D.glow = f
    end
    if f.side ~= side then
        f.side = side
        ShapeGlow(f, side)
    end
    -- Centred on the kit along the edge, kept on screen.
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local half = GLOW_LEN / 2
    local cx, cy
    if side == "left" or side == "right" then
        cx = side == "left" and GLOW_THICK / 2 or W - GLOW_THICK / 2
        cy = math.min(math.max(y, half), H - half)
    else
        cy = side == "bottom" and GLOW_THICK / 2 or H - GLOW_THICK / 2
        cx = math.min(math.max(x, half), W - half)
    end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    f:Show()
end

-- D.skip: the kit being dragged during a live merge preview. Layout leaves
-- it alone (it's under the cursor) but still keeps its place in the dock.
local function DoLayout()
    SplitEdges()
    local db = DB()
    local keys = DockedKeys()
    local pin = Pin()

    -- Where every kit is on screen right now, before anything moves (moving
    -- the pin moves the kits on it), so each glides from where it really was.
    local before = {}
    for key, api in pairs(D.kits) do
        local kit = api.kit
        if key ~= D.skip and kit:IsShown() then
            local x, y = kit:GetCenter()
            if x then before[key] = { x, y, kit:GetEffectiveScale() } end
        end
    end

    -- Floating kits: their own saved spots and size, never tucked. One that
    -- was on the pin a moment ago glides to its spot like a docked kit would.
    for key, api in pairs(D.kits) do
        if not InList(keys, key) and key ~= D.skip and D.stay and D.stay[key] then
            -- Out of the dock only for a preview: stays put, as it is.
            local kit = api.kit
            StopTween(kit)
            local x, y = kit:GetCenter()
            if x then
                kit:ClearAllPoints()
                kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            end
        elseif not InList(keys, key) and key ~= D.skip and not EdgeOf(key) then
            local kit = api.kit
            local b = before[key]
            local bx, by, bs
            if b then bx, by, bs = b[1], b[2], b[3] end
            StopTween(kit)
            if api.BeginMove then api.BeginMove() end
            SetCompact(api, false)
            SetEdge(api, nil)
            api.Tuck(false)
            api.PlaceFree()
            KitGlide(kit, bx, by, bs)
            if api.EndMove then api.EndMove() end
        end
    end

    -- Kits on the screen edges: each where it was put (kept on screen when
    -- it opens). They never tuck away for each other.
    for _, g in ipairs(Edges()) do
        local openKey
        for _, k in ipairs(g.keys) do
            if D.kits[k] and Shown(k) and D.kits[k].IsOpen() then openKey = k end
        end
        local c, lo, hi, gkeys = GroupCenters(g, openKey)
        for _, k in ipairs(gkeys) do
            local api = D.kits[k]
            if k == D.skip then
                SetEdge(api, g.side) -- under the cursor: just its slots take the edge shape
            else
                local kit = api.kit
                StopTween(kit)
                if api.BeginMove then api.BeginMove() end
                SetCompact(api, false)
                SetEdge(api, g.side)
                api.Tuck(false)
                local x, y = EdgePos(g.side, KitHalf(api), c[k])
                local s = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
                kit:ClearAllPoints()
                kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
                local b = before[k]
                if b then KitGlide(kit, b[1], b[2], b[3]) end
                if api.EndMove then api.EndMove() end
            end
        end
    end
    if #keys == 0 then
        pin:Hide()
        busy = false
        return
    end
    PlacePin(keys)
    -- Keep the pin far enough from the edges that whichever kit opens on it
    -- fits: the game holds that area on screen while you drag the pin, and
    -- an old spot (or a smaller window) is nudged in here.
    local L, R, T, B = 0, 0, 0, 0
    for _, k in ipairs(keys) do
        local api = D.kits[k]
        if api.Reach then
            local l, r, t, b = api.Reach()
            L, R, T, B = math.max(L, l), math.max(R, r), math.max(T, t), math.max(B, b)
        end
    end
    local hw = pin:GetWidth() / 2
    if pin.SetClampRectInsets then
        pin:SetClampRectInsets(-math.max(0, L - hw), math.max(0, R - hw), math.max(0, T - hw), -math.max(0, B - hw))
    end
    do
        local px, py = Center(pin)
        if px then
            local W, H = UIParent:GetWidth(), UIParent:GetHeight()
            local nx = math.min(math.max(px, L), math.max(L, W - R))
            local ny = math.min(math.max(py, B), math.max(B, H - T))
            if math.abs(nx - px) > 0.5 or math.abs(ny - py) > 0.5 then SetPinAt(nx, ny) end
        end
    end

    local openKey
    for _, k in ipairs(keys) do
        if D.kits[k].IsOpen() then openKey = k end
    end

    -- Where each docked kit is now, so it can glide to its new spot (and
    -- where its pinned slots are: BeginMove / EndMove let the kit slide them
    -- along instead of them jumping while the button glides).
    -- While previewing a merge into a floating kit, that kit is held: not
    -- moved, not resized, just its slots re-arranged; the pin and the rest
    -- go around it.
    local hold = D.skip and D.anchor and D.anchor.key or nil
    for _, k in ipairs(keys) do
        local api = D.kits[k]
        if k ~= D.skip and k ~= hold then
            StopTween(api.kit)
            if api.BeginMove then api.BeginMove() end
        end
    end

    local n = #keys
    -- WoW's y runs up: 90 is straight up.
    local angles = n == 2 and { db.two, db.two + 180 }
        or n == 3 and (db.triUp and { 90, -30, 210 } or { -90, 30, 150 })
        or { 0 }
    -- Shrink the closed kits (full size for the one open on the pin, or a
    -- kit docked alone), and space them by their shrunken size.
    local size = 0
    for i, k in ipairs(keys) do
        local api = D.kits[k]
        if k == D.skip or k == hold then
            -- (the held kit keeps its real size, so the pin sits clear of it)
            size = math.max(size, k == hold and api.kit:GetWidth() * api.kit:GetScale() or DockedSize(api, n, false))
            -- Its slots take the shape they'd have docked here (rings round
            -- its button in its slice), without resizing it under the cursor.
            if api.Compact then
                if api.BeginMove then api.BeginMove() end -- its slots glide to the new shape
                if n > 1 then api.Compact(true, angles[i], n == 2 and 170 or 115)
                else api.Compact(api.compact or false, api.compactAngle, api.compactSpan) end
                if api.EndMove then api.EndMove() end
            end
        else
            SetEdge(api, nil)
            SetCompact(api, n > 1 and k ~= openKey, angles[i], n == 2 and 170 or 115)
            local kit = api.kit
            size = math.max(size, kit:GetWidth() * kit:GetScale())
        end
    end
    local r = n == 2 and size * 0.55 or size * 0.66

    -- Two floating kits merging: the one you dropped onto (or are hovering
    -- over) is held exactly where it was, and the pin goes wherever that
    -- needs it, whatever sizes and spacing the dock settles on.
    local anchor = D.anchor
    if anchor and n > 1 then
        local ai = InList(keys, anchor.key)
        if ai and keys[ai] ~= openKey then
            local a = math.rad(angles[ai])
            SetPinAt(anchor.x - r * math.cos(a), anchor.y - r * math.sin(a))
        end
    end

    for i, k in ipairs(keys) do
        local api = D.kits[k]
        local kit = api.kit
        if k == D.skip or k == hold then -- under the cursor, or held where it is
        else
        local ks = kit:GetScale()
        local dx, dy = 0, 0
        if n > 1 and k ~= openKey then
            local a = math.rad(angles[i])
            dx, dy = r * math.cos(a), r * math.sin(a)
        end
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", pin, "CENTER", dx / ks, dy / ks)
        api.Tuck(openKey ~= nil and k ~= openKey)
        local b = before[k]
        if b and not (openKey ~= nil and k ~= openKey) then KitGlide(kit, b[1], b[2], b[3]) end
        if api.EndMove then api.EndMove() end
        end
    end
    pin:SetShown(n >= 2 and not openKey and not D.pinCombatHidden)
end

-- Lays every kit out: floating, on the pin, or on the screen edges.
-- Wrapped so a script error part-way through is reported but can't leave
-- the dock stuck: every later layout would be ignored (kits gone or frozen
-- until a /reload).
function D.Layout()
    if busy then return end
    if InCombatLockdown() then D.pending = true return end
    D.pending = nil
    busy = true
    local ok, err = pcall(DoLayout)
    busy = false
    if not ok then
        D.skip, D.anchor, D.stay = nil, nil, nil
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

local queued = false
local function QueueLayout()
    if queued then return end
    queued = true
    local function run()
        queued = false
        D.Layout()
        if D.SetupMinimap then D.SetupMinimap() end
    end
    if C_Timer then C_Timer.After(0, run) else run() end
end

-- Each kit addon calls this at login with:
--   kit       its main button
--   IsOpen()  whether its slots are out
--   Close()   close it
--   Tuck(on)  hide (on) or show its button and pinned slots
--   PlaceFree() put it at its own saved spot
--   SaveFree()  save where it is now as its own spot
--   BeginMove() / EndMove()  (optional) called around any relayout that
--             moves the kit, so it can glide its pinned slots along too
--   HidesInCombat() (optional) true if the kit hides itself in combat; when
--             every docked kit does, the pin hides in combat as well
--   Edge(side) (optional) the kit is on a screen edge ("left", "right",
--             "top", "bottom") or not (nil): lay its slots out in columns
--             (or rows) toward the middle of the screen
--   EdgeExtent(side, open) (optional) how much room (UI units) the kit
--             takes along that edge, closed or open
function D.Register(key, api)
    D.kits[key] = api
    QueueLayout()
end

---------------------------------------------------------------------------
-- Opening one kit closes the other docked ones
---------------------------------------------------------------------------

function D.Opening(key)
    if not D.IsDocked(key) or InCombatLockdown() then return end
    local g = EdgeOf(key)
    for _, k in ipairs(g and g.keys or DockedKeys()) do
        local api = D.kits[k]
        if k ~= key and api and api.IsOpen() then api.Close() end
    end
    D.Layout()
end

function D.Closed(key)
    if D.IsDocked(key) then D.Layout() end
end

---------------------------------------------------------------------------
-- Dragging a kit
---------------------------------------------------------------------------

-- A docked kit lets go of the pin and floats exactly where it is, at full
-- size. It's grown back before its spot is saved: anchor offsets are in a
-- frame's own scale, so saving a shrunken kit's spot and growing it after
-- would send it leaping across the screen.
local function Release(key)
    local api = D.kits[key]
    local kit = api.kit
    StopTween(kit)
    local x, y = Center(kit)
    DB().docked[key] = false
    SetCompact(api, false)
    if x then
        local s = kit:GetEffectiveScale() / UIParent:GetEffectiveScale()
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        api.SaveFree()
    end
end

-- Whatever was open closes when kits merge, so the result is in view
-- instead of the newcomer tucking away behind the open kit.
local function CloseOpen()
    for _, k in ipairs(DockedKeys()) do
        local api = D.kits[k]
        if api.IsOpen() then api.Close() end
    end
end

-- What a kit was dropped on: the nearest other kit showing on screen, or
-- the pin, within SNAP of the drop point. Returns its key (or "pin") and
-- whether it's part of the dock. floatingOnly: only kits off the dock count
-- (for the open kit carrying its dock, which is already sitting on it).
local function DropTarget(key, cx, cy, pinX, pinY, centers, floatingOnly)
    local docked = DockedKeys()
    local best, bestD, bestDocked
    local function try(k, x, y, inDock)
        if not x then return end
        local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
        if d < SNAP and (not bestD or d < bestD) then best, bestD, bestDocked = k, d, inDock end
    end
    for k, other in pairs(D.kits) do
        if k ~= key and Shown(k) and other.kit:IsVisible()
            and not (floatingOnly and InList(docked, k)) then
            local x, y
            if centers then
                if centers[k] then x, y = centers[k][1], centers[k][2] end
            else
                x, y = Center(other.kit)
            end
            try(k, x, y, InList(docked, k) ~= nil)
        end
    end
    local n = 0 -- the pin stands for the dock too (it hides while a kit is open on it)
    for _, k in ipairs(docked) do if k ~= key then n = n + 1 end end
    if n > 0 and not floatingOnly and (pinX or D.pin) then
        local x, y = pinX, pinY
        if not x then x, y = Center(D.pin) end
        try("pin", x, y, true)
    end
    return best, bestDocked
end

-- Join key to target (another kit, or "pin" for the dock), as if dropped at
-- cx, cy. Changes the saved dock (docked, order, side, pin); the caller lays
-- it out. Used for the drop and for the live preview while dragging.
local function Merge(key, target, targetDocked, cx, cy, centers, preview)
    local db = DB()
    if not targetDocked then
        -- Dropped on a floating kit: the two start a dock, set so the kit
        -- you dropped on stays where it is, and anything docked elsewhere
        -- lets go and floats where it is.
        for _, k in ipairs(DockedKeys()) do
            if k ~= key and k ~= target then
                if preview then -- just a preview: leave it exactly where it is
                    D.stay = D.stay or {}
                    D.stay[k] = true
                    DB().docked[k] = false
                else
                    Release(k)
                end
            end
        end
        local tx, ty
        if centers and centers[target] then tx, ty = centers[target][1], centers[target][2]
        else tx, ty = Center(D.kits[target].kit) end
        local two = math.floor(math.deg(math.atan2(cy - ty, cx - tx)) / 90 + 0.5) * 90
        local size = math.max(DockedSize(D.kits[key], 2), DockedSize(D.kits[target], 2))
        local a = math.rad(two + 180) -- the target's side of the pin
        -- Just noted: the layout moves the pin (after noting where every kit
        -- is), and holds the target where it is.
        Pin()
        db.pin = { tx - size * 0.55 * math.cos(a), ty - size * 0.55 * math.sin(a) }
        db.docked[target] = true
        db.docked[key] = true
        db.two = two
        D.anchor = { key = target, x = tx, y = ty }
        local order = { key, target }
        for _, k in ipairs(db.order) do if not InList(order, k) then order[#order + 1] = k end end
        db.order = order
        return
    end

    -- Join the dock at the pin, on the side (two kits) or corner (three)
    -- it was dropped on.
    db.docked[key] = true
    local px, py
    if db.pin then px, py = db.pin[1], db.pin[2] else px, py = Center(Pin()) end
    local ang = math.deg(math.atan2(cy - py, cx - px))
    local keys = DockedKeys()
    if #keys == 2 then
        -- Two: the dropped kit takes the side it was dropped on.
        db.two = math.floor(ang / 90 + 0.5) * 90
        local other = keys[1] == key and keys[2] or keys[1]
        local order = { key, other }
        for _, k in ipairs(db.order) do if not InList(order, k) then order[#order + 1] = k end end
        db.order = order
    elseif #keys == 3 then
        -- Three: the dropped kit takes the nearest corner, swapping with
        -- whichever kit was there.
        local angles = db.triUp and { 90, -30, 210 } or { -90, 30, 150 }
        local bestI, bestD = 1, 999
        for i, a in ipairs(angles) do
            local diff = math.abs(((ang - a) % 360 + 540) % 360 - 180)
            if diff < bestD then bestI, bestD = i, diff end
        end
        local cur = InList(keys, key)
        keys[cur], keys[bestI] = keys[bestI], keys[cur]
        for _, k in ipairs(db.order) do if not InList(keys, k) then keys[#keys + 1] = k end end
        db.order = keys
    end
end

-- The saved dock as it was when a drag began, so the live preview can try
-- each arrangement and go back.
local function Snapshot()
    local db = DB()
    local s = { docked = {}, order = {}, two = db.two, pin = db.pin and { db.pin[1], db.pin[2] }, edges = {} }
    for k, v in pairs(db.docked) do s.docked[k] = v end
    for i, k in ipairs(db.order) do s.order[i] = k end
    for i, g in ipairs(Edges()) do
        s.edges[i] = { side = g.side, at = g.at, start = g.start, keys = { unpack(g.keys) } }
    end
    return s
end

-- Puts the saved dock back. keepPin leaves the pin frame (and the kits on
-- it) where the preview put them, so what's under the cursor can be read
-- from what's on screen.
local function Restore(s, keepPin)
    local db = DB()
    db.docked, db.order, db.two = {}, {}, s.two
    for k, v in pairs(s.docked) do db.docked[k] = v end
    for i, k in ipairs(s.order) do db.order[i] = k end
    db.pin = s.pin and { s.pin[1], s.pin[2] } or nil
    db.edges = {}
    for i, g in ipairs(s.edges or {}) do
        db.edges[i] = { side = g.side, at = g.at, start = g.start, keys = { unpack(g.keys) } }
    end
    if db.pin and D.pin and not keepPin then SetPinAt(db.pin[1], db.pin[2]) end
end

-- What the dragged kit is over, judged against the dock and the kits as they
-- were when the drag began (not where the preview has moved them, or the
-- kit you're aiming at could slide along under the cursor), with
-- the saved dock put back ready for Merge. The pin itself isn't moved here:
-- the next layout does that, after noting where every kit is, so nothing on
-- the pin jumps before it glides.
local function Resolve(drag, key, cx, cy)
    local s = drag.snap
    Restore(s, true)
    return DropTarget(key, cx, cy, s.pin and s.pin[1], s.pin and s.pin[2], drag.centers, drag.group)
end

-- The open kit carrying its dock, over a floating kit: that kit joins the
-- dock and stays exactly where it is, and the dock settles round it. Same
-- as dropping a closed kit on it.
local function JoinGroup(target, centers)
    local tx, ty
    if centers and centers[target] then tx, ty = centers[target][1], centers[target][2]
    else tx, ty = Center(D.kits[target].kit) end
    Pin()
    DB().docked[target] = true
    D.anchor = { key = target, x = tx, y = ty }
end

local function Signature()
    local db = DB()
    local p = db.pin or {}
    local e = {}
    for _, g in ipairs(Edges()) do
        e[#e + 1] = g.side .. math.floor((g.at or g.start or 0) + 0.5) .. ":" .. table.concat(g.keys, ",")
    end
    return table.concat(DockedKeys(), ",") .. "|" .. tostring(db.two) .. "|"
        .. math.floor((p[1] or 0) + 0.5) .. "," .. math.floor((p[2] or 0) + 0.5) .. "|" .. table.concat(e, ";")
end

-- While you drag a kit (not the open one carrying its dock), the dock
-- rearranges live: over another kit or the pin, the kits move into the
-- shape they'd take with this one joined, leaving its spot free; away from
-- everything, the dock closes up without it. Letting go settles it there.
--
-- Open kits merge just like closed ones: whatever's open on the dock being
-- formed (the kit you're dragging, the kit you're over, or the one open on
-- the pin) closes as soon as the merge shows, so the preview is exactly
-- what you get on letting go, and nothing tucks away behind an open kit.
local function Preview(key, cx, cy)
    local drag = D.dragging
    if not drag or not drag.snap or InCombatLockdown() then return end
    local target, targetDocked = Resolve(drag, key, cx, cy)
    D.anchor = nil
    D.stay = nil
    -- (Carrying the dock, the edges don't count: the dock just moves.)
    local side = not drag.group and NearEdge(cx, cy) or nil
    if drag.group then
        -- Carrying the dock: only a floating kit is something to merge with;
        -- away from one, the dock just follows along. Until it first meets
        -- one, nothing moves: the dock is under it.
        if not target and not drag.merged then return end
        if target then
            JoinGroup(target, drag.centers)
            drag.merged = true
        end
    elseif side then
        target = nil
        JoinEdge(key, side, cx, cy)
        -- Pulled out of a pair: the kit left behind stays exactly where it is.
        local left = DockedKeys()
        if #left == 1 then
            D.stay = { [left[1]] = true }
            DB().docked[left[1]] = false
        end
    elseif target then
        LeaveEdge(key)
        Merge(key, target, targetDocked, cx, cy, drag.centers, true)
    else
        LeaveEdge(key)
        DB().docked[key] = false
        -- Pulled out of a pair: the kit left behind stays exactly where it is.
        local left = DockedKeys()
        if #left == 1 then
            D.stay = { [left[1]] = true }
            DB().docked[left[1]] = false
        end
    end
    local sig = Signature()
    if sig ~= drag.sig then
        drag.sig = sig
        D.skip = key -- before closing anything: a closing kit lays the dock out
        if target then CloseOpen() end
        D.Layout()
        -- Away from everything: the dragged kit's slots go back to how they
        -- really are. A kit that was held for a merge preview and isn't any
        -- more gets its own slots back too.
        local api = D.kits[key]
        if not target and api.Compact then api.Compact(api.compact or false, api.compactAngle, api.compactSpan) end
        if not side then SetEdge(api, nil) end
        local held = D.anchor and D.anchor.key or nil
        if drag.held and drag.held ~= held then
            local h = D.kits[drag.held]
            if h and h.Compact then h.Compact(h.compact or false, h.compactAngle, h.compactSpan) end
        end
        drag.held = held
    end
end

-- While a kit is dragged, a small watcher re-checks what's under it a few
-- times a second and updates the live preview.
local function Watcher()
    if D.watch then return D.watch end
    local w = CreateFrame("Frame")
    w:Hide()
    local elapsed = 0
    w:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        local drag = D.dragging
        local api = drag and D.kits[drag.key]
        if not api then return end
        local cx, cy = Center(api.kit)
        if cx then
            D.EdgeGlow(not drag.group and NearEdge(cx, cy) or nil, cx, cy)
            Preview(drag.key, cx, cy)
        end
    end)
    D.watch = w
    return w
end

-- Called from a kit's OnDragStart. The kit open on the pin carries its
-- whole dock with it; any other kit moves on its own.
function D.DragStart(key)
    if InCombatLockdown() then return end
    local api = D.kits[key]
    local kit = api.kit
    -- Lift the kit off the pin at the same spot so it can move freely.
    StopTween(kit)
    local x, y = kit:GetCenter()
    if x then
        kit:ClearAllPoints()
        kit:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end
    kit:StartMoving()
    -- Where every other kit sits right now: the preview judges what you're
    -- over against these, so its own rearranging doesn't move the target.
    local centers = {}
    for k, other in pairs(D.kits) do
        if k ~= key then
            StopTween(other.kit) -- where it's settling, not part-way there
            local x, y = Center(other.kit)
            if x then centers[k] = { x, y } end
        end
    end
    D.dragging = { key = key, group = PinDocked(key) and api.IsOpen(), snap = Snapshot(), centers = centers }
    Watcher():Show()
end

-- Called from a kit's OnDragStop.
function D.DragStop(key)
    local drag = D.dragging
    D.dragging = nil
    if D.watch then D.watch:Hide() end
    D.EdgeGlow(nil)
    D.skip = nil
    D.anchor = nil
    D.stay = nil
    local api = D.kits[key]
    local kit = api.kit
    kit:StopMovingOrSizing()
    if not drag then return end
    local db = DB()
    local cx, cy = Center(kit)
    if not cx then
        if drag.snap then Restore(drag.snap) end
        D.Layout()
        return
    end
    local target, targetDocked = Resolve(drag, key, cx, cy)

    if drag.group then
        if target then -- dropped on a floating kit: it joins, held where it is
            JoinGroup(target, drag.centers)
            CloseOpen()
            D.Layout()
            D.anchor = nil
            if api.Compact then api.Compact(api.compact or false, api.compactAngle, api.compactSpan) end
        else -- the open kit moved its dock: the pin follows it
            Pin()
            SetPinAt(cx, cy)
            D.Layout()
        end
        if drag.held and drag.held ~= target then
            local h = D.kits[drag.held]
            if h and h.Compact then h.Compact(h.compact or false, h.compactAngle, h.compactSpan) end
        end
        return
    end

    local side = NearEdge(cx, cy)
    if side then -- on a screen edge
        JoinEdge(key, side, cx, cy)
        SetCompact(api, false)
        local left = DockedKeys()
        local lone, lb
        if #left == 1 then
            lone = D.kits[left[1]].kit
            local x, y = lone:GetCenter()
            if x then lb = { x, y, lone:GetEffectiveScale() } end
            Release(left[1])
        end
        D.Layout()
        if lone and lb then KitGlide(lone, lb[1], lb[2], lb[3]) end
        if drag.held then
            local h = D.kits[drag.held]
            if h and h.Compact then h.Compact(h.compact or false, h.compactAngle, h.compactSpan) end
        end
        return
    end
    LeaveEdge(key)

    if not target then -- dropped on nothing: float right here
        Release(key)
        -- A dock can't be one kit: the one left behind floats where it is.
        local left = DockedKeys()
        local lone, lb
        if #left == 1 then
            lone = D.kits[left[1]].kit
            local x, y = lone:GetCenter()
            if x then lb = { x, y, lone:GetEffectiveScale() } end
            Release(left[1])
        end
        D.Layout()
        if lone and lb then KitGlide(lone, lb[1], lb[2], lb[3]) end -- grows back in place
        if drag.held then
            local h = D.kits[drag.held]
            if h and h.Compact then h.Compact(h.compact or false, h.compactAngle, h.compactSpan) end
        end
        if api.Compact then api.Compact(api.compact or false, api.compactAngle, api.compactSpan) end
        return
    end
    D.anchor = nil
    Merge(key, target, targetDocked, cx, cy, not drag.group and drag.centers or nil)
    CloseOpen()
    D.Layout()
    D.anchor = nil
    if drag.held and drag.held ~= target then
        local h = D.kits[drag.held]
        if h and h.Compact then h.Compact(h.compact or false, h.compactAngle, h.compactSpan) end
    end
    if api.Compact then api.Compact(api.compact or false, api.compactAngle, api.compactSpan) end
end

---------------------------------------------------------------------------
-- Slash helpers (each addon offers "dock" and "flip")
---------------------------------------------------------------------------

-- Dock every kit again, around the pin (or around this kit if there's none).
function D.DockAll(fromKey)
    if InCombatLockdown() then return end
    local db = DB()
    db.edges = {}
    local hadPin = db.pin and db.pin[1] and db.pin[2] and #DockedKeys() > 0
    for k in pairs(D.kits) do db.docked[k] = true end
    if not hadPin and fromKey and D.kits[fromKey] then
        local x, y = Center(D.kits[fromKey].kit)
        if x then Pin() SetPinAt(x, y) end
    end
    D.Layout()
end

-- Put the pin back in the middle of the screen.
function D.ResetPin()
    if InCombatLockdown() then return end
    Pin()
    SetPinAt(UIParent:GetWidth() / 2, UIParent:GetHeight() / 2)
    D.Layout()
end

-- A docking option changed somewhere (a kit's settings panel or the Kits
-- menu): let every kit's panel catch up.
function D.SettingsChanged()
    for _, api in pairs(D.kits) do
        if api.SettingsChanged then api.SettingsChanged() end
    end
end

-- Point the triangle the other way.
function D.Flip()
    if InCombatLockdown() then return end
    local db = DB()
    db.triUp = not db.triUp
    D.Layout()
end

---------------------------------------------------------------------------
-- One shared minimap button when two or more kits are installed. Its menu
-- shows or hides each kit entirely and opens each kit's settings. Each
-- addon's own minimap button steps aside while this one is there.
---------------------------------------------------------------------------

local NAMES = { fak = "First Aid Kit", ck = "Camping Kit", fk = "Fishing Kit" }

function D.SharedMinimap() return Installed() >= 2 end

local mmButton, menu

local function PlaceMinimap()
    if not mmButton then return end
    local angle = math.rad(DB().minimapAngle or 225)
    local r = (Minimap:GetWidth() / 2) + 6
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function BuildMenu()
    if menu then return menu end
    local ok, f = pcall(CreateFrame, "Frame", "KitDockMenu", UIParent, "BackdropTemplate")
    if not ok or not f then f = CreateFrame("Frame", "KitDockMenu", UIParent) end
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.06, 0.07, 0.05, 0.95)
        f:SetBackdropBorderColor(0.75, 0.62, 0.3, 1)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.07, 0.05, 0.95)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText("Kits")
    f.rows = {}
    -- Docking option: keep the kits at their normal size instead of shrinking them.
    local okc, cb = pcall(CreateFrame, "CheckButton", nil, f, "UICheckButtonTemplate")
    if not okc or not cb then cb = CreateFrame("CheckButton", nil, f) end
    cb:SetSize(24, 24)
    f.full = cb
    f.fullLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.fullLabel:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    f.fullLabel:SetText("Full-size kits when docked")
    cb:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(not self:GetChecked())
            return
        end
        DB().fullSize = self:GetChecked() and true or false
        D.Layout()
        D.SettingsChanged()
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Full-size kits when docked")
        GameTooltip:AddLine("Keep each docked kit at its normal size while it's closed, instead of shrinking it. Pinned slots still fan out around the outside.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Hide()
    tinsert(UISpecialFrames, "KitDockMenu") -- Escape closes it
    menu = f
    return f
end

local function FillMenu()
    local f = BuildMenu()
    local y = -30
    local i = 0
    for _, k in ipairs(ORDER) do
        local api = D.kits[k]
        if api then
            i = i + 1
            local row = f.rows[i]
            if not row then
                row = {}
                local okc, cb = pcall(CreateFrame, "CheckButton", nil, f, "UICheckButtonTemplate")
                if not okc or not cb then cb = CreateFrame("CheckButton", nil, f) cb:SetSize(24, 24) end
                cb:SetSize(24, 24)
                row.cb = cb
                row.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                local okb, gear = pcall(CreateFrame, "Button", nil, f, "UIPanelButtonTemplate")
                if not okb or not gear then gear = CreateFrame("Button", nil, f) end
                gear:SetSize(70, 20)
                gear:SetText("Settings")
                row.gear = gear
                f.rows[i] = row
            end
            row.cb:ClearAllPoints()
            row.cb:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
            row.label:SetText(NAMES[k] or k)
            row.gear:ClearAllPoints()
            row.gear:SetPoint("RIGHT", f, "TOPRIGHT", -10, y - 12)
            row.cb:SetChecked(not (api.IsHidden and api.IsHidden()))
            row.cb:SetScript("OnClick", function(self)
                if InCombatLockdown() then
                    self:SetChecked(not self:GetChecked())
                    return
                end
                if api.SetHidden then api.SetHidden(not self:GetChecked()) end
                D.Layout()
            end)
            row.gear:SetScript("OnClick", function()
                f:Hide()
                if api.OpenSettings then api.OpenSettings() end
            end)
            row.cb:Show() row.label:Show() row.gear:Show()
            y = y - 28
        end
    end
    for j = i + 1, #f.rows do f.rows[j].cb:Hide() f.rows[j].label:Hide() f.rows[j].gear:Hide() end
    y = y - 6
    f.full:ClearAllPoints()
    f.full:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
    f.full:SetChecked(DB().fullSize and true or false)
    y = y - 28
    f:SetSize(240, -y + 10)
end

local function ToggleMenu()
    local f = BuildMenu()
    if f:IsShown() then f:Hide() return end
    FillMenu()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", mmButton, "BOTTOMLEFT", 0, 0)
    f:Show()
end

function D.SetupMinimap()
    local shared = D.SharedMinimap()
    for _, api in pairs(D.kits) do
        if api.ApplyMinimap then api.ApplyMinimap() end -- own buttons step aside (or come back)
    end
    if not shared or not Minimap then
        if mmButton then mmButton:Hide() end
        return
    end
    if not mmButton then
        local b = CreateFrame("Button", "KitDockMinimapButton", Minimap)
        b:SetSize(31, 31)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 7, -7)
        icon:SetPoint("BOTTOMRIGHT", -7, 7)
        icon:SetTexture(D.media .. "pin_dot", nil, nil, "LINEAR")
        local ring = b:CreateTexture(nil, "OVERLAY")
        ring:SetAllPoints()
        ring:SetTexture(D.media .. "ring_prof_64", nil, nil, "LINEAR")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture(D.media .. "glow_ring")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints()
        hl:SetAlpha(0.5)
        b:SetScript("OnClick", function() ToggleMenu() end)
        b:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local px, py = GetCursorPosition()
                local sc = Minimap:GetEffectiveScale()
                DB().minimapAngle = math.deg(math.atan2(py / sc - my, px / sc - mx)) % 360
                PlaceMinimap()
            end)
            GameTooltip:Hide()
        end)
        b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Kits")
            GameTooltip:AddLine("Click: show or hide each kit, and open its settings", 1, 1, 1)
            GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        mmButton = b
    end
    mmButton:SetShown(DB().minimap ~= false)
    PlaceMinimap()
    if menu and menu:IsShown() then FillMenu() end
end

-- The pin steps out of the way in combat when every docked kit hides in
-- combat (each kit's own setting; First Aid Kit never does), and comes back
-- with them after. Combat also queues any layout that couldn't run.
local function PinHidesInCombat()
    local keys = DockedKeys()
    if #keys == 0 then return false end
    for _, k in ipairs(keys) do
        local api = D.kits[k]
        if not (api.HidesInCombat and api.HidesInCombat()) then return false end
    end
    return true
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for kit in pairs(tweens) do StopTween(kit) end
        if D.pin and PinHidesInCombat() then
            D.pinCombatHidden = true
            D.pin:Hide()
        end
    else
        local hidden = D.pinCombatHidden
        D.pinCombatHidden = nil
        if D.pending or hidden then D.Layout() end
    end
end)
