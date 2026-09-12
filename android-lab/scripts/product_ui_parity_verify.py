#!/usr/bin/env python3
"""Actual UI transactions, distinct from ScreenshotActivity's read-only fixtures."""
import json,os,re,time
from pathlib import Path
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
q.OUT=Path(os.environ.get('BEARLOCK_QA_OUT','artifacts/android-ui-parity/interactions'))
q.OUT.mkdir(parents=True,exist_ok=True)
results=[]
def record(name):
    results.append(name);print('PASS: '+name,flush=True)
    (q.OUT/'result.json').write_text(json.dumps({'passed':results},ensure_ascii=False,indent=2))
def state():return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def tap(label,scroll=False):
    for attempt in range(5 if scroll else 1):
        nodes=list(q.tree().iter('node'))
        n=next((n for n in nodes if n.get('text')==label or n.get('content-desc')==label),None)
        if n is not None:
            x,y,z,w=map(int,re.findall(r'\d+',n.get('bounds')))
            screen_h=int(re.findall(r'\d+x(\d+)',q.sh('wm','size'))[-1])
            if 0 < (y+w)//2 < screen_h:
                q.sh('input','tap',(x+z)//2,(y+w)//2);time.sleep(.8);return
        q.scroll()
    raise AssertionError((label,[(n.get('text'),n.get('content-desc')) for n in nodes]))
def pref_selection():
    import xml.etree.ElementTree as ET
    text=q.adb('exec-out','run-as',q.APP,'cat','shared_prefs/MainActivity.xml')
    return json.loads(next(x.text for x in ET.fromstring(text) if x.get('name')=='selection'))

q.page('home',True)
recent_before=state()['recent']
tap('ロック対象を選ぶ');tap('Chrome');tap('キャンセル')
assert any(x[0]=='1件の対象' for x in q.texts())
record('Picker cancel restores original selection')
tap('ロック対象を選ぶ');tap('Chrome');q.shot('targets-apps');tap('保存')
assert set(pref_selection()['apps'])=={'com.hiyozoo.bearlock.probe','com.android.chrome'}
record('Picker save persists both selected apps')
tap('ロック対象を選ぶ');tap('Web');q.edit('example.com','example.com');tap('Webサイトを追加');q.shot('targets-web');tap('保存')
q.page('home');assert pref_selection()['domains']==['example.com'];assert any(x[0]=='3件の対象' for x in q.texts())
record('Domain selection survives activity restart')
assert state()['recent']==recent_before
record('Saving app and domain selections does not add or update recent history')
tap('ロック対象を選ぶ');tap('カテゴリ');q.shot('targets-categories');tap('キャンセル')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1');time.sleep(3)
q.page('home',True);tap('後で');tap('15分');q.shot('compose-delayed')
before={r['id'] for r in state()['rules']}
recent_before=state()['recent']
tap('ロックを予約');q.shot('confirmation-sheet');tap('キャンセル')
assert {r['id'] for r in state()['rules']}==before
assert state()['recent']==recent_before
record('Confirmation cancel creates no schedule or recent history')
tap('ロックを予約');tap('ロックを予約')
new=[r for r in state()['rules'] if r['id'] not in before];assert len(new)==1 and new[0]['duration']==15
record('Delayed schedule saved through confirmation')
assert any(r['targets']==new[0]['targets'] for r in state()['recent'])
assert state()['recent']!=recent_before
record('Confirming a schedule records recent targets')
tap('対象一覧');q.shot('target-details');tap('対象のメニュー');tap('ピン解除' if any(x[0]=='ピン解除' for x in q.texts()) else 'ピン留め')
if not any(r['pinned'] for r in state()['recent']):tap('対象のメニュー');tap('ピン留め')
assert any(r['pinned'] for r in state()['recent'])
record('Recent selection can be pinned')
tap('対象一覧')

recent_before=state()['recent']
tap('予約を編集',True);q.shot('scheduled-editor');tap('30分');tap('保存')
assert next(r for r in state()['rules'] if r['id']==new[0]['id'])['duration']==30
assert state()['recent']==recent_before
record('Pending schedule duration edited without changing recent history')
tap('予約を削除',True);tap('削除');assert new[0]['id'] not in {r['id'] for r in state()['rules']}
record('Pending schedule deleted')
q.page('home',True);tap('繰り返し');q.shot('compose-repeat-home');tap('ロックを予約');tap('ロックを予約')
repeat=next(r for r in state()['rules'] if r['days'])
assert repeat['days']==[1,2,3,4,5] and repeat['minute']==1380 and repeat['duration']==480
record('Weekday overnight repeat saved as 23:00–07:00')
tap('予約を編集',True);q.shot('recurring-editor');tap('有効')
assert next(r for r in state()['rules'] if r['id']==repeat['id'])['enabled']
tap('キャンセル')
assert next(r for r in state()['rules'] if r['id']==repeat['id'])['enabled']
record('Cancelling a recurring toggle preserves saved state')
tap('予約を編集',True);tap('有効');tap('保存')
assert not next(r for r in state()['rules'] if r['id']==repeat['id'])['enabled']
tap('予約を編集',True);tap('有効');tap('保存')
assert next(r for r in state()['rules'] if r['id']==repeat['id'])['enabled']
record('Recurring enabled changes persist only on Save')
tap('予約を削除',True);tap('削除')
assert repeat['id'] not in {r['id'] for r in state()['rules']}
record('Repeat cleanup removes only the test schedule')
q.page('settings');q.shot('settings');tap('権限・動作状態を確認');q.shot('permissions')
record('Settings and Android permission recovery open')
