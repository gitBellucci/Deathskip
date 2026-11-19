-- Etages : la meme case de la carte appartient a une autre zone en dessous ou a cote (tunnels d'Uldaman sous
-- Stonesplinter Valley, Undercity...). Cle "faction:zone du joueur (uiMapID):sous-zone de la carte (areaID)"
-- -> cimetiere observe (c, rX, rY, nombre de morts). Utilise par l'encadre a l'ecran. Genere par tools/make_evidence_data.py.
local _, ns = ...
ns.LAYERS = {
  ["A:1418:923"] = {c=0,rX=-6293,rY=-3492,n=11},
  ["A:1424:1680"] = {c=0,rX=-732,rY=-593,n=3},
  ["A:1425:45"] = {c=0,rX=-289,rY=-4374,n=3},
  ["A:1432:11"] = {c=0,rX=-5351,rY=-2882,n=2},
  ["A:1455:1"] = {c=0,rX=-5166,rY=-875,n=2},
  ["A:1458:153"] = {c=0,rX=2605,rY=-542,n=19},
  ["A:2548:44"] = {c=0,rX=-9175,rY=-4895,n=3},
  ["A:2548:17847"] = {c=0,rX=-8229,rY=-5574,n=4},
  ["A:1448:618"] = {c=1,rX=5939,rY=-1218,n=5},
  ["H:1418:923"] = {c=0,rX=-6290,rY=-3493,n=6},
  ["H:1424:1680"] = {c=0,rX=-19,rY=-981,n=7},
  ["H:1425:45"] = {c=0,rX=-288,rY=-4374,n=2},
  ["H:1432:836"] = {c=0,rX=-5351,rY=-2882,n=2},
  ["H:1435:4"] = {c=0,rX=-10568,rY=-3377,n=5},
  ["H:1458:153"] = {c=0,rX=1781,rY=223,n=15},
  ["H:2548:17847"] = {c=0,rX=-8228,rY=-5576,n=2},
  ["H:1441:16985"] = {c=1,rX=-4656,rY=-1767,n=7},
}
