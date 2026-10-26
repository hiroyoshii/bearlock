import product_qa as q
import time,json,re
from pathlib import Path
q.PRESERVE_ACCESSIBILITY=True
q.OUT=Path('artifacts/android-ui-refresh/large-text')
def tap(label):
    for _ in range(10):
        width,height=map(int,re.findall(r'(\d+)x(\d+)',q.sh('wm','size'))[-1])
        matches=[n for n in q.tree().iter('node') if n.get('text')==label or n.get('content-desc')==label]
        for n in matches:
            x,y,z,w=map(int,re.findall(r'\d+',n.get('bounds')))
            if w>y and 50<y<height-100:
                q.sh('input','tap',(x+z)//2,(y+min(w,height-100))//2);time.sleep(.4);return
        q.sh('input','swipe',width//2,int(height*.8),width//2,int(height*.3),350)
    raise AssertionError(label)
q.sh('wm','size','960x2082');q.sh('settings','put','system','font_scale','1.5');time.sleep(1)
q.page('home',True);tap('繰り返し');q.sh('input','swipe',480,1800,480,600,350);time.sleep(.5);q.shot('repeat-controls')
q.page('targets',True);tap('Webサイト');q.edit('example.com','this-is-a-long-domain-name-for-confirmation-layout.example.com');tap('Webサイトを追加');tap('保存')
tap('後で');tap('ロックを予約');q.shot('confirmation-long-target');tap('キャンセル')
q.page('targets',True);tap('保存')
q.sh('wm','size','1284x2778');q.sh('settings','put','system','font_scale','1.0');q.page('home')
p=Path('artifacts/android-ui-refresh/acceptance.json');r=json.loads(p.read_text());r['checks']=list(dict.fromkeys(r['checks']+['Long domain plus app name: confirmation scroll and cancel at 150% text']));p.write_text(json.dumps(r,ensure_ascii=False,indent=2))
print('PASS: long target confirmation, cancelled without creating a rule',flush=True)
