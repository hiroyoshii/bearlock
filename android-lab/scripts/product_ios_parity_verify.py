#!/usr/bin/env python3
"""UI parity and external-support checks on the dedicated QA emulator.
Run after product_ui_parity_verify.py. Does not open a browser or create a lock.
"""
import json,re,time
from pathlib import Path
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
OUT=Path('artifacts/android-ios-parity-2026-09-10')
q.OUT=OUT/'acceptance'
checks=[]
def nodes():return list(q.tree().iter('node'))
def bounds(n):return list(map(int,re.findall(r'\d+',n.get('bounds'))))
def tap(label):
    for _ in range(8):
        matches=[n for n in nodes() if n.get('text')==label or n.get('content-desc')==label]
        matches.sort(key=lambda n:n.get('clickable')!='true')
        h=int(re.findall(r'\d+x(\d+)',q.sh('wm','size'))[-1])
        for n in matches:
            x,y,z,w=bounds(n)
            if w>y and 30<(y+w)//2<h-80:
                q.sh('input','tap',(x+z)//2,(y+w)//2);time.sleep(.6);return
        q.sh('input','swipe','500',int(h*.8),'500',int(h*.25),'350')
    raise AssertionError(label)
def check(name):checks.append(name);print('PASS: '+name,flush=True)
def language(lang):
    q.page('settings',language=lang)
def support(ja):
    q.page('settings');tap('Bear Lockを応援' if ja else 'Support Bear Lock')
    all_nodes=nodes()
    label='公式サイトを開く' if ja else 'Open website'
    assert any(n.get('text')==label and n.get('enabled')=='true' for n in all_nodes)
    assert not any(n.get('text','').startswith(x) for n in all_nodes for x in ['Coffee','Lunch','Dinner'])
    q.shot('support-web')
    tap('戻る' if ja else 'Back')
    assert any(n.get('text')==('設定' if ja else 'Settings') for n in nodes())
q.sh('wm','size','1284x2778');q.sh('wm','density','480');q.sh('settings','put','system','font_scale','1.0')
q.page('home',True);tap('対象一覧')
assert any(n.get('text')=='Bear Lock Probe' for n in nodes())
assert sum(n.get('content-desc')=='対象のメニュー' for n in nodes())<=3
q.shot('target-details')
recent_before=json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))['recent']
choice=next((n for n in nodes() if n.get('class')=='android.widget.Button' and n.get('content-desc','').endswith('未選択')),None)
assert choice is not None, 'Transaction QA should leave more than one recent target'
tap(choice.get('content-desc'))
assert json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))['recent']==recent_before
assert any(n.get('text')=='選択中' for n in nodes())
check('Recent target row selects without changing history')
tap('対象一覧');q.shot('home')
check('Grouped target details render; recent menus limited to three; disclosure closes')
for lang in ['ja','en']:
    if lang=='en':language('en')
    q.OUT=OUT/'actual'/lang
    support(lang=='ja');q.shot('settings')
    check(lang+': website link is enabled without purchase items; back returns to settings')
    q.OUT=OUT/'android'/lang
    for screen in ['home','setup','composeRepeat','activeLock','confirmation','settings']:
        q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.ScreenshotActivity','--es','screen',screen)
        time.sleep(.5);q.shot(screen,False)
language('ja')
try:
    q.sh('wm','size','960x2082');q.sh('settings','put','system','font_scale','1.5')
    q.OUT=OUT/'large-text'
    q.page('home',True);tap('対象一覧');q.shot('target-details')
    support(True);q.shot('settings')
    check('320dp and 150% text: target rows and support/back navigation usable')
finally:
    q.sh('wm','size','1284x2778');q.sh('settings','put','system','font_scale','1.0')
q.page('home')
(OUT/'acceptance.json').write_text(json.dumps({'passed':checks,'support':'website link only; browser launch is not exercised'},ensure_ascii=False,indent=2))
