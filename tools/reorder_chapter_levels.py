"""Import simple-toy chapter one and regroup Godot chapters, preserving snapshots.

Run once against the current catalog; reruns use the saved pre-reorder snapshot.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/Users/fansheng/Desktop/hexnum/simple-toy/levels')
LEVELS = ROOT / 'resources/levels'
ARCHIVE = LEVELS / 'archive/before-red-green-chapter'
SOURCE_ARCHIVE = LEVELS / 'archive/simple-toy-import-1-36'
# First: controls, red/green tutorial, a public r1 bridge, hidden-number tutorial.
# Then r1 practice, r2 tutorial/practice, r3 tutorial/practice and the large finale.
ORDER = [1, 2, 4, 3, 5, 9, 10, 18, 14, 32, 16, 15, 12, 13, 33, 34, 17, 31, 35, 36]
DRAFTS = set()

def load(path):
    return json.loads(path.read_text())

def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

def forbidden(data):
    types = {c.get('answer', {}).get('type', c['type']) for c in data['cells']}
    return sorted((types & {'black', 'purple', 'yellow'}) | ({'arrow'} if any(c.get('direction') for c in data['cells']) else set()))

def signature(data):
    return json.dumps({'board': data['board'], 'cells': data['cells']}, sort_keys=True)

if not ARCHIVE.exists():
    ARCHIVE.mkdir(parents=True)
    for path in LEVELS.glob('*.json'):
        (ARCHIVE / path.name).write_bytes(path.read_bytes())
SOURCE_ARCHIVE.mkdir(parents=True, exist_ok=True)
sources = {}
for number in range(1, 37):
    path = SOURCE / f'1-{number}.json'
    data = load(path)
    sources[number] = data
    (SOURCE_ARCHIVE / path.name).write_bytes(path.read_bytes())
assert sorted(ORDER) == [n for n, d in sources.items() if not forbidden(d)]
remaining = [n for n, d in sources.items() if forbidden(d)]
manifest = {'version': 'red_green_chapter_v1', 'chapters': {'1': [], '2': []}, 'old_to_new': {}}
outputs = {}
for chapter, numbers in [(1, ORDER), (2, remaining)]:
    for index, number in enumerate(numbers, 1):
        data = json.loads(json.dumps(sources[number]))
        source_id = data['id']
        data.update(id=f'{chapter}-{index}', chapter_id=chapter, source_id=f'simple-toy:{source_id}')
        if number in DRAFTS:
            data['draft'] = True
        if number in [35, 36]:
            data['review_note'] = '作者要求直接加入试玩；原始外观模板尚无可见数字线索。'
        if number == 18:
            data['review_note'] = '原 1-18 可见线索仍有 1 块候选砖无法唯一推断；保持原谜题数据，待复核。'
        outputs[data['id']] = data
        manifest['chapters'][str(chapter)].append({'id': data['id'], 'source': data['source_id'], 'excluded_rules': forbidden(data), 'draft': number in DRAFTS})
# Keep the original Godot chapter two after the sixteen moved source levels.
for index in range(1, 31):
    data = load(ARCHIVE / f'2-{index}.json')
    data.update(id=f'2-{len(remaining)+index}', chapter_id=2, source_id=f'godot:2-{index}')
    if index <= 5:
        data.setdefault('tutorial', {})['hint_key'] = f'TUTORIAL_YELLOW_{index}'
    outputs[data['id']] = data
    manifest['chapters']['2'].append({'id': data['id'], 'source': data['source_id'], 'excluded_rules': forbidden(data), 'draft': False})
# Migrate only puzzles whose board and cell definitions actually match.
for path in ARCHIVE.glob('*.json'):
    old = load(path)
    matches = [d['id'] for d in outputs.values() if signature(old) == signature(d)]
    manifest['old_to_new'][old['id']] = matches[0] if matches else None
for path in LEVELS.glob('*.json'):
    path.unlink()
for level_id, data in outputs.items():
    write(LEVELS / f'{level_id}.json', data)
write(ROOT / 'resources/level_order.json', manifest)
print('Chapter 1:', [f'1-{n}' for n in ORDER])
print('Moved to chapter 2:', [f'1-{n}' for n in remaining])
print('Catalog:', len(outputs), 'puzzles;', len(ORDER), 'chapter-one entries,', len(ORDER)-len(DRAFTS), 'playable;', len(manifest['chapters']['2']), 'chapter-two entries')
