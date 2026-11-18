Deathskip (beta)
================

Death skip map for WoW Forever. Fork of UnstuckSkips (MIT), adapted to how
graveyards actually work on Forever, and improved by real deaths shared by players.

INSTALL
- Unzip so you get: World of Warcraft\_forever_\Interface\AddOns\UnstuckSkipsForever
- Restart the game.

USE
- World map, top right: "Show DeathSkips" (white) and "Show UnstuckSkips" (red).
- DeathSkips (white lines): die inside an area, you respawn at that area's graveyard (X).
- Blue dots: real deaths collected from players (yours included).
- UnstuckSkips (red): unchanged from the original addon (Classic data, not verified on Forever).
- Nothing to type. Optional commands: /usf

THE RULE (why it differs from Classic UnstuckSkips)
You don't go to the nearest graveyard. Like every WoW server, Forever uses a table that
links each zone to its graveyards (with a faction), and sends you to the NEAREST graveyard
AMONG THOSE LINKED TO THE ZONE YOU DIE IN. The addon uses the Classic 1.12 version of that
table, with two changes seen on Forever:
  - city graveyards only serve the city (e.g. Gates of Ironforge);
  - starting-area graveyards only work near the starting area.
Zones without a graveyard are linked to a neighbour's (e.g. Alterac Mountains -> Southshore
for Alliance, Tarren Mill for Horde).
Where real deaths exist (blue dots), they override the rule.

DEATH SHARING (automatic)
When you die and release spirit, the addon notes where you died and where you respawned.
A few minutes later, out of combat and outside instances, it sends that on a hidden chat
channel to other players using the addon, and receives theirs. We use these deaths to build
better lines for each update (your map itself only changes when the addon is updated).
- Shared: death position, respawn position, continent, zone, subzone, faction, date.
- Also shared: when your character is moved while logged out (character unstuck service,
  logout skips), the logout position and the login position. Nothing else.
- NOT shared or stored: character names, guild, anything else.
- Max 1 small message per second, never in combat or instances. The channel is hidden.
- Turn it off: /usf share

Options: Options > AddOns > Deathskip, or type /usf.
Commands: /usf share (on/off) · /usf dots (show recorded deaths) · /usf data (deaths known) · /usf deaths (your last deaths)
          /usf notifier (small "where would I respawn" box)
          /usf collector (for data collectors: ask online players for everything at login)
          /usf watch (show each received death live in chat)

Credits: UnstuckSkips by SeargentFish / cloudbells, original LogoutSkips by yazpad,
skip research by Zarant, Tactics, TommySalami; map lines by Semlar. MIT License.
Icon: "Tombstone" by Lorc, game-icons.net, CC BY 3.0 (colors changed).
