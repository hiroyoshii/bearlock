#!/usr/bin/env python3
"""Android 14 acceptance on a disposable CI emulator, using the real planner/guard."""
import json
import os
from pathlib import Path
import re
import runpy
import time
import traceback
import product_qa as q

out = Path('artifacts/android14')
out.mkdir(parents=True, exist_ok=True)
q.OUT = out / 'ui'
q.PRESERVE_ACCESSIBILITY = True
result = {'commit': os.environ.get('GITHUB_SHA', 'local'),
          'run': os.environ.get('GITHUB_RUN_ID', 'local'), 'checks': [], 'passed': False}

def record(text):
    result['checks'].append(text)
    print('PASS: ' + text, flush=True)

def state():
    raw = q.sh('run-as', q.APP, 'sh', '-c', "'if [ -f files/locks-v1.json ]; then cat files/locks-v1.json; else echo {}; fi'")
    return {'rules': [], 'sessions': [], 'recent': [], **json.loads(raw)}

def tap(label):
    for _ in range(5):
        for n in q.tree().iter('node'):
            if label not in [n.get('text'), n.get('content-desc')]:
                continue
            x, y, z, w = map(int, re.findall(r'\d+', n.get('bounds')))
            if 0 < (y+w)//2 < 2700:
                q.sh('input', 'tap', (x+z)//2, (y+w)//2)
                time.sleep(.8)
                return
        q.scroll()
    raise AssertionError('Missing control: ' + label)

try:
    result['api'] = q.sh('getprop', 'ro.build.version.sdk')
    assert result['api'] == '34', result
    q.sh('wm', 'size', '1284x2778')
    q.sh('wm', 'density', '480')
    q.sh('input', 'keyevent', '82')
    # Configure app language via the debug-only helper, then leave its visual fixtures.
    q.sh('am', 'start', '-W', '-n', q.APP+'/.ScreenshotActivity', '--es', 'language', 'ja')
    q.sh('am', 'force-stop', q.APP)
    q.page('permissions')
    tap('ユーザー補助を設定')
    assert any('前面アプリ' in (x[0] or '') for x in q.texts())
    q.shot('disclosure')
    tap('同意しない')
    tap('ユーザー補助を設定')
    tap('同意して設定へ')
    record('Disclosure opens, declines, reopens, and navigates to Android settings after consent')
    q.sh('settings', 'put', 'secure', 'enabled_accessibility_services', q.APP+'/'+q.APP+'.GuardService')
    q.sh('settings', 'put', 'secure', 'accessibility_enabled', '1')
    q.sh('appops', 'set', q.APP, 'SCHEDULE_EXACT_ALARM', 'allow')
    time.sleep(3)
    q.page('permissions')
    assert any(x[0]=='接続済み' for x in q.texts())
    assert any(x[0]=='許可済み' for x in q.texts())
    record('Accessibility connected and exact alarm allowed on API 34')
    q.page('home', True)
    before = state()['recent']
    tap('ロック対象を選ぶ')
    tap('キャンセル')
    assert any(x[0]=='1件の対象' for x in q.texts())
    tap('ロック対象を選ぶ')
    tap('保存')
    assert state()['recent']==before
    record('Target selection cancel/save works without creating recent history')
    tap('後で')
    tap('15分')
    tap('ロックを予約')
    tap('キャンセル')
    assert not state()['rules'] and state()['recent']==before
    record('Confirmation cancel creates neither a rule nor recent history')
    tap('ロックを予約')
    tap('ロックを予約')
    saved = state()
    assert len(saved['rules'])==1 and saved['rules'][0]['duration']==15
    assert len(saved['recent'])==1
    q.shot('saved-schedule')
    record('Confirmed delayed schedule persists and records recent targets')
    tap('予約を編集')
    tap('30分')
    tap('保存')
    assert state()['rules'][0]['duration']==30
    assert state()['recent']==saved['recent']
    tap('予約を削除')
    tap('削除')
    assert not state()['rules']
    record('Pending schedule edit/delete works and preserves recent history')
    os.environ['BEARLOCK_PROBE_OUT'] = str(out / 'blocking')
    runpy.run_path(str(Path(__file__).with_name('product_verify.py')), run_name='__main__')
    probe = json.loads((out/'blocking/result.json').read_text())
    assert probe['passed'] and not probe['stateAfterEnd']['rules'] and not probe['stateAfterEnd']['sessions']
    record('Actual Probe input blocked during a one-minute lock and restored after natural expiry')
    result['passed'] = True
except Exception:
    result['error'] = traceback.format_exc()
    q.shot('failure', xml=False)
    raise
finally:
    (out/'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    (out/'logcat.txt').write_text(q.adb('logcat','-d','-v','threadtime'))
    q.sh('settings', 'delete', 'secure', 'enabled_accessibility_services')
    q.sh('settings', 'put', 'secure', 'accessibility_enabled', '0')
