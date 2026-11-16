"""Export the touch client and embed the shared offline rules in a signed APK."""
from pathlib import Path
import argparse
import json
import hashlib
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'GuildMaster-Godot-src'
PACK = ROOT / 'GuildMaster-Godot'
SDK = Path(os.environ.get('ANDROID_SDK_ROOT', ROOT.parent / '.qa-runtime/android-sdk'))
BUILD = Path(os.environ.get('GUILD_ANDROID_BUILD', Path.home() / '.codex/build/guild-android'))
EDITOR = Path(os.environ.get('GODOT_BIN', ROOT.parent / '.qa-runtime/godot-sdk/editor/Godot_v4.7.2-stable_win64_console.exe'))


def run(command, log):
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, env=os.environ.copy())
    if result.returncode:
        raise RuntimeError(log.read_text('utf-8', errors='replace')[-6000:])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--skip-assets', action='store_true')
    args = parser.parse_args()
    version = json.loads((ROOT / 'release.json').read_text('utf-8'))['version']
    major, minor, patch = map(int, version.split('.'))
    version_code = major * 10000 + minor * 100 + patch
    os.environ['JAVA_HOME'] = r'C:\Program Files\Eclipse Adoptium\jdk-21.0.5.11-hotspot'
    os.environ['ANDROID_HOME'] = str(SDK)
    os.environ['ANDROID_SDK_ROOT'] = str(SDK)
    BUILD.mkdir(parents=True, exist_ok=True)
    if not (BUILD / 'build.gradle').exists():
        with zipfile.ZipFile(ROOT.parent / '.qa-runtime/godot-sdk/templates/android_source.zip') as archive:
            archive.extractall(BUILD)
    subprocess.run([sys.executable, str(ROOT / 'tools/prepare_update.py')], check=True)
    for path in (PACK / 'rules').glob('*.py'):
        shutil.copy2(path, SRC / 'rules' / path.name)
    # Generated template changes are recreated from these small, tracked inputs.
    with zipfile.ZipFile(ROOT.parent / '.qa-runtime/godot-sdk/templates/android_source.zip') as archive:
        gradle = archive.read('build.gradle').decode()
        settings = archive.read('settings.gradle').decode()
        manifest = archive.read('src/main/AndroidManifest.xml').decode()
    gradle = gradle.replace("id 'org.jetbrains.kotlin.android'", "id 'org.jetbrains.kotlin.android'\n    id 'com.chaquo.python' version '17.2.0'")
    gradle = gradle.replace('    ndkVersion versions.ndkVersion\n', '')
    gradle += '\nchaquopy { defaultConfig { version = "3.13"; buildPython("C:/Python313/python.exe"); extractPackages("*") } }\n'
    (BUILD / 'build.gradle').write_text(gradle, 'utf-8')
    (BUILD / 'settings.gradle').write_text(settings, 'utf-8')
    manifest = manifest.replace('<application\n', '<uses-permission android:name="android.permission.INTERNET" />\n    <application\n        android:usesCleartextTraffic="true"\n')
    manifest = manifest.replace('    </application>', '        <meta-data android:name="org.godotengine.plugin.v2.GuildOffline" android:value="com.godot.game.GuildOfflinePlugin" />\n    </application>')
    (BUILD / 'src/main/AndroidManifest.xml').write_text(manifest, 'utf-8')
    java = BUILD / 'src/main/java/com/godot/game/GuildOfflinePlugin.java'
    shutil.copy2(ROOT / 'mobile/android/GuildOfflinePlugin.java', java)
    rules = BUILD / 'src/main/python'
    rules.mkdir(parents=True, exist_ok=True)
    for path in (PACK / 'rules').glob('*.py'): shutil.copy2(path, rules / path.name)
    shutil.copy2(ROOT / 'mobile/android/mobile_bridge.py', rules / 'mobile_bridge.py')
    for path in (PACK / 'rules').glob('*.json'): shutil.copy2(path, rules / path.name)
    (BUILD / 'local.properties').write_text('sdk.dir=' + SDK.as_posix() + '\n', 'utf-8')
    with zipfile.ZipFile(ROOT.parent / '.qa-runtime/godot-sdk/templates/android_source.zip') as archive:
        properties = archive.read('gradle.properties').decode()
    properties += '\nexport_enabled_abis=arm64-v8a|x86_64\nexport_package_name=cn.guildmaster.game\nexport_version_code=' + str(version_code) + '\nexport_version_name=' + version + '\nperform_signing=true\nperform_zipalign=true\ndoNotStrip=true\nandroid.suppressUnsupportedCompileSdk=36\norg.gradle.jvmargs=-Xmx4096m -Dfile.encoding=UTF-8\n'
    (BUILD / 'gradle.properties').write_text(properties, 'utf-8')
    # Reuse a single project signing identity across mobile rebuilds.
    (BUILD / 'res/values/strings.xml').write_text('<resources><string name="godot_project_name_string" translatable="false">异世界公会长</string></resources>', 'utf-8')
    for path in (BUILD / 'res').glob('values*/godot_project_name_string.xml'):
        path.write_text('<resources><string name="godot_project_name_string" translatable="false">异世界公会长</string></resources>', 'utf-8')
    (BUILD / 'res/values/strings.xml').unlink(missing_ok=True)
    from PIL import Image
    icon = Image.open(SRC / 'ui/app_icon.png').convert('RGBA')
    for path in (BUILD / 'res').glob('mipmap*/icon.png'):
        image = icon.copy();image.thumbnail(Image.open(path).size);image.save(path)
    assets = BUILD / 'src/main/assets'
    assets.mkdir(parents=True, exist_ok=True)
    if not args.skip_assets:
        export = ROOT / 'qa/android-assets.zip'
        run([str(EDITOR), '--headless', '--path', str(SRC), '--export-pack', 'AndroidAssets', str(export)], ROOT / 'qa/android-export.log')
        report = (ROOT / 'qa/android-export.log').read_text('utf-8')
        if 'SCRIPT ERROR' in report: raise RuntimeError(report[-4000:])
        with zipfile.ZipFile(export) as archive: archive.extractall(assets)
        for path in (PACK / 'art').rglob('*'):
            if path.is_file() and path.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp'):
                target = assets / 'art' / path.relative_to(PACK / 'art')
                target.parent.mkdir(parents=True, exist_ok=True);shutil.copy2(path, target)
    print('Building Android APK with offline CPython', flush=True)
    run([str(BUILD / 'gradlew.bat'), '--project-dir', str(BUILD), '--no-daemon', '--console=plain', 'assembleStandardDebug'], ROOT / 'qa/android-gradle.log')
    output = ROOT / 'dist' / f'GuildMaster-Android-{version}.apk'
    shutil.copy2(BUILD / 'build/outputs/apk/standard/debug/android_debug.apk', output)
    release_file = ROOT / 'release-files.json'
    if release_file.exists():
        release = json.loads(release_file.read_text('utf-8'))
        if release.get('version') == version:
            release['artifacts'] = [item for item in release['artifacts'] if item['name'] != output.name]
            release['artifacts'].append(dict(name=output.name, size_bytes=output.stat().st_size, sha256=hashlib.sha256(output.read_bytes()).hexdigest()))
            release_file.write_text(json.dumps(release, ensure_ascii=False, indent=2), 'utf-8')
    print(output, flush=True)


if __name__ == '__main__':
    main()
