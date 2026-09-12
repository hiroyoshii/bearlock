#!/usr/bin/env python3
"""One-minute actual probe input/expiry regression against the product APK."""
import json,time,re,os
import product_qa as q
from pathlib import Path

def state():return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def now():return int(q.sh('date','+%s%3N'))
q.OUT=Path(os.environ.get('BEARLOCK_PROBE_OUT','artifacts/android-product/verification'));q.OUT.mkdir(parents=True,exist_ok=True)
q.sh('am','start','-W','-n','com.hiyozoo.bearlock.probe/.ProbeActivity')
# Instrumenting the Probe package itself would stop the activity under measurement.
q.PRESERVE_ACCESSIBILITY=False
node=next(n for n in q.tree().iter('node') if n.get('text','').startswith('タップ試験'))
x,y,z,w=map(int,re.findall(r'\d+',node.get('bounds')));point=((x+z)//2,(y+w)//2)
# uiautomator temporarily suppresses services; reconnect before measuring input.
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1');time.sleep(3)
start=now();q.sh('input','tap',*point)
q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.QAHarnessActivity','--es','action','lock')
time.sleep(1)
s=state()['sessions'][-1];assert s['end']>now()
q.sh('am','start','-W','-n','com.hiyozoo.bearlock.probe/.ProbeActivity')
time.sleep(1)
q.shot('shield-active',xml=False)
blockedTap=now();assert blockedTap<s['end']-1000
q.sh('input','tap',*point)
q.page('home');q.shot('active-home',xml=False)
q.page('schedules');q.shot('active-schedule',xml=False)
q.sh('am','start','-W','-n','com.hiyozoo.bearlock.probe/.ProbeActivity')
while now()<s['end']+1200:time.sleep(2)
q.sh('input','tap',*point);time.sleep(.5);q.shot('expired-probe')
raw=q.adb('logcat','-d','-v','raw','-s','BearLockProbe:I','*:S')
events=[]
for line in raw.splitlines():
    m=re.search(r'(resume|pause|tap) wallMs=(\d+) uptimeMs=(\d+) taps=(\d+)',line)
    if m and int(m[2])>=start:events.append({'event':m[1],'wallMs':int(m[2]),'taps':int(m[4])})
result={'window':s,'blockedTapRequestedAt':blockedTap,'probeEvents':events,'stateAfterEnd':state()}
result['passed']=(any(e['event']=='tap' and e['wallMs']<s['start'] for e in events) and not any(e['event']=='tap' and s['start']<=e['wallMs']<s['end'] for e in events) and any(e['event']=='tap' and e['wallMs']>=s['end'] for e in events))
(q.OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
assert result['passed'],result
print('PASS: product probe input blocked; natural expiry restored input.',flush=True)
