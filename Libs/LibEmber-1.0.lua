-- LibEmber-1.0 — PURE: the particle brain.
--
-- One ember's whole life is planned here — birth spot, climb, drift, burn time — and handed to the
-- wiring as plain numbers; the wiring only aims one Texture and one AnimationGroup per plan and
-- lets the client animate. No emitter tick, no OnUpdate: a fixed pool of self-looping particles,
-- each re-rolling itself in OnFinished, is continuous ambience with zero per-frame Lua (every
-- consuming API field-proven on Classic Era 11509, first as Sigil's own SigilEmber.lua).
--
-- Randomness comes IN as a table of 0..1 rolls: deterministic under test, and tolerant PER FIELD —
-- a roll is noise by definition, any value in the band as right as any other, so a missing or
-- corrupt roll becomes the mid roll and an out-of-range one clamps. The domain still gates hard:
-- garbage width/height is "no ember", never NaN.
--
-- LIBRARY DISCIPLINE: this file references nothing but its own LibStub-registered table — no
-- consumer's globals, no addon-specific naming. Any addon may embed a copy in its own Libs/ folder
-- and list it in its own .toc; LibStub dedups so only the highest-minor copy loaded in a given
-- session ever runs (see README.md).
--
-- Usage: lua Tests/ember_test.lua   (run from the project root)

local MAJOR, MINOR = "LibEmber-1.0", 1
local Ember = LibStub:NewLibrary(MAJOR, MINOR)
if not Ember then return end   -- a newer copy of the core is already loaded; stand down

-- Every number the wiring reads, never inline there (tokens-not-literals). Fractions read against
-- the UNIT — the bar's height — so an ember stays ember-sized at any resolution or UI scale.
Ember.TOKENS = {
    count = 12,          -- live embers in the always-on loop; taste caps this long before the engine
    spawnMin = 0.03,     -- the horizontal spawn band, fractions of the width
    spawnMax = 0.97,
    -- FORCE-1: the band is not an even carpet. It divides into SEATS -- hot spots in the coals --
    -- and an ember piles toward the middle of whichever seat it rolls, so the fire reads as a few
    -- loose knots with gaps between them rather than a uniform sprinkle. Optional: a species
    -- without it spawns evenly, which is what a whisker of band round an orb wants.
    -- ⚠️ Seats rather than ONE bell across the whole band on purpose: this rail is 21:1 and
    -- Blizzard's action bar draws over its middle, so a single centred bell would pile most of
    -- the fire where nothing can be seen. `seats = 1` is that single bell, if a species wants it.
    spawnCluster = {
        seats = 5,       -- knots along the band; ODD keeps one centred on it (and the mid roll)
        spread = 1,      -- how much of its seat a knot fills; 0 pins embers to the seat's centre
    },
    originLine = 0.66,   -- where an ember is born, fraction of unit height from the top. The flock's
                         -- MEASURED perchLine (row-luminance scan, 2026-08-05): embers rise off the
                         -- wood, not off some eyeballed line.
    riseMin = 0.4,       -- how far it climbs before it dies, in units
    riseMax = 1.1,
    driftAmp = 0.15,     -- sideways drift over the whole life, units each way -- where the ember
                         -- ENDS UP, one straight line. The sway it takes to get there is `wander`.
    -- FORCE-2: the wander channel. A rising ember on a straight line reads as a soap bubble, so it
    -- also swings side to side on the way up -- its own amplitude and period, rolled per life, and
    -- the two compose in C (the wiring rides the sway on the ember's texture while its holder
    -- frame carries the climb: the flock's bob-over-glide exactly, one register down).
    -- Optional, like `spawnCluster`: a species without it climbs straight.
    wander = {
        ampMin = 0.03,     -- peak-to-peak sway, fractions of unit -- small against the climb, or
        ampMax = 0.10,     -- the ember reads as a pendulum rather than as something rising
        secondsMin = 1.2,  -- one full out-and-back; several to a life, and no two embers share a
        secondsMax = 2.8,  -- period, so the pool can never fall into step
    },
    -- FORCE-3: the wind. Not a per-ember band at all -- ONE gust moves every ember together, and
    -- that coherence is what says these flecks share air instead of each carrying its own weather.
    -- Two layers, deliberately with period bands that cannot even overlap: a brisk gust rides a
    -- slow swell, each re-rolled at the end of its own cycle, so the beat between them never
    -- repeats. Amplitudes are units (bar heights), scaled by the SKIN's own `ember.wind` -- a
    -- Mage's drift is not a Hunter's breeze, and a skin that says nothing stays calm.
    wind = {
        layers = {
            { ampMin = 0.02, ampMax = 0.08, secondsMin = 2.4, secondsMax = 3.8 },   -- the gust
            { ampMin = 0.05, ampMax = 0.16, secondsMin = 6.5, secondsMax = 9.5 },   -- the swell
        },
        lift = 0.3,      -- the vertical share of a gust: wind blows along the rail, and only
                         -- leans on the climb rather than driving it
    },
    secondsMin = 2.5,    -- one life, wall-clock
    secondsMax = 6,
    -- FORCE-4: how much of a life is spent COOLING. A real ember is white-hot at birth and settles
    -- to its own colour on the way up; a fleck that holds one colour for its whole life reads as a
    -- firefly rather than as fire. The wiring stacks a white core over the tinted glow and fades
    -- the core out over this share of the life -- so the colour the ember cools TO is the skin's,
    -- which is the class hook. Pro rata with the life on purpose: a half-second heal spark must
    -- not spend two seconds cooling.
    coolFrac = 0.45,
    -- FORCE-8: the turbulence the ambience rises through. A curl field is divergence-free by
    -- construction, so embers never pile up or vacuum out; `steps` legs are walked through it at
    -- spawn and then corrected to land exactly where the plan already said. Optional, and the
    -- burst species deliberately go without: a thrown spark is ballistic, not buoyant.
    turbulence = {
        strength = 0.55,   -- how far the field pushes over a whole life, in units
        steps = 5,         -- waypoints; each is a course change, and 5 across a life is ~1/s
        scale = 0.75,      -- the field's own size in domain fractions -- smaller is choppier air
    },
    delayMax = 4,        -- spawn stagger; each re-roll gets a fresh delay, so the pool never
                         -- breathes in unison and the loop stays desynchronised forever
    sizeMin = 0.05,      -- quad size, fraction of unit
    sizeMax = 0.11,
    alphaMin = 0.35,     -- the peak the fade-in reaches; rest state is 0 — ADD-blended and
    alphaMax = 0.8,      -- invisible, the painting untouched when nothing burns
    -- The atlas (plan §5): a 4x4 grid of 64px cells in one 256x256 white-on-transparency TGA,
    -- tinted at spawn. `mix` is which cells embers roll from, WEIGHTED — cell 1 soft mote,
    -- 2 hard spark, 3 cross flare, 4 irregular fleck; ambience is mostly motes and flecks,
    -- the flare a rare glint. Cells number row-major from the top-left; twelve stay reserved.
    cells = {
        rows = 4,
        columns = 4,
        mix = {
            { cell = 1, weight = 4 },
            { cell = 4, weight = 3 },
            { cell = 2, weight = 2 },
            { cell = 3, weight = 1 },
        },
    },
}

-- A roll is noise: missing or corrupt becomes the mid roll, out-of-range clamps. Tolerance is per
-- field on purpose — one bad roll must not cost the plan (unlike an authored seat, where a wrong
-- number means a wrong painting and silence would hide it).
-- Authored data (a token band, a species' field) is real or it is absent -- never coerced. NaN
-- counts as absent: it compares false to everything, so it would poison a band silently.
local function isNum(v)
    return type(v) == "number" and v == v
end

local function clean(v)
    if type(v) ~= "number" or v ~= v then return 0.5 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- FORCE-1: where along the spawn band an ember is born, as a 0..1 fraction of the band.
-- `x` picks which hot seat; x2/x3/x4 are a sum-of-three approximation of a normal (the Bates
-- trick -- three uniform rolls averaged already read as a bell) that piles the ember toward that
-- seat's middle. The bell is scaled to the seat, so it can never spill into the next one: the
-- gaps between knots are the whole effect. No clamp is needed and none is done -- seat/n and
-- (seat+1)/n bracket the result by construction.
-- Malformed cluster data is NO clustering rather than an error: an unseatable band is still a
-- band, and a species arrives from a consumer (the library half), not from an author here.
local function spawnFraction(T, roll)
    local sc = T.spawnCluster
    local n = type(sc) == "table" and sc.seats or nil
    if type(n) ~= "number" or n ~= n or n < 1 or n ~= math.floor(n) then return roll("x") end

    -- The knot's WIDTH is taste, not structure, so it degrades like a roll: absent fills the
    -- seat, out of range clamps.
    local spread = sc.spread
    if type(spread) ~= "number" or spread ~= spread then spread = 1
    elseif spread < 0 then spread = 0
    elseif spread > 1 then spread = 1 end

    local seat = math.floor(roll("x") * n)
    if seat > n - 1 then seat = n - 1 end        -- a roll of exactly 1 belongs to the last seat
    local bell = (roll("x2") + roll("x3") + roll("x4")) / 3 - 0.5
    return (seat + 0.5 + spread * bell) / n
end

-- FORCE-2: the sway an ember rides while it climbs -> amplitude (SIGNED: which way it leans off
-- first, so the pool never sways in unison) and the seconds one out-and-back takes. Optional
-- exactly like the seats -- no `wander` band is a species that climbs straight, which is what a
-- heal fountain's half-second life wants. Zeros say "no sway" and the wiring reads them as that.
-- Malformed is no sway rather than an error, for the same reason the seats gate that way.
local function wanderPlan(T, roll, height)
    local w = T.wander
    if type(w) ~= "table" then return 0, 0 end
    local a0, a1, s0, s1 = w.ampMin, w.ampMax, w.secondsMin, w.secondsMax
    if not (isNum(a0) and isNum(a1) and isNum(s0) and isNum(s1)) then return 0, 0 end
    if a0 < 0 or a1 < a0 or s0 <= 0 or s1 < s0 then return 0, 0 end

    local amp = (a0 + (a1 - a0) * roll("wanderAmp")) * height
    -- A mid roll is a real direction, not a standstill: an ember that sways nowhere is the tell
    -- this whole channel exists to kill.
    if roll("wanderSide") < 0.5 then amp = -amp end
    return amp, s0 + (s1 - s0) * roll("wanderPace")
end

-- FORCE-6: the ballistic arc -> how high above its birth point a spark peaks, and how long it
-- takes to get there. Absent, an ember rises in a straight line for its whole life, which is what
-- smoke does; present, the wiring chains an eased climb into an eased fall under a linear drift
-- and it reads as a spark thrown off the wood and falling back to it.
--
-- The apex is a HEIGHT, not a velocity, on purpose: the plan is a shape the C engine interpolates,
-- and every other field here is already a displacement. `upFrac` must land strictly inside the
-- life -- a spark still climbing when it dies never falls, which is the bug this gates against.
local function arcPlan(T, roll, height, seconds)
    local a = T.arc
    if type(a) ~= "table" then return 0, 0 end
    local lo, hi, up = a.apexMin, a.apexMax, a.upFrac
    if not (isNum(lo) and isNum(hi) and isNum(up)) then return 0, 0 end
    if lo <= 0 or hi < lo or up <= 0 or up >= 1 then return 0, 0 end
    return (lo + (hi - lo) * roll("arc")) * height, seconds * up
end

-- FORCE-9: the emitter SHAPE, as species data rather than as code. Unity's Shape module is the
-- vocabulary and its rule is the one that matters -- a shape decides the spawn REGION *and* the
-- initial DIRECTION -- so this answers both at once, in domain coordinates, y DOWN:
--
--   nil / anything malformed -> the LINE along the rail every ember has always been born on
--   box   { height }               -> the line gains a vertical extent; direction unchanged
--   ring  { radius, filled }       -> a rim (or a filled disc), travelling OUTWARD: a halo
--   cone  { direction, spread }    -> a point, throwing over a spread of directions
--
-- ⚠️ THE SQRT IN THE DISC IS NOT DECORATION. `r = R * sqrt(roll)` is what spreads spawns evenly
-- over the area; `r = R * roll` piles them at the centre, because a ring of radius r has
-- circumference proportional to r and so deserves proportionally more of the roll.
--
-- Returns x0, y0, and optionally dx, dy -- nil travel means "the shape has no opinion", and the
-- caller's own rise-and-drift stands. Every angle is degrees, 0 east, -90 UP (y down).
-- (`width` is read only by the mask, whose cells are a grid over the WHOLE painting; every other
-- shape measures in units of height, so an ember stays ember-shaped at any aspect.)
local function shapePlan(T, roll, width, height, cx, cy, dist)
    local s = T.shape
    if type(s) ~= "table" then return cx, cy end

    if s.kind == "box" then
        if not isNum(s.height) or s.height <= 0 then return cx, cy end
        return cx, cy + (roll("y") - 0.5) * s.height * height
    end

    if s.kind == "ring" then
        if not isNum(s.radius) or s.radius <= 0 then return cx, cy end
        local r = s.radius * height
        if s.filled then r = r * math.sqrt(roll("radial")) end
        local a = roll("theta") * 2 * math.pi
        local ux, uy = math.cos(a), math.sin(a)
        -- Outward: the spawn offset and the travel share one unit vector, which is the whole
        -- difference between a halo and a ring of embers all drifting the same way.
        return cx + ux * r, cy + uy * r, ux * dist, uy * dist
    end

    -- FORCE-10: the painting decides. A weighted grid of cells derived offline from the rail art,
    -- so each class's fire rises off its own embers-in-the-art rather than off a flat band. The
    -- pick is the cumulative-weight walk the cell mix and FlightPath's perches already use -- one
    -- idiom for every weighted choice here -- and the ember is born ANYWHERE inside the cell it
    -- picked, or a mask of 71 cells would read as 71 jets.
    if s.kind == "mask" then
        local cells = s.cells
        if type(cells) ~= "table" or #cells == 0 then return cx, cy end
        if not (isNum(s.columns) and isNum(s.rows)) or s.columns < 1 or s.rows < 1 then
            return cx, cy
        end
        local total = 0
        for _, c in ipairs(cells) do total = total + (c.weight or 0) end
        if total <= 0 then return cx, cy end
        local target, cum = roll("mask") * total, 0
        local pick = cells[#cells]
        for _, c in ipairs(cells) do
            cum = cum + (c.weight or 0)
            if target < cum then
                pick = c
                break
            end
        end
        return (pick.cx + roll("maskX")) / s.columns * width,
            (pick.cy + roll("maskY")) / s.rows * height
    end

    if s.kind == "cone" then
        if not (isNum(s.direction) and isNum(s.spread)) then return cx, cy end
        local a = math.rad(s.direction + (roll("cone") - 0.5) * s.spread)
        return cx, cy, math.cos(a) * dist, math.sin(a) * dist
    end

    return cx, cy
end

-- FORCE-7: orbit and vortex. The research reached for `Rotation:SetOrigin` -- circular motion
-- computed in C for free -- but that primitive has no field exercise on this Era install and is
-- still sitting on FORCE-5's probe list. A circle is also a polygon with enough sides, and chained
-- legs are already proven and already wired (FORCE-8 built them), so this ships on the machinery
-- that exists. At ember scale eight sides read as a circle; if the probe lands, the same plan
-- becomes one Rotation and the legs come back for something else.
--
-- ⚠️ A swirl DEFINES the flight rather than decorating one: it returns the displacement as well
-- as the legs, and Roll takes both. The alternative -- bending legs to reach an endpoint chosen
-- independently -- cannot be done exactly, since a half turn about a centre lands diametrically
-- opposite wherever a straight rise would have gone. Owning the endpoint keeps the legs exact by
-- construction, and keeps EndPoint (FORCE-11) telling the truth about where sparks should pop.
-- The radius grows by the rise band, so a ring that travels outward SPIRALS rather than turning.
local function swirlLegs(T, roll, cx, cy, x0, y0, dist, seconds)
    local s = T.swirl
    if type(s) ~= "table" then return nil end
    local revs, steps = s.revolutions, s.steps
    if not (isNum(revs) and isNum(steps)) then return nil end
    if revs <= 0 or steps < 2 or steps ~= math.floor(steps) then return nil end

    local r0 = math.sqrt((x0 - cx) ^ 2 + (y0 - cy) ^ 2)
    if r0 <= 0 then return nil end          -- a mote born ON the pivot has no orbit to walk
    local a0 = math.atan2(y0 - cy, x0 - cx)
    local r1 = r0 + dist
    -- Which way it spins is rolled per particle, so a vortex SHEARS rather than turning as one
    -- piece -- the research's point about inner and outer orbits at different speeds.
    local sweep = revs * 2 * math.pi
    if roll("swirlSide") < 0.5 then sweep = -sweep end

    local legs, px, py = {}, x0, y0
    for i = 1, steps do
        local t = i / steps
        local r = r0 + (r1 - r0) * t
        local a = a0 + sweep * t
        local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
        legs[i] = { dx = nx - px, dy = ny - py, seconds = seconds / steps }
        px, py = nx, ny
    end
    return legs, px - x0, py - y0
end

-- The streamline an ember walks: `steps` legs through the frozen field from where it was born,
-- then corrected so the legs sum EXACTLY to the flight the plan already promised. Without that
-- correction a turbulent ember would land somewhere its own EndPoint does not know about -- and
-- FORCE-11 pops sparks at that point, so the two would disagree in a way nothing would report.
local function streamline(T, width, height, x0, y0, dx, dy, seconds)
    local t = T.turbulence
    if type(t) ~= "table" then return nil end
    local strength, steps, scale = t.strength, t.steps, t.scale
    if not (isNum(strength) and isNum(steps) and isNum(scale)) then return nil end
    if strength <= 0 or scale <= 0 or steps < 2 or steps ~= math.floor(steps) then return nil end

    -- Walk in DOMAIN fractions so the field's shape is the bar's, not the pixel grid's.
    local px, py = x0 / width, y0 / height
    local step = strength / steps
    local legs, sx, sy = {}, 0, 0
    for i = 1, steps do
        local u, v = Ember.Curl(px, py, scale)
        if not u then return nil end
        local lx, ly = u * step * height, v * step * height
        legs[i] = { dx = lx, dy = ly }
        sx, sy = sx + lx, sy + ly
        -- Advance through the field by the leg just taken, plus this leg's share of the base
        -- flight -- so a rising ember samples the air it is actually rising through.
        px = px + (lx + dx / steps) / width
        py = py + (ly + dy / steps) / height
    end

    -- Share the correction equally, which keeps every leg's wander and moves only the sum.
    local cx, cy = (dx - sx) / steps, (dy - sy) / steps
    for i = 1, steps do
        legs[i].dx = legs[i].dx + cx
        legs[i].dy = legs[i].dy + cy
        legs[i].seconds = seconds / steps
    end
    return legs
end

---
-- One ember's whole life from unit rolls -> a plan, in domain coordinates, y DOWN:
--   { cell, x0, y0, dx, dy, seconds, delay, size, peakAlpha }
-- x0/y0 the birth point, dx/dy the whole displacement of the life (dy negative: an ember rises),
-- everything the wiring needs to aim one texture and one animation group, nothing it doesn't.
-- The domain gates like OrbLayout/FlightPath: garbage is nil, never NaN out.
--
-- `tokens` (optional) is a SPECIES: a table shaped like TOKENS whose bands rule this one roll --
-- how a consumer plans a different kind of particle (a heal flourish's short fast life off an
-- orb's seat) through the same tested path. Absent, TOKENS stands; anything else non-table is a
-- caller error and gates like the rest of the domain. The table's fields are the caller's to get
-- right -- a species is authored data, the seat's rule, not a roll's.
function Ember.Roll(width, height, rolls, tokens)
    if type(width) ~= "number" or width ~= width or width <= 0 then return nil end
    if type(height) ~= "number" or height ~= height or height <= 0 then return nil end
    if type(rolls) ~= "table" then return nil end
    if tokens ~= nil and type(tokens) ~= "table" then return nil end

    local T = tokens or Ember.TOKENS
    local function roll(name) return clean(rolls[name]) end

    -- The weighted species pick: the cell roll walks the cumulative weights, so a weight-4 mote
    -- claims four times the flare's share of the roll's 0..1 (FlightPath's perch pick exactly).
    local mix = T.cells.mix
    local total = 0
    for _, m in ipairs(mix) do total = total + m.weight end
    local target = roll("cell") * total
    local cell, cum = mix[#mix].cell, 0
    for _, m in ipairs(mix) do
        cum = cum + m.weight
        if target < cum then
            cell = m.cell
            break
        end
    end

    local wanderAmp, wanderSeconds = wanderPlan(T, roll, height)
    local seconds = T.secondsMin + (T.secondsMax - T.secondsMin) * roll("pace")

    -- FORCE-4: a malformed coolFrac cools over the WHOLE life rather than none of it. A core that
    -- never quite fades is merely wrong; a core that vanishes at birth is invisible, and a silent
    -- nothing is the harder failure to notice -- the same argument the tint's fallbacks make.
    local coolFrac = T.coolFrac
    if not isNum(coolFrac) or coolFrac <= 0 or coolFrac > 1 then coolFrac = 1 end

    local arcApex, arcSeconds = arcPlan(T, roll, height, seconds)

    -- How far this ember travels, which the LINE emitter spends going up and the shapes spend
    -- going wherever their geometry points.
    local dist = (T.riseMin + (T.riseMax - T.riseMin) * roll("rise")) * height
    -- FORCE-9: the shape answers where it is born and, for ring and cone, which way it goes. A
    -- shape with no opinion on travel leaves the line emitter's own rise and drift standing.
    local x0, y0, sdx, sdy = shapePlan(T, roll, width, height,
        (T.spawnMin + (T.spawnMax - T.spawnMin) * spawnFraction(T, roll)) * width,
        T.originLine * height, dist)

    local dx = sdx or (roll("drift") * 2 - 1) * T.driftAmp * height
    local dy = sdy or -dist

    -- FORCE-7: a swirl owns the flight, so it is asked before the streamline and outranks it --
    -- a mote cannot walk two paths, and the legs are one channel.
    local cx0 = (T.spawnMin + (T.spawnMax - T.spawnMin) * 0.5) * width
    local legs, swx, swy = swirlLegs(T, roll, cx0, T.originLine * height, x0, y0, dist, seconds)
    if legs then
        dx, dy = swx, swy
    else
        legs = streamline(T, width, height, x0, y0, dx, dy, seconds)
    end

    return {
        arcApex = arcApex,
        arcSeconds = arcSeconds,
        -- FORCE-12: which way this ember flies, for a species that wears a streak. In SCREEN
        -- space -- y UP, where SetRotation lives -- not in the plan's own y-down domain, hence
        -- the negated dy: get that backwards and every trail points the wrong way. The atlas's
        -- streak cells are drawn along +X so that 0 radians IS the direction of travel and the
        -- wiring has nothing left to correct. An ember going nowhere reports 0, not a NaN.
        angle = (dx == 0 and dy == 0) and 0 or math.atan2(-dy, dx),
        -- FORCE-7/8: the path, when the species asks for one -- nil is a straight flight.
        legs = legs,
        cell = cell,
        wanderAmp = wanderAmp,
        wanderSeconds = wanderSeconds,
        x0 = x0,
        y0 = y0,
        dx = dx,
        dy = dy,
        seconds = seconds,
        coolSeconds = seconds * coolFrac,
        delay = T.delayMax * roll("delay"),
        size = (T.sizeMin + (T.sizeMax - T.sizeMin) * roll("size")) * height,
        peakAlpha = T.alphaMin + (T.alphaMax - T.alphaMin) * roll("alpha"),
    }
end

---
-- FORCE-8: the turbulence field -- a flow velocity at a point, in fractions of the domain.
--
-- ⚠️ IT IS A CURL, AND THAT IS THE POINT. The field is the curl of a scalar potential psi, so it
-- is **divergence-free by construction** (Bridson): no point can be a source or a sink, and
-- embers therefore never pile up in some places and vacuum out of others. Two independent noise
-- functions would be the obvious build and would do exactly that -- the test measures the
-- divergence rather than trusting the comment.
--
--   psi = sin(x/L)cos(y/L) + 0.5 sin(2x/L + 1.7)cos(2y/L + 0.4)
--   (u, v) = (dpsi/dy, -dpsi/dx)
--
-- Computed rather than looked up: the research called for a grid baked offline by a Tools/
-- script, but an ANALYTIC curl is divergence-free exactly rather than to grid precision, needs
-- no generated file and no second load-order dependency in the library half, and the cost
-- argument does not hold -- a dozen trig calls at spawn, and a hearth spawns a handful a second.
-- FROZEN: no time term, so the field an ember flies through is the field it was born in.
function Ember.Curl(x, y, scale)
    if not (isNum(x) and isNum(y) and isNum(scale)) or scale <= 0 then return nil end
    local a, b = x / scale, y / scale
    -- u = dpsi/dy, v = -dpsi/dx, differentiated by hand so the identity is exact.
    local u = (-math.sin(a) * math.sin(b) - math.sin(2 * a + 1.7) * math.sin(2 * b + 0.4)) / scale
    local v = (-math.cos(a) * math.cos(b) - math.cos(2 * a + 1.7) * math.cos(2 * b + 0.4)) / scale
    return u, v
end

---
-- FORCE-11: where a plan FINISHES, in the same domain coordinates it was rolled in.
--
-- The point of this being answerable at all: every Tier-A trajectory is deterministic, decided
-- entirely at spawn, so an ember that wants to pop into sparks when it dies never has to be
-- WATCHED -- its death place is known the moment it is born, and the whole feature costs a dozen
-- Lua ops at the one moment it fires. `dx`/`dy` are the whole displacement of the life, so a
-- ballistic plan reports the ground it lands on rather than the apex it passed through.
function Ember.EndPoint(plan)
    if type(plan) ~= "table" then return nil end
    local x0, y0, dx, dy = plan.x0, plan.y0, plan.dx, plan.dy
    if not (isNum(x0) and isNum(y0) and isNum(dx) and isNum(dy)) then return nil end
    return x0 + dx, y0 + dy
end

---
-- FORCE-3: one gust of wind -> { dx, dy, seconds }, in domain coordinates, y DOWN like every plan
-- here. ONE of these moves the whole hearth, however many embers burn in it, so this is the
-- cheapest motion in the system by a wide margin -- the wiring rides it on frames above the
-- holders and the C engine carries every ember along for nothing.
--
-- `layer` is one entry of TOKENS.wind.layers (or a consumer's own): a species for weather. It
-- gates HARD rather than degrading, unlike a roll -- a layer is authored, and a wind with no
-- period would be a frame animation of duration zero looping forever.
function Ember.Gust(height, rolls, layer)
    if type(height) ~= "number" or height ~= height or height <= 0 then return nil end
    if type(rolls) ~= "table" then return nil end
    if type(layer) ~= "table" then return nil end

    local a0, a1, s0, s1 = layer.ampMin, layer.ampMax, layer.secondsMin, layer.secondsMax
    if not (isNum(a0) and isNum(a1) and isNum(s0) and isNum(s1)) then return nil end
    if a0 < 0 or a1 < a0 or s0 <= 0 or s1 < s0 then return nil end

    local lift = Ember.TOKENS.wind.lift
    if not isNum(lift) then lift = 0 end

    local function roll(name) return clean(rolls[name]) end
    local amp = (a0 + (a1 - a0) * roll("amp")) * height
    if roll("side") < 0.5 then amp = -amp end

    return {
        dx = amp,
        -- Signed on its own roll: air presses down as readily as it lifts, and the share is of
        -- the gust's own strength, so a hard gust leans harder. Negative is UP (y down).
        dy = -(roll("lift") * 2 - 1) * math.abs(amp) * lift,
        seconds = s0 + (s1 - s0) * roll("pace"),
    }
end

---
-- A cell number -> the atlas quarter SetTexCoord addresses: { left, right, top, bottom }, each
-- 0..1 of the atlas. Cells number row-major from the top-left, 1-based, exactly as TOKENS.cells
-- and the atlas tool count them. Gates like everything here: a cell off the grid is nil, and the
-- wiring skips the plan rather than drawing the whole atlas on one quad.
function Ember.CellCoords(cell)
    local c = Ember.TOKENS.cells
    if type(cell) ~= "number" or cell ~= cell
        or cell < 1 or cell > c.rows * c.columns or cell ~= math.floor(cell) then
        return nil
    end
    local col = (cell - 1) % c.columns
    local row = math.floor((cell - 1) / c.columns)
    return {
        left = col / c.columns,
        right = (col + 1) / c.columns,
        top = row / c.rows,
        bottom = (row + 1) / c.rows,
    }
end

---
-- Pure slot policy over n slots: acquire()/release(i) on a free-list stack (pop and push are
-- swap-remove's degenerate case — no hole can exist), active() the held count. The always-on loop
-- doesn't strictly need it (a fixed set of self-looping particles never releases), but bursts
-- (EMBER-4) and the library's attach API both do, and it is fifteen testable lines.
-- No widgets in sight: slots are indices; what a slot indexes is the wiring's business.
function Ember.Pool(n)
    if type(n) ~= "number" or n ~= n or n < 0 then return nil end
    n = math.floor(n)

    local free, held = {}, {}
    for i = 1, n do free[i] = i end

    local pool = {}

    function pool.acquire()
        local top = #free
        if top == 0 then return nil end
        local slot = free[top]
        free[top] = nil
        held[slot] = true
        return slot
    end

    -- Only a slot this pool handed out and still holds may come back: a double release would put
    -- one slot on the free list twice and hand it to two owners.
    function pool.release(slot)
        if not held[slot] then return false end
        held[slot] = nil
        free[#free + 1] = slot
        return true
    end

    function pool.active()
        return n - #free
    end

    return pool
end

return Ember                        -- WoW discards a file's return value; Tests/ needs it
