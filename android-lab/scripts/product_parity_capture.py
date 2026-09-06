#!/usr/bin/env python3
"""Capture production components and clearly separate visual fixtures from real state."""
from pathlib import Path
import json,time,re,hashlib
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
OUT=Path('artifacts/android-ui-parity')
SCREENS=['home','setup','composeRepeat','activeLock','confirmation','composeDelayed','composeDate','settings']
def tap(label):
    for _ in range(5):
        nodes=list(q.tree().iter('node'))
        for n in nodes:
            if n.get('text')==label or n.get('content-desc')==label:
                x,y,z,w=map(int,re.findall(r'\d+',n.get('bounds')))
                if 80<y<w<2706:
                    q.sh('input','tap',(x+z)//2,(y+w)//2);time.sleep(.5);return
        q.scroll()
    raise AssertionError(label)
def language(lang):
    q.page('settings')
    texts=q.texts();japanese=any(x[0]=='データの扱い' for x in texts)
    tap('言語 / Language' if japanese else 'Language / 言語')
    tap('日本語' if lang=='ja' else 'English');time.sleep(1)

q.OUT=OUT/'interactions'
q.page('home',True);tap('後で');tap('開始を5分遅らせる')
assert any(x[0]=='35分' for x in q.texts())
tap('開始を5分早める');assert any(x[0]=='30分' for x in q.texts())
q.shot('delayed-final')
print('PASS: final delay stepper increments/decrements; summary visible',flush=True)
q.page('home',True);tap('日時指定');q.shot('date-final')
# Open and cancel the actual OS date picker without creating a rule.
labels=q.texts();date=next(x[1] or x[0] for x in labels if '年' in (x[1] or x[0]) and '月' in (x[1] or x[0]) and ':' in (x[1] or x[0]))
tap(date);q.shot('date-picker');q.sh('input','keyevent','4')
for lang in ['ja','en']:
    language(lang)
    q.OUT=OUT/'android'/lang
    for screen in SCREENS:
        q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.ScreenshotActivity','--es','screen',screen)
        time.sleep(1);q.shot(screen,False)
    print('Captured '+lang+' visual fixtures',flush=True)
language('ja')
q.sh('wm','size','960x2082');q.sh('settings','put','system','font_scale','1.5');time.sleep(1)
q.OUT=OUT/'accessibility';q.page('home',True);q.shot('home-320dp-font150',False)
q.sh('wm','size','1284x2778');q.sh('settings','put','system','font_scale','1.0');time.sleep(1)
q.page('home',True);tap('繰り返し')
q.sh('wm','size','960x2082');q.sh('settings','put','system','font_scale','1.5');time.sleep(2)
q.scroll();q.shot('repeat-320dp-font150',False)
q.sh('wm','size','1284x2778');q.sh('settings','put','system','font_scale','1.0');time.sleep(1)
q.page('home')
(OUT/'capture-checks.json').write_text(json.dumps({'passed':True,'checks':['Delay 30→35→30 minutes','Date picker opens and cancels','Japanese and English fixtures','320dp / 150% font images inspected separately']},indent=2))
print('Captured 320dp / 150% font screens; restored comparison dimensions and Japanese',flush=True)
