#!/usr/bin/env python3
"""Refresh the rule sets Lightboat ships for its first connection.

Reads the rule-providers of the panel's Clash template (the main project's
deploy/templates/clash.gotmpl), downloads each list and writes it gzipped to
assets/lightboat/rules/ with a manifest the app seeds from (02 §5).

    python3 tool/lightboat/bundle_rules.py [path/to/clash.gotmpl]
"""
import gzip
import hashlib
import json
import pathlib
import re
import sys
import urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
template = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else root.parent / 'vpn/deploy/templates/clash.gotmpl')
out = root / 'assets/lightboat/rules'

section = template.read_text(encoding='utf-8').split('\nrule-providers:\n', 1)[1]
section = re.split(r'\n(?=\S)', section, maxsplit=1)[0]
providers = re.findall(r'^  ([^\s:][^:]*):\n((?:    .*\n?)+)', section, re.M)

out.mkdir(parents=True, exist_ok=True)
for old in out.glob('*.gz'):
    old.unlink()
manifest = []
for name, body in providers:
    fields = dict(re.findall(r'^    ([\w-]+):\s*(.+?)\s*$', body, re.M))
    url = fields.get('url')
    if fields.get('type') != 'http' or not url:
        continue
    request = urllib.request.Request(url, headers={'User-Agent': 'clash.meta'})
    data = urllib.request.urlopen(request, timeout=60).read()
    file = hashlib.md5(url.encode()).hexdigest() + '.gz'
    (out / file).write_bytes(gzip.compress(data, mtime=0))
    manifest.append({'name': name, 'url': url, 'file': file})
    print(f'{len(data):>9}  {name}')
(out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
total = sum(p.stat().st_size for p in out.glob('*.gz'))
print(f'{len(manifest)} rule sets, {total} bytes gzipped')
