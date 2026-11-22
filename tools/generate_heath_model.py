#!/usr/bin/env python3
"""Draft transcribed from A-201; endpoints are deliberately review-required.
All positions are FEET in the surveyed drawing's horizontal plan view. The JSON
that the iOS app reads stores METERS. A-201 W/M tags are framing, not finish.
"""
import json, math
from pathlib import Path
FOOT=.3048
walls=[]; devices=[]; rooms=[]
def wall(id,tag,x1,z1,x2,z2,note='Approximate visual trace; needs dimension check'):
    tags={'W4':3.5,'W6':5.5,'W8':7.25,'W10':9.25,'M4':3.625,'M6':6,'M8':8,'M10':10}
    walls.append(dict(id=id,tag=tag,start={'x':round(x1*FOOT,4),'z':round(z1*FOOT,4)},end={'x':round(x2*FOOT,4),'z':round(z2*FOOT,4)},thicknessMeters=round(tags[tag]*.0254,4),heightMeters=round(10*FOOT,4),sourceSheet='A-201',verified=False,note=note))
def device(id,kind,label,x,y,z,sheet='E-104',circuit='Unverified',note='Illustrative placement in the room shown by the drawings; exact coordinate and height NOT verified'):
    devices.append(dict(id=id,kind=kind,label=label,x=round(x*FOOT,4),y=round(y*FOOT,4),z=round(z*FOOT,4),sourceSheet=sheet,circuit=circuit,verified=False,note=note))
