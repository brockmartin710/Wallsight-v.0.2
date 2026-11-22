#!/usr/bin/env python3
import json,math
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'Resources'/'HeathChickFilA_DRAFT.json'
m=json.loads(p.read_text())
assert abs(m['widthMeters']-123.5*.3048)<0.001
assert abs(m['depthMeters']-(47+8/12)*.3048)<0.001
assert len(m['walls']) >= 40
assert len(m['devices']) >= 10
assert len(m['rooms']) >= 10
assert not m['modelVerified']
ids=set()
for w in m['walls']:
 assert w['id'] not in ids; ids.add(w['id'])
 assert w['heightMeters'] > 0 and w['thicknessMeters'] > 0
 assert not w['verified']
 assert w['sourceSheet']=='A-201'
 assert math.hypot(w['end']['x']-w['start']['x'],w['end']['z']-w['start']['z']) > 0
for d in m['devices']:
 assert not d['verified'] and d['circuit']=='Unverified'
 assert d['sourceSheet'] in ('E-104','E-801')
print('PASS:',len(m['walls']),'walls,',len(m['rooms']),'rooms,',len(m['devices']),'provisional devices')
