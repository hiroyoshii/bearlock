"""Intro and permission round trip on a disposable CI emulator. Never run on a personal device."""
import os,time,json,re
from pathlib import Path
import product_qa as q
assert os.environ.get('BEARLOCK_DISPOSABLE_QA')=='1'
q.PRESERVE_ACCESSIBILITY=True
q.OUT=Path('artifacts/android14/onboarding'); q.OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def tap(label):
    for _ in range(6):
        for n in q.tree().iter('node'):
            if label in [n.get('text'),n.get('content-desc')]:
                b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
                if len(b)==4 and b[3]>b[1] and b[1]>=0:
                    q.sh('input','tap',(b[0]+b[2])//2,(b[1]+b[3])//2);time.sleep(1);return
        q.scroll()
    raise AssertionError('Missing '+label)
def has(text):return any(text==a or text==b for a,b,_ in q.texts())
q.sh('pm','clear',q.APP)
q.sh('am','start','-W','-n',q.APP+'/.ScreenshotActivity','--es','language','ja')
q.sh('am','force-stop',q.APP)
q.sh('am','start','-W','-n',q.APP+'/.MainActivity');time.sleep(2)
assert has('はじめる') and not has('ロックのアクセスを許可')
q.shot('introduction-ja');tap('はじめる')
assert has('ロック対象を選ぶ') and not has('ロックに必要な設定')
q.shot('home-before-selection-ja')
tap('ロック対象を選ぶ');tap('Bear Lock Probe');tap('保存')
tap('30分');tap('ロック開始')
assert has('先に設定を完了してください')
tap('キャンセル');assert has('30分')
tap('ロック開始');tap('設定へ');q.shot('required-permissions-ja')
tap('ユーザー補助を設定');tap('同意しない');assert has('ロックに必要な設定')
tap('ユーザー補助を設定');tap('同意して設定へ')
q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
q.sh('settings','put','secure','accessibility_enabled','1')
q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow');time.sleep(3)
# Bring the same activity back from OS settings, retaining the draft and return destination.
q.sh('input','keyevent','4');time.sleep(2)
assert has('接続済み');tap('確認に戻る')
assert has('開始から30分後')
q.shot('confirmation-after-settings-ja');tap('キャンセル')
q.sh('am','force-stop',q.APP);q.sh('am','start','-W','-n',q.APP+'/.MainActivity');time.sleep(2)
assert not has('はじめる') and has('ロック対象を選ぶ')
checks.append('Intro -> home without permission -> target selection -> cancel permission gate -> decline disclosure -> OS settings -> confirmation retains 30 minutes -> relaunch skips intro')
# English introduction uses the same production UI; capture before the next acceptance script.
q.sh('am','start','-W','-n',q.APP+'/.ScreenshotActivity','--es','language','en')
q.page('setup');q.shot('introduction-en')
(q.OUT/'result.json').write_text(json.dumps({'passed':True,'checks':checks},indent=2))
print('PASS onboarding round trip',flush=True)
