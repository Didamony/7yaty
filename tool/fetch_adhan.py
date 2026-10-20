"""Finds adhan recordings on Wikimedia Commons whose license lets the app
use them (public domain, CC0, CC BY, CC BY-SA), downloads them into
assets/adhan-candidates/ and writes report.json with each one's author,
license and length, to pick from."""
import json
import os
import re
import subprocess
import urllib.parse
import urllib.request

API = 'https://commons.wikimedia.org/w/api.php'
OUT = 'assets/adhan-candidates'
UA = {'User-Agent': 'HayatiApp/1.0 (https://github.com/Didamony/7yaty)'}
FREE = re.compile(r'^(public domain|pd|cc0|cc[- ]by(-sa)?([- ][\d.]+)?)', re.I)


def get(params):
    url = API + '?' + urllib.parse.urlencode({**params, 'format': 'json'})
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
        return json.load(r)


def clean(html):
    return re.sub(r'<[^>]+>', '', html or '').strip()


found = {}
for term in ['adhan', 'azan', 'athan', 'adzan', 'call to prayer', 'أذان', 'اذان']:
    data = get({
        'action': 'query',
        'generator': 'search',
        'gsrsearch': f'{term} filetype:audio',
        'gsrnamespace': 6,
        'gsrlimit': 50,
        'prop': 'videoinfo',
        'viprop': 'url|size|mime|extmetadata|duration',
        'viextmetadatafilter': 'LicenseShortName|Artist|Credit|ImageDescription',
    })
    for page in (data.get('query') or {}).get('pages', {}).values():
        info = (page.get('videoinfo') or [{}])[0]
        meta = info.get('extmetadata') or {}
        lic = clean((meta.get('LicenseShortName') or {}).get('value'))
        if not FREE.match(lic):
            continue
        found[page['title']] = {
            'title': page['title'],
            'url': info.get('url'),
            'page': 'https://commons.wikimedia.org/wiki/'
            + urllib.parse.quote(page['title'].replace(' ', '_')),
            'license': lic,
            'author': clean((meta.get('Artist') or {}).get('value')),
            'credit': clean((meta.get('Credit') or {}).get('value')),
            'description': clean((meta.get('ImageDescription') or {}).get('value'))[:300],
            'mime': info.get('mime'),
            'size': info.get('size'),
            'duration': info.get('duration'),
        }

os.makedirs(OUT, exist_ok=True)
picked = []
for c in sorted(found.values(), key=lambda c: c['title']):
    # A whole adhan runs about 1.5 to 6 minutes.
    d = c.get('duration') or 0
    if not (60 <= d <= 420) or (c.get('size') or 0) > 40_000_000:
        continue
    name = f'c{len(picked):02d}'
    src = os.path.join(OUT, name + '.src')
    req = urllib.request.Request(c['url'], headers=UA)
    with urllib.request.urlopen(req) as r, open(src, 'wb') as f:
        f.write(r.read())
    mp3 = os.path.join(OUT, name + '.mp3')
    subprocess.run(
        ['ffmpeg', '-loglevel', 'error', '-y', '-i', src, '-ac', '1',
         '-ar', '44100', '-b:a', '96k', mp3],
        check=True,
    )
    os.remove(src)
    c['file'] = name + '.mp3'
    picked.append(c)
    if len(picked) >= 15:
        break

with open(os.path.join(OUT, 'report.json'), 'w', encoding='utf-8') as f:
    json.dump({'all_free': list(found.values()), 'downloaded': picked}, f,
              ensure_ascii=False, indent=1)
print(f'{len(found)} free recordings found, {len(picked)} downloaded')
