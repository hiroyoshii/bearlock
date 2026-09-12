"""Permission gates on a disposable emulator; no recordings or real-duration locks."""
import json, re, time
from pathlib import Path
import product_qa as q
assert q.sh("getprop", "ro.kernel.qemu") == "1", "Use a disposable emulator"
q.PRESERVE_ACCESSIBILITY = True
q.OUT = Path('artifacts/android14/permission-scope')
q.OUT.mkdir(parents=True, exist_ok=True)
def texts(): return [t for pair in q.texts() for t in pair[:2]]
def tap(label):
    node = next(n for n in q.tree().iter('node') if label.casefold() in [n.get('text','').strip().casefold(), n.get('content-desc','').casefold()])
    x,y,z,w = map(int,re.findall(r'\d+',node.get('bounds')))
    q.sh('input','tap',(x+z)//2,(y+w)//2); time.sleep(1)
def home():
    q.sh('am','start','-W','-n',q.APP+'/.ScreenshotActivity','--es','language','en')
    q.page('home',True)
q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','deny')
q.sh('settings','delete','secure','enabled_accessibility_services')
q.sh('settings','put','secure','accessibility_enabled','0'); time.sleep(3)
home(); tap('Start lock')
assert 'Allow accessibility access to block your selected apps.' in texts()
assert not any('Allow alarms' in t for t in texts())
q.shot('immediate-missing-accessibility')
tap('Setup')
assert 'Set up accessibility' in texts() and 'Set up alarms' not in texts()
q.shot('immediate-setup')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1'); time.sleep(3)
tap('Return to confirmation'); assert 'Put Bear to sleep.' in texts()
q.shot('immediate-confirmation-without-alarm'); tap('Cancel')
for mode in ['Later','Date','Repeat']:
    tap(mode); tap('Schedule lock')
    assert any('Allow alarms and reminders to start locks' in t for t in texts())
    assert not any('Allow accessibility access' in t for t in texts())
    q.shot('scheduled-'+mode.lower());tap('Cancel')
assert 'deny' in q.sh('appops','get',q.APP,'SCHEDULE_EXACT_ALARM')
(q.OUT/'result.json').write_text(json.dumps({'passed':True,'checks':['Immediate gate only requests accessibility','Immediate setup hides alarm permission','Permission return opens immediate confirmation without alarm access','Later, Date and Repeat request only missing alarm access']},indent=2))
print('PASS permission scope', flush=True)
