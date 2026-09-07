#!/usr/bin/env python3
"""UI refresh acceptance: stable controls, readable scaling and screenshot evidence.
Run on the dedicated emulator after installing the debug product and probe APKs.
No active locks are created by this script.
"""
import json,re,time,subprocess
from pathlib import Path
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
OUT=Path('artifacts/android-ui-refresh')
q.OUT=OUT/'acceptance'
checks=[]
def nodes(): return list(q.tree().iter('node'))
def node(label):
    matches=[n for n in nodes() if n.get('text')==label or n.get('content-desc')==label]
    return next((n for n in matches if n.get('clickable')=='true'),matches[0] if matches else None)
def bounds(label):
    n=node(label)
    if n is None: raise StopIteration(label)
    return list(map(int,re.findall(r'\d+',n.get('bounds'))))
def tap(label):
    for _ in range(7):
        try:
            b=bounds(label)
            if b[3]>b[1] and b[1]>50:
                q.sh('input','tap',(b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(.4);return
        except StopIteration: pass
        width,height=map(int,re.findall(r"(\d+)x(\d+)",q.sh("wm","size"))[-1]);q.sh("input","swipe",width//2,int(height*.8),width//2,int(height*.3),300);time.sleep(.3)
    raise AssertionError(label)
def check(name): checks.append(name);print('PASS: '+name,flush=True)
def language(lang):
    q.page('settings');tap('言語 / Language' if lang=='en' else 'Language / 言語');tap('English' if lang=='en' else '日本語')
q.sh('wm','size','1284x2778');q.sh('wm','density','480');q.sh('settings','put','system','font_scale','1.0')
q.page('home',True)
# Capture a video of actual repeated interaction, separate from read-only fixtures.
rec=subprocess.Popen([q.ADB,'-s',q.SERIAL,'shell','screenrecord','--time-limit','45','/sdcard/bearlock-ui-stability.mp4'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
    for label in ['30分','60分','120分','15分']:
        before=bounds(label);tap(label);assert bounds(label)==before,(label,before,bounds(label))
    check('Preset buttons retain bounds across four changes')
    tap('繰り返し')
    for day in ['月','火','水']:
        before=bounds(day);tap(day);assert bounds(day)==before;tap(day);assert bounds(day)==before
    check('Weekday buttons retain bounds when toggled off/on')
    q.shot('stable-repeat')
finally:
    rec.wait(timeout=50)
    q.OUT.mkdir(parents=True,exist_ok=True)
    (q.OUT/'stability.mp4').write_bytes(q.adb('exec-out','cat','/sdcard/bearlock-ui-stability.mp4',binary=True))
for page,title in [('settings','設定'),('targets','ロック対象')]:
    q.page(page,True);b=bounds(title);assert abs((b[0]+b[2])/2-642)<=3,(title,b)
    q.shot(page);check(title+' title is horizontally centered')
for lang in ['ja','en']:
    if lang=='en':language('en')
    q.OUT=OUT/'android'/lang
    for screen in ['home','setup','composeRepeat','activeLock','confirmation','composeDelayed','composeDate','settings']:
        q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.ScreenshotActivity','--es','screen',screen)
        time.sleep(.5);q.shot(screen,False)
language('ja')
q.sh('wm','size','960x2082');q.sh('settings','put','system','font_scale','1.5');time.sleep(1)
q.OUT=OUT/'large-text'
q.page('home',True);q.shot('home')
for label in ['今すぐ','後で','日時指定','繰り返し']:
    b=bounds(label);assert 0<=b[0]<b[2]<=960 and b[3]>b[1],(label,b)
check('All four modes fit horizontally at 320dp and 150% text')
tap('60分');q.shot('duration');assert any(n.get('text')=='60分' and n.get('selected')=='true' for n in nodes())
tap('繰り返し');q.shot('repeat')
q.page('home',True);tap('後で');tap('ロックを予約');q.shot('confirmation');tap('キャンセル')
check('Actual confirmation can be cancelled at 150% text')
q.sh('wm','size','2082x960');time.sleep(1)
q.page('home',True);tap('後で');tap('ロックを予約');q.shot('confirmation-landscape');tap('キャンセル')
check('Actual confirmation can be cancelled in landscape at 150% text')
q.sh('wm','size','960x2082');time.sleep(1)
q.page('settings');q.shot('settings')
q.page('targets',True);q.shot('targets')
q.sh('wm','size','1284x2778');q.sh('settings','put','system','font_scale','1.0')
q.page('home')
(OUT/'acceptance.json').write_text(json.dumps({'checks':checks,'note':'Video records actual controls. android/ images are read-only visual fixtures. Large text images require visual inspection.'},ensure_ascii=False,indent=2))
