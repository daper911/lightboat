#!/usr/bin/env python3
"""Upload installers to the R2 bucket behind cdn.cnbetx.com and update latest.json.

    python3 tool/lightboat/publish_r2.py --notes "· ..." \
        [--android dist/Lightboat-X-android-arm64-v8a.apk] \
        [--windows path/to/Lightboat-X-windows-amd64-setup.exe] [--min-build N]

Version and build come from pubspec.yaml. Credentials are read from key.env
(R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY), which git must never
track. A platform left out keeps its previous entry. Needs boto3.
"""
import argparse
import datetime
import hashlib
import json
import pathlib
import re

import boto3
from botocore.config import Config

BUCKET = 'qzvpn'
PREFIX = 'lightboat'
CDN = 'https://cdn.cnbetx.com'

root = pathlib.Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--android')
parser.add_argument('--windows')
parser.add_argument('--notes', required=True)
parser.add_argument('--min-build', type=int)
parser.add_argument('--version', help='X.Y.Z+N of the installers; defaults to pubspec.yaml')
parser.add_argument('--env', default=str(root / 'key.env'))
args = parser.parse_args()

env = dict(
    line.strip().split('=', 1)
    for line in pathlib.Path(args.env).read_text().splitlines()
    if re.match(r'^R2_\w+=', line)
)
source = args.version or re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.M)[1]
version, build = re.fullmatch(r'([\d.]+)\+(\d+)', source).groups()
s3 = boto3.client(
    's3',
    endpoint_url=f"https://{env['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
    aws_access_key_id=env['R2_ACCESS_KEY_ID'],
    aws_secret_access_key=env['R2_SECRET_ACCESS_KEY'],
    region_name='auto',
    config=Config(signature_version='s3v4'),
)

try:
    latest = json.loads(s3.get_object(Bucket=BUCKET, Key=f'{PREFIX}/latest.json')['Body'].read())
except s3.exceptions.NoSuchKey:
    latest = {}


MIME = {'android': 'application/vnd.android.package-archive'}


def upload(path, platform, file_key, name):
    data = pathlib.Path(path).read_bytes()
    key = f'{PREFIX}/{platform}/{name}'
    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=data,
        ContentType=MIME.get(platform, 'application/octet-stream'),
        ContentDisposition=f'attachment; filename="{name}"',
    )
    entry = latest.setdefault(platform, {})
    entry.update(version=version, build=int(build))
    entry[file_key] = {
        'url': f'{CDN}/{key}',
        'sha256': hashlib.sha256(data).hexdigest(),
    }
    print(f'uploaded {CDN}/{key}')


if args.android:
    upload(args.android, 'android', 'arm64-v8a', f'Lightboat-{version}-android-arm64-v8a.apk')
if args.windows:
    upload(args.windows, 'windows', 'amd64-setup', f'Lightboat-{version}-windows-amd64-setup.exe')
# Apps up to 0.4.0 read only the top-level version, so it names the oldest
# platform entry: a trailing installer delays an update instead of looping one.
oldest = min(
    (latest[p] for p in ('android', 'windows') if 'build' in latest.get(p, {})),
    key=lambda entry: entry['build'],
    default={'version': version, 'build': int(build)},
)
latest.update(
    version=oldest['version'],
    build=oldest['build'],
    min_build=args.min_build if args.min_build is not None else latest.get('min_build', 1),
    published_at=datetime.date.today().isoformat(),
    notes=args.notes,
)
s3.put_object(
    Bucket=BUCKET,
    Key=f'{PREFIX}/latest.json',
    Body=json.dumps(latest, ensure_ascii=False, indent=1).encode(),
    ContentType='application/json',
    CacheControl='no-cache',
)
print(json.dumps(latest, ensure_ascii=False, indent=1))
