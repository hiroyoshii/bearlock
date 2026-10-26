#!/usr/bin/env python3
"""Regular-tab domain blocking, unrelated-domain control and natural expiry on a QA emulator."""
from pathlib import Path
import argparse,json,time,re
import product_qa as q
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--browser',choices=['com.android.chrome','org.mozilla.firefox'],default='com.android.chrome')
parser.add_argument('--output',type=Path,default=Path('artifacts/android-ui-parity/web-verification'))
args=parser.parse_args()
assert q.sh('getprop','ro.kernel.qemu')=='1', 'Use a QA emulator'
q.PRESERVE_ACCESSIBILITY=True
q.OUT=args.output;q.OUT.mkdir(parents=True,exist_ok=True)
(q.OUT/'result.json').unlink(missing_ok=True)
def visit(url):
    q.sh('am','start','-W','-a','android.intent.action.VIEW','-d',url,'-p',args.browser);time.sleep(3)
def state():return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def now():return q.device_clock()[0]
def await_overlay(expected):
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        if ('type=2032' in q.sh('dumpsys','window','windows'))==expected:return
        time.sleep(.25)
    raise AssertionError('Blocking overlay did not become '+('visible' if expected else 'absent'))
def address_is(host,visible):
    if args.browser=='org.mozilla.firefox':
        # Current Firefox exposes the URL via accessibility description, not text.
        return any((d.strip().startswith(host+'. ') or d.strip().startswith(host+'/')) for _,d,_ in visible)
    return any(n.get('class')=='android.widget.EditText' and
               (n.get('text')==host or n.get('text','').startswith(host+'/')) for n in q.tree().iter('node'))
visit('https://example.com')
node=next(n for n in q.tree().iter('node') if n.get('text')=='Learn more')
x,y,z,w=map(int,re.findall(r'\d+',node.get('bounds')));point=((x+z)//2,(y+w)//2)
assert z>x and w>y, 'The test link must be visible before the positive input control'
q.sh('input','tap',*point);time.sleep(3)
assert address_is('iana.org',q.texts()),q.texts()
visit('https://example.com')
q.sh('am','start','-W','-f','0x10008000','-n',q.APP+'/.QAHarnessActivity','--es','action','webLock');time.sleep(1)
window=next(s['schedule'] for s in state()['rules'] if s['schedule']['type']=='single' and 'example.com' in s['targets']['domains'] and s['schedule']['start'] <= now() < s['schedule']['end'])
visit('https://example.org')
assert not any('Bear is sleeping' in (x[0] or '') for x in q.texts()), 'Unrelated domain was blocked'
await_overlay(False)
q.shot('unrelated-domain-control',False)
visit('https://example.com')
await_overlay(True)
q.shot('web-shield-active',False)
blocked=now();assert blocked<window['end']-1000
q.sh('input','tap',*point);time.sleep(.5);q.shot('web-shield-after-tap',False)
while now()<window['end']+1200:time.sleep(2)
await_overlay(False)
q.shot('web-expired',False)
visible=q.texts();assert address_is('example.com',visible),visible
q.tap('Learn more');time.sleep(3);after=q.texts();assert address_is('iana.org',after),after
q.shot('web-post-end-link',False)
result={'passed':True,'window':window,'blockedTapRequestedAt':blocked,'point':point,'afterExpiry':visible,'afterLink':after,
        'browser':args.browser,'version':q.sh('dumpsys','package',args.browser).split('versionName=')[1].split()[0],
        'viewport':q.sh('wm','size'),'density':q.sh('wm','density'),
        'unrelatedDomainControl':True,'scope':'Regular tab with visible address bar only. Positive link control before and after lock; no UI instrumentation during blocked interval.'}
(q.OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print('PASS: '+args.browser+' unrelated-domain control and link restored after natural expiry',flush=True)
