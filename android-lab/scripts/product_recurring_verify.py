#!/usr/bin/env python3
"""Legacy overlapping data: immutable editing, first deadline still blocked, final deadline releases.
This writes an old saved-state fixture directly; normal creation must reject overlapping repeats.
Only writes fixtures on an explicitly disposable emulator; never use on a personal device.
"""
import json, os, re, subprocess, time
from datetime import datetime, timezone
from pathlib import Path
import product_qa as q

assert os.environ.get('BEARLOCK_DISPOSABLE_QA') == '1'
assert q.sh('getprop', 'ro.kernel.qemu') == '1'
q.OUT = Path('artifacts/android14/recurring-contract')
q.OUT.mkdir(parents=True, exist_ok=True)
q.PRESERVE_ACCESSIBILITY = True
probe = 'com.hiyozoo.bearlock.probe'
def now(): return int(q.sh('date', '+%s%3N'))
def state(): return json.loads(q.adb('exec-out', 'run-as', q.APP, 'cat', 'files/locks-v1.json'))
q.sh('pm', 'clear', q.APP)
q.sh('input', 'keyevent', 224); q.sh('wm', 'dismiss-keyguard')
q.sh('am', 'start', '-W', '-n', probe+'/.ProbeActivity')
# UI automation must use uiautomator here, because instrumenting Probe stops its activity.
q.PRESERVE_ACCESSIBILITY = False
node = next(n for n in q.tree().iter('node') if n.get('text','').startswith('タップ試験'))
x,y,z,w = map(int,re.findall(r'\d+',node.get('bounds'))); point=((x+z)//2,(y+w)//2)
q.PRESERVE_ACCESSIBILITY = True
q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1'); time.sleep(3)
start = now()
date = datetime.fromtimestamp(start/1000, timezone.utc)
minute = date.hour*60+date.minute
# Leave at least one minute for screen inspection even if the run starts just before a boundary.
end1 = (start//60000+2)*60000
end2 = end1+60000
rules = [dict(id=f'repeat-{i}', title=f'Repeat {i}', targets=dict(apps=[probe],domains=[],categories=[]),
              schedule=dict(type='weekly',days=[date.isoweekday()],startMinute=minute,
                            endMinute=(minute+i+2)%1440,zone='UTC'),enabled=True) for i in range(2)]
fixture = dict(schema=3, rules=rules, recent=[])
q.sh('run-as',q.APP,'mkdir','-p','files')
subprocess.run([*q.ADB_COMMAND,'-s',q.SERIAL,'shell','run-as',q.APP,'sh','-c',"'cat > files/locks-v1.json'"],
               input=json.dumps(fixture).encode(),check=True)
q.page('schedules',language='en')
nodes = list(q.tree().iter('node'))
buttons = [n for n in nodes if n.get('content-desc') in ('Edit scheduled lock','Delete scheduled lock')]
assert len(buttons)==4
assert all(n.get('enabled') == ('true' if n.get('content-desc')=='Delete scheduled lock' else 'false') for n in buttons)
q.shot('active-repeats')
q.sh('am','start','-W','-n',probe+'/.ProbeActivity'); time.sleep(2)
assert now() < end1
q.shot('overlap-shield',xml=False)
q.sh('input','tap',*point)
while now()<end1+1200: time.sleep(1)
assert now()<end2
q.sh('input','tap',*point); q.shot('first-deadline-still-blocked',xml=False)
while now()<end2+1500: time.sleep(1)
q.sh('input','tap',*point); time.sleep(.5); q.shot('last-deadline-released',xml=False)
raw=q.adb('logcat','-d','-v','raw','-s','BearLockProbe:I','*:S')
taps=[int(m[1]) for line in raw.splitlines() if (m:=re.search(r'tap wallMs=(\d+)',line)) and int(m[1])>=start]
assert not any(t<end2 for t in taps) and any(t>=end2 for t in taps), taps
assert state()==fixture, 'Enforcement mutated the saved rules'
q.page('schedules',language='en')
buttons=[n for n in q.tree().iter('node') if n.get('content-desc') in ('Edit scheduled lock','Delete scheduled lock')]
assert len(buttons)==4 and all(n.get('enabled')=='true' for n in buttons)
q.shot('ended-repeats-editable')
(q.OUT/'result.json').write_text(json.dumps(dict(passed=True,start=start,firstEnd=end1,lastEnd=end2,taps=taps),indent=2))
print('PASS: overlapping repeats, active editing disabled, first end still blocked, final end released without reopening Bear Lock',flush=True)
