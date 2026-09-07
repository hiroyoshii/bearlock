#!/usr/bin/env python3
"""Compare unmodified emulator screenshots with the committed iOS CI fixtures.
Pixel changes describe images, not feature parity or a pass/fail quality score.
"""
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw,ImageFont
import hashlib,json,argparse
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--directory',type=Path,default=ROOT/'docs/qa/android-ui-parity')
OUT=parser.parse_args().directory
RESAMPLE=getattr(Image,'Resampling',Image)
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
