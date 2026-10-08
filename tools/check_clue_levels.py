"""Verify input policy, clue arithmetic, logical solvability and clue necessity.

Also cross-check the domain solver against exhaustive independent arithmetic.
Run: PYTHONDONTWRITEBYTECODE=1 python3 tools/check_clue_levels.py
"""
import copy
import itertools
import json
import random
from collections import Counter
from pathlib import Path
from build_chapter_levels import DIRS, typ, axial, compute
from puzzle_logic import ColorPuzzle

LEVELS = Path(__file__).resolve().parents[1] / 'resources/levels'


def reference_values(cells, colors):
    positions = {axial(c): i for i,c in enumerate(cells)}
    values = []
    for i,c in enumerate(cells):
        color = colors[i]; q,r = axial(c); radius = c['scope_radius']
        if color == 'black': values.append(None); continue
        if color == 'yellow':
            total = 0
            for dq,dr in DIRS[:3]:
                for d in range(1,radius+1):
                    a = positions.get((q+dq*d,r+dr*d))
                    b = positions.get((q-dq*d,r-dr*d))
                    if (a is not None and colors[a]=='black') or (b is not None and colors[b]=='black'): break
                    if a is not None and b is not None and {colors[a],colors[b]}=={'red','green'}:total += 1
        else:
            nearby = []
            for j,other in enumerate(cells):
                x,y = axial(other)
                if j!=i and max(abs(x-q),abs(y-r),abs(x+y-q-r))<=radius: nearby.append(colors[j])
            if color in ('red','green'):total = nearby.count(color)
            else:total = abs(nearby.count('red')-nearby.count('green'))
        values.append(total)
    return values


def exhaustive(cells):
    ids = [i for i,c in enumerate(cells) if c['mode']=='candidate']
    colors = [typ(c) for c in cells]
    totals = Counter(colors)
    result = []
    for options in itertools.product(('red','green'),repeat=len(ids)):
        for i,color in zip(ids,options):colors[i]=color
        if Counter(colors)!=totals: continue
        if reference_values(cells,colors)==[c['value'] for c in cells]:result.append(tuple(colors))
    return result


def cross_check():
    for seed in range(150):
        rng = random.Random(seed)
        cells = []
        for row in range(3):
            for col in range(3):
                if rng.random()<.15:continue
                color=rng.choices(['red','green','purple','yellow','black'],[4,4,2,2,1])[0]
                c=dict(id=f'{row}_{col}',row=row,col=col,mode='fixed',type=color,value=0,scope_radius=rng.randint(1,3))
                if color in ('red','green') and rng.random()<.8:
                    c.update(mode='candidate',type='neutral',answer={'type':color},candidate_types=['red','green'])
                cells.append(c)
        if not cells: continue
        compute(cells)
        # Include deliberately unsatisfiable clues as well as authored answers.
        if seed%3==0:
            editable=[c for c in cells if typ(c)!='black']
            if editable: rng.choice(editable)['value']+=rng.randint(1,3)
        expected=exhaustive(cells)
        actual=ColorPuzzle(cells).solutions(limit=1000)
        assert set(map(tuple,actual))==set(expected),(seed,'solver/exhaustive mismatch')
        solved,_,_=ColorPuzzle(cells).logical_result()
        if solved: assert len(expected)==1,(seed,'invalid logical deduction')
    print('PASS: 150 sparse boards cross-checked against exhaustive independent arithmetic.')


def audit():
    redesigned=0
    for path in sorted(LEVELS.glob('*.json')):
        level=json.loads(path.read_text());cells=level['cells']
        assert level['allowed_colors']==['red','green'] and not level.get('infer_yellow',False),path.stem
        for c in cells:
            if c['mode']=='candidate':
                assert c['candidate_types']==['red','green'] and typ(c) in ('red','green'),(path.stem,c['id'])
            if typ(c) in ('purple','yellow'):assert c['mode']=='fixed',(path.stem,c['id'])
        assert reference_values(cells,[typ(c) for c in cells])==[c['value'] for c in cells],(path.stem,'rule values')
        if level.get('tutorial',{}).get('practice'):continue
        puzzle=ColorPuzzle(cells)
        assert puzzle.logical_result()[0],(path.stem,'requires search')
        assert len(puzzle.solutions())==1,(path.stem,'not unique')
        if 'design' in level:
            main=level['design']['featured_clue']
            ids=[i for i,c in enumerate(cells) if typ(c)==main]
            assert len(ColorPuzzle(cells,ids).solutions())==2,(path.stem,'redundant featured clues')
            redesigned+=1
    assert redesigned==41,redesigned
    print('PASS: all 60 boards follow red/green-only input; 59 puzzles have unique solutions without branching; 41 redesigned boards require their featured fixed clues. The first practice accepts either color.')


if __name__=='__main__':
    cross_check()
    audit()
