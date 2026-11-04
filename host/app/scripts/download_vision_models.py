#!/usr/bin/env python3
"""Fetch official pretrained weights; do not claim untrained tool classes."""
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parents[1]
models = root/'models'
models.mkdir(exist_ok=True)
sources = {
    'yolo11n.pt': 'https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt',
    'hand_landmarker.task': 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task',
}
manifest = {}
for filename, url in sources.items():
    dest = models/filename
    if not dest.exists():
        temporary = dest.with_suffix(dest.suffix+'.download')
        download_urls = [url]
        if filename == 'yolo11n.pt':
            download_urls.append('https://hf-mirror.com/Ultralytics/YOLO11/resolve/main/yolo11n.pt')
        for candidate in download_urls:
            try:
                with urllib.request.urlopen(candidate, timeout=30) as response, temporary.open('wb') as output:
                    import shutil
                    shutil.copyfileobj(response, output)
                if filename == 'yolo11n.pt':
                    expected = '0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1'
                    if hashlib.sha256(temporary.read_bytes()).hexdigest() != expected:
                        raise ValueError('YOLO weights differ from the locally validated version')
                    (root/'runtime').mkdir(exist_ok=True)
                    (root/'runtime/yolo-model-source.json').write_text(json.dumps({'url':candidate}))
                break
            except Exception:
                temporary.unlink(missing_ok=True)
                if candidate == download_urls[-1]:
                    raise
        temporary.rename(dest)
    actual_source = url
    if filename == 'yolo11n.pt' and (root/'runtime/yolo-model-source.json').exists():
        actual_source = json.loads((root/'runtime/yolo-model-source.json').read_text())['url']
    manifest[filename] = {'official_source':url, 'download_source':actual_source,
                          'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(), 'bytes':dest.stat().st_size}
(models/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
