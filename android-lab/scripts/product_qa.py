#!/usr/bin/env python3
"""Helpers for real emulator UI runs. Does not reset application data or end locks."""
import argparse,json,os,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path
ADB=os.environ.get('ADB','/mnt/c/Users/orien/AppData/Local/Android/Sdk/platform-tools/adb.exe')
SERIAL=os.environ.get('ANDROID_SERIAL','emulator-5554')
APP='com.hiyozoo.bearlock'
OUT=Path('artifacts/android-product')
PRESERVE_ACCESSIBILITY=False
def adb(*args,binary=False):
    r=subprocess.run([ADB,'-s',SERIAL,*map(str,args)],capture_output=True,timeout=45,check=True)
    return r.stdout if binary else r.stdout.decode(errors='replace').strip()
def sh(*args):return adb('shell',*args)
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
    nodes=list(tree().iter('node'))
    n=next(n for n in nodes if n.get('text')==text or n.get('content-desc')==text)
    x,y,z,w=map(int,re.findall(r'\d+',n.get('bounds')))
    sh('input','tap',(x+z)//2,(y+w)//2)
    time.sleep(.5)
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
    sh('input','swipe','550','1900','550','700','350')
    time.sleep(.4)
