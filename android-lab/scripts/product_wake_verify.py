#!/usr/bin/env python3
"""Free wake UI/persistence and background expiry on a disposable emulator.

Uses the real 30-minute policy for UI booking/cancellation. Only the final expiry
fixture shortens its stored deadline. --real-time leaves the deadline unchanged.
"""
import argparse, json, os, re, subprocess, time
from pathlib import Path
import product_qa as q

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--real-time', action='store_true', help='Wait for the unchanged 30-minute deadline')
parser.add_argument('--output', type=Path, help='Evidence directory for a separate device/layout run')
parser.add_argument('--without-exact-alarm', action='store_true', help='Verify the permission warning and inexact fallback')
args = parser.parse_args()
device_sdk = int(q.sh('getprop', 'ro.build.version.sdk'))
has_exact_alarm_permission = device_sdk >= 31
clock_precision_ms = q.device_clock()[1]
def now(): return q.device_clock()[0]
assert not args.without_exact_alarm or has_exact_alarm_permission, 'Exact-alarm permission is not present on this OS'
assert os.environ.get('BEARLOCK_DISPOSABLE_QA') == '1'
assert os.environ.get('ANDROID_SERIAL'), 'Select the disposable emulator explicitly'
assert q.sh('getprop', 'ro.kernel.qemu') == '1'
assert q.sh('getprop', 'sys.boot_completed') == '1', 'Wait for emulator boot to complete'
q.OUT = args.output or Path('artifacts/android-product/free-wake-real-time' if args.real_time else 'artifacts/android-product/free-wake')
q.OUT.mkdir(parents=True, exist_ok=True)
(q.OUT/'result.json').unlink(missing_ok=True)
probe = 'com.hiyozoo.bearlock.probe'
q.sh('pm', 'clear', q.APP)
q.sh('input', 'keyevent', 224)
q.sh('wm', 'dismiss-keyguard')
q.sh('dumpsys', 'battery', 'set', 'ac', '1')
q.sh('svc', 'power', 'stayon', 'true')
q.page('home', language='en')
q.sh('am', 'start', '-W', '-n', probe+'/.ProbeActivity')
node = next(n for n in q.tree().iter('node') if n.get('text', '').startswith('タップ試験'))
x, y, z, w = map(int, re.findall(r'\d+', node.get('bounds')))
point = ((x+z)//2, (y+w)//2)
control_at = now()
q.sh('input', 'tap', *point)
control_log = q.adb('logcat', '-d', '-v', 'raw', '-s', 'BearLockProbe:I', '*:S')
assert any(int(value) >= control_at for value in re.findall(r'tap wallMs=(\d+)', control_log)), 'Probe input control failed'
print('PASS: target input control before locking', flush=True)
q.PRESERVE_ACCESSIBILITY = True
if has_exact_alarm_permission:
    q.sh('appops', 'set', q.APP, 'SCHEDULE_EXACT_ALARM', 'deny' if args.without_exact_alarm else 'allow')
q.sh('settings', 'put', 'secure', 'enabled_accessibility_services', q.APP+'/'+q.APP+'.GuardService')
q.sh('settings', 'put', 'secure', 'accessibility_enabled', '1')
time.sleep(3)

def state(): return json.loads(q.adb('exec-out', 'run-as', q.APP, 'cat', 'files/locks-v1.json'))
def write(value):
    q.sh('run-as', q.APP, 'mkdir', '-p', 'files')
    subprocess.run([*q.ADB_COMMAND, '-s', q.SERIAL, 'shell', 'run-as', q.APP, 'sh', '-c',
                    "'cat > files/locks-v1.json'"], input=json.dumps(value).encode(), check=True, timeout=30)
tap = q.tap
def open_wake():
    tap('Cancel wake-up' if state().get('wakes') else 'Wake in 30 minutes for free')
def find_wake_summary(label):
    for _ in range(6):
        if any(n.get('text') == label for n in q.tree().iter('node')): return
        q.scroll()
    raise AssertionError('Missing wake summary: '+label)

start = now()
rule = dict(id='wake-ui', title='Focus', targets=dict(apps=[probe], domains=[], categories=[]),
            schedule=dict(type='single', start=start, end=start+120*60_000), enabled=True)
write(dict(schema=3, rules=[rule], recent=[]))
q.page('home', language='en')
q.shot('en-active')
open_wake()
q.shot('en-wake-options')
if args.without_exact_alarm:
    assert any('Exact alarms are not allowed' in n.get('text', '') for n in q.tree().iter('node'))
tap('Cancel')
assert state()['schema'] == 3, 'Opening/cancelling dialog wrote state'
open_wake()
before = now()
tap('Wake in 30 minutes for free')
booked = state()
deadline = booked['wakes'][0]['wakesAt']
assert before+30*60_000 <= deadline <= now()+30*60_000+clock_precision_ms-1
assert booked['schema'] == 4 and len(booked['wakes']) == 1
print('PASS: booking stores one 30-minute wake and migrates schema 3', flush=True)
find_wake_summary('Wake-up scheduled')
q.shot('en-wake-scheduled')
open_wake()
tap('Cancel wake-up')
assert state()['wakes'] == [] and state()['rules'][0]['schedule']['end'] == rule['schedule']['end']
print('PASS: cancellation restores the original deadline', flush=True)
open_wake()
tap('Wake in 30 minutes for free')
booked = state()
restart_at = now()
q.sh('am', 'force-stop', q.APP)
q.page('home', language='ja')
assert state() == booked, 'Restart changed the stored booking'
print('PASS: restart preserves the booked deadline', flush=True)
if device_sdk >= 35:
    # Android 15 delivers BOOT_COMPLETED on leaving force-stop. Wait for that OS
    # transition before simulating explicit accessibility reconnection, not automatic restoration.
    deadline_wait=time.monotonic()+15
    while time.monotonic()<deadline_wait:
        events=q.adb('logcat','-d','-v','epoch','-s','BearLock:I','*:S')
        if any(float(value)*1000 >= restart_at for value in re.findall(
                r'^\s*(\d+\.\d+).*boundary:android.intent.action.BOOT_COMPLETED',events,re.MULTILINE)):
            break
        time.sleep(.25)
    else: raise AssertionError('Android 15 restart did not complete the BOOT_COMPLETED transition')
# Force-stop can leave a stale enabled setting until the OS finishes disconnecting.
# Simulate an explicit OFF -> ON in Settings rather than re-writing the same value.
q.sh('settings', 'delete', 'secure', 'enabled_accessibility_services')
q.sh('settings', 'put', 'secure', 'accessibility_enabled', '0')
time.sleep(2)
q.sh('settings', 'put', 'secure', 'enabled_accessibility_services', q.APP+'/'+q.APP+'.GuardService')
q.sh('settings', 'put', 'secure', 'accessibility_enabled', '1')
time.sleep(3)
q.page('home', language='ja')
find_wake_summary('30分後の起床を予約済み')
q.shot('ja-wake-scheduled')

# OS permission loss is separate from persisted booking; reconnect must not extend it.
q.sh('settings','delete','secure','enabled_accessibility_services')
q.sh('settings','put','secure','accessibility_enabled','0')
time.sleep(2)
q.page('home',language='en')
assert state()==booked
assert any('App blocking is unavailable' in n.get('text','') for n in q.tree().iter('node'))
assert not any(n.get('text')=='Bear is sleeping.' for n in q.tree().iter('node'))
q.shot('service-disconnected')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1')
time.sleep(3)
q.page('home',language='en')
assert state()==booked
find_wake_summary('Wake-up scheduled')
q.shot('service-reconnected')
if has_exact_alarm_permission:
    q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','deny')
    q.page('home',language='en')
    assert state()==booked
    assert any('Scheduled timing permission is missing' in n.get('text','') for n in q.tree().iter('node'))
    open_wake()
    assert any('Exact alarms are not allowed' in n.get('text','') for n in q.tree().iter('node'))
    tap('Cancel')
    q.shot('alarm-permission-revoked')
    if not args.without_exact_alarm:
        q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow')
q.page('home',language='ja')
assert state()==booked
print('PASS: accessibility disconnect/reconnect preserves booking; exact-alarm recovery '+('verified' if has_exact_alarm_permission else 'not applicable before API 31'),flush=True)

# Measure target input before/after expiry without opening Bear Lock after it.
# Only the quick mode shortens the stored deadline.
q.sh('am', 'start', '-W', '-n', probe+'/.ProbeActivity')
time.sleep(3)
blocked_at = now()
q.sh('input', 'tap', *point)
q.shot('shield-before-expiry', xml=False)
def target_is_foreground():
    return any(probe+'/.ProbeActivity' in line for line in q.sh('dumpsys', 'activity', 'activities').splitlines()
               if 'topResumedActivity=' in line or 'mResumedActivity:' in line)
assert target_is_foreground(), 'Target left foreground during blocking measurement'
if not args.real_time:
    booked['wakes'][0]['wakesAt'] = now()+8_000
    write(booked)
while (remaining := booked['wakes'][0]['wakesAt']-now()) > 0:
    assert target_is_foreground(), 'Target left foreground while waiting; the expiry measurement is invalid'
    print(f'Waiting for background wake: {remaining//1000}s remaining', flush=True)
    time.sleep(min(30, remaining/1000))
time.sleep(2)
assert target_is_foreground(), 'Target left foreground before the post-expiry control'
q.sh('input', 'tap', *point)
time.sleep(.5)
raw = q.adb('logcat', '-d', '-v', 'raw', '-s', 'BearLockProbe:I', '*:S')
taps = [int(m[1]) for line in raw.splitlines() if (m := re.search(r'tap wallMs=(\d+)', line))]
assert not any(blocked_at <= value < booked['wakes'][0]['wakesAt'] for value in taps), 'Blocked input reached probe'
assert any(value >= booked['wakes'][0]['wakesAt'] for value in taps), 'Expiry did not restore input'
q.shot('probe-after-expiry', xml=False)
q.page('home', language='ja')
assert not any(n.get('text') == '熊は眠っています。' for n in q.tree().iter('node'))
assert state() == booked, 'Expiry changed the saved rule or wake request'
result = dict(passed=True, bookingDelayMs=30*60_000, cancellation=True, restart=True,
              languages=['en', 'ja'], actualProbeExpiry=True, acceleratedExpiryFixture=not args.real_time,
              realThirtyMinuteLongevityVerified=args.real_time, wakesAt=booked['wakes'][0]['wakesAt'],
              withoutExactAlarm=args.without_exact_alarm,
              permissionRecovery=True,
              exactAlarmPermissionRecovery=has_exact_alarm_permission,
              deviceClockPrecisionMs=clock_precision_ms,
              probeTapWallMs=min(value for value in taps if value >= booked['wakes'][0]['wakesAt']))
(q.OUT/'result.json').write_text(json.dumps(result, indent=2))
print('PASS: free wake booking/cancel/restart, ja/en UI, background expiry restores probe input; real-time='+str(args.real_time))
