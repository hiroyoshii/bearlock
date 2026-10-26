#!/usr/bin/env python3
"""Capture the installed product's screens and actual UI transitions on disposable QA.
No product code is changed. Fixtures seed only the explicitly selected emulator.
"""
import argparse,hashlib,json,os,re,struct,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
import product_qa as q

parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--apk',type=Path,required=True)
parser.add_argument('--languages',nargs='+',choices=['ja','en'],default=['ja','en'])
parser.add_argument('--flows',nargs='+',help='Capture only named flows; retain verified frames from other completed flows')
args=parser.parse_args()
assert os.environ.get('BEARLOCK_DISPOSABLE_QA')=='1'
assert os.environ.get('ANDROID_SERIAL') and q.sh('getprop','ro.kernel.qemu')=='1'
assert q.sh('getprop','sys.boot_completed')=='1'
q.PRESERVE_ACCESSIBILITY=True
OUT=args.output;OUT.mkdir(parents=True,exist_ok=True)
APK=hashlib.sha256(args.apk.read_bytes()).hexdigest()
def verify_apk():
    path=q.sh('pm','path',q.APP).split('package:',1)[1].splitlines()[0]
    actual=hashlib.sha256(q.adb('exec-out','cat',path,binary=True)).hexdigest()
    assert actual==APK,(actual,APK)
    return actual
verify_apk()
proof_path=OUT/'capture-result.json'
proof=json.loads(proof_path.read_text()) if proof_path.exists() else dict(frames=[],flows=[],completeLatestCapture=False)
assert not proof.get('apkSha256') or proof['apkSha256']==APK
proof.update(apkSha256=APK,installedApkSha256=APK,sdk=int(q.sh('getprop','ro.build.version.sdk')),logicalViewportPixels=[1284,2778],density=480,fontScale=1,
             source='QAHarnessActivity routes, production MainActivity and real buttons; state fixtures on disposable emulator, not enforcement/30-minute longevity proof')
q.sh('wm','size','1284x2778');q.sh('wm','density','480');q.sh('settings','put','system','font_scale','1')
q.sh('input','keyevent','224');q.sh('wm','dismiss-keyguard')
q.sh('settings','put','system','screen_off_timeout','1800000')
if proof['sdk']>=31:q.sh('appops','set',q.APP,'SCHEDULE_EXACT_ALARM','allow')
def targets(apps=None,domains=None):return dict(apps=apps or [],domains=domains or [],categories=[])
PROBE='com.hiyozoo.bearlock.probe'
def state():return json.loads(q.adb('exec-out','run-as',q.APP,'cat','files/locks-v1.json'))
def write(value):
    q.sh('run-as',q.APP,'mkdir','-p','files')
    subprocess.run([*q.ADB_COMMAND,'-s',q.SERIAL,'shell','run-as',q.APP,'sh','-c',"'cat > files/locks-v1.json'"],
                   input=json.dumps(value).encode(),check=True,timeout=30,capture_output=True)
    assert state()==value
def reconnect():
    q.sh('settings','delete','secure','enabled_accessibility_services')
    q.sh('settings','put','secure','accessibility_enabled','0');time.sleep(1)
    q.sh('settings','put','secure','enabled_accessibility_services',q.APP+'/'+q.APP+'.GuardService')
    q.sh('settings','put','secure','accessibility_enabled','1');time.sleep(2)
def seed(value):
    q.sh('am','force-stop',q.APP);write(value);reconnect()
def single(id,title,start,end,immediate=False):
    return dict(id=id,title=title,targets=targets([PROBE]),schedule=dict(type='single',start=start,end=end,immediate=immediate),enabled=True)
def base(lang):
    now=q.device_clock()[0];zone=q.sh('getprop','persist.sys.timezone')
    later=single('capture-later','あとで開始' if lang=='ja' else 'Starts later',now+1800000,now+9000000)
    fixed=single('capture-fixed','日時指定' if lang=='ja' else 'Date & Time',now+7*3600000,now+9*3600000)
    repeat=dict(id='capture-repeat',title='繰り返し' if lang=='ja' else 'Repeats',targets=targets([PROBE]),schedule=dict(type='weekly',days=[1,2,3,4,5],startMinute=1380,endMinute=420,zone=zone),enabled=True)
    off=dict(repeat,id='capture-off',enabled=False)
    return dict(schema=4,selection=targets(),rules=[later,fixed,repeat,off],recent=[],wakes=[])