def room(label,x,z): rooms.append(dict(name=label,x=round(x*FOOT,4),z=round(z*FOOT,4)))
# Endpoints were estimated from the A-201 vector PDF image using its actual
# overall dimension chain as a scale check. This is not a verified CAD trace.
# A-201 plan positive X runs to the right; Z runs down; main west/north facade=(0,0).
# The plan's 47 ft 8 in dimension spans projections, NOT a plain rectangle.
wall('EXT-N-01','W6',0,0,38,0)
wall('EXT-N-02','W6',38,0,38,-4.0)
wall('EXT-N-03','W6',38,-4.0,60,-4.0)
wall('EXT-N-04','W6',60,-4.0,60,0)
wall('EXT-N-05','W6',60,0,123.5,0)
wall('EXT-E-01','W6',123.5,0,123.5,41.8)
wall('EXT-S-01','W6',123.5,41.8,95.5,41.8)
wall('EXT-S-02','W6',95.5,41.8,95.5,44.0)
wall('EXT-S-03','W6',95.5,44.0,60.0,44.0)
wall('EXT-S-04','W6',60.0,44.0,60.0,41.8)
wall('EXT-S-05','W6',60,41.8,33,41.8)
wall('EXT-S-06','W6',33,41.8,25,41.8)
wall('EXT-S-07','W6',25,41.8,0,41.8)
wall('EXT-W-01','W6',0,0,0,16.6)
wall('EXT-W-02','W6',0,16.6,0,41.8)
# Dining and play (child play has storefront glazing not yet cut into mesh).
wall('PLAY-N','W6',0,16.6,16.2,16.6)
wall('PLAY-E','W6',16.2,16.6,16.2,41.8)
# Meal fulfillment and counter, behind dining.
wall('MFA-W','W6',38,0,38,14.3)
wall('MFA-S','W6',38,14.3,59.2,14.3)
wall('MFA-E','W8',59.2,-4,59.2,28.4)
wall('SERVING-S-01','W6',38,28.4,59.2,28.4)
wall('SERVING-W','W6',38,14.3,38,28.4)
wall('SERVING-COUNTER','W6',39.5,24.0,57,24.0)
# Kitchen zone and WIF/WIC; upper-right references from A-201.
wall('KITCHEN-S-01','W8',60,28.9,83,28.9)
wall('KITCHEN-S-02','W8',83,28.9,100.5,28.9)
wall('KITCHEN-E','W6',107.5,0,107.5,22.5)
wall('WIF-W','W6',107.5,0,107.5,7.0)
wall('WIC-W','W6',110.0,7.0,110.0,19.4)
wall('WIF-WIC-DIV','M6',107.5,7.0,117.0,7.0)
wall('WIF-E','W6',117.0,0,117.0,7.0)
wall('WIC-E','W6',117.0,7.0,117.0,19.4)
wall('WIC-S','W6',110.0,19.4,117.0,19.4)
wall('RISER-E','W6',123.5,0,123.5,7.2)
wall('RISER-S','W6',117,7.2,123.5,7.2)
# Restroom bank and vestibule. Door gaps here are illustrative.
wall('REST-W','W6',60,28.9,60,38.6)
wall('MEN-WOMEN','W6',80.8,28.9,80.8,38.6)
wall('WOMEN-E','W6',95.5,28.9,95.5,43.0)
wall('REST-S-MEN','W6',60,38.6,68.0,38.6)
wall('REST-S-MEN-2','W6',70.6,38.6,80.8,38.6)
wall('REST-S-WOMEN','W6',80.8,38.6,86,38.6)
wall('REST-S-WOMEN-2','W6',88.5,38.6,95.5,38.6)
# Service/office/flex/tech/team-member rooms near the east end.
wall('SERVICE-NE','W8',100.5,28.9,123.5,28.9)
wall('SERVICE-W','W6',100.5,28.9,100.5,35.2)
wall('OFFICE-W','W6',101,29,101,35.0)
wall('OFFICE-N','W6',101,29,111.7,29)
wall('OFFICE-E','W6',111.7,29,111.7,35)
wall('OFFICE-S','W6',101,35,111.7,35)
wall('FLEX-N','W6',95.5,35,101,35)
wall('FLEX-E','W6',104.5,35,104.5,41.8)
wall('TECH-E','W6',112.5,35,112.5,41.8)
wall('TEAM-N','W6',112.5,35,123.5,35)
wall('TEAM-W','W6',112.5,35,112.5,41.8)
# Entry vestibule: left of queue and east of play.
wall('ENTRY-W','W6',23.6,34.0,23.6,41.8)
wall('ENTRY-E','W6',33.0,34.0,33.0,41.8)
wall('ENTRY-N-L','W6',23.6,34.0,26.4,34.0)
wall('ENTRY-N-R','W6',29.6,34.0,33.0,34.0)
for r in [
 ('Dining',19,11),('Play',7,30),('Meal fulfillment',47,6),('Serving',47,24),
 ('Queue',48,36),('Entry vestibule',28.5,38),('Kitchen',81,14),
 ('WIF',113,3),('WIC',113,14),('Service',116,24),('Men',70,33),
 ('Women',88,33),('RR vestibule',78,41.5),('Office',106,32),
 ('Flex space',100,38),('Tech closet',108.5,38),('Team member',118,38)
]: room(*r)
# Devices from E-104/E-801 shown as review-required indicators, NOT exact symbols/circuits.
for e in [
 ('DEV-01','receptacle','Dining receptacle (example)',12,1.5,0.5,'E-104'),
 ('DEV-02','receptacle','Dining receptacle (example)',25,1.5,0.5,'E-104'),
 ('DEV-03','receptacle','Serving receptacle (example)',47,1.5,28,'E-104'),
 ('DEV-04','receptacle','Kitchen receptacle (example)',68,1.5,28.7,'E-104'),
 ('DEV-05','receptacle','Kitchen receptacle (example)',87,1.5,28.7,'E-104'),
 ('DEV-06','switch','Office switch (example)',102,4,35.1,'E-104'),
 ('DEV-07','receptacle','Office receptacle (example)',105,1.5,34.8,'E-104'),
 ('DEV-08','receptacle','Team member receptacle (example)',117,1.5,41.4,'E-104'),
 ('DEV-09','panel','Panel equipment zone (approximate)',120,5.5,28.7,'E-104'),
 ('DEV-10','receptacle','Tech closet receptacle (example)',108,1.5,41.4,'E-104'),
 ('DEV-11','lowVoltage','Tech/data outlet (example)',108,1.5,41.4,'E-801'),
 ('DEV-12','lowVoltage','Office communications (example)',105,1.5,35.1,'E-801'),
 ('DEV-13','lowVoltage','Dining WiFi access point (example)',23,8,14,'E-801'),
 ('DEV-14','lowVoltage','Kitchen WiFi access point (example)',82,8,14,'E-801'),
 ('DEV-15','receptacle','Play area receptacle (example)',1,1.5,32,'E-104'),
 ('DEV-16','switch','Entry switch (example)',34,4,38,'E-104'),
 ('DEV-17','receptacle','Flex-space receptacle (example)',100,1.5,41.4,'E-104')]:device(*e)
model=dict(id='heath-06213-draft',name='Chick-fil-A — Heath OH (A-201 draft)',sourceSheet='A-201',revisionDate='2026-04-24',widthMeters=round(123.5*FOOT,4),depthMeters=round((47+8/12)*FOOT,4),description='Manually traced DRAFT from A-201 with measured overall dimensions; room wall endpoints, ceiling heights and all electrical device locations unverified. Not for construction.',modelVerified=False,walls=walls,devices=devices,rooms=rooms)
out=Path(__file__).resolve().parents[1]/'Resources'/'HeathChickFilA_DRAFT.json';out.write_text(json.dumps(model,indent=2,ensure_ascii=False)+'\n')
print(out, 'walls',len(walls),'devices',len(devices),'rooms',len(rooms),'actual footprint m',model['widthMeters'],model['depthMeters'])
