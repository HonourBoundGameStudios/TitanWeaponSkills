-- LibEmber-1.0 — the WIRING half of the particle library.
--
-- A hearth is a pool of embers burning on a HOST FRAME. It takes the host and three numbers for a
-- tint, and owns nothing else: no skin, no class colours, no strata argument, no idea what a rail
-- is. That is the whole item -- the brain (LibEmber-1.0.lua) is host-agnostic, and a hearth built
-- on a 400x200 panel costs the same call as one built on a 3840x182 painting.
--
-- LIBRARY DISCIPLINE: this file may reference nothing but the core it attaches to and the client's
-- own frame API -- no consumer's globals, ever.
--
-- Loaded as a SEPARATE file after LibEmber-1.0.lua (both an addon's .toc and this repo's own
-- Tests/run-all.ps1 order them that way). It cannot re-run `LibStub:NewLibrary` for the same major
-- the core already claimed -- a second call with an equal minor would stand down and strand this
-- half's code -- so it fetches the core's table directly and tracks its OWN component version in a
-- private field on it, immune to the core's own minor ticking independently.
--
-- The API, and the caller's half of the bargain:
--   local hearth = Ember.Hearth(host, { atlas = "...path..." })
--   hearth.light{ count, r, g, b, wind, core, species }   ambience: retires, then relights from rest
--   hearth.burst(n, { r, g, b, species, delayScale, pop })  one flourish: n one-life embers
--   hearth.grow(from, to)                                  add slots WITHOUT disturbing the burning
--   hearth.retire()                                        dark and motionless
--   hearth.census()                                        slots, animations, animations-per-slot
--
-- The engine is the whole point: pooled Textures, one AnimationGroup per slot, and an OnFinished
-- re-roll loop. A fixed set of N particles each on its own randomised life IS continuous ambience
-- -- no emitter tick, no OnUpdate, zero per-frame Lua. Every call is field-proven on Classic Era
-- 11509: the fades are LibDBIcon's breathing, the climb is Details' Translation, SetToFinalAlpha is
-- LibCustomGlow's ProcStart, and the sub-pixel snapping calls ship ungated in WeakAuras and Details.

local MAJOR, HEARTH_MINOR = "LibEmber-1.0", 1
local Ember = LibStub:GetLibrary(MAJOR, true)
if not Ember then return end                              -- the core did not load first; nothing to attach to
if (Ember.hearthMinor or 0) >= HEARTH_MINOR then return end  -- a newer (or equal) copy of THIS half already attached
Ember.hearthMinor = HEARTH_MINOR

-- The wiring's own knobs -- numbers here, never inline below. The particle MATH (bands, the atlas
-- grid, the wind's periods) lives in Ember.TOKENS; these are properties of how a SLOT is
-- built, which is this file's business alone. Every one is overridable per hearth through opts, so
-- two hosts can differ without either editing the library's defaults.
Ember.HEARTH = {
    fadeInSeconds = 0.4,    -- the kindle: quick off the wood, like the climb's own easing
    fadeOutFrac   = 0.35,   -- the last stretch of a life spent dying, fraction of its seconds
    legMax        = 8,      -- FORCE-8/7: path legs built per slot -- 8 because that is what a
                            -- swirl needs to read as a circle rather than a hexagon. A species
                            -- asking for more walks straight instead: the wiring cannot grow an
                            -- animation group at play time, and a half-walked path would land the
                            -- ember somewhere its own EndPoint does not know about.
    burstMax      = 200,    -- the flourish pool: a full fountain plus an occasion with headroom,
                            -- then quiet refusal. A pool smaller than one burst silently caps it.
}

