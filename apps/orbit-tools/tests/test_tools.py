import datetime
import json
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from orbit import scenes, shelf, paste, search, snippets
from orbit.common import atomic_json, update_json, lua


class ToolsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
        self.patches=[patch.object(shelf,'PATH',self.root/'shelf.json'),patch.object(snippets,'PATH',self.root/'snippets.json'),patch.object(search,'DB',self.root/'index.db')]
        for p in self.patches:p.start()

    def tearDown(self):
        for p in self.patches:p.stop()
        self.temp.cleanup()

    def test_scene_identity_survives_title_change(self):
        old={'stableId':'1','pid':20,'class':'foot','title':'old'}
        current={'address':'0x1','stableId':'1','pid':20,'class':'foot','title':'new'}
        self.assertEqual(scenes.matching(old,[current],set(),True),current)

    def test_scene_does_not_match_reused_pid_after_session(self):
        saved={'stableId':'1','pid':20,'class':'foot','title':'old'}
        current={'address':'0x1','stableId':'1','pid':20,'class':'foot','title':'new'}
        self.assertIsNone(scenes.matching(saved,[current],set(),False))

    def test_scene_ambiguous_title_is_skipped(self):
        saved={'class':'foot','title':'same'}
        live=[dict(saved,address='0x1'),dict(saved,address='0x2')]
        self.assertIsNone(scenes.matching(saved,live,set(),False))

    def test_scene_does_not_reuse_a_window_twice(self):
        saved={'class':'foot','title':'same'}
        self.assertIsNone(scenes.matching(saved,[dict(saved,address='0x1')],{'0x1'},False))

    def test_atomic_update_failure_keeps_previous(self):
        path=self.root/'data.json'; atomic_json(path,[1])
        def bad(x):x.append(2); raise ValueError('stop')
        with self.assertRaises(ValueError):update_json(path,[],bad)
        self.assertEqual(json.loads(path.read_text()),[1])

    def test_lua_quoting(self):
        self.assertEqual(lua('a"b\\c'),'"a\\"b\\\\c"')

    def test_shelf_unicode_uri_dedup(self):
        file=self.root/'자료 파일.txt';file.write_text('hello')
        shelf.add([str(file),file.as_uri()]);self.assertEqual(len(shelf.items()),1)

    def test_shelf_remove_keeps_file(self):
        file=self.root/'a';file.touch();shelf.add([str(file)])
        shelf.remove([shelf.items()[0]['id']]);self.assertTrue(file.exists())

    def test_shelf_archive_handles_duplicate_names(self):
        for d in ('a','b'):(self.root/d).mkdir();(self.root/d/'same.txt').write_text(d)
        shelf.add([str(self.root/'a/same.txt'),str(self.root/'b/same.txt'),'https://example.com'])
        with zipfile.ZipFile(shelf.archive(shelf.items(),self.root)) as z:
            self.assertEqual(z.read('same.txt'),b'a');self.assertEqual(z.read('1-same.txt'),b'b');self.assertIn('link.url',z.namelist())

    def test_shelf_missing_file_is_reported(self):
        with self.assertRaises(ValueError):shelf.add([str(self.root/'missing')])

    def test_shelf_archive_skips_external_symlinks(self):
        folder=self.root/'folder';folder.mkdir();(folder/'link').symlink_to('/etc/passwd')
        shelf.add([str(folder)])
        with zipfile.ZipFile(shelf.archive(shelf.items(),self.root)) as z:self.assertNotIn('folder/link',z.namelist())

    def test_json_transform(self):
        self.assertEqual(json.loads(paste.transform('{"한글":1}','json')),{'한글':1})
        self.assertEqual(paste.transform('{ "a": 1 }','compact'),'{"a":1}')

    def test_invalid_json(self):
        with self.assertRaises(ValueError):paste.transform('{broken','json')

    def test_html_markdown(self):
        self.assertEqual(paste.transform('<h1>제목</h1><p><b>강조</b></p>','markdown'),'# 제목\n\n**강조**')

    def test_html_scripts_removed(self):
        self.assertEqual(paste.transform('<p>safe</p><script>bad</script><style>bad</style>','html-text'),'safe')

    def test_plain_text_preserves_angle_brackets(self):
        self.assertEqual(paste.transform('x < y','plain'),'x < y')

    def test_table_quotes_and_pipes(self):
        value=paste.transform('name,value\n"a,b","c|d"','table')
        self.assertIn('| a,b | c\\|d |',value)

    def test_search_unicode_and_incremental(self):
        docs=self.root/'docs';docs.mkdir();file=docs/'회의.md';file.write_text('별빛고래 프로젝트')
        search.index([str(docs)]);self.assertEqual(search.find('고래')[0]['path'],str(file))
        self.assertTrue(search.find('별빛고래'))
        file.write_text('다른문장');search.index([str(docs)]);self.assertFalse(search.find('고래'))
        file.unlink();search.index([str(docs)]);self.assertFalse(search.find('다른문장'))

    def test_search_ignores_hidden_and_vendor(self):
        docs=self.root/'docs';docs.mkdir();(docs/'.env').write_text('SECRET')
        (docs/'node_modules').mkdir();(docs/'node_modules/x.md').write_text('SECRET')
        search.index([str(docs)]);self.assertFalse(search.find('SECRET'))

    def test_search_short_wildcards_are_literal(self):
        docs=self.root/'docs';docs.mkdir();(docs/'a.txt').write_text('ordinary')
        search.index([str(docs)]);self.assertFalse(search.find('%'))

    def test_docx_text(self):
        path=self.root/'test.docx'
        with zipfile.ZipFile(path,'w') as z:z.writestr('word/document.xml','<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>한글 문서</w:t></w:r></w:p></w:body></w:document>')
        self.assertEqual(search.extract(path),'한글 문서')

    def test_snippet_literal_values(self):
        self.assertEqual(snippets.render('{{이름}}',{'이름':'$(touch x) {{date}}'}),'$(touch x) {{date}}')

    def test_snippet_builtin_date(self):
        self.assertEqual(snippets.render('{{date}} {{time}}',{},datetime.datetime(2026,9,22,11,5)),'2026-09-22 11:05')

    def test_snippet_duplicate_rejected(self):
        snippets.seed()
        with self.assertRaises(ValueError):snippets.save(dict(keyword='DATE',name='duplicate',body='x'))

    def test_snippet_edit_and_delete(self):
        row=snippets.save(dict(keyword='test',name='Test',body='one'))
        snippets.save(dict(row,body='two'));self.assertEqual(snippets.all_snippets()[0]['body'],'two')
        snippets.remove(row['id']);self.assertEqual(snippets.all_snippets(),[])


if __name__=='__main__':unittest.main()
