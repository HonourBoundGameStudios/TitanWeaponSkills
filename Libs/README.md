# Embedded libraries

Vendored unmodified (WJ-4), copied from the sibling Gear Journey addon. Load order matters: LibStub → CallbackHandler → the rest.

| Library | Source | License note |
|---|---|---|
| `LibStub.lua` | https://www.wowace.com/projects/libstub | Public Domain |
| `CallbackHandler-1.0.lua` | https://www.wowace.com/projects/callbackhandler | BSD-style (Ace community) |
| `LibDataBroker-1.1.lua` | https://github.com/tekkub/libdatabroker-1-1 | No license text shipped upstream; universally embedded by the addon ecosystem (incl. Titan Panel). Fallback position: the ~90-line interface is reimplementable — see Gear Journey's `Research/titan-independence-research.md` §5. |
| `LibDBIcon-1.0.lua` | https://www.curseforge.com/wow/addons/libdbicon-1-0 | GPLv2+ — embed **unmodified only**; never fold its code into our sources. |
| `LibEmber-1.0.lua` / `LibEmber-1.0-Hearth.lua` | https://github.com/rlalance/LibEmber | MIT — a Honour Bound library, extracted out of Sigil (EMBER-L). Update by re-copying from that repo, not by hand-editing here. |
