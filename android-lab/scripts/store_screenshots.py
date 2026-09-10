#!/usr/bin/env python3
"""Capture unmodified Android UI fixtures for Play; requires a disposable emulator."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import time
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=Path('ci-screenshots/android-store'))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
app = 'com.hiyozoo.bearlock'
adb = os.environ.get('ADB', 'adb')

def call(*parts):
    return subprocess.check_output([adb, *parts], timeout=60)

call('shell', 'wm', 'size', '1080x1920')
call('shell', 'wm', 'density', '400')
call('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
call('shell', 'input', 'keyevent', '82')
records = []
screens = ['home', 'setup', 'composeRepeat', 'composeDelayed', 'activeLock', 'confirmation']
try:
    for lang in ['ja', 'en']:
        directory = args.output / lang
        directory.mkdir(exist_ok=True)
        for index, screen in enumerate(screens, 1):
            call('shell', 'am', 'force-stop', app)
            result = call('shell', 'am', 'start', '-W', '-n', app + '/.ScreenshotActivity',
                          '--es', 'screen', screen, '--es', 'language', lang).decode()
            assert 'Error' not in result, result
            time.sleep(3)
            call('shell', 'uiautomator', 'dump', '/sdcard/store-window.xml')
            hierarchy = call('shell', 'cat', '/sdcard/store-window.xml').decode()
            assert f'package="{app}"' in hierarchy, hierarchy
            expected = {'home': ('選択済み対象', 'Selected targets'),
                        'setup': ('ロックのアクセスを許可', 'Allow lock access'),
                        'composeRepeat': ('繰り返し', 'Repeat'),
                        'composeDelayed': ('あとで開始', 'Start later'),
                        'activeLock': ('熊は眠っています', 'Bear is sleeping'),
                        'confirmation': ('ロックを予約', 'Schedule lock')}[screen][lang == 'en']
            assert expected in hierarchy, (lang, screen, hierarchy)
            raw = call('exec-out', 'screencap', '-p')
            picture = Image.open(io.BytesIO(raw))
            assert picture.size == (1080, 1920), picture.size
            path = directory / f'{index:02d}-{screen}.png'
            # Strip alpha only. Never resize, crop, or replace the captured UI.
            picture.convert('RGB').save(path)
            assert path.stat().st_size < 8 * 1024 * 1024
            records.append({'path': str(path.relative_to(args.output)),
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
            print(f'Captured {lang}/{screen}', flush=True)
finally:
    call('shell', 'wm', 'size', 'reset')
    call('shell', 'wm', 'density', 'reset')

(args.output / 'capture.json').write_text(json.dumps({
    'commit': os.environ.get('GITHUB_SHA', 'local'),
    'run': os.environ.get('GITHUB_RUN_ID', 'local'),
    'size': [1080, 1920], 'density': 400,
    'source': 'Debug ScreenshotActivity using production UI components and sample data. '
              'Visual fixtures, not proof of blocking or purchase behavior.',
    'images': records,
}, indent=2) + '\n')
(args.output / 'README.md').write_text(
    '# Android Play Store screenshots\n\n'
    '1080×1920 PNG, Japanese and English. Download the Android Store Assets workflow artifact '
    'for all images. These are production UI components rendered with sample data; '
    'they do not demonstrate real blocking or purchase transactions.\n\n' +
    '\n'.join(f'## {lang}\n\n' + '\n\n'.join(
        f'![{screen}]({lang}/{i:02d}-{screen}.png)' for i, screen in enumerate(screens, 1)
    ) for lang in ['ja', 'en']) + '\n')
