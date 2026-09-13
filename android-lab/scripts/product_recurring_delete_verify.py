#!/usr/bin/env python3
"""Delete active all-day repeats through the UI; verify cancellation and remaining shields."""
import json, os, re, subprocess, time
from pathlib import Path
import product_qa as q

assert os.environ.get('BEARLOCK_DISPOSABLE_QA') == '1'
assert q.sh('getprop', 'ro.kernel.qemu') == '1'
q.OUT = Path('artifacts/android14/recurring-deletion')
q.OUT.mkdir(parents=True, exist_ok=True)
probe = 'com.hiyozoo.bearlock.probe'
q.sh('pm', 'clear', q.APP)
q.sh('input', 'keyevent', 224); q.sh('wm', 'dismiss-keyguard')
q.sh('am', 'start', '-W', '-n', probe+'/.ProbeActivity')
node = next(n for n in q.tree().iter('node') if n.get('text','').startswith('タップ試験'))
x,y,z,w = map(int,re.findall(r'\d+',node.get('bounds'))); point=((x+z)//2,(y+w)//2)
q.PRESERVE_ACCESSIBILITY = True
q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1'); time.sleep(3)
start = int(q.sh('date','+%s%3N'))
rules = [dict(id=f'all-day-{i}', title=f'All day {i}', targets=dict(apps=[probe],domains=[],categories=[]),
              schedule=dict(type='weekly',days=list(range(1,8)),startMinute=540,endMinute=540,zone='UTC'),enabled=True) for i in range(2)]
fixture = dict(schema=3, rules=rules, recent=[])
q.sh('run-as',q.APP,'mkdir','-p','files')
subprocess.run([q.ADB,'-s',q.SERIAL,'shell','run-as',q.APP,'sh','-c',"'cat > files/locks-v1.json'"], input=json.dumps(fixture).encode(),check=True)
def state(): return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def probe_tap():
    q.sh('am','start','-W','-n',probe+'/.ProbeActivity'); time.sleep(2)
    q.sh('input','tap',*point); time.sleep(.5)
    raw=q.adb('logcat','-d','-v','raw','-s','BearLockProbe:I','*:S')
    return [int(m[1]) for line in raw.splitlines() if (m:=re.search(r'tap wallMs=(\d+)',line)) and int(m[1])>=start]
q.page('schedules',language='en')
assert not probe_tap(), 'Initial all-day locks did not block'
q.page('schedules',language='en')
q.tap('Delete scheduled lock')
assert any('also ends its active lock' in n.get('text','') for n in q.tree().iter('node'))
q.shot('delete-confirmation')
q.tap('Cancel'); assert len(state()['rules'])==2
assert not probe_tap(), 'Cancellation ended the lock'
q.page('schedules',language='en'); q.tap('Delete scheduled lock'); q.tap('Delete')
assert len(state()['rules'])==1
assert not probe_tap(), 'Deleting one schedule cleared the overlapping schedule'
q.shot('remaining-schedule-blocks',xml=False)
q.page('schedules',language='en'); q.tap('Delete scheduled lock'); q.tap('Delete')
assert state()['rules']==[]
assert probe_tap(), 'Deleting the final schedule did not release the probe'
q.shot('deleted-schedules-release',xml=False)
q.page('schedules',language='en')
assert state()['rules']==[]
q.shot('empty-schedule-list')
(q.OUT/'result.json').write_text(json.dumps(dict(passed=True,cancelPreserves=True,overlapPreserved=True,finalDeletionReleases=True),indent=2))
print('PASS: active all-day deletion, cancellation, overlapping shield retained, final deletion releases',flush=True)