def empty(selection=None):return dict(schema=4,selection=selection or targets(),rules=[],recent=[],wakes=[])
if not (OUT/'initial-state.json').exists():
    original=q.adb('shell','run-as',q.APP,'cat','files/locks-v1.json')
    (OUT/'initial-state.json').write_text(original)
def store_proof():
    proof_path.write_text(json.dumps(proof,ensure_ascii=False,indent=2))
def text_values(tree):
    return {n.get(key,'').strip() for n in tree.iter('node') for key in ['text','content-desc']}
for lang in args.languages:
    JA=lang=='ja'
    tr=lambda ja,en:ja if JA else en
    q.OUT=OUT/lang;q.OUT.mkdir(exist_ok=True)
    flow=None;steps=[]
    def page(name='home',draft=False):
        q.page(name,draft,language=lang)
    def begin(name):
        global flow,steps
        flow=name;steps=[]
    def snap(name,label,expected=None,canonical=None):
        tree=q.tree();values=text_values(tree)
        assert not any("isn't responding" in s or 'not responding' in s for s in values),'ANR dialog'
        if expected:assert expected.casefold() in {s.casefold() for s in values},(name,expected,sorted(values))
        (q.OUT/(name+'.xml')).write_text(ET.tostring(tree,encoding='unicode'))
        q.shot(name,False)
        path=q.OUT/(name+'.png')
        record=dict(id=lang+'/'+name,language=lang,path=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),apkSha256=APK,
                    sdk=proof['sdk'],rasterSize=list(struct.unpack('>II',path.read_bytes()[16:24])),flow=flow,action=label,canonical=canonical,fixture=state())
        proof['frames']=[r for r in proof['frames'] if r['id']!=record['id']]+[record]
        steps.append(record['id']);store_proof()
        print('CAPTURE '+record['id']+' '+label,flush=True)
    def end():
        proof['flows']=[r for r in proof['flows'] if not(r['language']==lang and r['name']==flow)]
        proof['flows'].append(dict(language=lang,name=flow,steps=list(steps),orderedInteractionCheckpoints=True,qaRouteEntries=True))
        store_proof()
    tap=q.tap
    def toggle_enabled():
        node=next(n for n in q.tree().iter('node') if n.get('class','').endswith('Switch') and n.get('text','').startswith(tr('有効','Enabled')))
        tap(node.get('content-desc') or node.get('text'))
    # Initial and target-selection flow. None of these actions creates lock history.
    if not args.flows or 'onboarding-targets' in args.flows:
        begin('onboarding-targets')
        seed(empty());page('setup')
        snap('setup','初回説明',tr('はじめる','Get started'),'setup')
        tap(tr('はじめる','Get started'))
        snap('setup-home','はじめる→ホーム',tr('ロック対象を選ぶ','Select targets'))
        tap(tr('ロック対象を選ぶ','Select targets'));tap('Chrome');tap('Bear Lock Probe')
        snap('targets-apps','アプリ2件を選択',tr('保存','Save'))
        tap(tr('Webサイト','Websites'));q.edit('example.com','example.com');tap(tr('Webサイトを追加','Add website'))
        snap('targets-web','Webを追加',tr('保存','Save'))
        tap(tr('カテゴリ','Categories'));snap('targets-categories','カテゴリを確認',tr('保存','Save'))
        tap(tr('キャンセル','Cancel'));assert state()['selection']==targets()
        snap('targets-cancelled','対象の取消→ホーム',tr('ロック対象を選ぶ','Select targets'))
        tap(tr('ロック対象を選ぶ','Select targets'));tap('Chrome');tap('Bear Lock Probe')
        tap(tr('Webサイト','Websites'));q.edit('example.com','example.com');tap(tr('Webサイトを追加','Add website'));tap(tr('保存','Save'))
        assert len(state()['selection']['apps'])==2 and state()['selection']['domains']==['example.com']
        snap('targets-saved','対象の保存→ホーム',tr('ロック対象を選ぶ','Select targets'))
        page();tap(tr('対象一覧','Target list'));snap('target-details','再表示して対象一覧を展開','Bear Lock Probe')
        end()
        # Canonical composer screens: actual home-embedded controls, not synthetic dedicated pages.
    if not args.flows or 'composer-preview' in args.flows:
        begin('composer-preview')
        fixture=base(lang);fixture['rules']=fixture['rules'][:3];seed(fixture);page()
        snap('home','対象なし・予定3件のホーム',tr('なし','None'),'home')
        q.scroll();q.scroll();snap('home-bottom','ホーム末尾の予定一覧',tr('ロック予定','Scheduled Locks'))
        seed(empty(targets([PROBE])));page()
        snap('composeNow','今すぐ作成',tr('ロック開始','Start Lock'),'composeNow')
        tap(tr('ロック開始','Start Lock'))
        snap('confirmation','今すぐ120分の開始確認',tr('このロックを開始しますか？','Start this lock?'),'confirmation')
        tap(tr('キャンセル','Cancel'));assert not state()['rules']
        snap('confirmation-cancelled','開始確認の取消',tr('ロック開始','Start Lock'))
        tap(tr('後で','In'));snap('composeDelayed','30分後の作成',tr('開始まで','Starts in'),'composeDelayed')
        page();tap(tr('日時指定','Date & Time'));snap('composeDate','日時指定の作成',tr('開始','Starts'),'composeDate')
        tap(tr('開始日','Start date'))
        snap('date-picker','OS日付入力');q.sh('input','keyevent','4')
        tap(tr('開始日','Start date'));tap('OK')
        snap('date-confirmed','日付確定→作成（時刻pickerを連続表示しない）',tr('開始時刻','Start time'))
        tap(tr('開始時刻','Start time'));tap('OK')
        snap('fixed-time-confirmed','時刻確定→作成',tr('ロックを予約','Schedule Lock'))
        page();tap(tr('繰り返し','Repeat'));snap('composeRepeat','繰り返し作成',tr('曜日','Weekdays'),'composeRepeat')
        tap(tr('開始時刻','Start time'));snap('time-picker','OS時刻入力');q.sh('input','keyevent','4')
        end()
        # Actual create, cancel, edit and delete, including resulting home states.
    if not args.flows or 'single-save-edit-delete' in args.flows:
        begin('single-save-edit-delete')
        seed(empty(targets([PROBE])));page();tap(tr('後で','In'));tap(tr('15分','15 min'))
        tap(tr('ロックを予約','Schedule Lock'));snap('delayed-confirmation','予約確認')
        tap(tr('キャンセル','Cancel'));assert not state()['rules'] and not state()['recent']
        snap('cancelledHome','予約確認の取消',tr('ロックを予約','Schedule Lock'))
        tap(tr('ロックを予約','Schedule Lock'));tap(tr('ロックを予約','Schedule Lock'))
        assert len(state()['rules'])==1 and len(state()['recent'])==1
        snap('savedHome','予約保存→ホーム',tr('ロック予定','Scheduled Locks'))
        tap(tr('対象一覧','Target list'));tap(tr('対象の操作','Target actions'))
        snap('recent-menu','履歴メニュー');tap(tr('対象を固定','Pin target'))
        assert state()['recent'][0]['pinned'];snap('recent','履歴をピン留め')
        page();tap(tr('予定ロックを編集','Edit scheduled lock'))
        snap('scheduledEditor','単発予定の編集',tr('保存','Save'),'scheduledEditor')
        tap(tr('30分','30 min'));tap(tr('キャンセル','Cancel'))
        assert state()['rules'][0]['schedule']['end']-state()['rules'][0]['schedule']['start']==900000
        snap('edit-cancelled','編集取消→ホーム')
        tap(tr('予定ロックを編集','Edit scheduled lock'));tap(tr('30分','30 min'));tap(tr('保存','Save'))
        assert state()['rules'][0]['schedule']['end']-state()['rules'][0]['schedule']['start']==1800000
        snap('editedHome','編集保存→ホーム')
        tap(tr('予定ロックを削除','Delete scheduled lock'))
        snap('deleteConfirmation','単発の削除確認',tr('削除','Delete'))
        tap(tr('キャンセル','Cancel'));assert len(state()['rules'])==1
        snap('delete-cancelled','削除取消→ホーム')
        tap(tr('予定ロックを削除','Delete scheduled lock'));tap(tr('削除','Delete'));assert not state()['rules']
        snap('deletedHome','削除後のホーム');end()
    if not args.flows or 'repeat-save-edit-delete' in args.flows:
        begin('repeat-save-edit-delete')
        seed(empty(targets([PROBE])));page();tap(tr('繰り返し','Repeat'));tap(tr('ロックを予約','Schedule Lock'))
        snap('repeatConfirmation','繰り返しの確認');tap(tr('ロックを予約','Schedule Lock'))
        assert len(state()['rules'])==1 and state()['rules'][0]['schedule']['type']=='weekly'
        snap('repeat-saved','繰り返し保存後')
        tap(tr('予定ロックを編集','Edit scheduled lock'))
        snap('recurringEditor','繰り返し編集',tr('保存','Save'),'recurringEditor')
        toggle_enabled();tap(tr('キャンセル','Cancel'));assert state()['rules'][0]['enabled']
        snap('repeat-edit-cancelled','有効変更の取消')
        tap(tr('予定ロックを編集','Edit scheduled lock'));toggle_enabled();tap(tr('保存','Save'))
        assert not state()['rules'][0]['enabled'];snap('repeat-off','無効を保存')
        tap(tr('予定ロックを編集','Edit scheduled lock'));toggle_enabled();tap(tr('保存','Save'))
        assert state()['rules'][0]['enabled'];snap('repeat-on','再有効化を保存')
        tap(tr('予定ロックを削除','Delete scheduled lock'));snap('repeat-delete-confirmation','繰り返し削除確認')
        tap(tr('削除','Delete'));assert not state()['rules'];snap('repeat-deleted','繰り返し削除後');end()
    if not args.flows or 'scheduled-list' in args.flows:
        begin('scheduled-list')
        fixture=base(lang);seed(fixture);page();q.scroll();q.scroll()
        snap('scheduledList','単発/繰り返し/無効の予定一覧',tr('ロック予定','Scheduled Locks'),'scheduledList');end()
    if not args.flows or 'active-free-wake' in args.flows:
        begin('active-free-wake')
        now=q.device_clock()[0];active=empty(targets([PROBE]))
        active['rules']=[single('capture-active','Focus',now-60000,now+7200000,True)]
        seed(active);page()
        snap('activeLock','実行中・対象固定',tr('熊は眠っています。','Bear is sleeping.'),'activeLock')
        tap(tr('熊を起こす','Wake the bear'))
        snap('wakeOptions','無料30分の確認',tr('キャンセル','Cancel'),'wakeOptions')
        tap(tr('キャンセル','Cancel'));assert not state()['wakes'];snap('wake-confirm-cancelled','起床確認の取消')
        tap(tr('熊を起こす','Wake the bear'));start=q.device_clock()[0]
        tap(tr('無料で30分後に起こす','Wake in 30 minutes for free'));booked=state();deadline=booked['wakes'][0]['wakesAt']
        assert start+1800000<=deadline<=q.device_clock()[0]+1801000
        snap('wake-booked','無料30分を予約')
        tap(tr('熊を起こす','Wake the bear'));snap('wake-cancel-confirmation','起床予約の取消確認')
        tap(tr('キャンセル','Cancel'));assert state()['wakes']==booked['wakes'];snap('wake-keep-booking','取消確認を閉じ予約維持')
        tap(tr('熊を起こす','Wake the bear'));tap(tr('起床を取り消す','Cancel wake-up'))
        assert not state()['wakes'];snap('wakeCancelled','起床予約を取消した結果')
        # Only the expiry deadline is shortened; actual booking above uses 30 minutes.
        now=q.device_clock()[0];active['rules'][0]['schedule']['end']=now+8000
        seed(active);page();time.sleep(9)
        snap('wakeResult','自然終了後の実際のホーム（iOSの独立結果画面はAndroidにない）',tr('ロック対象を選ぶ','Select targets'),'wakeResult')
        end()
    if not args.flows or 'settings-support-diagnostics-permissions' in args.flows:
        begin('settings-support-diagnostics-permissions')
        fixture=base(lang);fixture['rules']=fixture['rules'][:3];seed(fixture);page('settings')
        snap('settings','設定',tr('設定','Settings'),'settings')
        q.scroll();q.scroll();snap('settings-bottom','設定の下部・診断項目',tr('診断','Diagnostics'))
        page('settings');tap(tr('サポート','Support'))
        snap('support','応援・公式サイト導線',tr('公式サイトを開く','Open website'),'support')
        tap(tr('戻る','Back'));page('settings');tap(tr('診断','Diagnostics'),clickable=True)
        snap('diagnostics','端末内の診断ページ',tr('状態','Status'),'diagnostics')
        tap(tr('診断を共有','Share diagnostics'));snap('diagnostics-share','OS共有シート');q.sh('input','keyevent','4')
        page('settings');tap(tr('権限・動作状態を確認','Permissions and status'))
        snap('permissions','権限・動作状態',tr('ユーザー補助を設定','Set up accessibility'))
        tap(tr('ユーザー補助を設定','Set up accessibility'))
        snap('accessibility-disclosure','ユーザー補助の事前説明',tr('同意しない','Do not agree'))
        tap(tr('同意しない','Do not agree'));snap('disclosure-cancelled','事前説明の取消')
        tap(tr('ユーザー補助を設定','Set up accessibility'));tap(tr('同意して設定へ','Agree and open settings'))
        snap('accessibility-os','OSユーザー補助設定');q.sh('input','keyevent','4')
        snap('permissions-returned','OS設定から戻る',tr('ロックに必要な設定','Required settings'));page('settings');tap(tr('対応する制限','Supported blocking'))
        snap('supported-blocking','対応範囲の説明dialog');tap('OK');end()
    if not args.flows or 'external-return' in args.flows:
        begin('external-return')
        seed(empty(targets([PROBE])));page('settings');tap(tr('診断','Diagnostics'),clickable=True)
        tap(tr('診断を共有','Share diagnostics'));snap('share-os','OS共有シートを開く');q.sh('input','keyevent','4')
        snap('share-return','OS共有から診断へ戻る',tr('診断','Diagnostics'))
        page('settings');tap(tr('サポート','Support'))
        snap('support-before-external','応援の外部起動前',tr('公式サイトを開く','Open website'))
        tap(tr('公式サイトを開く','Open website'))
        snap('support-external','外部ブラウザー入口（選択/初回説明を含み得る）')
        resumed=lambda:[s for s in q.sh('dumpsys','activity','activities').splitlines() if 'mResumedActivity:' in s or 'topResumedActivity=' in s]
        assert not any(q.APP+'/' in s for s in resumed()),'Website intent did not leave the app'
        for _ in range(4):
            q.sh('input','keyevent','4');time.sleep(.5)
            if any(q.APP+'/' in s for s in resumed()):break
        snap('support-external-return','外部ブラウザー入口から戻る',tr('公式サイトを開く','Open website'));end()
    verify_apk()
    proof.setdefault('completedLanguages',[])
    expected={'setup','home','composeNow','composeDelayed','composeDate','composeRepeat','confirmation','scheduledList','activeLock','wakeOptions','wakeResult','scheduledEditor','recurringEditor','settings','support','diagnostics'}
    captured={r['canonical'] for r in proof['frames'] if r['language']==lang and r['canonical']}
    if captured==expected and lang not in proof['completedLanguages']:proof['completedLanguages'].append(lang)
    if args.flows:assert set(args.flows)<={r['name'] for r in proof['flows'] if r['language']==lang}
    else:assert captured==expected
    proof['completeLatestCapture']=set(proof['completedLanguages'])=={'ja','en'}
    store_proof()
    print('PASS: selected capture completed, '+lang+', canonical '+str(len(captured))+'/16',flush=True)
# Leave no active test locks; keep evidence in the output directory.
seed(empty());q.page('home',language='en')
print(json.dumps(dict(apkSha256=APK,completeLatestCapture=proof['completeLatestCapture'],frames=len(proof['frames']),flows=len(proof['flows'])),indent=2))
