"""Convert the full-size character illustrations into packaged portrait art.

Source illustrations live in ``GuildMaster-Godot-src/art/characters`` (very large
PNG, excluded from the repository).  The game loads portraits through
``data/portraits.json`` from ``art/characters`` in the packaged client, so this
script halves the working resolution and re-encodes every illustration as WebP.
"""
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'GuildMaster-Godot-src/art/characters'
PACK = ROOT / 'GuildMaster-Godot/art/characters'
SIZE = (1080, 1920)
QUALITY = 86
# The supplied illustration for Ayaka carries a stray trailing underscore.
ALIASES = {'ayaka_': 'ayaka'}


def main():
    if not SRC.is_dir():
        raise SystemExit('Missing source illustrations: ' + str(SRC))
    PACK.mkdir(parents=True, exist_ok=True)
    generated = []
    for path in sorted(SRC.glob('*.png')):
        name = ALIASES.get(path.stem, path.stem)
        image = Image.open(path).convert('RGB')
        image = image.resize(SIZE, Image.LANCZOS)
        target = PACK / (name + '.webp')
        image.save(target, 'WEBP', quality=QUALITY, method=6)
        generated.append(target)
        print('%s -> %s (%d bytes)' % (path.name, target.relative_to(ROOT), target.stat().st_size))
    stale = {path for path in PACK.glob('*.webp') if path not in set(generated)}
    for path in sorted(stale):
        path.unlink()
        print('removed', path.relative_to(ROOT))
    print('Generated', len(generated), 'character illustrations into', PACK.relative_to(ROOT))


if __name__ == '__main__':
    sys.exit(main())
