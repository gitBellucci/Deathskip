![Deathskip](https://i.imgur.com/2CmVysl.png)

_Know exactly where you respawn before you die. The death skip map built for how graveyards really work on WoW Forever._

[![Join the Deathskip Discord](https://i.imgur.com/W69RzbD.png)](https://discord.gg/BKHgxaatxz)

**On Forever, the subzone you die in decides your graveyard, not the distance.**

The Classic UnstuckSkips assumes you respawn at the nearest graveyard. On Forever that's wrong: die on The Merchant Coast and you wake up in Ratchet, die 100 yards away in The Barrens and you wake up at The Crossroads.

Deathskip reads the game's own subzone borders and real deaths shared by players, and shows you the answer for any spot on the map: **98% correct** on 5,671 real deaths (cross-validation), against 78% for the old Classic rule.

![Hover a subzone to see where you respawn](https://i.imgur.com/CJmChIW.png)

_The Merchant Coast sends you to Ratchet. A few yards west, in The Barrens, you would wake up at The Crossroads. The red line splits The Barrens between The Crossroads and Camp Taurajo._

### ![](https://i.imgur.com/iX2bqJm.png) ___**Hover, read, die**___

Open the world map and hover any spot. The tooltip in the top left gives the **subzone** and the **spirit healer** you'd respawn at, and a green line points to it. The tooltip scales with the map, so it stays readable on the small map. No command, nothing to set up.

### ![](https://i.imgur.com/KtwSTCv.png) ___**The real subzone borders**___

The borders are the game's own subzones, read from the client's terrain files, on land and at sea. By default they follow the game's exact 33-yard squares, like ClassicZoneMap (smoothed lines are an option):

*   **solid white**: crossing this border changes your graveyard
*   **dashed white**: same graveyard on both sides, the border makes no difference (hidden by default, one click to show)
*   **red**: one area shared between two graveyards, you go to the nearer one. The line is the exact straight line halfway between the two graveyards

So **no border is invisible**, and the ones that matter stand out. Graveyards your faction can reach are shown with a spirit-healer icon and their name.

![Subzone borders and graveyards](https://i.imgur.com/6uEOmq9.png)

_Eastern Plaguelands: dying at Lake Mereldar sends you to Darrowshire. Solid borders change your graveyard, dashed ones don't, red lines split an area between two graveyards. The map menu is open on the right._

### ![](https://i.imgur.com/9axmVJG.png) ___**Alliance, Horde or both**___

You see your own faction by default, and it follows you when you switch between Alliance and Horde characters. Switch to the other faction or to both: the tooltip then gives one respawn line per faction. Neutral graveyards like Ratchet serve both.

### ![](https://i.imgur.com/Q4ZUBcb.png) ___**Options right on the map**___

The _Deathskip_ button at the top right of the world map opens a menu of clickable options. Everything else is in _Options > AddOns > Deathskip_ (or type `/usf`):

*   subzone borders, no-effect borders (dashed), red splits, exact or smoothed borders, graveyard markers, old Classic deathskips
*   graveyards as a spirit-healer icon or a cross, 4 sizes, 5 colors, with or without names
*   tooltip on/off, text size, green line
*   the on-screen _Deathskips_ box (on by default, close it with its X, bring it back from the map menu): the graveyard you'd respawn at if you died where you stand, updated as you walk

![Options](https://i.imgur.com/Z0qSaP0.jpeg)

### ![](https://i.imgur.com/hFdyJav.png) ___**Light on your PC**___

All the data ships with the addon: nothing is computed while you play. The map drawing is cached per zone and redrawn at most once per frame, so opening, closing and zooming the map stay smooth.

### ![](https://i.imgur.com/ujEpJf2.png) ___**How graveyards work on Forever**___

*   A **subzone** can have its own graveyard, which overrides the zone's. The Merchant Coast: Ratchet. The rest of The Barrens: The Crossroads.
*   **Starting areas** are subzones too. Shadowglen: Aldrassil, the rest of Teldrassil: Dolanaar. Coldridge Valley: Anvilmar, the rest of Dun Morogh: Kharanos.
*   Some subzones send you to **another zone**: The Zoram Strand (Ashenvale) to Twilight Vale (Darkshore), North Coast (Tirisfal) to Faol's Rest, Freewind Post to The Great Lift.
*   **City** graveyards only serve the city. The other faction's graveyards don't count.

### ![](https://i.imgur.com/4FVTNmE.png) ___**Death sharing and privacy**___

When you die and release your spirit, the addon notes where you died and where you respawned. When your character is moved while you're logged out (character unstuck service, logout skips), it notes where you logged out and where you logged back in. A few minutes later (out of combat, outside instances) it shares this on a hidden channel with other players using the addon. This is how each update gets more accurate, and how we're mapping unstuck skips on Forever next.

*   **Shared:** death and respawn positions, logout and login positions when your character was moved, continent, zone, subzone, faction, date.
*   **Never shared:** character names, guild, or anything else about you.
*   Off anytime in the options or with `/usf share`. Recorded deaths can be shown as blue dots (off by default).

### ![](https://i.imgur.com/9oAoZGo.png) ___**Commands**___

`/usf` options | `/usf share` sharing on/off | `/usf data` deaths known | `/usf deaths` your last deaths (predicted vs actual) | `/usf unstucks` your recorded unstucks | `/usf notifier` on-screen box

### ![](https://i.imgur.com/peM71ux.png) ___**Wrong prediction?**___

Nothing to do: your death is shared automatically and fixes the next update. To help more, post the zone and spot in the comments.

### ![](https://i.imgur.com/t8rOc4u.png) ___**Credits**___

*   UnstuckSkips by **SeargentFish** and **cloudbells**.
*   LogoutSkips by **yazpad** and **Zarant** (MIT).
*   Logout skip locations: **Zarant**.
*   Skip discoveries and research: **Tactics**, **TommySalami**, **Vitochie**.
*   Map line drawing: **Semlar**.
*   Client file reader adapted from OpenMap by **jiforever** (MIT). Icons: Lorc, game-icons.net (CC BY 3.0).

[![Join the Deathskip Discord](https://i.imgur.com/W69RzbD.png)](https://discord.gg/BKHgxaatxz)
