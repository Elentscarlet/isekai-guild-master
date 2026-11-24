"""Install the Android SDK packages used by the mobile client build."""
from pathlib import Path
import argparse
import os
import subprocess
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SDK = ROOT.parent / '.qa-runtime/android-sdk'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--emulator', action='store_true')
    args = parser.parse_args()
    manager = SDK / 'cmdline-tools/19.0/bin/sdkmanager.bat'
    if not manager.exists():
        url = 'https://dl.google.com/android/repository/'
        tree = ET.fromstring(urllib.request.urlopen(url + 'repository2-3.xml', timeout=60).read())
        candidates = []
        for package in tree.findall('remotePackage'):
            if not package.get('path', '').startswith('cmdline-tools;'):
                continue
            channel = package.find('channelRef')
            if channel is not None and channel.get('ref') != 'channel-0':
                continue
            for archive in package.findall('archives/archive'):
                if archive.findtext('host-os') == 'windows':
                    major = int(package.findtext('revision/major'))
                    if major <= 19:
                        candidates.append((major, archive.findtext('complete/url')))
        download = SDK.parent / 'android-commandline.zip'
        print('Downloading Android command-line tools', flush=True)
        urllib.request.urlretrieve(url + max(candidates)[1], download)
        with zipfile.ZipFile(download) as archive:
            for member in archive.infolist():
                relative = Path(member.filename).relative_to('cmdline-tools')
                target = SDK / 'cmdline-tools/19.0' / relative
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(member))
    env = os.environ.copy()
    env['JAVA_HOME'] = str(Path(r'C:\Program Files\Eclipse Adoptium\jdk-21.0.5.11-hotspot'))
    common = [str(manager), '--sdk_root=' + str(SDK)]
    subprocess.run(common + ['--licenses'], input='y\n' * 50, text=True, env=env, check=True)
    packages = ['platform-tools', 'platforms;android-36', 'build-tools;36.1.0']
    if args.emulator:
        packages += ['emulator', 'system-images;android-35;google_apis;x86_64']
    subprocess.run(common + packages, input='y\n' * 50, text=True, env=env, check=True)
    print('ANDROID_SDK_ROOT=' + str(SDK), flush=True)


if __name__ == '__main__':
    main()
