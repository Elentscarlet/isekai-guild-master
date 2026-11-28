"""Build the Windows server executable or a server source ZIP."""
import argparse
import hashlib
from importlib.util import find_spec
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from build_update_release import ROOT, SERVER, VERSION, package


def build_executable(target):
    with tempfile.TemporaryDirectory(prefix='server-build-', dir=target.parent) as directory:
        staging = Path(directory)
        args = [
            sys.executable, '-B', '-m', 'PyInstaller', '--onefile', '--console', '--noupx',
            '--name', target.stem, '--distpath', str(staging),
            '--workpath', str(staging / 'work'), '--specpath', str(staging),
        ]
        for name in ('guild_asset_manifest.json', 'guild_card_layouts.json',
                     'site', 'replay_web', 'card_components', 'images'):
            path = SERVER / name
            if path.exists():
                destination = name if path.is_dir() else '.'
                args.extend(['--add-data', f'{path}:{destination}'])
        env = dict(os.environ, PYINSTALLER_CONFIG_DIR=str(staging / 'cache'))
        subprocess.run([*args, str(SERVER / 'server.py')], env=env, check=True)
        output = staging / target.name
        subprocess.run([str(output), '--help'], cwd=staging, stdout=subprocess.DEVNULL, check=True)
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        output.replace(target)
    return digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', action='store_true', help='package the Python sources for Linux or Windows')
    parser.add_argument('--output', type=Path, help='override the output path')
    args = parser.parse_args()
    filename = f'guild-server-{VERSION}.zip' if args.source_zip else 'GuildMasterServer.exe'
    target = (args.output or ROOT / 'dist' / filename).resolve()

    if not (SERVER / 'server.py').is_file():
        parser.error(f'Server entry point not found: {SERVER / "server.py"}')
    suffix = Path(filename).suffix
    if target.is_relative_to(SERVER) or target.suffix != suffix:
        parser.error(f'--output must be a {suffix} path outside the server source directory')
    if not args.source_zip:
        if sys.platform != 'win32':
            parser.error('The Windows EXE must be built on Windows. Use --source-zip for a source archive.')
        if find_spec('PyInstaller') is None:
            parser.error('Install PyInstaller with python -m pip install pyinstaller.')

    target.parent.mkdir(parents=True, exist_ok=True)
    if args.source_zip:
        artifact = package(SERVER, target,
                           exclude={'server_config.json', '.idea', '.venv', '.git', '.env'},
                           refresh_manifest=True)
        digest = artifact['sha256']
    else:
        digest = build_executable(target)
    print(target)
    print(f'SHA-256 {digest}')


if __name__ == '__main__':
    main()
