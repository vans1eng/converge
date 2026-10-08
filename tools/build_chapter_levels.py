"""Deterministic authored silhouettes, clue calculation and uniqueness checks."""
import json, random
from pathlib import Path
from collections import Counter
ROOT = Path(__file__).resolve().parents[1] / 'resources/levels'
DIRS = [(1,0),(1,-1),(0,-1),(-1,0),(-1,1),(0,1)]
COLORS = ['red','green','purple']
def typ(c): return c.get('answer',{}).get('type',c['type'])
def axial(c): return c['col']-(c['row']//2),c['row']
def scopes(c,cells,yellow=False):
 q,r=axial(c)
 if not yellow:
  return [i for i,o in enumerate(cells) if o!=c and typ(o)!='black' and max(abs(axial(o)[0]-q),abs(axial(o)[1]-r),abs(sum(axial(o))-q-r))<=c.get('scope_radius',1)]
 positions={axial(o):i for i,o in enumerate(cells)}; result=[]
 rows=max(o['row'] for o in cells)+1; cols=max(o['col'] for o in cells)+1
 for dq,dr in DIRS:
  x,y=q,r
  for distance in range(1,c.get('scope_radius',1)+1):
   x+=dq;y+=dr
   if y<0 or y>=rows or x+y//2<0 or x+y//2>=cols: break
   i=positions.get((x,y))
   if i is not None:
    if typ(cells[i])=='black': break
    result.append(i)
 return result
def axis_pairs(c,cells):
 positions={axial(o):i for i,o in enumerate(cells)}
 q,r=axial(c); result=[]
 for dq,dr in DIRS[:3]:
  for distance in range(1,c.get('scope_radius',1)+1):
   first=positions.get((q+dq*distance,r+dr*distance))
   second=positions.get((q-dq*distance,r-dr*distance))
   if any(i is not None and typ(cells[i])=='black' for i in (first,second)):break
   if first is not None and second is not None:result.append((first,second))
 return result

def compute(cells):
 for c in cells:
  t=typ(c); ids=scopes(c,cells)
  if t=='black':value=None
  elif t in COLORS[:2]:value=sum(typ(cells[i])==t for i in ids)
  elif t=='purple':value=abs(sum((1 if typ(cells[i])=='red' else -1 if typ(cells[i])=='green' else 0) for i in ids))
  else:value=sum({typ(cells[a]),typ(cells[b])}=={'red','green'} for a,b in axis_pairs(c,cells))
  if c['mode'] in ('hidden','red_input'):c['answer']['value']=value
  else:c['value']=value

def clue_possible(color,value,ids,pairs,domains):
 if color in COLORS[:2]:
  return sum(domains[j]=={color} for j in ids)<=value<=sum(color in domains[j] for j in ids)
 if color=='purple':
  differences={0}
  for j in ids:
   contributions={1 if t=='red' else -1 if t=='green' else 0 for t in domains[j]}
   differences={a+b for a in differences for b in contributions}
  return value in {abs(n) for n in differences}
 lo=hi=0
 for a,b in pairs:
  possible={int({x,y}=={'red','green'}) for x in domains[a] for y in domains[b]}
  lo+=min(possible);hi+=max(possible)
 return lo<=value<=hi

def oversized_purple(cells):
 """Use the actual clue radius and exclude walls, exactly like red/green counts."""
 return [c for c in cells if typ(c)=='purple' and c['value']>len(scopes(c,cells))]

def balance_purple(cells):
 """Difference clues always fit their scope; no recoloring is needed."""
 compute(cells)
 return True
def solutions(cells,infer=False):
 from puzzle_logic import ColorPuzzle
 return ColorPuzzle(cells).solutions()

def shape(kind,n):
 points=[]
 for r in range(-n,n+1):
  for q in range(-n,n+1):
   dist=max(abs(q),abs(r),abs(q+r)); x=2*q+r
   keep={'hex':dist<=n,'ring':n-1<=dist<=n,'flower':dist<=n and (dist<=1 or q==0 or r==0 or q+r==0 or dist<n),'diamond':abs(x)+abs(r)<=2*n,'hourglass':dist<=n and abs(x)<=abs(r)+1,'wings':dist<=n and (abs(x)>=abs(r) or abs(r)<=1),'star':dist<=n and (abs(q)<=1 or abs(r)<=1 or abs(q+r)<=1),'crescent':dist<=n and max(abs(q-1),abs(r),abs(q+r-1))>=n}.get(kind,False)
   if keep:points.append((q,r))
 return points

def make(points,chapter,number,name,seed,targets,infer=False,special=None):
 rng=random.Random(seed);coords=[(r,q+r//2) for q,r in points]; mr=min(r for r,c in coords)
 # Shift in axial space first so odd-r alignment remains exact.
 shifted=[(r-mr,q+(r-mr)//2) for q,r in points]; mc=min(c for r,c in shifted)
 cells=[]
 for row,col in sorted((r,c-mc) for r,c in shifted):
  t=rng.choices(COLORS,[4,4,2])[0]
  cells.append(dict(id=f'r{row}c{col}',row=row,col=col,mode='fixed',type=t,value=0,scope_radius=1,revealed=True))
 if chapter==2:
  # Spread yellow anchors across the silhouette, then teach inference later.
  anchors=sorted(range(len(cells)),key=lambda i:abs(cells[i]['row']-(max(c['row'] for c in cells)/2))+abs(cells[i]['col']-(max(c['col'] for c in cells)/2)))[:max(1,len(cells)//17)]
  for i in anchors:cells[i]['type']='yellow'
 if special:special(cells)
 compute(cells)
 if not balance_purple(cells):raise ValueError('Cannot balance purple clues')
 candidates=list(range(len(cells)));rng.shuffle(candidates)
 hidden=0
 for i in candidates:
  c=cells[i];t=typ(c)
  if t not in ['red','green']:continue
  c.update(mode='candidate',type='neutral',answer={'type':t},candidate_types=['red','green'])
  if len(solutions(cells,infer))!=1:
   c.update(mode='fixed',type=t);c.pop('answer');c.pop('candidate_types')
  else:hidden+=1
  if hidden>=targets:break
 assert hidden>0 and len(solutions(cells,infer))==1
 return dict(id=f'{chapter}-{number}',chapter_id=chapter,rule_version=3,infer_yellow=False,allowed_colors=['red','green'],board=dict(layout='odd_r',rows=max(c['row'] for c in cells)+1,columns=max(c['col'] for c in cells)+1),cells=cells)

def build():
 from redesign_clue_levels import build as redesign
 return redesign()

if __name__=='__main__':build()
