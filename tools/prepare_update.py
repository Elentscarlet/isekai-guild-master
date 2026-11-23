"""Prepare the refactor source, external runtime, synchronized rules and catalog."""
from pathlib import Path
import argparse
import json
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'GuildMaster-Godot-src';PACK=ROOT/'GuildMaster-Godot';SERVER=ROOT/'guild-server'
LOCAL_RULE_FILES = ('guild_session.py', 'guild_lossless_art.py', 'local_bridge.py')


def sync_rules():
    """Use the server sources for both offline runtimes."""
    sources = list(SERVER.glob('*.py'))
    sources.extend(PACK / 'rules' / name for name in LOCAL_RULE_FILES)
    for source in sources:
        contents = source.read_bytes()
        for rules in (PACK / 'rules', SRC / 'rules'):
            rules.mkdir(exist_ok=True)
            destination = rules / source.name
            if destination != source and (
                    not destination.is_file() or destination.read_bytes() != contents):
                shutil.copy2(source, destination)
            if destination.read_bytes() != contents:
                raise RuntimeError(f'Rule file is out of sync: {destination}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rules-only', action='store_true')
    args = parser.parse_args()
    sync_rules()
    if args.rules_only:
        return
    previous=ROOT.parent/'.godot-client'
    for name in ('python.exe','pythonw.exe','python313.zip'):
        destination=PACK/'runtime'/name
        if not destination.exists():shutil.copy2(previous/'runtime'/name,destination)
    if not (SRC/'main.tscn').exists():shutil.copy2(previous/'main.tscn',SRC/'main.tscn')
    sys.path.insert(0,str(SERVER))
    from guild_content import HEROES,CHARACTERS,CARDS
    path=SRC/'data/catalog.json';catalog=json.loads(path.read_text('utf8'))
    for section,definitions in [('heroes',HEROES),('cards',CARDS)]:
        for key,definition in definitions.items():
            key=str(key)
            if key not in catalog[section]:catalog[section][key]=definition
            else:
                saved={k:v for k,v in catalog[section][key].items() if k in ('source','portrait','image_path','face_variants','printed_text','name')}
                catalog[section][key].update(definition);catalog[section][key].update(saved)
                if key.startswith('shion'):catalog[section][key]['name']='紫苑'
    catalog['characters']=CHARACTERS
    path.write_text(json.dumps(catalog,ensure_ascii=False,separators=(',',':')),'utf8')
    for folder in ('art','runtime'):
        if not (SRC/folder).exists():shutil.copytree(PACK/folder,SRC/folder)
    # The art directory may already exist from an earlier build. Synchronize the
    # character illustrations the source tree loads for editor test runs.
    portraits=json.loads((SRC/'data/portraits.json').read_text('utf8'))['sources']
    for source in set(portraits.values()):
        if not source.startswith('images/characters/'):continue
        relative=Path(source.removeprefix('images/'))
        original=(PACK/'art'/relative).resolve();original.relative_to((PACK/'art').resolve())
        destination=(SRC/'art'/relative).resolve();destination.relative_to((SRC/'art').resolve())
        if not original.is_file():raise RuntimeError('Missing character portrait: '+source)
        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(original,destination)
    print('Prepared',len(HEROES),'hero prints in',len(CHARACTERS),'character groups.')

if __name__=='__main__':main()
