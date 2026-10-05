#!/usr/bin/env python3
"""Write the release manifest the app's update check reads (lib/core/update): latest.json, schema 1.

    release/make-latest.py <dir with janzeer-wallet-<ver>-* archives> <base URL of that dir> [version] [> latest.json]

Version and build number come from pubspec.yaml, the notes from release/notes/<version>.json ({"en": …, "ar": …}).
A third argument names an EARLIER released version (the source is already on the next one, its archives are not built
yet): build number and release date are then read from that version's git tag `v<version>`.
Every archive found for that version becomes one entry under "files", keyed by platform, with its SHA-256 and size.
The app accepts download URLs only on downloads.janzeer.org and on this repository's GitHub releases.
"""
import hashlib, json, os, re, subprocess, sys, datetime

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORMS = (('-android.apk', 'android'), ('-linux-x64.tar.gz', 'linux-x64'), ('-windows-x64.zip', 'windows-x64'), ('-macos.zip', 'macos'))

def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    folder, base = sys.argv[1], sys.argv[2].rstrip('/')
    spec = open(os.path.join(here, 'pubspec.yaml')).read()
    released = datetime.date.today().isoformat()
    if len(sys.argv) == 4 and not re.search(r'^version:\s*' + re.escape(sys.argv[3]) + r'(\+|\s|$)', spec, re.M):
        tag = 'v' + sys.argv[3]                      # an earlier release: its own pubspec and date, from the tag
        try:
            spec = subprocess.run(['git', '-C', here, 'show', f'{tag}:pubspec.yaml'], check=True, capture_output=True, text=True).stdout
            released = subprocess.run(['git', '-C', here, 'log', '-1', '--format=%cs', tag], check=True, capture_output=True, text=True).stdout.strip() or released
        except (subprocess.CalledProcessError, FileNotFoundError):
            sys.exit(f'version {sys.argv[3]} is not the pubspec version and git tag {tag} was not found')
    m = re.search(r'^version:\s*([0-9][0-9.]*)\+?(\d+)?', spec, re.M)
    version, build = m.group(1), int(m.group(2) or 0)
    notes_file = os.path.join(here, 'release', 'notes', version + '.json')
    notes = json.load(open(notes_file, encoding='utf-8')) if os.path.exists(notes_file) else {}
    files = {}
    for suffix, key in PLATFORMS:
        name = f'janzeer-wallet-{version}{suffix}'
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        files[key] = {'name': name, 'url': f'{base}/{name}', 'sha256': h.hexdigest(), 'size': os.path.getsize(path)}
    if not files:
        sys.exit(f'no janzeer-wallet-{version}-* archive in {folder}')
    json.dump({'schema': 1, 'version': version, 'build': build, 'released': released, 'notes': notes, 'files': files},
              sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')

if __name__ == '__main__':
    main()
