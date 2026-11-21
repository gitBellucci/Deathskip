-- Etages : la meme case de la carte appartient a une autre zone en dessous ou a cote (tunnels d'Uldaman sous
-- Stonesplinter Valley, Undercity...). Cle "faction:zone du joueur (uiMapID):sous-zone de la carte (areaID)"
-- -> cimetiere observe (c, rX, rY, nombre de morts). Utilise par l'encadre a l'ecran. Genere par tools/make_evidence_data.py.
local _, ns = ...
ns.LAYERS = {
  ["A:1418:38"] = {c=0,rX=-6296,rY=-3492,n=4},
  ["A:1418:923"] = {c=0,rX=-6293,rY=-3493,n=16},
  ["A:1424:1680"] = {c=0,rX=-731,rY=-593,n=8},
  ["A:1425:45"] = {c=0,rX=-289,rY=-4374,n=4},
  ["A:1432:11"] = {c=0,rX=-5351,rY=-2882,n=2},
  ["A:1434:10"] = {c=0,rX=-11543,rY=-228,n=4},
  ["A:1455:1"] = {c=0,rX=-5165,rY=-874,n=6},
  ["A:1458:153"] = {c=0,rX=2605,rY=-542,n=32},
  ["A:2548:44"] = {c=0,rX=-9175,rY=-4895,n=3},
  ["A:2548:17847"] = {c=0,rX=-8229,rY=-5574,n=5},
  ["A:1448:493"] = {c=1,rX=5938,rY=-1218,n=2},
  ["A:1448:618"] = {c=1,rX=5939,rY=-1218,n=7},
  ["H:1418:923"] = {c=0,rX=-6290,rY=-3493,n=8},
  ["H:1424:1680"] = {c=0,rX=-19,rY=-981,n=13},
  ["H:1425:45"] = {c=0,rX=-290,rY=-4374,n=6},
  ["H:1432:836"] = {c=0,rX=-5351,rY=-2882,n=3},
  ["H:1435:4"] = {c=0,rX=-10568,rY=-3377,n=5},
  ["H:1455:1"] = {c=0,rX=-5680,rY=-519,n=2},
  ["H:1455:809"] = {c=0,rX=-5680,rY=-519,n=2},
  ["H:1458:153"] = {c=0,rX=1781,rY=222,n=24},
  ["H:2548:17847"] = {c=0,rX=-8228,rY=-5576,n=2},
  ["H:1441:16985"] = {c=1,rX=-4656,rY=-1767,n=10},
}
