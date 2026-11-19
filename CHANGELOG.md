# 0.4.21

- **HORDE / ALLIANCE buttons fixed:** on a Horde character you could not turn a faction off. Each button now turns on and off as expected.
- **Clearer buttons:** flat style with the faction logo, colored when on, grey when off.
- **All recorded deaths are shown:** the blue dots stopped at 2,500 per continent, so whole areas looked empty. All 8,721 now show.
- **Blue dots follow the view:** they show the deaths of the factions you picked with HORDE / ALLIANCE, not only your character's.
- The faction choice now lives only in the map menu (removed from the options page to avoid two places for one setting).

# 0.4.20

- **Data update: 8,721 real deaths** (164 new since 0.4.19). 98.8% correct in cross-validation.
- **HORDE / ALLIANCE buttons** at the top of the map menu: your faction is on by default, turn the other one on to see both. The map shows which one you are looking at: **Deathskip view: Alliance**.
- **ON/OFF button** next to Deathskip in the map menu: hides all of Deathskip on the map in one click, your settings stay as they are.
- **Classic UnstuckSkips** has its own ON/OFF button, separate from Deathskip's.
- The green line no longer depends on the hover tooltip: each option now does only what it says.

# 0.4.19

- **Data update: 8,557 real deaths** (308 new since 0.4.18). 98.7% correct in cross-validation.
- **New map menu** in the game's own style: sections (Map, Graveyards, Mouse over the map, Other) and a short explanation when you hover each option.
- Clearer options: **Non impacted sub zones** (the dashed borders), one **Graveyards** option for the markers and their names, **Mouse to Graveyard Green Line**. Exact borders are always on now.
- The original Classic UnstuckSkips layers are set apart: **Old unstucks** (red) and the new **Old deathskips** (purple).
- The on-screen box shows where you are: **Current: Goldshire (Elwynn Forest)**, then your graveyard.
- For collectors: Deathskip Collector can now ask for deaths right after login.

# 0.4.18

- **Data update: 8,249 real deaths** (599 new since 0.4.17). 98.8% correct in cross-validation.
- New **Show on the map** switch, in the Deathskip menu on the world map and in the options: untick it to hide everything Deathskip draws on the map, tick it to bring it back.

# 0.4.17

- **Data update: 7,650 real deaths** (733 new since 0.4.16). 98.7% correct in cross-validation.

# 0.4.16

- **Data update: 6,917 real deaths** (351 new since 0.4.15). 98.8% correct in cross-validation.

# 0.4.15

- **Data update: 6,566 real deaths** (380 new since 0.4.14). 98.7% correct in cross-validation.

# 0.4.14

- **Data update: 6,186 real deaths** (383 new since 0.4.13). 98.6% correct in cross-validation.
- The on-screen **Deathskips** box now knows the places where the game puts you in another zone than the map shows: the Uldaman tunnels under Stonesplinter Valley (Badlands graveyard), Undercity, The Shaper's Terrace (The Great Lift), the Swamp of Sorrows edge of the Blasted Lands (Stonard) and a few more. Standing there, it shows the graveyard you really go to.

# 0.4.13

- **Data update: 5,803 real deaths**. 98.7% correct in cross-validation (98% before).
- Fixed Stonesplinter Valley (Loch Modan): it now sends you to Thelsamar. Deaths in the Uldaman back-entrance tunnels underneath (they count as Badlands) had been pulling it to the Badlands graveyard. Deaths taken in a cave or city under another zone no longer change the map of the surface.

# 0.4.12

- **Data update: 5,671 real deaths** (273 new since 0.4.10). 98% correct in cross-validation.
- The on-screen **Deathskips** box (the graveyard for where you stand) is back on screen by default, now with a close button. Closed it? The Deathskip menu on the world map or `/usf notifier` brings it back.

# 0.4.11

- The on-screen **Deathskips** box (the graveyard for where you stand) is back on screen by default, now with a close button. Closed it? The Deathskip menu on the world map or `/usf notifier` brings it back.
- Same data as 0.4.10 (5,398 real deaths, 98% correct in cross-validation).

# 0.4.10

- **Data update: 5,398 real deaths** (299 new since 0.4.9). 98% correct in cross-validation.

# 0.4.9

- For collectors: Deathskip now tells Deathskip Collector users when a newer Collector is available. Nothing changes for other players.
- Same data as 0.4.8 (5,099 real deaths, 98% correct in cross-validation).

# 0.4.8

