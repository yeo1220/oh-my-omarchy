import threading
from pathlib import Path
from .ui import Page, Gtk, Gio, GLib, box, button, label, clear, scroll
from . import search
from .common import atomic_json


class SearchPage(Page):
    def __init__(self, window):
        super().__init__(window, '문서 통합 검색', '파일 이름과 문서 속 문장을 찾으세요. 한글 부분 검색, PDF·DOCX·텍스트를 지원합니다.')
        row=box(False)
        self.query=Gtk.SearchEntry(placeholder_text='문서 안의 문장이나 파일 이름',hexpand=True)
        self.query.connect('search-changed',lambda _:self.lookup())
        row.append(self.query); row.append(button('색인 갱신',self.reindex))
        row.append(button('폴더 추가',self.choose_root))
        self.append(row)
        self.root_label=label('', 'muted'); self.append(self.root_label)
        self.roots_combo=Gtk.DropDown.new_from_strings(search.roots())
        config=box(False); self.roots_combo.set_hexpand(True); config.append(self.roots_combo)
        config.append(button('검색 범위에서 제외',self.remove_root)); self.append(config)
        self.rows=box(); self.append(scroll(self.rows)); self.generation=0
        self.apps=[a for a in Gio.AppInfo.get_all() if a.should_show()]
        self.update_roots()
        self.rows.append(label('검색어를 입력하세요. 검색 결과를 누르면 해당 문서를 엽니다.', 'card'))

    def update_roots(self):
        roots=search.roots()
        self.roots_combo.set_model(Gtk.StringList.new(roots))
        self.root_label.set_text('검색 폴더 '+str(len(roots))+'개 · 첫 100쪽 PDF / 최대 20MB 문서 · 숨김 폴더 제외')

    def reindex(self):
        def done(result):
            self.status(f"{result['count']}개 파일 · {result['updated']}개 갱신 · 오류 {len(result['errors'])}개")
            self.lookup()
        self.work(search.index,done)

    def lookup(self):
        self.generation+=1; generation=self.generation; query=self.query.get_text()
        def work():
            try:
                hits=search.find(query)
                GLib.idle_add(lambda:self.show_results(hits,generation))
            except Exception as e:
                message=str(e); GLib.idle_add(lambda:self.status(message))
        threading.Thread(target=work,daemon=True).start()

    def show_results(self,hits,generation):
        if generation!=self.generation: return False
        clear(self.rows)
        query=self.query.get_text().strip().casefold()
        apps=[a for a in self.apps if query and query in a.get_display_name().casefold()][:8]
        for app in apps:
            self.rows.append(button('앱 · '+app.get_display_name(),lambda a=app:a.launch([],None)))
        if not hits and not apps: self.rows.append(label('검색 결과가 없습니다. 파일을 추가했다면 색인을 갱신하세요.', 'card'))
        for hit in hits:
            row=box(); row.add_css_class('card')
            title=button(hit['name'],lambda p=hit['path']:Gio.AppInfo.launch_default_for_uri(Path(p).as_uri(),None))
            title.set_halign(Gtk.Align.START); row.append(title)
            row.append(label(hit['excerpt'])); row.append(label(hit['path'],'muted')); self.rows.append(row)
        return False

    def choose_root(self):
        dialog=Gtk.FileChooserNative(title='검색할 폴더',transient_for=self.window,action=Gtk.FileChooserAction.SELECT_FOLDER,accept_label='추가',cancel_label='취소')
        def response(d,code):
            if code==Gtk.ResponseType.ACCEPT:
                roots=search.roots(); path=d.get_file().get_path()
                if path not in roots: roots.append(path); atomic_json(search.ROOTS,roots)
                self.update_roots(); self.reindex()
            d.destroy()
        dialog.connect('response',response); dialog.show()

    def remove_root(self):
        roots=search.roots(); index=self.roots_combo.get_selected()
        if index<len(roots):
            roots.pop(index); atomic_json(search.ROOTS,roots); self.update_roots(); self.reindex()
