-- Cimetieres appris des morts partagees par les joueurs, dans les zones ajoutees par Forever
-- (absentes de la table Classic). Genere par tools/make_learned_data.py.
-- uiMapID -> { {continent, X, Y, factions ("A", "H" ou "AH"), nombre de morts}, ... }
local _, ns = ...
ns.LEARNED = {
  [2482] = {{1, 5221, -1255, "A", 2}},
  [2548] = {{0, -7948, -4846, "H", 1}, {0, -8228, -5575, "AH", 2}, {0, -9175, -4895, "A", 4}},
  [2652] = {{1, -2549, 1320, "H", 2}},
}
