"""Rebuild 1-20..1-30 and chapter 2 around fixed clues and red/green answers.

Run with PYTHONDONTWRITEBYTECODE=1 python3 tools/redesign_clue_levels.py.
Every board must solve by local clue support and visible totals, without search.
Removing the featured clue equations must admit a second solution.
"""
import copy
import csv
import json
import random
from pathlib import Path
from build_chapter_levels import DIRS, shape, compute, typ, scopes, axis_pairs
from build_chapter_one import wall_points
from puzzle_logic import ColorPuzzle

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ROOT / 'resources/levels'
RG = ['red', 'green']


def make_cells(points, seed, walls=(), clues=(), radii=(1,)):
    rng = random.Random(seed)
    min_r = min(r for q, r in points)
    min_c = min(q + (r-min_r)//2 for q, r in points)
    cells = []
    clue_map = {position: (color, radius) for position, color, radius in clues}
    for q, r in sorted(points, key=lambda p: (p[1], p[0])):
        row, col = r-min_r, q+(r-min_r)//2-min_c
        color, radius = clue_map.get((q, r), (rng.choice(RG), rng.choice(radii)))
        if (q, r) in walls: color, radius = 'black', 1
        cells.append(dict(id=f'r{row}c{col}', row=row, col=col, mode='fixed',
                          type=color, value=0, scope_radius=radius, revealed=True))
    compute(cells)
    return cells


def hide_cell(c):
    color = typ(c)
    assert color in RG
    c.update(mode='candidate', type='neutral', answer={'type': color}, candidate_types=RG[:])


def hide_logically(cells, seed):
    rng = random.Random(seed)
    order = [i for i, c in enumerate(cells) if typ(c) in RG]
    rng.shuffle(order)
    for i in order:
        original = copy.deepcopy(cells[i])
        hide_cell(cells[i])
        if not ColorPuzzle(cells).logical_result()[0]: cells[i] = original
    return sum(c['mode'] == 'candidate' for c in cells)


def tutorial(left_key, right_key):
    with (ROOT / 'localization/translations.csv').open() as f:
        rows = {row['keys']: row for row in csv.DictReader(f)}
    def localized(key):
        return {lang: text for lang, text in rows[key].items() if lang != 'keys'}
    return dict(floating={'left': localized(left_key), 'right': localized(right_key)}, practice=False)


def package(cells, chapter, number, concept, main_type, copy_keys=None):
    puzzle = ColorPuzzle(cells)
    solved, rounds, trace = puzzle.logical_result()
    assert solved, (chapter, number, 'requires guessing')
    answers = puzzle.solutions()
    assert len(answers) == 1, (chapter, number, 'not unique')
    assert answers[0] == [typ(c) for c in cells], (chapter, number, 'wrong authored answer')
    featured = [i for i, c in enumerate(cells) if typ(c) == main_type]
    alternatives = ColorPuzzle(cells, disabled_clues=featured).solutions()
    assert len(alternatives) == 2, (chapter, number, 'featured clues are redundant')
    used = sum(rule_type == main_type for _, rule_type, _ in trace)
    assert used, (chapter, number, 'featured clue has no deduction')
    metadata = dict(concept=concept, featured_clue=main_type, logic_rounds=rounds,
                    clue_deductions=used, unique_solution=True,
                    featured_clues_required=True)
    level = dict(id=f'{chapter}-{number}', chapter_id=chapter, rule_version=3,
                 chapter_revision=6, generated_chapter=True, allowed_colors=RG[:],
                 infer_yellow=False, design=metadata,
                 board=dict(layout='odd_r', rows=max(c['row'] for c in cells)+1,
                            columns=max(c['col'] for c in cells)+1), cells=cells)
    if copy_keys: level['tutorial'] = tutorial(*copy_keys)
    return level


def compact(chapter, number):
    if chapter == 1:
        # Two isolated gray bricks have equal public numbers. The displayed
        # color total leaves both assignments open until the purple clue is used.
        if number == 20:
            points = [(-1,0),(0,0),(1,0),(3,0)]
            setup = [((-1,0),'red',1),((0,0),'purple',1),((1,0),'green',1),((3,0),'red',1)]
            hidden = [(1,0),(3,0)]; walls = []
            concept = 'purple_balance'; keys = ('TUTORIAL_PURPLE_BALANCE','TUTORIAL_FIXED_CLUES')
        elif number == 21:
            points = [(-1,0),(0,0),(1,0),(2,0),(3,0)]
            setup = [((-1,0),'green',1),((0,0),'purple',1),((1,0),'green',1),((3,0),'red',1)]
            hidden = [(1,0),(3,0)]; walls = [(2,0)]
            concept = 'purple_absolute_difference'; keys = ('TUTORIAL_PURPLE_ABSOLUTE','TUTORIAL_PURPLE_ZERO_BRICK')
        else:
            points = [(-4,0),(-2,0),(0,0),(1,0),(2,0)]
            setup = [((-4,0),'green',1),((-2,0),'green',1),((0,0),'purple',2),((2,0),'red',1)]
            hidden = [(-4,0),(2,0)]; walls = [(1,0)]
            concept = 'purple_radius_wall'; keys = ('TUTORIAL_PURPLE_R2','TUTORIAL_PURPLE_WALL')
        cells = make_cells(points, 100+number, walls, setup)
        min_r = min(r for q,r in points)
        min_c = min(q+(r-min_r)//2 for q,r in points)
        for q,r in hidden:
            hide_cell(next(c for c in cells if c['row']==r-min_r and c['col']==q+(r-min_r)//2-min_c))
        return package(cells, chapter, number, concept, 'purple', keys)
    radius = 1 if number == 1 else 2
    points = {(0,0)}
    setup = [((0,0),'yellow',radius)]
    distances = [1] if number == 1 else [2]
    for distance in distances:
        for direction, (dq,dr) in enumerate(DIRS):
            if number in (1,2) and direction in (2,5): continue
            if number == 2 and direction in (0,3): distance_for_axis = 1
            else: distance_for_axis = distance
            p = (dq*distance_for_axis, dr*distance_for_axis); points.add(p)
            color = ('red' if direction in (0,4,2) else 'green')
            setup.append((p, color, 1))
    walls = []
    if number == 4:
        points.add((1,0)); walls = [(1,0)]
    if number == 5:
        # A purple brick on the inner ray does not block the distance-two pair.
        points.add((1,0)); setup.append(((1,0),'purple',1))
    cells = make_cells(points, 200+number, walls, setup)
    if number in (1,2,3,5):
        # Opposite pairs on two axes; each gray pair can be swapped with the
        # same total and same own numbers until yellow fixes its orientation.
        coords = [(-1 if number == 2 else -radius,0),(-radius,radius)]
        min_r = min(r for q,r in points)
        min_c = min(q+(r-min_r)//2 for q,r in points)
        for q,r in coords:
            hide_cell(next(c for c in cells if c['row']==r-min_r and c['col']==q+(r-min_r)//2-min_c))
    else:
        hide_logically(cells, 20_000+number)
    concepts = ['yellow_opposite_pairs','yellow_two_distances','yellow_gaps','yellow_wall','yellow_transparent_clues']
    return package(cells, chapter, number, concepts[number-1], 'yellow')


# Deliberate silhouettes/obstacles, then choose reproducible clue placements.
# The unknown count grows with board size; radii/overlaps form the progression.
PURPLE = [
    (23,'diamond',2,(1,2),'gate','purple_overlap'),
    (24,'flower',3,(1,2),'crossbar','purple_zero_and_difference'),
    (25,'wings',3,(2,3),'gates','purple_cross_wall'),
    (26,'hourglass',4,(1,2,3),'spine','purple_two_regions'),
    (27,'crescent',4,(2,3),'crescent','purple_nested_scopes'),
    (28,'ring',4,(2,3),'divider','purple_hollow_ring'),
    (29,'star',4,(1,2,3),'zigzag','purple_overlap_chain'),
    (30,'flower',4,(2,3),'spine','purple_final_combination'),
]
YELLOW = [
    (6,'hex',2,(1,),'none','yellow_three_axes'),
    (7,'diamond',2,(1,2),'none','yellow_r2'),
    (8,'flower',2,(2,),'none','yellow_multiple_clues'),
    (9,'ring',3,(2,),'none','yellow_equal_distance_gaps'),
    (10,'hex',3,(2,),'gate','yellow_blocked_pairs'),
    (11,'wings',3,(1,2),'none','yellow_axis_overlap'),
    (12,'diamond',3,(3,),'none','yellow_r3'),
    (13,'flower',3,(2,3),'gate','yellow_long_rays'),
    (14,'hourglass',3,(2,3),'divider','yellow_split_axes'),
    (15,'hex',3,(2,3),'zigzag','yellow_wall_and_radius'),
    (16,'ring',3,(3,),'none','yellow_hollow_axes'),
    (17,'wings',3,(2,3),'gates','yellow_wall_limits'),
    (18,'crescent',4,(2,3),'none','yellow_asymmetric_board'),
    (19,'star',3,(1,2,3),'none','yellow_nested_axes'),
    (20,'flower',3,(2,3),'crossbar','yellow_purple_combination'),
    (21,'diamond',4,(1,2,3),'gate','yellow_complementary_axes'),
    (22,'hourglass',4,(2,3),'spine','yellow_two_halves'),
    (23,'ring',4,(3,),'none','yellow_outer_pairs'),
    (24,'hex',4,(2,3),'gates','yellow_interlocking_axes'),
    (25,'wings',4,(2,3),'divider','yellow_far_pairs'),
    (26,'star',4,(2,3),'none','yellow_six_arms'),
    (27,'flower',4,(1,2,3),'zigzag','yellow_partial_pairs'),
    (28,'crescent',5,(2,3),'crescent','yellow_offset_scopes'),
    (29,'ring',5,(2,3),'none','yellow_ring_and_difference'),
    (30,'hex',4,(1,2,3),'crossbar','yellow_final_combination'),
]


def generated(chapter, spec):
    number, kind, size, radii, pattern, concept = spec
    points = set(shape(kind, size))
    walls = set() if pattern == 'none' else wall_points(points, size, pattern)
    main = 'purple' if chapter == 1 else 'yellow'
    rejected = {"empty_axis": 0, "too_few_unknowns": 0, "redundant": 0}
    for attempt in range(400):
        seed = 600_000 + chapter*100_000 + number*1000 + attempt
        rng = random.Random(seed)
        available = sorted(points - walls)
        # Spread clues across the silhouette with a fixed density rather than
        # turning every remaining gray brick into a new clue after generation.
        count = max(2, round(len(available) * (.26 if main == 'purple' else .36)))
        if main == 'yellow':
            def pair_capacity(p):
                result = 0
                for dq,dr in DIRS[:3]:
                    for distance in range(1,min(radii)+1):
                        a = (p[0]+dq*distance,p[1]+dr*distance)
                        b = (p[0]-dq*distance,p[1]-dr*distance)
                        if a in walls or b in walls: break
                        if a in points and b in points: result += 1
                return result
            pool = [p for p in available if pair_capacity(p) >= 1]
            count = min(count, max(2,len(pool)-2))
            count = rng.randint(max(2,count//2), count)
        else: pool = available
        if len(pool) < count: continue
        selected = rng.sample(pool, count)
        clues = [(p, main, radii[i % len(radii)]) for i,p in enumerate(selected)]
        if chapter == 2 and number >= 20:
            extra = rng.sample([p for p in available if p not in selected], max(1,len(available)//14))
            clues += [(p,'purple',rng.choice((1,2,3))) for p in extra]
        cells = make_cells(points, seed, walls, clues)
        # Every yellow anchor must form at least one genuine red/green pair;
        # avoiding inert edge rays is part of choosing the board, not a repair.
        if main == 'yellow' and any(not any(typ(cells[a]) in RG and typ(cells[b]) in RG for a,b in axis_pairs(c,cells)) for c in cells if typ(c)=='yellow'):
            rejected['empty_axis'] += 1
            continue
        hidden = hide_logically(cells, seed+500)
        if hidden < max(4, round(len(available)*.48)):
            rejected['too_few_unknowns'] += 1
            continue
        featured = [i for i,c in enumerate(cells) if typ(c)==main]
        if len(ColorPuzzle(cells,featured).solutions()) < 2:
            rejected['redundant'] += 1
            continue
        level = package(cells, chapter, number, concept, main)
        level["design"].update(seed=seed, silhouette=kind, obstacle=pattern)
        return level
    raise AssertionError((chapter,number,'no clue-dependent design found', rejected))


def build():
    protected = {p: p.read_bytes() for p in LEVELS.glob('1-*.json') if int(p.stem.split('-')[1]) < 20}
    levels = []
    for chapter, numbers in [(1,range(20,23)), (2,range(1,6))]:
        for number in numbers:
            level = compact(chapter,number); levels.append(level)
            print(level['id'],level['design'],flush=True)
    for chapter, specs in [(1,PURPLE),(2,YELLOW)]:
        for spec in specs:
            level = generated(chapter,spec); levels.append(level)
            print(level['id'],len(level['cells']),'bricks;',sum(c['mode']=='candidate' for c in level['cells']),'unknown;',level['design'],flush=True)
    assert len(levels)==41
    # No partial chapter is written if any design/validation fails.
    for level in levels:
        (LEVELS/f"{level['id']}.json").write_text(json.dumps(level,ensure_ascii=False,indent=2)+'\n')
    assert all(p.read_bytes()==data for p,data in protected.items())
    print('PASS: 41 redesigned boards; red/green-only answers; fixed clues; unique solutions; deduction without branching; featured clues required.')
    return levels


if __name__ == '__main__': build()
