"""Color-domain propagation for the public clues, without consulting hidden colors.

Hidden answers are used only for the red/green totals displayed in the HUD.
Each deduction tests support in one clue (or a displayed total), never branches.
The separate solution enumerator branches only to certify uniqueness/ablation.
"""
from collections import Counter
from build_chapter_levels import typ, scopes, axis_pairs, clue_possible


class ColorPuzzle:
    def __init__(self, cells, disabled_clues=(), use_totals=True):
        self.cells = cells
        self.disabled = set(disabled_clues)
        self.use_totals = use_totals
        self.totals = Counter(typ(c) for c in cells)
        self.normal = [scopes(c, cells) for c in cells]
        self.pairs = [axis_pairs(c, cells) for c in cells]
        self.domains = [set(c.get('candidate_types', [typ(c)])) for c in cells]
        self.dependencies = []
        for i, c in enumerate(cells):
            deps = {i}
            if 'yellow' in self.domains[i]:
                deps.update(j for pair in self.pairs[i] for j in pair)
            if self.domains[i] - {'yellow', 'black'}:
                deps.update(self.normal[i])
            self.dependencies.append(sorted(deps))

    def supported(self, i, domains):
        return any(clue_possible(t, self.cells[i]['value'], self.normal[i],
                                 self.pairs[i], domains) for t in domains[i])

    def propagate(self, domains=None):
        ds = [d.copy() for d in (self.domains if domains is None else domains)]
        trace = []
        rounds = 0
        while True:
            previous = [d.copy() for d in ds]
            rounds += 1
            if any(not d for d in ds): return None, rounds, trace
            if self.use_totals:
                for color in ('red', 'green'):
                    fixed = sum(d == {color} for d in ds)
                    possible = sum(color in d for d in ds)
                    if not fixed <= self.totals[color] <= possible: return None, rounds, trace
                    for j, d in enumerate(ds):
                        if len(d) > 1 and color in d:
                            if fixed == self.totals[color]:
                                d.discard(color)
                                trace.append(('total', color, j))
                            elif possible == self.totals[color]:
                                d.intersection_update({color})
                                trace.append(('total', color, j))
            for i, c in enumerate(self.cells):
                if i in self.disabled or typ(c) == 'black': continue
                if not self.supported(i, ds): return None, rounds, trace
                for j in self.dependencies[i]:
                    if len(ds[j]) <= 1: continue
                    for option in sorted(ds[j]):
                        saved = ds[j]
                        ds[j] = {option}
                        supported = self.supported(i, ds)
                        ds[j] = saved
                        if not supported:
                            ds[j].discard(option)
                            trace.append((c['id'], typ(c) if c['mode'] == 'fixed' else 'candidate', j))
                    if not ds[j]: return None, rounds, trace
            if ds == previous: return ds, rounds, trace

    def logical_result(self):
        ds, rounds, trace = self.propagate()
        return ds is not None and all(len(d) == 1 for d in ds), rounds, trace

    def solutions(self, limit=2):
        found = []
        weights = Counter(j for deps in self.dependencies for j in deps)
        def search(ds):
            if len(found) >= limit: return
            ds, _, _ = self.propagate(ds)
            if ds is None: return
            choices = [i for i, d in enumerate(ds) if len(d) > 1]
            if not choices:
                found.append([next(iter(d)) for d in ds])
                return
            i = min(choices, key=lambda j: (len(ds[j]), -weights[j], j))
            for color in sorted(ds[i]):
                trial = [d.copy() for d in ds]
                trial[i] = {color}
                search(trial)
        search(self.domains)
        return found
