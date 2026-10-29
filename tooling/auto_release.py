"""Fixed signing and release synchronization. Credentials never enter source or logs."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

REPO = 'xiziyuse-cmd/LifeAtlas'
ORIGIN = 'https://lifeatlas-updates.xiziyuse.workers.dev'
AUDIENCE = 'https://lifeatlas-ai-console.xiziyuse.chatgpt.site/updates-ci'

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

HTTP = urllib.request.build_opener(NoRedirect)

def mask(value):
    print('::add-mask::' + value, flush=True)

def oidc():
    url = os.environ['ACTIONS_ID_TOKEN_REQUEST_URL']
    url += ('&' if '?' in url else '?') + urllib.parse.urlencode({'audience': AUDIENCE})
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN']})
    with HTTP.open(request, timeout=30) as response:
        token = json.load(response)['value']
    mask(token)
    return token

def ci(operation, body=None, *, upload=None, upload_id=None, part=None):
    query = {'operation': operation}
    if upload_id:
        query['id'] = upload_id
    if part is not None:
        query['part'] = str(part)
    payload = upload if upload is not None else json.dumps(body or {}).encode()
    for attempt in range(3):
        request = urllib.request.Request(ORIGIN + '/v1/update/ci?' + urllib.parse.urlencode(query), data=payload,
            headers={'Authorization': 'Bearer ' + oidc(), 'Content-Type': 'application/octet-stream' if upload is not None else 'application/json'}, method='POST')
        try:
            with HTTP.open(request, timeout=90) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            error.close()
            if error.code not in (409, 429, 500, 502, 503, 504) or attempt == 2:
                raise RuntimeError(f'Update service refused operation {operation} (HTTP {error.code})') from None
        except (TimeoutError, urllib.error.URLError):
            if attempt == 2:
                raise RuntimeError('Update service connection failed') from None
        time.sleep(2)
    raise RuntimeError('Update service request failed')

def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()

def read_version(text):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', text, re.M)
    if not match:
        raise RuntimeError('Invalid app version')
    return match[1], int(match[2])

def parse_badging(text):
    package = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", text)
    sdk = re.search(r"sdkVersion:'(\d+)'", text)
    if not package or not sdk or package[1] != 'com.example.lifeatlas':
        raise RuntimeError('APK identity is invalid')
    return {'packageName': package[1], 'build': int(package[2]), 'version': package[3], 'minSdk': int(sdk[1])}

def build_tool(name):
    root = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT']) / 'build-tools'
    paths = [p / name for p in root.iterdir() if (p / name).is_file()]
    if not paths:
        raise RuntimeError('Missing Android build tool: ' + name)
    return str(max(paths, key=lambda p: tuple(int(x) for x in re.findall(r'\d+', p.parent.name))))

def prepare_signing():
    data = ci('signing')
    password = data['password']
    encoded = data['keystoreBase64']
    mask(password)
    mask(encoded)
    if data['alias'] != 'lifeatlas-release' or not re.fullmatch(r'[a-f0-9]{64}', data['certificateSha256']):
        raise RuntimeError('Signing configuration is invalid')
    path = Path(os.environ['RUNNER_TEMP']) / 'lifeatlas-release.p12'
    path.write_bytes(base64.b64decode(encoded, validate=True))
    path.chmod(0o600)
    env = {**os.environ, 'LIFEATLAS_SIGNING_INPUT_PASSWORD': password}
    result = subprocess.run(['keytool', '-list', '-rfc', '-keystore', str(path), '-alias', data['alias'], '-storepass:env', 'LIFEATLAS_SIGNING_INPUT_PASSWORD'], env=env, capture_output=True, text=True, check=True)
    cert = re.search(r'-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----', result.stdout, re.S)
    actual = hashlib.sha256(base64.b64decode(re.sub(r'\s+', '', cert[1]))).hexdigest() if cert else ''
    if actual != data['certificateSha256']:
        raise RuntimeError('Stored signing certificate does not match')
    values = {'LIFEATLAS_RELEASE_STORE_FILE': str(path), 'LIFEATLAS_RELEASE_STORE_PASSWORD': password,
        'LIFEATLAS_RELEASE_KEY_PASSWORD': password, 'LIFEATLAS_RELEASE_KEY_ALIAS': data['alias'],
        'LIFEATLAS_RELEASE_CERT_SHA256': actual}
    with open(os.environ['GITHUB_ENV'], 'a') as output:
        for key, value in values.items():
            if '\n' in value or '\r' in value:
                raise RuntimeError('Invalid signing value')
            output.write(key + '=' + value + '\n')
    print('Fixed release certificate loaded: ' + actual)

def gh(*args):
    return subprocess.run(['gh', *args], capture_output=True, text=True)

def publish():
    version, build = read_version(Path('pubspec.yaml').read_text())
    apk = Path('build/app/outputs/flutter-apk/app-release.apk')
    info = parse_badging(subprocess.check_output([build_tool('aapt'), 'dump', 'badging', str(apk)], text=True))
    if info['version'] != version or info['build'] != build:
        raise RuntimeError('APK does not match the release version')
    verification = subprocess.run([build_tool('apksigner'), 'verify', '--print-certs', str(apk)], capture_output=True, text=True, check=True)
    certificates = re.findall(r'certificate SHA-256 digest:\s*([a-f0-9]{64})', verification.stdout)
    if certificates != [os.environ['LIFEATLAS_RELEASE_CERT_SHA256']]:
        raise RuntimeError('APK was not signed with the fixed certificate')
    meta = {**info, 'size': apk.stat().st_size, 'sha256': sha256(apk), 'certificateSha256': certificates[0],
        'notes': Path('UPDATE_RELEASE_NOTES.md').read_text().strip()}
    Path('update-metadata.json').write_text(json.dumps(meta, ensure_ascii=False, indent=2))
    tag = 'v' + version
    name = 'LifeAtlas-' + version + '.apk'
    current = gh('api', f'repos/{REPO}/releases/tags/{tag}')
    if current.returncode == 0:
        asset = next((x for x in json.loads(current.stdout).get('assets', []) if x['name'] == name), None)
        if not asset or asset.get('digest') != 'sha256:' + meta['sha256']:
            raise RuntimeError('This version already exists with different bytes; increase the app version')
    else:
        if '404' not in current.stderr:
            raise RuntimeError('Cannot verify GitHub release state')
        with tempfile.TemporaryDirectory(prefix='lifeatlas-publish-') as directory:
            target = Path(directory) / name
            # File copy avoids exposing any signing material to the release assets.
            import shutil
            shutil.copyfile(apk, target)
            checksum = Path(directory) / (name + '.sha256')
            checksum.write_text(meta['sha256'] + '  ' + name + '\n')
            created = gh('release', 'create', tag, str(target), str(checksum), 'update-metadata.json', '--target', os.environ['GITHUB_SHA'], '--title', 'LifeAtlas ' + tag, '--notes-file', 'UPDATE_RELEASE_NOTES.md', '--latest')
            if created.returncode:
                raise RuntimeError('GitHub release publication failed')
    with HTTP.open(ORIGIN + '/v1/update/latest', timeout=30) as response:
        active = json.load(response).get('release')
    if active and active['build'] >= build:
        if active['build'] == build and active['sha256'] == meta['sha256'] and active.get('certificateSha256') == certificates[0]:
            print('Release already synchronized and verified')
            return
        raise RuntimeError('Update service already has this or a newer build')
    started = ci('begin', meta)
    release_id, part_size = started['id'], started['partSize']
    try:
        with apk.open('rb') as stream:
            number = 1
            while chunk := stream.read(part_size):
                ci('part', upload=chunk, upload_id=release_id, part=number)
                print(f'Uploaded APK part {number}', flush=True)
                number += 1
        uploaded = ci('complete', {'id': release_id})['release']
        if uploaded['sha256'] != meta['sha256'] or uploaded['size'] != meta['size']:
            raise RuntimeError('Uploaded bytes failed checksum verification')
        ci('publish', {'id': release_id})
    except Exception:
        try:
            ci('abort', {'id': release_id})
        except Exception:
            pass
        raise
    with HTTP.open(ORIGIN + '/v1/update/latest', timeout=30) as response:
        active = json.load(response)['release']
    if not active or active['build'] != build or active['sha256'] != meta['sha256']:
        raise RuntimeError('Published update was not confirmed')
    print(f'Published and verified LifeAtlas {version}+{build}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare-signing', 'publish'])
    args = parser.parse_args()
    if args.action == 'prepare-signing':
        prepare_signing()
    else:
        publish()
