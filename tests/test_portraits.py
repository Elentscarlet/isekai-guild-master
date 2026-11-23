import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'GuildMaster-Godot/art/characters'


class CharacterPortraits(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / 'GuildMaster-Godot-src/data/catalog.json').read_text('utf8'))
        self.record = json.loads((ROOT / 'GuildMaster-Godot-src/data/portraits.json').read_text('utf8'))

    def test_every_print_uses_the_character_art_folder(self):
        self.assertEqual(self.record['policy'], 'character_art')
        self.assertEqual(set(self.record['sources']), set(self.catalog['heroes']))
        cards = {source for hero in self.catalog['heroes'].values() for source in hero['source']}
        for key, source in self.record['sources'].items():
            with self.subTest(hero=key):
                character = self.catalog['heroes'][key]['character'].split('_')[0]
                self.assertEqual(source, 'images/characters/%s.webp' % character)
                self.assertNotIn(source, cards)
                self.assertNotIn(source, self.catalog['atlas'])
                self.assertTrue((ART / (character + '.webp')).is_file())

    def test_deprecated_portrait_folder_is_gone(self):
        for key, source in self.record['sources'].items():
            with self.subTest(hero=key):
                self.assertNotIn('images/portraits/', source)
                self.assertNotIn('images/standalone/', source)
        for folder in ('GuildMaster-Godot/art/portraits', 'GuildMaster-Godot-src/art/portraits',
                       'GuildMaster-Godot/art/standalone', 'GuildMaster-Godot-src/art/standalone'):
            with self.subTest(folder=folder):
                self.assertFalse((ROOT / folder).exists())

    def test_packaged_character_art_matches_the_sources(self):
        sources = json.loads((ROOT / 'GuildMaster-Godot-src/data/portraits.json').read_text('utf8'))['sources']
        referenced = {source.rsplit('/', 1)[1] for source in sources.values()}
        packaged = {path.name for path in ART.glob('*.webp')}
        self.assertTrue(referenced <= packaged, referenced - packaged)
