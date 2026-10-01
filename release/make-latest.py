#!/usr/bin/env python3
"""Write the release manifest the app's update check reads (lib/core/update): latest.json, schema 1.

    release/make-latest.py <dir with janzeer-wallet-<ver>-* archives> <base URL of that dir> [> latest.json]

Version and build number come from pubspec.yaml, the notes from release/notes/<version>.json ({"en": …, "ar": …}).
Every archive found for that version becomes one entry under "files", keyed by platform, with its SHA-256 and size.
The app accepts download URLs only on downloads.janzeer.org and on this repository's GitHub releases.
"""
import hashlib, json, os, re, sys, datetime

here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLATFORMS = (('-android.apk', 'android'), ('-linux-x64.tar.gz', 'linux-x64'), ('-windows-x64.zip', 'windows-x64'), ('-macos.zip', 'macos'))

def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    folder, base = sys.argv[1], sys.argv[2].rstrip('/')
    m = re.search(r'^version:\s*([0-9][0-9.]*)\+?(\d+)?', open(os.path.join(here, 'pubspec.yaml')).read(), re.M)
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
    json.dump({'schema': 1, 'version': version, 'build': build, 'released': datetime.date.today().isoformat(), 'notes': notes, 'files': files},
              sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write('\n')

if __name__ == '__main__':
    main()
