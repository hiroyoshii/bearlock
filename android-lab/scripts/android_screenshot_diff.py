#!/usr/bin/env python3
"""Compare unmodified emulator screenshots with the committed iOS CI fixtures.
Pixel changes describe images, not feature parity or a pass/fail quality score.
"""
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw,ImageFont
import hashlib,json,argparse,html,shutil
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--directory',type=Path,default=ROOT/'docs/qa/android-ui-parity')
parser.add_argument('--review-manifest',type=Path,help='Build the source-labelled screen/flow review, without recapturing or modifying source images')
args=parser.parse_args()
OUT=args.directory
RESAMPLE=getattr(Image,'Resampling',Image)

def build_review(manifest_path, out):
    manifest=json.loads(manifest_path.read_text())
    metadata=json.loads((ROOT/manifest['iosMetadata']).read_text())
    current=json.loads((ROOT/manifest['androidProof']).read_text())
    capture=json.loads((ROOT/manifest['latestCaptureProof']).read_text())
    assert capture['completeLatestCapture'] and capture['apkSha256']==capture['installedApkSha256']==current['apkSha256']
    sources=manifest['sources']
    out=out.resolve(); (out/'assets').mkdir(parents=True,exist_ok=True)
    (out/'compare').mkdir(exist_ok=True)
    esc=html.escape
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',14)
    images={}
    proofs={manifest['latestCaptureProof']:capture}
    def image_record(relative,status,label,proof=None):
        path=(ROOT/relative).resolve()
        if not path.is_relative_to(ROOT): raise ValueError('Image outside repository: '+relative)
        if not path.is_file(): raise FileNotFoundError(path)
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if digest not in images:
            shutil.copyfile(path,out/'assets'/(digest+'.png'))
            with Image.open(path) as im: size=list(im.size)
            images[digest]={'path':relative,'sha256':digest,'size':size}
        record=dict(images[digest],path=relative,status=status,label=label,url='assets/'+digest+'.png')
        if proof:
            if proof not in proofs:proofs[proof]=json.loads((ROOT/proof).read_text())
            result=proofs[proof]
            record['proof']=proof; record['apkSha256']=result.get('apkSha256')
            record['sdk']=result.get('sdk')
            if 'frames' in result:
                frame=next(r for r in result['frames'] if (ROOT/r['path']).resolve()==path)
                assert frame['sha256']==digest and frame['apkSha256']==record['apkSha256']
                record['captureAction']=frame['action']
                with Image.open(path) as image:
                    rgb=image.convert('RGB');box=ImageChops.difference(rgb,Image.new('RGB',rgb.size,'black')).getbbox()
                    if record['sdk']==26 and box and box[0]>20 and rgb.width-box[2]>20 and box[1]==0 and box[3]==rgb.height:
                        record['analysisCrop']=list(box)
                        record['analysisUrl']='assets/'+digest+'-analysis.png'
                        if not (out/record['analysisUrl']).exists():rgb.crop(box).save(out/record['analysisUrl'])
        return record
    def reference(ref):
        if not ref: return None
        family,name=ref.split('/',1); source=sources[family]
        return image_record(source['root']+'/'+name,source['status'],source['label'],source.get('proof'))
    def comparison(a,b,key):
        if not a or not b: return None
        left=Image.open(out/a['url']).convert('RGB');right=Image.open(out/b['url']).convert('RGB')
        if left.size!=right.size: raise ValueError('Before/after raster mismatch: '+key)
        w=max(left.width,right.width);h=max(left.height,right.height)
        def pad(im):
            canvas=Image.new('RGB',(w,h),'white');canvas.paste(im,(0,0));return canvas
        left,right=pad(left),pad(right)
        channels=ImageChops.difference(left,right).split()
        maximum=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2])
        mask=maximum.point(lambda value:255 if value>24 else 0)
        heat=Image.new('RGB',(w,h),'#f2faff');heat.paste('#df3150',mask=mask)
        preview_h=round(h*320/w)
        pair=Image.new('RGB',(992,preview_h+42),'white');draw=ImageDraw.Draw(pair)
        for x,im,title in [(0,left,'Before'),(336,right,'After (current APK)'),(672,heat,'RGB difference > 24 (not a score)')]:
            draw.text((x+4,10),title,font=font,fill='#142e4f')
            pair.paste(im.resize((320,preview_h),RESAMPLE.LANCZOS if im is not heat else RESAMPLE.NEAREST),(x,42))
        url='compare/'+key+'.png';pair.save(out/url)
        return {'url':url,'method':'raw equal-size RGB >24; Android historical before/after only', 'qualityScore':False}
    def component_image(im, region, key):
        # Coordinates are in a width-320 view, after the declared outer-black crop.
        source=Image.open(out/im['url']).convert('RGB')
        outer=im.get('analysisCrop',[0,0,source.width,source.height])
        factor=(outer[2]-outer[0])/320
        box=[round(outer[0]+region[0]*factor),round(outer[1]+region[1]*factor),
             round(outer[0]+region[2]*factor),round(outer[1]+region[3]*factor)]
        if not (0<=box[0]<box[2]<=source.width and 0<=box[1]<box[3]<=source.height):
            raise ValueError('Invalid component region: '+key)
        url='compare/'+key+'-region.png'
        source.crop(box).save(out/url)
        return dict(im,analysisUrl=url,componentCrop=box,componentCoordinates320=region)
    rows=[]
    for screen in manifest['screens']+manifest['checkpoints']:
        locales=['ja','en'] if screen.get('iosScreen') else ['ja' if screen.get('android',{}).get('ja') or screen.get('ios') or not screen.get('android') else 'en']
        for locale in locales:
            ios=None
            if screen.get('iosScreen'):
                name='ci-screenshots/app-store-'+locale+'/'+screen['iosScreen']+'.png'
                if name not in metadata['files']: raise ValueError('iOS image missing in published metadata: '+name)
                ios=image_record(name,'ios-fixture','iOS公開fixture / '+metadata['source_commit'][:7]+(' / '+manifest['iosReferenceNote'] if manifest.get('iosReferenceNote') else ''))
            elif screen.get('ios'):ios=reference(screen['ios'])
            android=reference(screen.get('android',{}).get(locale))
            row=dict(id=screen['id']+'-'+locale,screen=screen['id'],title=screen['title'],group=screen['group'],locale=locale,note=screen['note'],ios=ios,android=android,canonical=bool(screen.get('iosScreen')))
            row['review']=screen.get('review')
            row['comparison']=None  # Uncontrolled cross-OS states cannot support a pixel diff.
            if row['review'] and row['review']['kind']=='component':
                regions=row['review']['regions'][locale]
                row['componentImages']={side:component_image(im,regions[side],row['id']+'-'+side)
                                        for side,im in [('ios',ios),('android',android)]}
            rows.append(row)
    changes=[]
    history=manifest['beforeAfter']
    for name in history['images']:
        before=reference(history['beforeSource']+'/'+name);after=reference(history['afterSource']+'/'+name)
        key='change-'+name.removesuffix('.png').replace('/','-')
        changes.append(dict(id=key,title=name,before=before,after=after,comparison=comparison(before,after,key)))
    counts={
        'publishedIosScreens':len(manifest['screens']),
        'publishedIosImages':sum(r['canonical'] for r in rows),
        'canonicalCurrentAndroidImages':sum(r['canonical'] and bool(r['android']) and r['android']['status']=='current' for r in rows),
        'canonicalHistoricalAndroidImages':sum(r['canonical'] and bool(r['android']) and r['android']['status']=='historical' for r in rows),
        'canonicalMissingAndroidImages':sum(r['canonical'] and not r['android'] for r in rows),
        'checkpoints':len(manifest['checkpoints']), 'flows':len(capture['flows']), 'beforeAfterPairs':len(changes)
    }
    complete=bool(capture) and counts['canonicalCurrentAndroidImages']==32 and counts['canonicalHistoricalAndroidImages']==counts['canonicalMissingAndroidImages']==0
    units={kind:sum(s['review']['kind']==kind for s in manifest['screens']) for kind in ['screen','component','semantic','unpaired']}
    record=dict(date=manifest.get('reviewDate',manifest['date']),method=manifest.get('reviewMethod'),reviewUnits=units,completeLatestCapture=complete,iosMetadata=metadata,currentAndroidProof=current,latestCapture=capture,counts=counts,rows=rows,changes=changes,flows=capture['flows'],manifestSha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest())
    (out/'review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
    def figure(im,title):
        if not im:return '<figure class="missing"><h4>'+esc(title)+'</h4><p>対応する画像なし／未撮影</p></figure>'
        size=' × '.join(map(str,im['size']))
        crop_note='表示用画像のみOS画面外の黒帯を除外。クリックで無加工原寸。<br>' if im.get('analysisCrop') else ''
        if im.get('componentCrop'):crop_note='部品切り出し（元画像座標 '+esc(str(im['componentCrop']))+'）。クリックで無加工の全画面。<br>'
        return '<figure><h4>'+esc(title)+'</h4><p class="badge '+esc(im['status'])+'">'+esc(im['label'])+'</p><a href="'+im['url']+'" target="_blank" rel="noopener"><img loading="lazy" src="'+im.get('analysisUrl',im['url'])+'" alt="'+esc(title)+'"></a><figcaption>'+crop_note+size+(' / API '+str(im['sdk']) if im.get('sdk') else '')+'<br>'+esc(im['path'])+'<br>SHA256 '+im['sha256'][:16]+(' / APK '+im['apkSha256'][:12] if im.get('apkSha256') else '')+'</figcaption></figure>'
    cards=[]
    kind_labels={'screen':'画面単位（条件差あり）','component':'部品単位','semantic':'目的・機能単位（視覚比較不可）','unpaired':'対応ペアなし'}
    for row in rows:
        status=row['android']['status'] if row['android'] else 'missing'
        review=row['review']
        if review:
            finding='<p class="badge">'+esc(kind_labels[review['kind']])+'</p><p><strong>比較条件：</strong>'+esc(review['conditions'])+'</p><p><strong>確認できる差：</strong>'+esc(review['finding'])+'</p><p><strong>判断・除外：</strong>'+esc(review['judgment'])+'</p>'
            if review['kind']=='unpaired':
                evidence=figure(row['ios'],'iOS：蜂蜜による即時起床結果（対になるAndroid画像なし）')+'<p>Androidの自然終了ホームは別操作です。下の実操作フローでのみ表示します。</p>'
            else:
                shown=row.get('componentImages',{'ios':row['ios'],'android':row['android']})
                evidence='<div class="pair">'+figure(shown['ios'],'iOS'+('：対象部品' if review['kind']=='component' else ''))+figure(shown['android'],'Android'+('：対象部品' if review['kind']=='component' else ''))+'</div>'
                if review['kind']=='component':evidence+='<details><summary>切り出し元の全画面（配置の差の判定には使用しない）</summary><div class="pair">'+figure(row['ios'],'iOS撮影fixture全体')+figure(row['android'],'Android実ホーム全体')+'</div></details>'
        else:
            finding='<p>'+esc(row['note'])+'</p>'
            evidence=figure(row['android'],'Androidのみ：操作チェックポイント')
        cards.append('<article id="'+row['id']+'" data-locale="'+row['locale']+'" data-status="'+status+'"><h3>'+esc(row['title'])+' <small>'+row['locale'].upper()+'</small></h3>'+finding+evidence+'</article>')
    flow_html=[]
    captured_frames={frame['id']:frame for frame in capture['frames']}
    actual_flows=[]
    for flow in capture['flows']:
        steps=[];step_records=[]
        for id in flow['steps']:
            frame=captured_frames[id]
            relative=str(Path(frame['path']).relative_to(sources['full']['root']))
            android=reference('full/'+relative)
            ios=None  # Android-only flow: no corresponding iOS interaction capture exists.
            step_records.append(dict(frame=frame,ios=ios,android=android))
            steps.append('<li><p><strong>'+esc(frame['action'])+'</strong></p>'+figure(android,'Android実操作の証跡（iOS遷移比較なし）')+'</li>')
        actual_flows.append(dict(name=flow['name'],language=flow['language'],steps=step_records))
        flow_html.append('<details data-flow-locale="'+flow['language']+'"><summary>'+esc(flow['name'])+' / '+flow['language'].upper()+' / '+str(len(steps))+'枚</summary><ol>'+''.join(steps)+'</ol></details>')
    record['actualFlows']=actual_flows
    counts['actualCapturedFrames']=len(capture['frames'])
    (out/'review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
    change_html=[]
    for change in changes:
        change_html.append('<details><summary>'+esc(change['title'])+' — Before / 今回のAPK / diff</summary><a href="'+change['comparison']['url']+'" target="_blank"><img class="comparison" loading="lazy" src="'+change['comparison']['url']+'" alt="Android修正前後と差分"></a><p>同一ラスタ、閾値24。別セッションの日時・対象・予定状態の差を含みます。合否判定ではありません。</p>'+figure(change['after'],'今回のAPKの元画像')+'</details>')
    summary='<section class="notice"><h2>不要な差分をiOSへ統一 — '+esc(manifest.get('reviewDate',manifest['date']))+'</h2><p>iOS: '+esc(metadata['source_commit'][:7])+' / run '+str(metadata['run_id'])+'。Android: '+esc(current['apkSha256'][:12])+' / API26・428×926dp・文字100%。iOSは公開撮影fixture、Androidは実画面をQA状態と操作で撮影したものです。</p><p>UNITS。日英32画像を取得したことを、同条件の全画面比較完了とは呼びません。値・対象・日時・撮影ホストの違いは各項目で除外します。OS間RGB差分は撤去しました。</p><p>部品は明示座標で切り出し、同じ横幅で並べます。縦方向の引き伸ばし・内容の再配置はせず、部品の高さの違いを保持します。各画像から無加工の全画面を開けます。API26の画面外の黒帯と部品範囲の座標はJSONに記録しています。</p><p>起床結果は別操作のためペア解除。Androidの操作フローはAndroid単独の証跡です。iOSの同じ操作の連写がないため、遷移比較は未実施。Before/Afterは同じAPI26での旧APKと今回の修正後です。</p>COUNTS</section>'
    matrix='<section><h2>比較項目・判定</h2><div class="table-scroll"><table><thead><tr><th scope="col">対象</th><th scope="col">粒度</th><th scope="col">差分・判断</th><th scope="col">画像</th></tr></thead><tbody>'
    for screen in manifest['screens']:
        review=screen['review']
        matrix+='<tr><th scope="row">'+esc(screen['title'])+'</th><td>'+esc(kind_labels[review['kind']])+'</td><td>'+esc(review['finding'])+'<br><small>'+esc(review['judgment'])+'</small></td><td>'+ ' / '.join('<a href="#'+screen['id']+'-'+lang+'">'+lang.upper()+'</a>' for lang in ['ja','en'])+'</td></tr>'
    matrix+='</tbody></table></div></section>'
    page='''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bear Lock 正しい粒度でのUI比較</title>
<style>body{margin:0;background:#f2faff;color:#142e4f;font:16px/1.65 system-ui,sans-serif}main{max-width:1180px;margin:auto;padding:24px}h1{font-size:28px;line-height:1.35}h2{margin-top:40px}h3{margin-top:0}a{color:#225d97}a:focus-visible,summary:focus-visible,select:focus-visible{outline:3px solid #225d97;outline-offset:3px}nav{display:flex;gap:16px;flex-wrap:wrap}.notice,article,details{background:white;padding:20px;border:1px solid #d6e0e9;border-radius:8px;margin:16px 0}.notice{border-left:5px solid #a64e12}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0;min-width:0;max-width:560px}figure img{display:block;width:100%;height:auto}h4{margin:8px 0}.badge{font-size:14px;padding:4px 8px;background:#e9eef4}.current{background:#dff2e8;color:#145e39}.historical{background:#fff0d5;color:#764300}.missing{background:#f7f0ed;padding:16px;box-sizing:border-box}figcaption{font-size:12px;overflow-wrap:anywhere}.comparison{width:100%;height:auto}summary{cursor:pointer;font-weight:600;min-height:44px}select{font:inherit;min-height:44px;max-width:100%;margin-right:12px}li{margin:24px 0}small{font-weight:400}footer{padding:24px 0}article[hidden]{display:none}.table-scroll{overflow-x:auto}table{border-collapse:collapse;width:100%;background:white}td,th{text-align:left;vertical-align:top;border-bottom:1px solid #d6e0e9;padding:10px}td:last-child{min-width:75px}td a{display:inline-block;min-height:44px}th:first-child{min-width:90px}@media(max-width:620px){main{padding:12px}.pair{grid-template-columns:1fr}h1{font-size:23px}}@media print{select,nav{display:none}}</style>
<main><h1>Bear Lock：比較単位を揃えたUIレビュー</h1><nav><a href="#screens">画面・部品・機能比較</a><a href="#flows">Android操作の証跡</a><a href="#changes">今回のBefore/After</a><a href="review.json">出典・判定・切り出し座標</a></nav>SUMMARY MATRIX
<h2 id="screens">項目別の比較画像</h2><label>言語 <select id="locale"><option value="ja">日本語</option><option value="en">English</option><option value="all">すべて</option></select></label><label>Android出典 <select id="status"><option value="all">すべて</option><option value="current">最新APKのみ</option><option value="historical">過去参考のみ</option><option value="missing">未撮影のみ</option></select></label>CARDS
<h2 id="flows">Android操作の証跡 — iOSとの遷移比較ではありません</h2><p>同じAPKの順序付き撮影。初期fixture投入・QAルート起動を含み、連続録画ではありません。30分実時間・全異常系・実機/OEMの検証は含みません。</p>FLOWS
<h2 id="changes">今回のAndroid Before/After</h2><p>左はBEFORELABEL、中央は今回のAPK、右はRGB差分。両方API26です。状態・日時の違いも含むため、合否判定にはしません。</p>CHANGES
<footer>正本：docs/qa/screenshot-review-2026-10-17.json。原画像は無加工、撮影日CAPTUREDATE。今回の製品UI修正を同一APKで検証・撮影。詳細は撮影証跡と各項目の比較条件を参照。</footer></main>
<script>const locale=document.getElementById('locale'),status=document.getElementById('status');function filter(){for(const card of document.querySelectorAll('article[data-locale]'))card.hidden=(locale.value!=='all'&&locale.value!==card.dataset.locale)||(status.value!=='all'&&status.value!==card.dataset.status);for(const flow of document.querySelectorAll('[data-flow-locale]'))flow.hidden=locale.value!=='all'&&flow.dataset.flowLocale!==locale.value}document.addEventListener('click',event=>{const link=event.target.closest('a[href^="#"]');if(!link)return;const target=document.getElementById(link.hash.slice(1));if(target&&target.dataset.locale){locale.value=target.dataset.locale;status.value='all';filter();}});locale.addEventListener('change',filter);status.addEventListener('change',filter);filter();</script></html>'''
    unit_text='画面'+str(units['screen'])+'項目・部品'+str(units['component'])+'項目・目的/機能'+str(units['semantic'])+'項目・対応ペアなし'+str(units['unpaired'])+'項目'
    if manifest.get('iosReferenceNote'):
        summary=summary.replace('</h2>','</h2><p>'+esc(manifest['iosReferenceNote'])+'</p>',1)
    summary=summary.replace('UNITS',unit_text)
    page=page.replace('SUMMARY',summary).replace('MATRIX',matrix).replace('CAPTUREDATE',esc(manifest['date']))
    page=page.replace('BEFORELABEL',esc(sources[manifest['beforeAfter']['beforeSource']]['label']))
    labels={'publishedIosScreens':'レビュー対象項目','publishedIosImages':'iOS日英画像','canonicalCurrentAndroidImages':'Android日英撮影状態','canonicalHistoricalAndroidImages':'旧APK参考','canonicalMissingAndroidImages':'未撮影','checkpoints':'追加チェックポイント','flows':'Android手順実行数','beforeAfterPairs':'履歴Before/After','actualCapturedFrames':'Android撮影枚数'}
    count_text='<p>'+esc(' / '.join(f'{labels[key]}: {value}' for key,value in counts.items()))+'</p>'
    page=page.replace('COUNTS',count_text).replace('CARDS',''.join(cards)).replace('FLOWS',''.join(flow_html)).replace('CHANGES',''.join(change_html))
    (out/'index.html').write_text(page)
    print(json.dumps({'directory':str(out),'counts':counts,'completeLatestCapture':complete},ensure_ascii=False,indent=2))

if args.review_manifest:
    build_review(args.review_manifest,OUT)
    raise SystemExit(0)
SCREENS=['home','setup','composeRepeat','activeLock','confirmation']
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
records=[]
for lang in ['ja','en']:
    for screen in SCREENS:
        ios=OUT/'ios'/lang/(screen+'.png');android=OUT/'android'/lang/(screen+'.png')
        a=Image.open(ios).convert('RGB');b=Image.open(android).convert('RGB')
        assert a.size==b.size==(1284,2778),(a.size,b.size)
        pair=Image.new('RGB',(868,974),'white');d=ImageDraw.Draw(pair)
        d.text((12,12),'iOS CI fixture',fill='#142e4f',font=font)
        d.text((452,12),'Android emulator fixture',fill='#142e4f',font=font)
        pair.paste(a.resize((428,926),RESAMPLE.LANCZOS),(0,48))
        pair.paste(b.resize((428,926),RESAMPLE.LANCZOS),(440,48))
        directory=OUT/'compare'/lang;directory.mkdir(parents=True,exist_ok=True)
        pair.save(directory/(screen+'.png'))
        diff=ImageChops.difference(a,b)
        channels=diff.split();maximum=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2])
        mask=maximum.point(lambda v:255 if v>24 else 0)
        changed=mask.histogram()[255]/(a.width*a.height)
        heat=Image.new('RGB',a.size,'#f2faff');heat.paste('#df3150',mask=mask)
        heat.resize((428,926),RESAMPLE.NEAREST).save(directory/(screen+'-diff.png'))
        records.append({'screen':screen,'language':lang,'changedPixelFractionAtMaxChannel24':round(changed,6),
                        'iosSha256':hashlib.sha256(ios.read_bytes()).hexdigest(),'androidSha256':hashlib.sha256(android.read_bytes()).hexdigest()})
(OUT/'pixel-diff.json').write_text(json.dumps({'method':'Raw full-frame RGB max-channel absolute difference > 24; identical 1284x2778 rasters; no alignment, masking or content replacement. Includes OS bars, fonts, dates and fixture data. Not a quality score.', 'screens':records},indent=2))
print(json.dumps(records,indent=2))
