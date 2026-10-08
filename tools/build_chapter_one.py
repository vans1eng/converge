"""Chapter one: authored progression, reproducible colors, no guessing required.
Run this file to rebuild ONLY chapter 1; chapter 2 remains untouched.
"""
import csv, json, random
from collections import Counter
from pathlib import Path
from build_chapter_levels import compute, scopes, shape, typ, solutions, axial, balance_purple, oversized_purple, clue_possible
ROOT = Path(__file__).resolve().parents[1]
RG = ['red', 'green']
RGP = RG + ['purple']


def logical_solve(cells):
    from puzzle_logic import ColorPuzzle
    solved, rounds, _ = ColorPuzzle(cells).logical_result()
    return solved, rounds


def board(points, palette, seed, radii=(1,), walls=()):
    rng = random.Random(seed)
    min_r = min(r for q, r in points)
    coords = [(r-min_r, q+(r-min_r)//2) for q,r in points]
    min_c = min(c for r,c in coords)
    wall_positions = {(r-min_r, q+(r-min_r)//2-min_c) for q,r in walls}
    cells = []
    for row, col in sorted((r,c-min_c) for r,c in coords):
        color = rng.choices(palette, [5,5,2] if len(palette)==3 else [1,1])[0]
        if (row, col) in wall_positions: color = 'black'
        radius = rng.choice(radii) if color != 'black' else 1
        cells.append(dict(id=f'r{row}c{col}', row=row, col=col, mode='fixed', type=color,
                          value=0, scope_radius=radius, revealed=True))
    compute(cells)
    return cells


def hide(cells, palette, target, rng, preferred=None):
    order = list(range(len(cells)))
    rng.shuffle(order)
    if preferred: order.sort(key=lambda i: i not in preferred)
    count = 0
    for i in order:
        c = cells[i]
        color = typ(c)
        if color not in RG: continue
        c.update(mode='candidate', type='neutral', candidate_types=RG[:], answer={'type':color})
        solved, _ = logical_solve(cells)
        if not solved:
            c.update(mode='fixed', type=color)
            c.pop('answer'); c.pop('candidate_types')
        else: count += 1
        if count >= target: break
    return count


# Retain these files byte for byte. The first wall appears in level six;
# radius two, radius three and purple remain at levels 10, 12 and 20.
PRESERVED = {1, 2, 3, 4, 5, 10, 12}
# number, silhouette, size, editable target, radii, wall pattern
SPECS = [
    (6, 'hex', 1, 2, (1,), 'center'),
    (7, 'diamond', 2, 4, (1,), 'gate'),
    (8, 'flower', 2, 6, (1,), 'crossbar'),
    (9, 'wings', 2, 8, (1,), 'gate'),
    (11, 'hourglass', 2, 6, (1, 2), 'divider'),
    (13, 'hex', 2, 7, (1, 3), 'zigzag'),
    (14, 'diamond', 3, 10, (1, 2, 3), 'gate'),
    (15, 'ring', 3, 12, (1, 2, 3), 'divider'),
    (16, 'crescent', 3, 12, (1, 2, 3), 'crescent'),
    (17, 'hourglass', 3, 14, (1, 2, 3), 'spine'),
    (18, 'flower', 3, 16, (1, 2, 3), 'zigzag'),
    (19, 'wings', 3, 18, (1, 2, 3), 'crossbar'),

]


def wall_points(points, size, pattern):
    patterns = {
        'center': [(0, 0)],
        'crescent': [(-size, 0), (-size, 1), (-size+1, -1), (-size+1, 0)],
        'gate': [(0, 0), (0, 1)],
        'crossbar': [(-1, 0), (0, 0), (1, 0)],
        'divider': [(q, 0) for q in range(-size+1, size)],
        'spine': [(0, r) for r in range(-size+1, size)],
        'gates': [(-1, -1), (-1, 1), (1, -1), (1, 1)],
        'zigzag': [(-1, -1), (0, -1), (0, 0), (1, 0), (1, 1)],
    }
    walls = set(patterns[pattern]) & set(points)
    assert walls, (pattern, size)
    return walls


def wall_tutorial():
    with (ROOT/'localization/translations.csv').open() as f:
        rows = list(csv.DictReader(f))
    copy = {row['keys']: {locale: text for locale, text in row.items() if locale != 'keys'} for row in rows}
    return dict(floating={'left': copy['TUTORIAL_WALL_LEFT'], 'right': copy['TUTORIAL_WALL_RIGHT']}, practice=False)


def build():
    directory = ROOT/'resources/levels'
    originals = {n: json.loads((directory/f'1-{n}.json').read_text()) for n in range(1, 31)}
    protected = {p: p.read_bytes() for p in directory.glob('*.json') if p.stem.startswith('2-') or int(p.stem.split('-')[1]) in PRESERVED or int(p.stem.split('-')[1]) >= 20}
    generated = []
    for n, kind, size, target, radii, pattern in SPECS:
        if n >= 20: continue
        points = shape(kind, size)
        walls = wall_points(points, size, pattern)
        palette = RG
        best = None
        for attempt in range(80):
            seed = 400_000+n*1000+attempt
            cells = board(points, palette, seed, radii, walls)
            wall_ids = {i for i,c in enumerate(cells) if typ(c) == 'black'}
            # Prefer editable bricks touching walls, so the missing colored
            # neighbors matter to the puzzle instead of decorating its edge.
            preferred = [i for i,c in enumerate(cells) if typ(c) != 'black' and any(max(abs(axial(c)[0]-axial(cells[j])[0]), abs(axial(c)[1]-axial(cells[j])[1]), abs(sum(axial(c))-sum(axial(cells[j])))) == 1 for j in wall_ids)]
            hidden = hide(cells, palette, target, random.Random(seed+500), preferred)
            if best is None or hidden > best[0]: best = (hidden, cells)
            if hidden >= target: break
        assert best and best[0] >= max(1, int(target*.65)), (n, best[0] if best else None)
        cells = best[1]
        assert logical_solve(cells)[0], (n, 'logic')
        assert len(solutions(cells, False)) == 1, (n, 'uniqueness')
        assert not oversized_purple(cells), (n, 'purple exceeds count capacity')
        d = dict(id=f'1-{n}', chapter_id=1, rule_version=3, chapter_revision=6,
                 generated_chapter=True, allowed_colors=palette, infer_yellow=False,
                 board=dict(layout='odd_r', rows=max(c['row'] for c in cells)+1, columns=max(c['col'] for c in cells)+1), cells=cells)
        if n == 6: d['tutorial'] = wall_tutorial()
        elif 'tutorial' in originals[n]: d['tutorial'] = originals[n]['tutorial']
        generated.append(d)
        print(d['id'], len(cells), 'bricks;', len(walls), 'walls;', best[0], 'editable; logic rounds:', logical_solve(cells)[1], flush=True)
    # Finish all validation before writing any board.
    assert {int(d['id'].split('-')[1]) for d in generated} == set(range(1,20))-PRESERVED
    for d in generated:
        (directory/f"{d['id']}.json").write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n')
    assert all(p.read_bytes() == data for p,data in protected.items())
    print('PASS: red/green wall puzzles validated; clue chapters are built by redesign_clue_levels.py.')
    return generated


if __name__ == '__main__': build()
