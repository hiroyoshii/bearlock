#!/usr/bin/env python3
"""Delete active all-day repeats through the UI; verify cancellation and remaining shields."""
import json, os, re, subprocess, time
from pathlib import Path
import product_qa as q

assert os.environ.get('BEARLOCK_DISPOSABLE_QA') == '1'
assert q.sh('getprop', 'ro.kernel.qemu') == '1'
q.OUT = Path('artifacts/android14/recurring-deletion')
q.OUT.mkdir(parents=True, exist_ok=True)
(q.OUT/'result.json').unlink(missing_ok=True)
probe = 'com.hiyozoo.bearlock.probe'
q.sh('pm', 'clear', q.APP)
q.sh('input', 'keyevent', 224); q.sh('wm', 'dismiss-keyguard')
q.sh('am', 'start', '-W', '-n', probe+'/.ProbeActivity')
node = next(n for n in q.tree().iter('node') if n.get('text','').startswith('タップ試験'))
x,y,z,w = map(int,re.findall(r'\d+',node.get('bounds'))); point=((x+z)//2,(y+w)//2)
q.PRESERVE_ACCESSIBILITY = True
# pm clear leaves the package stopped; launch it before enabling its service.
q.page('schedules', language='en')
q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1')
for _ in range(30):
    if re.search(r'Bound services:.*Service\[label=Bear Lock,', q.sh('dumpsys','accessibility')):
        break
    time.sleep(1)
else:
    raise AssertionError('GuardService did not bind during test setup')
start = int(q.sh('date','+%s%3N'))
rules = [dict(id=f'all-day-{i}', title=f'All day {i}', targets=dict(apps=[probe],domains=[],categories=[]),
              schedule=dict(type='weekly',days=list(range(1,8)),startMinute=540,endMinute=540,zone='UTC'),enabled=True) for i in range(2)]
fixture = dict(schema=3, rules=rules, recent=[])
q.sh('run-as',q.APP,'mkdir','-p','files')
subprocess.run([*q.ADB_COMMAND,'-s',q.SERIAL,'shell','run-as',q.APP,'sh','-c',"'cat > files/locks-v1.json'"], input=json.dumps(fixture).encode(),check=True)
def state(): return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def probe_tap(blocked=True):
    q.sh('am','start','-W','-n',probe+'/.ProbeActivity'); time.sleep(2)
    # Wait for the actual overlay window to finish drawing (or be removed).
    # A service callback alone does not mean Android has presented its surface.
    for _ in range(10):
        windows = re.split(r'\n  Window #', q.sh('dumpsys','window','windows'))
        visible = any('package='+q.APP+' ' in w and 'type=2032' in w and
                      'mDrawState=HAS_DRAWN' in w and 'isVisible=true' in w for w in windows)
        if visible == blocked:
            break
        time.sleep(1)
    else:
        raise AssertionError(f'Shield window did not reach blocked={blocked}')
    q.sh('input','tap',*point); time.sleep(.5)
    raw=q.adb('logcat','-d','-v','raw','-s','BearLockProbe:I','*:S')
    return [int(m[1]) for line in raw.splitlines() if (m:=re.search(r'tap wallMs=(\d+)',line)) and int(m[1])>=start]
q.page('schedules',language='en')
assert not probe_tap(), 'Initial all-day locks did not block'
q.page('schedules',language='en')
q.tap('Delete scheduled lock')
assert any('also ends its active lock' in n.get('text','') for n in q.tree().iter('node'))
q.shot('delete-confirmation')
q.tap('CANCEL'); assert len(state()['rules'])==2
assert not probe_tap(), 'Cancellation ended the lock'
q.page('schedules',language='en'); q.tap('Delete scheduled lock'); q.tap('DELETE')
assert len(state()['rules'])==1
assert not probe_tap(), 'Deleting one schedule cleared the overlapping schedule'
q.shot('remaining-schedule-blocks',xml=False)
q.page('schedules',language='en'); q.tap('Delete scheduled lock'); q.tap('DELETE')
assert state()['rules']==[]
assert probe_tap(blocked=False), 'Deleting the final schedule did not release the probe'
q.shot('deleted-schedules-release',xml=False)
q.page('schedules',language='en')
assert state()['rules']==[]
q.shot('empty-schedule-list')
(q.OUT/'result.json').write_text(json.dumps(dict(passed=True,cancelPreserves=True,overlapPreserved=True,finalDeletionReleases=True),indent=2))
print('PASS: active all-day deletion, cancellation, overlapping shield retained, final deletion releases',flush=True)
