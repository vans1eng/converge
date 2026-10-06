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
  while True:
   x+=dq;y+=dr
   if y<0 or y>=rows or x+y//2<0 or x+y//2>=cols: break
   i=positions.get((x,y))
   if i is not None:
    if typ(cells[i])=='black': break
    result.append(i)
 return result
def compute(cells):
 for c in cells:
  t=typ(c)
  c['value']=None if t=='black' else sum(typ(cells[i])==t for i in scopes(c,cells)) if t in COLORS[:2] else 0
 for c in cells:
  if typ(c) in ['purple','yellow']:
   c['value']=sum(cells[i]['value'] for i in scopes(c,cells,typ(c)=='yellow') if typ(cells[i]) in COLORS[:2])
def solutions(cells,infer):
 domains=[set(c.get('candidate_types',[typ(c)])) for c in cells]
 total=Counter(typ(c) for c in cells); normal=[scopes(c,cells) for c in cells]; rays=[scopes(c,cells,True) for c in cells]
 def propagate(ds):
  changed=True
  while changed:
   changed=False
   for t in COLORS+['yellow']:
    fixed=sum(d=={t} for d in ds); possible=sum(t in d for d in ds)
    if fixed>total[t] or possible<total[t]: return False
    for d in ds:
     if len(d)>1 and t in d:
      if fixed==total[t]: d.remove(t);changed=True
      elif possible==total[t]: d.intersection_update({t});changed=True
   for i,c in enumerate(cells):
    if typ(c)=='black':continue
    for t in list(ds[i]):
     ids=rays[i] if t=='yellow' else normal[i]
     if t in COLORS[:2]:
      lo=sum(ds[j]=={t} for j in ids);hi=sum(t in ds[j] for j in ids)
     else:
      lo=sum(cells[j]['value'] for j in ids if ds[j]<=set(COLORS[:2]));hi=sum(cells[j]['value'] for j in ids if ds[j]&set(COLORS[:2]))
     if not lo<=c['value']<=hi:
      ds[i].remove(t);changed=True
    if not ds[i]:return False
  return True
 found=[]
 def search(ds):
  if len(found)>=2 or not propagate(ds):return
  choices=[i for i,d in enumerate(ds) if len(d)>1]
  if not choices:found.append([next(iter(d)) for d in ds]);return
  i=min(choices,key=lambda i:len(ds[i]))
  for t in sorted(ds[i]):
   cp=[d.copy() for d in ds];cp[i]={t};search(cp)
 search(domains);return found

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
 candidates=list(range(len(cells)));rng.shuffle(candidates)
 if infer:candidates.sort(key=lambda i:typ(cells[i])!='yellow')
 hidden=0
 for i in candidates:
  c=cells[i];t=typ(c)
  if t=='black' or (t=='yellow' and not infer):continue
  c.update(mode='candidate',type='neutral',answer={'type':t},candidate_types=COLORS+(['yellow'] if infer else []))
  if len(solutions(cells,infer))!=1:
   c.update(mode='fixed',type=t);c.pop('answer');c.pop('candidate_types')
  else:hidden+=1
  if hidden>=targets:break
 assert hidden>0 and len(solutions(cells,infer))==1
 return dict(id=f'{chapter}-{number}',chapter_id=chapter,rule_version=2,infer_yellow=infer,board=dict(layout='odd_r',rows=max(c['row'] for c in cells)+1,columns=max(c['col'] for c in cells)+1),cells=cells)

def build():
 originals=[]
 for p in sorted(ROOT.glob('*.json'), key=lambda p: tuple(map(int, p.stem.split('-')))):
  d=json.loads(p.read_text())
  if 'generated_chapter' not in d: originals.append((p,d))
 plain=[(p,d) for p,d in originals if not any(typ(c)=='yellow' for c in d['cells'])];yellow=[(p,d) for p,d in originals if any(typ(c)=='yellow' for c in d['cells'])]
 for ch,items,start in [(1,plain,1),(2,yellow,6)]:
  for i,(p,d) in enumerate(items,start):
   d.pop('name',None)
   d['id']=f'{ch}-{i}';d['chapter_id']=ch
   target=ROOT/f"{d['id']}.json"
   if p != target:p.unlink()
   target.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 generated=[]
 # Compact, deliberately constrained tutorials; later chapters keep richer silhouettes.
 specs=[('hex',1,'三轴初见'),('diamond',2,'求和而非计数'),('ring',2,'跨越空位'),('hex',2,'墙壁截断'),('flower',2,'找出黄色')]
 for i,(kind,n,name) in enumerate(specs,1):
  def special(cells):
   if i==4:
    anchor=next(c for c in cells if c['type']=='yellow');neighbors=[c for c in cells if c['row']==anchor['row'] and c['col']>anchor['col']]
    if neighbors:neighbors[0]['type']='black'
  generated.append(make(shape(kind,n),2,i,name,700+i,1 if i<3 else 2 if i<5 else 3,i==5,special))
 silhouettes=[('diamond',3,'菱光'),('flower',3,'六瓣'),('ring',3,'光环'),('hourglass',3,'沙漏'),('wings',3,'蝶翼'),('star',3,'星芒'),('crescent',3,'弦月'),('hex',3,'蜂巢'),('diamond',4,'晶面'),('flower',4,'绽放'),('ring',4,'回环'),('hourglass',4,'流沙'),('wings',4,'展翼'),('star',4,'星冠'),('flower',4,'花庭')]
 for ch,start in [(1,len(plain)+1),(2,6+len(yellow))]:
  for k,num in enumerate(range(start,31)):
   kind,n,name=silhouettes[k];generated.append(make(shape(kind,n),ch,num,name,1000*ch+num,round(len(shape(kind,n))*(0.65+0.01*k)),ch==2))
 for d in generated:
  d['generated_chapter']=True
  (ROOT/f"{d['id']}.json").write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 print(f'Preserved {len(originals)} boards; generated {len(generated)} uniquely solvable boards.')
 for d in generated:print(d['id'],len(d['cells']),sum(c['mode']=='candidate' for c in d['cells']))
if __name__=='__main__':build()
