"""Rebuild bundled Korean UI glyphs: python3 tools/subset_korean_font.py SOURCE.ttf.

SOURCE is the official Noto Sans KR font (SIL OFL; license in assets/fonts).
The subset covers every Korean translation and floating tutorial, plus UI numbers and punctuation.
Requires fontTools.
"""
import csv
import json
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1]
rows = list(csv.reader((root / 'localization/translations.csv').open()))
column = rows[0].index('ko')
text = ''.join(row[column] for row in rows[1:] if row)
# Floating tutorials are stored in level JSON rather than the translation CSV.
for path in (root / 'resources/levels').glob('*.json'):
    level = json.loads(path.read_text())
    for hint in level.get('tutorial', {}).get('floating', {}).values():
        text += hint.get('ko', '')
# Also cover new characters absent from the primary font in every locale.
primary_chars = TTFont(root / 'assets/fonts/MiSans-Light.ttf').getBestCmap()
all_text = ''.join(value for row in rows[1:] for value in row[1:])
for path in (root / 'resources/levels').glob('*.json'):
    level = json.loads(path.read_text())
    for hint in level.get('tutorial', {}).get('floating', {}).values():
        all_text += ''.join(hint.values())
text += ''.join(char for char in set(all_text) if ord(char) not in primary_chars)
text += '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ‹›−×·/?:%'
font = TTFont(sys.argv[1])
if 'fvar' in font:
    font = instantiateVariableFont(font, {'wght': 300}, inplace=True)
options = subset.Options()
options.name_IDs = ['*']
options.name_languages = ['*']
options.name_legacy = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
font.save(root / 'assets/fonts/NotoSansKR-UI.ttf')