local function isNum(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- One hearth on one host. Everything below closes over `self`; nothing is a method, so a caller
-- can hand `hearth.burst` to a handler without carrying the receiver with it (Ember.Pool's
-- idiom, one register up).
function Ember.Hearth(host, opts)
    if type(host) ~= "table" or type(host.CreateAnimationGroup) ~= "function" then return nil end
    if type(opts) ~= "table" or type(opts.atlas) ~= "string" then return nil end

    local W = Ember.HEARTH
    local cfg = {
        atlas         = opts.atlas,
        fadeInSeconds = isNum(opts.fadeInSeconds) and opts.fadeInSeconds or W.fadeInSeconds,
        fadeOutFrac   = isNum(opts.fadeOutFrac) and opts.fadeOutFrac or W.fadeOutFrac,
        legMax        = isNum(opts.legMax) and math.floor(opts.legMax) or W.legMax,
        burstMax      = isNum(opts.burstMax) and math.floor(opts.burstMax) or W.burstMax,
    }

    -- The hearth's own frame, laid over the host: the pure code's domain is this frame's rect, so
    -- every fraction an effect is described in -- the origin line, a spawn band, a mask's grid --
    -- is a fraction of whatever the host happens to be. That is the whole of the port to a panel.
    local self = {
        host = host,
        cfg = cfg,
        frame = CreateFrame("Frame", nil, host),
        slots = {},
        gen = 0,
        r = 1, g = 1, b = 1,
        core = 0,
        windScale = 0,
    }
    self.frame:SetAllPoints(host)

    local playEmber                 -- forward: the OnFinished handler is installed once, at acquire
    local burst                     -- forward: a dying ember's pop raises more of them

    -- ── The wind ────────────────────────────────────────────────────────────────────────────
    -- FORCE-3: two frames NESTED inside the hearth, each carrying one slow oscillation, and every
    -- ember holder hangs off the inner one -- so one gust moves a hundred embers for the price of
    -- one, and the C engine composes it with each ember's own climb and sway for nothing.
    --
    -- Two FRAMES rather than two animations on one, for the flock's reason a third time: two
    -- Translations on one region overwrite. Nesting is what makes them add up, and it is what buys
    -- the beat -- a brisk gust riding a slow swell whose periods cannot lock.
    --
    -- ⚠️ THE ONE UNPROVEN PRIMITIVE IN THE HEARTH (SPEC-3d). Everything else here was field-checked
    -- against shipped Era addons first; this rests on a frame's Translation carrying its child
    -- FRAMES, not merely its own textures. Written up in Research/emitter-types.md §0.1. The
    -- failure mode is BENIGN and self-announcing: if it does not propagate, the wind frames swing
    -- and no ember moves -- still air, never an error.
    local function acquireWind()
        if self.wind then return self.wind end
        local layers = Ember.TOKENS.wind.layers
        local wind, parent = {}, self.frame
        for i = 1, #layers do
            -- No SetFrameLevel: the hierarchy orders these (BUG-8). Pinning them to an absolute
            -- level read at build time is what let the draw order drift out from under the embers.
            local f = CreateFrame("Frame", nil, parent)
            f:SetAllPoints(self.frame)
            local group = f:CreateAnimationGroup()
            -- BUG-8's fix, and it is a RETURN to what the research asked for: "two slow LOOPING
            -- oscillating Translations at incommensurate periods". The first cut made each layer a
            -- one-shot re-rolled from OnFinished so every gust could pick a fresh strength, and
            -- that seam was the whole bug: a Translation's displacement exists only while its
            -- group PLAYS, so a group that finishes, drops its transform and is re-Played jerks
            -- everything hanging off it -- and everything hangs off this one.
            group:SetLooping("REPEAT")
            local out = group:CreateAnimation("Translation")
            out:SetOrder(1)
            out:SetSmoothing("IN_OUT")
            local back = group:CreateAnimation("Translation")
            back:SetOrder(2)
            back:SetSmoothing("IN_OUT")
            wind[i] = { frame = f, group = group, out = out, back = back, tokens = layers[i] }
            parent = f                  -- the next layer hangs off this one, so they compose
        end
        self.wind = wind
        return wind
    end

    -- One gust on one layer: roll it, aim the two halves, play. Stops dead when the caller says
    -- calm, which is the default -- a host that names no wind never starts the loop at all.
    -- Rolled ONCE per lighting: the two layers' period bands cannot overlap, so a brisk gust rides
    -- a slow swell and the beat between them never visibly repeats. That is the variety, and it
    -- never came from the re-roll the bug shipped.
    local function playGust(layer)
        local scale = self.windScale
        if not isNum(scale) or scale <= 0 then return end
        local gust = Ember.Gust(self.frame:GetHeight(), {
            amp = math.random(), side = math.random(), lift = math.random(), pace = math.random(),
        }, layer.tokens)
        if not gust then return end     -- an unsized host: no wind, never an error

        local half = gust.seconds / 2
        -- The plan is y-DOWN like every other here; a Translation's offset is y-up.
        layer.out:SetDuration(half)
        layer.out:SetOffset(gust.dx * scale, -gust.dy * scale)
        layer.back:SetDuration(half)
        layer.back:SetOffset(-gust.dx * scale, gust.dy * scale)
        layer.group:Play()
    end

    -- ── One slot ────────────────────────────────────────────────────────────────────────────
    -- One holder, one texture and one life per slot, built once and reused forever -- frames and
    -- regions are indestructible, so pooling is correctness, not thrift.
    --
    -- FORCE-2 made the ember a HOLDER FRAME wearing a texture rather than a bare texture, and the
    -- reason is the flock's own field lesson: two Translations on ONE region overwrite each other,
    -- so a carrier and a rider have to sit on different objects. The holder walks the climb; the
    -- quad sways about the holder. A frame's alpha cascades to its texture, so the kindle and the
    -- death simply moved up with the climb and stayed one animation each.
    local function acquireEmber(index)
        local slot = self.slots[index]
        if slot then return slot end

        -- Hung off the INNERMOST wind layer (FORCE-3), so both gusts carry this ember without it
        -- knowing anything about weather. Still anchored to the hearth: the pure code's domain is
        -- the host's rect, and an animation transform never moves the anchor it was laid from.
        local wind = acquireWind()
        -- No SetFrameLevel here either (BUG-8): a holder draws above the wind layer that parents
        -- it because it is its child, and that ordering cannot be stranded by a level moving.
        local holder = CreateFrame("Frame", nil, wind[#wind].frame)
        -- Rest is dark, so the first frame after Play cannot flash a lit ember before the kindle
        -- takes hold (the flock's holders open at zero for the same reason).
        holder:SetAlpha(0)

        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(holder)
        tex:SetTexture(cfg.atlas)
        -- FORCE-4: the white-hot CORE, stacked over the tinted glow and never tinted itself. It
        -- fades out over the life's first stretch, so what is left is the caller's colour -- an
        -- ember that COOLS as it climbs, which is the difference between fire and a firefly. One
        -- layer up (OVERLAY) so it always burns through its own glow, and ADD like the glow, so a
        -- core at rest is not there at all.
        local core = holder:CreateTexture(nil, "OVERLAY")
        core:SetAllPoints(holder)
        core:SetTexture(cfg.atlas)
        core:SetBlendMode("ADD")
        core:SetSnapToPixelGrid(false)
        core:SetTexelSnappingBias(0)
        core:SetAlpha(0)
        -- ADD: an ember only ever brightens the painting beneath it, and at rest (alpha 0) it is
        -- not there at all -- so nothing burns on an untouched host.
        tex:SetBlendMode("ADD")
        -- A particle drifts fractions of a pixel per frame; grid snapping would stairstep the
        -- climb into a shiver. Both calls ship ungated in WeakAuras/Details on this Era install.
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)

        -- The life: kindle, climb, die -- all order 1, so the group runs exactly one life. The
        -- finished fade-in HOLDS while the climb runs (LibCustomGlow's ProcStart persistence), and
        -- SetToFinalAlpha lands the finished one-shot at the fade-out's 0, dark until re-rolled.
        local life = holder:CreateAnimationGroup()
        life:SetToFinalAlpha(true)
        local kindle = life:CreateAnimation("Alpha")
        kindle:SetOrder(1)
        kindle:SetSmoothing("IN")
        local climb = life:CreateAnimation("Translation")
        climb:SetOrder(1)
        climb:SetSmoothing("OUT")       -- quick off the wood, slowing as it cools
        -- FORCE-6: the ballistic pair, idle unless a species asks for an arc. Order 1 with start
        -- delays, exactly as the kindle and the death already sequence themselves -- NOT chained
        -- orders, which would wait for the whole life. Vertical only, so the horizontal drift
        -- beside them can stay LINEAR while these ease: same-order animations combine, which is
        -- what makes a straight throw curve.
        local arcUp = life:CreateAnimation("Translation")
        arcUp:SetOrder(1)
        arcUp:SetSmoothing("OUT")       -- fastest at the throw, slowing into the apex
        local arcDown = life:CreateAnimation("Translation")
        arcDown:SetOrder(1)
        arcDown:SetSmoothing("IN")      -- and gathering speed all the way back down

        -- FORCE-8: the streamline's legs, idle unless a species walks a turbulence field. Order 1
        -- with start delays like everything else here, and deliberately NOT eased: an eased leg
        -- starts AND ends at zero speed, so easing all of them would stop the ember dead at every
        -- waypoint and snap it back to speed -- the flock learned that one the hard way.
        local legs = {}
        for _ = 1, cfg.legMax do
            local leg = life:CreateAnimation("Translation")
            leg:SetOrder(1)
            leg:SetSmoothing("NONE")
            legs[#legs + 1] = leg
        end
        local die = life:CreateAnimation("Alpha")
        die:SetOrder(1)
        die:SetSmoothing("OUT")
        -- The cooling rides in the life group, aimed at the CORE alone (Details hosts groups on a
        -- frame and retargets them to regions all over 11509). One group means the cool can never
        -- drift out of step with the climb it belongs to.
        local cool = life:CreateAnimation("Alpha")
        cool:SetOrder(1)
        cool:SetSmoothing("OUT")        -- hottest at birth, and most of the change comes early
        cool:SetTarget(core)

        -- FORCE-2, the sway: out and back, retargeted at BOTH textures from one group. Hosted on
        -- the holder rather than on a texture since FORCE-4, and that is what keeps the two layers
        -- welded: two identical groups on two textures would be two clocks, where two targets in
        -- ONE group cannot shear by construction. The holder's own Translation is the climb, and
        -- these never touch the holder, so nothing overwrites anything.
        -- Mirrored halves under REPEAT and never BOUNCE, since no Era addon exercises it.
        local wander = holder:CreateAnimationGroup()
        wander:SetLooping("REPEAT")
        local sways = {}
        for i, target in ipairs({ tex, core }) do
            local out = wander:CreateAnimation("Translation")
            out:SetOrder(1)
            out:SetSmoothing("IN_OUT")
            out:SetTarget(target)
            local home = wander:CreateAnimation("Translation")
            home:SetOrder(2)
            home:SetSmoothing("IN_OUT")
            home:SetTarget(target)
            sways[i] = { out = out, home = home }
        end

        slot = { holder = holder, tex = tex, core = core, life = life, kindle = kindle,
            climb = climb, die = die, cool = cool, wander = wander, sways = sways,
            arcUp = arcUp, arcDown = arcDown, legs = legs, r = 1, g = 1, b = 1 }

        -- One closure per slot, created at build and NEVER per play (the flock's rule): a fresh
        -- closure per life is a slow leak measured in evenings. A finished life re-rolls itself
        -- unless the generation moved -- then it goes quiet, and stays dark by the final alpha.
        -- A BURST slot plays one life instead: it hands its pool slot back and rests.
        life:SetScript("OnFinished", function()
            if slot.gen ~= self.gen then return end
            if slot.burstIndex then
                -- The sway loops forever by contract, so a slot going back to rest has to end it
                -- here: an idle burst slot must be dark AND still, not dark and swinging.
                slot.wander:Stop()
                -- FORCE-11: what this slot leaves behind, read off BEFORE the slot goes back --
                -- the children may well be handed this very slot, and recycling it is the point.
                local pop, px, py = slot.pop, slot.endX, slot.endY
                slot.pop = nil
                if self.burstPool then self.burstPool.release(slot.burstIndex) end
                slot.burstIndex = nil
                if pop then
                    -- The seat is a FRACTION, because that is the only language Roll speaks.
                    -- Clamped into the hearth: a spark that drifted off the end of the host must
                    -- not pop off the side of it.
                    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
                    if isNum(px) and isNum(py) and isNum(w) and w > 0 and isNum(h) and h > 0 then
                        local s = {}
                        for k, v in pairs(pop) do s[k] = v end
                        s.spawnMin = math.max(0, math.min(1, px / w))
                        s.spawnMax = s.spawnMin
                        s.originLine = math.max(0, math.min(1, py / h))
                        s.cells = s.cells or Ember.TOKENS.cells
                        -- In the parent's own colour, and never popping in turn (`pop` is not
                        -- passed on) -- which is what stops one thrown spark becoming a chain.
                        burst(pop.count, { r = slot.r, g = slot.g, b = slot.b, species = s })
                    end
                end
                return
            end
            playEmber(slot)
        end)
        self.slots[index] = slot
        return slot
    end

    -- ── One life ────────────────────────────────────────────────────────────────────────────
    -- Roll a plan, aim the holder, its textures and their animations at it, play. The rolls are
    -- the wiring's only creative act -- everything that DECIDES lives in Ember.Roll, tested.
    -- `delayScale` compresses the spawn stagger (a roll is 0..1 by contract, so scaling the roll
    -- keeps the contract): ambience breathes in over delayMax, a flourish answers its event
    -- promptly. `tokens` is a species for Roll. `given` (FORCE-12) replays an EXISTING plan
    -- instead of rolling a fresh one -- how a streak's echo is a copy of its parent's flight
    -- rather than one more particle beside it. Returns the plan it played, so a caller can echo it.
    playEmber = function(slot, delayScale, tokens, given)
        -- The ambience's own species, when the caller named one. Defaulted HERE rather than
        -- passed, because the re-roll loop's OnFinished calls this with no tokens at all -- an
        -- ember that spawned on a painting once must go on doing so for the whole session.
        tokens = tokens or self.species
        local width, height = self.frame:GetWidth(), self.frame:GetHeight()
        local plan = given or Ember.Roll(width, height, {
            -- x picks the hot seat, x2/x3/x4 are the bell inside it (FORCE-1). A species without a
            -- spawnCluster never reads the last three -- rolling them anyway keeps this one call.
            x = math.random(), x2 = math.random(), x3 = math.random(), x4 = math.random(),
            cell = math.random(), rise = math.random(), drift = math.random(),
            pace = math.random(), delay = math.random() * (delayScale or 1),
            size = math.random(), alpha = math.random(),
            -- The sway's own width, period and which way it leans off first (FORCE-2). All three
            -- rolled per LIFE, so a slot never repeats its last swing.
            wanderAmp = math.random(), wanderPace = math.random(), wanderSide = math.random(),
            -- The shape's own rolls (FORCE-9/10): which way round a ring or cone, and which
            -- painted cell of a mask plus where inside it. Unread by a species with no shape.
            theta = math.random(), radial = math.random(), cone = math.random(), y = math.random(),
            mask = math.random(), maskX = math.random(), maskY = math.random(),
        }, tokens)
        local coords = plan and Ember.CellCoords(plan.cell)
        if not coords then return nil end   -- a host with no size yet: no ember, never an error

        local holder = slot.holder
        slot.gen = self.gen
        slot.tex:SetTexCoord(coords.left, coords.right, coords.top, coords.bottom)
        slot.core:SetTexCoord(coords.left, coords.right, coords.top, coords.bottom)
        -- FORCE-12: a species that wears a streak turns it to face the way it flies. Every other
        -- species is squared up explicitly -- a pooled slot that streaked last life would
        -- otherwise hand a rotated mote to the next one.
        local turn = (tokens and tokens.aligned) and plan.angle or 0
        slot.tex:SetRotation(turn)
        slot.core:SetRotation(turn)
        holder:SetSize(plan.size, plan.size)
        -- The flock's trap 1: a Translation displaces the drawn quad, never the anchor -- re-anchor
        -- to the rolled origin before every Play, or each life climbs from where the last ended.
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", self.frame, "TOPLEFT", plan.x0, -plan.y0)

        -- FORCE-2: the sway, re-aimed and restarted per life. Stop FIRST -- a looping group
        -- already mid-cycle would carry the last life's duration -- and stopping also returns the
        -- quad to its anchor, which keeps a species that does not wander climbing dead straight.
        slot.wander:Stop()
        if plan.wanderSeconds > 0 and plan.wanderAmp ~= 0 then
            local half = plan.wanderSeconds / 2
            for _, s in ipairs(slot.sways) do
                s.out:SetDuration(half)
                s.out:SetOffset(plan.wanderAmp, 0)
                s.home:SetDuration(half)
                s.home:SetOffset(-plan.wanderAmp, 0)
            end
            slot.wander:Play()
        end

        slot.kindle:SetStartDelay(plan.delay)
        slot.kindle:SetDuration(cfg.fadeInSeconds)
        slot.kindle:SetFromAlpha(0)
        slot.kindle:SetToAlpha(plan.peakAlpha)
        slot.climb:SetStartDelay(plan.delay)
        -- FORCE-6: with an arc, the carrier keeps the HORIZONTAL and hands the vertical to the
        -- pair below -- linear, because a drift that eased with the climb would curve the wrong
        -- way. The net vertical still comes from `dy`, so a species whose rise band is zero lands
        -- back on the wood it left. Without an arc this is the one straight Translation it was.
        -- The plan is y-DOWN (dy negative: the ember rises); a Translation's offset is y-up.
        local arcing = plan.arcApex > 0 and plan.arcSeconds > 0
        -- FORCE-8: a turbulent ember's legs carry the WHOLE flight (they sum to dx/dy by
        -- construction), so the straight carrier stands down entirely rather than adding to them.
        local walking = plan.legs ~= nil and #plan.legs <= cfg.legMax
        slot.climb:SetSmoothing(arcing and "NONE" or "OUT")
        slot.climb:SetDuration(walking and 0.001 or plan.seconds)
        slot.climb:SetOffset(walking and 0 or plan.dx, (walking or arcing) and 0 or -plan.dy)

        -- The streamline, leg by leg: each starts where the last one ended, because a finished
        -- Translation holds its displacement while the rest of order 1 runs -- the same
        -- persistence the kindle already leans on. Spare legs stand down at zero offset over a
        -- hair of time.
        local at = plan.delay
        for i, leg in ipairs(slot.legs) do
            local step = walking and plan.legs[i] or nil
            if step then
                leg:SetStartDelay(at)
                leg:SetDuration(step.seconds)
                leg:SetOffset(step.dx, -step.dy)    -- the plan is y-down, a Translation is y-up
                at = at + step.seconds
            else
                leg:SetStartDelay(0)
                leg:SetDuration(0.001)
                leg:SetOffset(0, 0)
            end
        end

        -- Up to the apex, then down past it to wherever `dy` says the life ends. Both idle at a
        -- zero offset over a hair of time when nothing arcs -- the flock's own way of standing an
        -- animation down without removing it, rather than a zero duration.
        slot.arcUp:SetStartDelay(plan.delay)
        slot.arcUp:SetDuration(arcing and plan.arcSeconds or 0.001)
        slot.arcUp:SetOffset(0, arcing and plan.arcApex or 0)
        slot.arcDown:SetStartDelay(plan.delay + (arcing and plan.arcSeconds or 0))
        slot.arcDown:SetDuration(arcing and (plan.seconds - plan.arcSeconds) or 0.001)
        slot.arcDown:SetOffset(0, arcing and -(plan.arcApex + plan.dy) or 0)

        -- FORCE-4: the core burns down from the host's own heat to nothing over the life's first
        -- stretch, leaving the tint behind. Set explicitly before every Play -- the group's
        -- SetToFinalAlpha lands it at 0, and the next life needs it hot again.
        local heat = self.core or 0
        slot.core:SetAlpha(0)
        slot.cool:SetStartDelay(plan.delay)
        slot.cool:SetDuration(plan.coolSeconds)
        slot.cool:SetFromAlpha(heat)
        slot.cool:SetToAlpha(0)

        -- The death occupies the last stretch of the life, so it can never overlap the kindle: the
        -- shortest life leaves secondsMin * (1 - fadeOutFrac) of held peak between them.
        local dying = plan.seconds * cfg.fadeOutFrac
        slot.die:SetStartDelay(plan.delay + plan.seconds - dying)
        slot.die:SetDuration(dying)
        slot.die:SetFromAlpha(plan.peakAlpha)
        slot.die:SetToAlpha(0)
        -- FORCE-11: where this life will end, recorded now rather than watched for. Tier-A
        -- trajectories are decided entirely at spawn, which is what makes spawn-on-death free.
        slot.endX, slot.endY = Ember.EndPoint(plan)

        slot.life:Play()
        return plan
    end

    -- Paint a slot in a tint and remember it: a dying spark's pop is raised in its parent's colour,
    -- and the parent is long past caring by then.
    local function tint(slot, r, g, b)
        slot.r, slot.g, slot.b = r, g, b
        slot.tex:SetVertexColor(r, g, b)
    end

    -- ── The public four ─────────────────────────────────────────────────────────────────────

    -- Stop every life and rest dark. The generation bump strands anything already
    -- finished-and-rerolling mid-frame; Stop fires no OnFinished, so the loop simply ends. The
    -- burst pool is discarded whole rather than drained slot by slot: stopped burst embers never
    -- release, and a fresh pool on the next flourish is cheaper than the bookkeeping.
    self.retire = function()
        self.gen = self.gen + 1
        self.burstPool = nil
        -- pairs, not ipairs: ambience slots are array-keyed but burst slots are "burst<i>"-keyed
        -- (their own key space), and a retire must stop BOTH registers.
        for _, slot in pairs(self.slots) do
            slot.life:Stop()
            slot.wander:Stop()      -- the sway loops forever by design; only a retire ends it
            slot.burstIndex = nil
            slot.pop = nil
            slot.holder:SetAlpha(0)
        end
        -- Stop returns both wind layers to still air -- so a retired hearth is not merely dark but
        -- motionless, whatever it was doing mid-gust.
        for _, layer in ipairs(self.wind or {}) do layer.group:Stop() end
    end

    -- Light (or relight) the ambience register at a count, a tint and a species.
    --
    -- It RETIRES first, always. Every caller of the old bar-local pair did (a dress, a slider, a
    -- bisect level), and folding the retire in is what makes a double light impossible: two
    -- lightings without one would leave the first generation's slots looping under the second's.
    -- A count below the last one leaves the spare slots exactly as retire left them: stopped and
    -- dark. `wind` and `core` are per-lighting properties of the WHOLE hearth rather than of a
    -- species, which is why they arrive here and not in Roll's tokens.
    self.light = function(o)
        o = type(o) == "table" and o or {}
        self.retire()
        self.r = isNum(o.r) and o.r or 1
        self.g = isNum(o.g) and o.g or 1
        self.b = isNum(o.b) and o.b or 1
        self.core = isNum(o.core) and o.core or 0
        self.windScale = isNum(o.wind) and o.wind or 0
        self.species = type(o.species) == "table" and o.species or nil

        local count = isNum(o.count) and math.floor(o.count) or Ember.TOKENS.count
        if count < 0 then count = 0 end

        -- A relight always follows a retire, so the layers are stopped -- the guard is for the day
        -- that stops being true, since Play mid-swing would jerk the lot.
        for _, layer in ipairs(acquireWind()) do
            if not layer.group:IsPlaying() then playGust(layer) end
        end

        for i = 1, count do
            local slot = acquireEmber(i)
            tint(slot, self.r, self.g, self.b)
            playEmber(slot)
        end
        return count
    end

    -- Add ambience slots WITHOUT disturbing the ones already burning -- the stress path. A relight
    -- at every rung reads as the hearth blinking, and it is also the worse measurement: a relit
    -- pool spends the next delayMax seconds staggering back in rather than burning, so the sample
    -- lands on a hearth that is half dark. Growth has neither problem.
    self.grow = function(from, to)
        if not (isNum(from) and isNum(to)) then return 0 end
        for i = math.floor(from) + 1, math.floor(to) do
            local slot = acquireEmber(i)
            tint(slot, self.r, self.g, self.b)
            playEmber(slot)
        end
        return to
    end

    -- One flourish: n one-life embers through the pool, in the given tint, on the given species.
    -- Quietly stops at the pool's edge -- a missing ember is invisible -- and a life that could not
    -- roll (an unsized host) hands its slot back on the spot, or the pool would bleed dry one
    -- failed flourish at a time.
    -- `pop` (FORCE-11) is the species each of these leaves behind when it dies, or nil for the
    -- registers that should simply go out.
    burst = function(n, o)
        o = type(o) == "table" and o or {}
        if not isNum(n) or n < 1 then return end
        local species = type(o.species) == "table" and o.species or self.species
        local r = isNum(o.r) and o.r or self.r
        local g = isNum(o.g) and o.g or self.g
        local b = isNum(o.b) and o.b or self.b
        self.burstPool = self.burstPool or Ember.Pool(cfg.burstMax)

        for _ = 1, math.floor(n) do
            local i = self.burstPool.acquire()
            if not i then return end
            -- Pool slot i is texture slot "burst<i>", a fixed mapping for the session -- so the
            -- OnFinished closure built at acquire releases by a stored index, never a per-play
            -- closure. A string key on purpose: the ambience register owns the array part, and its
            -- size is the caller's call, so offset arithmetic would collide the moment a host
            -- burned more than the default.
            local slot = acquireEmber("burst" .. i)
            slot.burstIndex = i
            slot.pop = o.pop
            tint(slot, r, g, b)
            local plan = playEmber(slot, o.delayScale, species)
            if not plan then
                slot.burstIndex = nil
                slot.pop = nil
                self.burstPool.release(i)
                return
            end

            -- FORCE-12: the echo -- the same flight again, a breath later and half as bright,
            -- which is what a streak's tail is made of when there is no ribbon mesh to make one
            -- with. It replays the PARENT'S PLAN rather than rolling its own: two independent
            -- rolls would be two particles near each other, and the eye reads that as clutter, not
            -- as speed. Never popping (the parent already answers for that), and a dry pool simply
            -- skips it.
            local echo = species and species.echo
            if echo and self.burstPool then
                local j = self.burstPool.acquire()
                if j then
                    local ghost = acquireEmber("burst" .. j)
                    ghost.burstIndex = j
                    ghost.pop = nil
                    tint(ghost, r, g, b)
                    local copy = {}
                    for k, v in pairs(plan) do copy[k] = v end
                    copy.delay = plan.delay + echo.seconds
                    copy.peakAlpha = plan.peakAlpha * echo.alpha
                    if not playEmber(ghost, o.delayScale, species, copy) then
                        ghost.burstIndex = nil
                        self.burstPool.release(j)
                    end
                end
            end
        end
    end
    self.burst = burst

    -- What the hearth is carrying right now: slots built, and the animations the C engine is
    -- ticking for them. COUNTED rather than assumed -- the per-slot animation count is a property
    -- of how a slot was built, and it has changed four times in one week (FORCE-2, 4, 6, 8). A
    -- stress reading that quoted a remembered number would be measuring last Tuesday.
    self.census = function()
        local slots, perSlot = 0, 0
        for _, slot in pairs(self.slots) do
            slots = slots + 1
            if perSlot == 0 then
                -- ⚠️ `GetAnimations` returns them as a VARARG, and the first cut of this wrote
                -- `local ok, list = pcall(...)`, which keeps only the first return -- so every
                -- slot counted as exactly 2 animations and the column read 3200 where the truth
                -- was nearer 28,800. Collect the varargs into a table or do not collect them.
                local function count(group)
                    local ok, list = pcall(function() return { group:GetAnimations() } end)
                    return ok and #list or 0
                end
                perSlot = count(slot.life) + count(slot.wander)
            end
        end
        return slots, slots * perSlot, perSlot
    end

    return self
end

return Ember.Hearth       -- WoW discards a file's return value; Tests/ needs it