- **Data update: 5,099 real deaths** (1,286 new since 0.4.7), including the first deaths collected on NA realms. 98% correct in cross-validation.
- The addon is now called **Deathskip** in game too: addon list, options, world map button and chat messages (the folder stays UnstuckSkipsForever, so your settings are kept).
- **Recorded deaths** (blue dots) now show the real deaths included with the addon, the same for everyone, instead of only the deaths your own game received.
- New default settings: the on-screen Deathskips box is now off (turn it on in the map menu or the options), and borders with no effect (dashed) are hidden.
- Everything else stays as before: subzone borders, exact borders, shared areas, small healer icons with names, hover tooltip and green line, your faction only.
- New addon icon: the Deathskip spirit healer (addon list and on-screen box).
- Shared deaths now carry the language of your game client, so collectors can see it (nothing changes for you).
- With SeargentFish's original UnstuckSkips installed too, the Deathskip map button moves to the left of its buttons instead of covering them.

# 0.4.7

- **Data update: 3,813 real deaths** (2,341 new since 0.4.5). New graveyards learned, including Whispering Forest (Tirisfal) and the Horde spots of Riverglades.
- New or corrected spots: Dustbelch Grotto (Badlands) sends Alliance to Kargath, Menethil Bay to Baradin Bay, The Shattered Strand (Azshara) to Legash Encampment, Eastern Strand (Hillsbrad, Horde) to Tarren Mill.
- 98% correct in cross-validation (78% for the plain Classic rule).
- The map hover tooltip scales with the map, so it stays readable without covering the small map.
- **Clearer map**: a subzone border is now drawn as a solid line only where it changes your graveyard. Borders that make no difference (same graveyard on both sides) are dashed, so the borders that matter stand out. Dashed borders can be hidden (option "Borders with no effect"). Shared areas (two graveyards, the nearer one) are now drawn in thicker red lines. Borders are now also drawn over the sea, where water belongs to a subzone (e.g. off The Merchant Coast).
- **Unstuck skips, next step**: when your character is moved while you're logged out (character unstuck service, logout skips), the addon now records where you logged out and where you logged back in, and shares it anonymously like deaths. This is how we'll map how unstuck works on Forever. `/usf unstucks` shows yours. Turn sharing off anytime with `/usf share`.
- **Exact borders** (on by default): subzone borders are drawn exactly as the game's 33-yard squares (like ClassicZoneMap). Red lines are now the exact straight line halfway between the two graveyards (the server measures the distance from your exact position). Turn them off in the map menu or the options for lighter smoothed lines. The hover tooltip and the on-screen box always use the exact squares.
- New defaults: graveyards shown with the spirit-healer icon, small, with their names on zone maps; the on-screen Deathskips box sits at the top right. Settings you already changed are kept.
- The map always shows your current character's faction by default. The faction setting is now "mine / the other / both", so it follows you when you switch between Alliance and Horde characters.

# 0.4.5

- **The map now shows subzones.** On Forever the graveyard depends on the subzone you die in (e.g. The Merchant Coast sends you to Ratchet, the rest of The Barrens to The Crossroads; Shadowglen to Aldrassil, the rest of Teldrassil to Dolanaar). The addon now draws the game's own subzone borders (read from the client's terrain files, 33-yard precision) instead of the big white lines, plus an X on each graveyard your faction can reach. Where a single area is served by two graveyards (you go to the nearer one), the split is drawn in orange, so no border is invisible. Starting-area graveyards now serve exactly their starting subzone (Coldridge Valley → Anvilmar, the rest of Dun Morogh → Kharanos).
- **Hover a subzone** to see its name and where you'd respawn if you died there, with a green line to that spirit healer. The tooltip scales with the map, so it stays readable on the small map without covering it.
- **Hand-built, the same for everyone.** Everything comes from the data shipped with the addon; nothing is recomputed on your PC. We build it from the deaths players share (resurrections by another player are thrown out): 1,472 real deaths for this version, 96% correct in cross-validation.
- **Your faction only.** A Horde character no longer sees Alliance respawn logic, and vice versa. Neutral graveyards (e.g. Ratchet) serve the same subzones for both factions.
- **Options panel** (Options > AddOns > UnstuckSkips Forever, or `/usf`): subzone borders, orange splits, graveyard markers, old deathskips, hover tooltip, green line, tooltip text size, respawn box, death sharing, and recorded deaths (blue dots, off by default).
- **Options right on the map**: the "UnstuckSkips Forever" button (top right of the map) opens a menu of clickable options; "More options…" opens the full panel.
- **Show Alliance, Horde or both**: pick which faction's graveyards and respawns the map shows (your own faction is marked "(you)"); with both, the hover tooltip gives one respawn line per faction.
- The original UnstuckSkips lines are now called **Old deathskips**.
- **On-screen Deathskips box** (on by default, can be turned off): the addon logo, "Deathskips", and in green, with the RestedXP death-skip icon, the graveyard you'd respawn at if you died where you stand, updated live as you walk. Drag it anywhere.
- **Spirit healer markers your way**: cross or spirit-healer icon, 4 sizes, 5 colors, and optional graveyard names on zone maps (Options > Spirit healers).
- **Faster map**: opening, closing, zooming and changing zones no longer recompute the drawing (cached per map, one redraw per frame). Subzone borders show on zone maps only (thousands of lines on the continent view slowed zooming down).
- Fixed map markers drawn in the wrong place on zone maps (a point outside the zone could land inside it).
- Death sharing is unchanged (anonymous, `/usf share` to turn it off): it's what lets us improve the data.

