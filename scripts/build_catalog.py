#!/usr/bin/env python3
"""Quét đề HTML và trò chơi HTML, sinh catalog.json cho MathTex THPT."""
from pathlib import Path
from html.parser import HTMLParser
import json, re
ROOT=Path(__file__).resolve().parents[1]
class Parser(HTMLParser):
 def __init__(self): super().__init__(); self.title=False; self.parts=[]; self.meta={}
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag.lower()=='title': self.title=True
  if tag.lower()=='meta':
   k=(a.get('name') or a.get('property') or '').lower()
   if k in {'exam-title','game-title','school','location','school-year','description'}: self.meta[k]=a.get('content','').strip()
 def handle_endtag(self,tag):
  if tag.lower()=='title': self.title=False
 def handle_data(self,data):
  if self.title and data.strip(): self.parts.append(data.strip())
def parse(file):
 p=Parser()
 try:p.feed(file.read_text(encoding='utf-8',errors='replace')[:400000])
 except OSError:return p
 return p
def clean(s):return re.sub(r'[-_]+',' ',s).strip().title()
def main():
 exams=[]; games=[]
 for d in sorted(ROOT.glob('lop[0-9]*')):
  m=re.fullmatch(r'lop(\d+)',d.name)
  if not d.is_dir() or not m:continue
  for f in sorted(d.rglob('*.html')):
   if f.name.lower()=='index.html':continue
   p=parse(f); rel=f.relative_to(ROOT).as_posix(); parts=f.relative_to(d).parts
   exams.append({'grade':int(m.group(1)),'category':parts[0] if len(parts)>1 else 'khac','title':p.meta.get('exam-title') or ' '.join(p.parts) or clean(f.stem),'school':p.meta.get('school',''),'location':p.meta.get('location',''),'year':p.meta.get('school-year',''),'description':p.meta.get('description',''),'path':rel})
 for f in sorted((ROOT/'games').rglob('*.html')) if (ROOT/'games').exists() else []:
  if f.name.lower()=='index.html' and f.parent==ROOT/'games':continue
  p=parse(f); rel=f.relative_to(ROOT).as_posix()
  games.append({'title':p.meta.get('game-title') or ' '.join(p.parts) or clean(f.stem),'description':p.meta.get('description','Trò chơi Toán học'),'path':rel})
 exams.sort(key=lambda x:(x['grade'],x['category'],x['year'],x['title'].casefold()))
 games.sort(key=lambda x:x['title'].casefold())
 data={'exam_count':len(exams),'exams':exams,'game_count':len(games),'games':games}
 (ROOT/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(f"Đã tạo catalog.json: {len(exams)} đề, {len(games)} trò chơi.")
if __name__=='__main__':main()
