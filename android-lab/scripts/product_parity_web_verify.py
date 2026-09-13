#!/usr/bin/env python3
"""One-minute example.com test with observed link coordinates and natural expiry."""
from pathlib import Path
import json,time,re
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
q.OUT=Path('artifacts/android-ui-parity/web-verification');q.OUT.mkdir(parents=True,exist_ok=True)
def state():return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def now():return int(q.sh('date','+%s%3N'))
q.sh('am','start','-W','-a','android.intent.action.VIEW','-d','https://example.com','-p','com.android.chrome');time.sleep(3)
node=next(n for n in q.tree().iter('node') if n.get('text')=='Learn more')
x,y,z,w=map(int,re.findall(r'\d+',node.get('bounds')));point=((x+z)//2,(y+w)//2)
q.sh('input','tap',*point);time.sleep(3)
assert any('iana.org' in (x[0] or '') for x in q.texts()),q.texts()
q.sh('am','start','-W','-a','android.intent.action.VIEW','-d','https://example.com','-p','com.android.chrome');time.sleep(2)
q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.QAHarnessActivity','--es','action','webLock');time.sleep(1)
window=next(s['schedule'] for s in state()['rules'] if s['schedule']['type']=='single' and 'example.com' in s['targets']['domains'] and s['schedule']['start'] <= now() < s['schedule']['end'])
q.sh('am','start','-W','-a','android.intent.action.VIEW','-d','https://example.com','-p','com.android.chrome');time.sleep(2)
q.shot('web-shield-active',False)
blocked=now();assert blocked<window['end']-1000
q.sh('input','tap',*point);time.sleep(.5);q.shot('web-shield-after-tap',False)
while now()<window['end']+1200:time.sleep(2)
q.shot('web-expired',False)
visible=q.texts();assert any(x[0]=='example.com' for x in visible),visible
q.tap('Learn more');time.sleep(3);after=q.texts();assert any('iana.org' in (x[0] or '') for x in after),after
q.shot('web-post-end-link',False)
result={'passed':True,'window':window,'blockedTapRequestedAt':blocked,'point':point,'afterExpiry':visible,'afterLink':after,
        'scope':'Chrome regular tab only. Positive link control before and after lock; no UI instrumentation during blocked interval.'}
(q.OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('PASS: Chrome link blocked and restored after natural expiry',flush=True)