# 0.4.4

- **Subzones.** On Forever the respawn graveyard depends on the subzone you die in (e.g. in The Barrens, The Merchant Coast sends you to Ratchet, but just outside it you go to The Crossroads). The addon now learns "zone + subzone -> graveyard" from shared deaths and uses your current subzone for its predictions.
- Map lines are redrawn as soon as a shared death changes something.
- Areas corrected by a real death now show a thin blue line to the graveyard they actually send you to, with its name.
- Near real deaths, the closest one decides, so a correction from a neighbouring subzone no longer spills over (e.g. Valley of Trials vs The Merchant Coast).
- **Real deaths now fix the map lines.** When a player respawns somewhere other than predicted, the area around that death (about 350 m) now shows the real graveyard on the map and in the prediction (e.g. The Zoram Strand in Ashenvale sends you to Twilight Vale in Darkshore). Deaths that match the prediction change nothing, so correct borders stay put. The map gets more accurate as deaths are shared.
- Graveyard markers (X) now only show graveyards your faction can actually reach (e.g. an Alliance character no longer sees Brill or Deathknell marked in Tirisfal).
- **Hover the map** (with DeathSkips shown) to see which graveyard you'd respawn at if you died there, and why: graveyard table, real death, or graveyard learned from players.

# 0.4.3

- **Learned graveyards for the new Forever zones.** Zones that don't exist in Classic (Riverglades, Mount Hyjal...) now get their graveyards from deaths shared by players, with their faction: e.g. Riverglades has an Alliance graveyard, a Horde graveyard and a shared one. The addon keeps learning as more deaths come in.
- Mulgore: the Red Cloud Mesa starting-area graveyard now covers the whole starting area.
- Checked against 87 real deaths shared by players: 97% correct in zones covered by the graveyard table.

# 0.4.2

- Better predictions where Forever changed Classic graveyards: graveyards that exist in the Classic data but not on Forever are now replaced by the Forever graveyard that took their place (Desolace: Ghost Walker Post instead of Ethel Rethor; also Arathi Highlands and Eastern Plaguelands). Found thanks to deaths shared by players.

# 0.4.1

- `/usf watch` now only shows deaths you didn't already have (no more "already known" spam).
- Fewer duplicate messages: when another player is already answering a request for deaths, the addon stays quiet instead of sending the same deaths again.

# 0.4.0

- **Real graveyard rule.** The map now uses the actual server logic: you respawn at the nearest graveyard *among those linked to the zone you die in*, using the real Classic 1.12 graveyard/zone table (factions included), with the two Forever changes (city graveyards only serve the city, starting-area graveyards only work near the starting area). Replaces the hand-made rules of 0.3.0.
- **No more gaps in the lines** between zones: mountain ridges that belong to no zone on the continent map now take the nearest zone's graveyard.
- **Subzone in shared deaths.** Each shared death now also includes the subzone, to find graveyards that Forever links to a specific subzone. Fully compatible with 0.3.0 and other addons that share deaths.
- **Collector mode** (`/usf collector`, for people gathering data): at login, asks online players for everything they have instead of only their latest deaths.
- **Live view** (`/usf watch`): shows each death received from other players in chat as it arrives (no names).

# 0.3.0 (first public release)

- DeathSkips map using the WoW Forever graveyard rule (zone-based, faction graveyards, starting-area and city graveyards, Alterac Mountains).
- Pre-computed lines for both factions and both continents: instant display.
- Automatic, anonymous death sharing between players over a hidden channel (no names stored), with resync at login.
- Real deaths shown as blue dots; they override the predicted rule where they exist.
- Death log: predicted vs actual respawn (`/usf deaths`).
- English and French.
