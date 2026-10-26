#!/usr/bin/env python3
"""Helpers for real emulator UI runs. Does not reset application data or end locks."""
import argparse,json,os,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ADB=os.environ.get('ADB','/mnt/c/Users/orien/AppData/Local/Android/Sdk/platform-tools/adb.exe')
ADB_COMMAND=[ADB]+(['-P',os.environ['BEARLOCK_ADB_PORT']] if os.environ.get('BEARLOCK_ADB_PORT') else [])
SERIAL=os.environ.get('ANDROID_SERIAL','emulator-5554')
APP='com.hiyozoo.bearlock'
OUT=Path('artifacts/android-product')
PRESERVE_ACCESSIBILITY=False
def adb(*args,binary=False):
    r=subprocess.run([*ADB_COMMAND,'-s',SERIAL,*map(str,args)],capture_output=True,timeout=45,check=True)
    return r.stdout if binary else r.stdout.decode(errors='replace').strip()
def sh(*args):return adb('shell',*args)
def device_clock():
    """Device wall time and precision in ms; Android 8 date lacks %3N."""
    value=sh('date','+%s%3N')
    return (int(value[:-2])*1000,1000) if value.endswith('3N') else (int(value),1)
def tree():
    if PRESERVE_ACCESSIBILITY:
        result=sh('am','instrument','-w','com.hiyozoo.bearlock.probe/.QAInstrumentation')
        line=next((x for x in result.splitlines() if x.startswith('INSTRUMENTATION_RESULT: tree=')),None)
        if line is None:raise RuntimeError(result)
        return ET.fromstring(line.split('tree=',1)[1])
    sh('uiautomator','dump','/sdcard/bearlock-product.xml')
    return ET.fromstring(sh('cat','/sdcard/bearlock-product.xml'))
def texts():return [(n.get('text'),n.get('content-desc'),n.get('bounds')) for n in tree().iter('node') if n.get('text') or n.get('content-desc')]
def tap(text):
    def visible_point(node,clip=None):
        bounds=list(map(int,re.findall(r'-?\d+',node.get('bounds',''))))
        if len(bounds)==4:
            x,y,z,w=bounds
            clip=(x,y,z,w) if clip is None else (max(x,clip[0]),max(y,clip[1]),min(z,clip[2]),min(w,clip[3]))
            if clip[2]<=clip[0] or clip[3]<=clip[1]:return None
        if clip and clip[3]-clip[1]>=24 and any(node.get(key,'').casefold()==text.casefold() for key in ('text','content-desc')):
            return ((clip[0]+clip[2])//2,(clip[1]+clip[3])//2)
        for child in node:
            point=visible_point(child,clip)
            if point is not None:return point
        return None
    for _ in range(6):
        point=visible_point(tree())
        if point is not None:
            sh('input','tap',*point)
            time.sleep(.5)
            return
        scroll()
    raise AssertionError('Missing visible control: '+text)
def shot(name,xml=True):
    OUT.mkdir(parents=True,exist_ok=True)
    if xml: (OUT/f'{name}.xml').write_text(ET.tostring(tree(),encoding='unicode'))
    time.sleep(.7)
    (OUT/f'{name}.png').write_bytes(adb('exec-out','screencap','-p',binary=True))
def page(name,draft=False,language=None):
    command=['am','start','-W','-f','0x10008000','-n',APP+'/.QAHarnessActivity','--es','page',name,'--ez','draft',str(draft).lower()]
    if language in ('ja','en'): command += ['--es','language',language]
    sh(*command)
    time.sleep(2)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['texts','tap','shot','page']);p.add_argument('value',nargs='?',default='home');a=p.parse_args()
    if a.action=='texts':print(json.dumps(texts(),ensure_ascii=False))
    elif a.action=='tap':tap(a.value)
    elif a.action=='shot':shot(a.value)
    else:page(a.value,True)

def edit(description,value):
    tap(description)
    sh('input','keyevent','123')
    sh('input','keyevent',*(['67']*24))
    sh('input','text',value)
    sh('input','keyevent','4')

def scroll():
    width,height=map(int,re.findall(r'(\d+)x(\d+)',sh('wm','size'))[-1])
    sh('input','swipe',width//2,height*4//5,width//2,height//3,'350')
    time.sleep(.4)
