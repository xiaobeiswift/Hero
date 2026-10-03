#!/usr/bin/env python3
"""Read-only pixel inspection. Never writes or changes image pixels."""
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'assets/generated/characters/painted_liang_combat_v4.png'
HELPER = (ROOT / 'scripts/painted_battle_liang.gd').read_text()

def rects(key):
    block = HELPER.split('const ' + key + ' := {', 1)[1].split('}', 1)[0]
    return {name: tuple(map(int, values.split(','))) for name, values in
            re.findall(r'"([a-z]+)": Rect2\(([^)]+)\)', block)}

def vectors(key):
    block = HELPER.split('const ' + key + ' := {', 1)[1].split('}', 1)[0]
    return {name: tuple(map(int, values.split(','))) for name, values in
            re.findall(r'"([a-z]+)": Vector2\(([^)]+)\)', block)}

image = Image.open(PATH)
assert image.mode == 'RGBA' and image.size == (1254, 1254)
alpha = np.array(image)[:, :, 3]
regions, expected = rects('SOURCE_REGIONS'), rects('OPAQUE_BOUNDS')
foot, chest, weapon = (vectors(key) for key in ('FOOT_ANCHORS', 'CHEST_ANCHORS', 'WEAPON_ANCHORS'))
coverage = np.zeros(alpha.shape, dtype=np.uint8)
report = {'source': str(PATH.relative_to(ROOT)), 'mode': image.mode, 'size': list(image.size),
          'sha256': hashlib.sha256(PATH.read_bytes()).hexdigest(), 'alpha_threshold': '> 2/255',
          'alpha_range': [int(alpha.min()), int(alpha.max())], 'poses': {},
          'limit': 'Numerical geometry only; facing, anatomy and identity require pixel review.'}
for pose, (x, y, w, h) in regions.items():
    area = alpha[y:y+h, x:x+w]
    yy, xx = np.where(area > 2)
    bounds = (int(x + xx.min()), int(y + yy.min()), int(xx.max()-xx.min()+1), int(yy.max()-yy.min()+1))
    assert bounds == expected[pose], (pose, bounds, expected[pose])
    bx, by, bw, bh = bounds
    gutters = [bx-x, by-y, x+w-bx-bw, y+h-by-bh]
    assert min(gutters) >= 3, (pose, gutters)
    assert not np.any(area[0, :] > 2) and not np.any(area[-1, :] > 2)
    assert not np.any(area[:, 0] > 2) and not np.any(area[:, -1] > 2)
    for anchor in (chest[pose], weapon[pose]):
        assert int(alpha[anchor[1], anchor[0]]) > 200, (pose, anchor)
    coverage[y:y+h, x:x+w] += 1
    report['poses'][pose] = {'source_region': [x,y,w,h], 'alpha_bounds': list(bounds),
                             'gutters_ltrb': gutters, 'foot_anchor': foot[pose],
                             'chest_anchor': chest[pose], 'weapon_anchor': weapon[pose],
                             'battle_visible_size': [round(bw*204/512, 3), round(bh*204/512, 3)]}
assert np.all(coverage <= 1), 'Source regions must not overlap'
excluded = (coverage == 0) & (alpha > 2)
assert int(excluded.sum()) == 44 and int(alpha[excluded].max()) == 12
yy, xx = np.where(excluded)
assert (int(xx.min()),int(yy.min()),int(xx.max()),int(yy.max())) == (1243,1245,1253,1253)
report['excluded_corner_fringe'] = {'pixels':44, 'max_alpha':12, 'bounds_inclusive':[1243,1245,1253,1253], 'method':'Runtime region excludes distant corner artifact; no PNG edits.'}
assert report['sha256'] == '4812052ca14b016e43818713eaefe3a15ba3baa79fc421a8d40fc1e6774b5f33', 'Accepted atlas bytes must remain exact'
portrait_path = ROOT/'assets/generated/characters/painted_liang_portrait_v1.png'
assert hashlib.sha256(portrait_path.read_bytes()).hexdigest() == 'ce56fcca4b2bfaa5af6511df62b65e1463fc21437d5d452d8cb75ede00e081d3'
portrait = Image.open(portrait_path)
assert portrait.mode == 'RGBA' and portrait.size == (1254, 1254)
portrait_alpha = np.array(portrait)[:,:,3]
yp, xp = np.where(portrait_alpha > 2)
assert (int(xp.min()),int(yp.min()),int(xp.max()-xp.min()+1),int(yp.max()-yp.min()+1)) == (17,33,1231,1203)
report['portrait_sha256'] = hashlib.sha256(portrait_path.read_bytes()).hexdigest()
report['npc_idle_visible_height'] = 72.0
report['source_pixels_modified'] = False
report['notes'] = ['Foot anchors are stance baseline midpoints, not necessarily painted pixels.',
                   'All poses share one anatomical scale; bent/kneeling poses are naturally shorter.',
                   'Independent source regions are required. This is not a uniform 2x3 grid.',
                   'Minimum measured transparent alpha>2 gutter is three source pixels.',
                   'Runtime kneel region excludes 44 detached low-alpha pixels in extreme bottom-right corner.']
print(json.dumps(report, ensure_ascii=False, indent=2))
print('PASS: immutable atlas bytes, six region bounds, alpha>2 coverage with documented detached corner exclusion, anchor alpha and clear edges')
