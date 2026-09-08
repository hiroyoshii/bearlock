#!/usr/bin/env python3
"""Picker regression checks; run product_ui_parity_verify.py into the same QA directory first."""
import json,os
from pathlib import Path
import product_qa as q
q.PRESERVE_ACCESSIBILITY=True
q.OUT=Path(os.environ.get('BEARLOCK_QA_OUT','artifacts/android-picker-fix'))
q.page('home',True);q.shot('home')
q.tap('ロック対象を選ぶ');q.edit('アプリを検索','chrome')
labels=[x[0] for x in q.texts()]
assert 'Chrome' in labels and 'Bear Lock Probe' not in labels
q.tap('Chrome');q.tap('カテゴリ');q.tap('アプリ')
labels=[x[0] for x in q.texts()]
assert 'Chrome' in labels and 'Bear Lock Probe' not in labels
assert any(n.get('text')=='Chrome' and n.get('checked')=='true' for n in q.tree().iter('node'))
q.shot('search');q.tap('キャンセル')
assert any(x[0]=='1件の対象' for x in q.texts())
try:
    q.sh('settings','put','system','font_scale','1.5');q.sh('wm','size','960x2082')
    q.page('home',True);q.shot('home-large-text')
    q.tap('ロック対象を選ぶ');q.tap('キャンセル')
finally:
    q.sh('settings','put','system','font_scale','1.0');q.sh('wm','size','1284x2778')
p=q.OUT/'result.json';r=json.loads(p.read_text())
r['passed']+=['App search is retained across category/app tabs; cancel restores draft','Target button remains usable at 320dp and 150% font size']
p.write_text(json.dumps(r,ensure_ascii=False,indent=2))
print('PASS: search, tab switch, cancel and large text')
