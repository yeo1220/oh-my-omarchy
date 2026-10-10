#!/usr/bin/python3
import sys
from orbit.ui import Gtk, Gio, GLib, Gdk, theme, box, label, button
from orbit.scenes_ui import ScenesPage
from orbit.shelf_ui import ShelfPage
from orbit.overview_ui import OverviewPage
from orbit.paste_ui import PastePage
from orbit.search_ui import SearchPage
from orbit.snippets_ui import SnippetsPage
from orbit.common import hypr, dispatch, copy_text, run
import time
import threading


class Window(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title='Orbit Tools')
        self.set_default_size(960, 650)
        outer = box(spacing=0)
        header = Gtk.HeaderBar()
        title = label('◉  ORBIT TOOLS', 'accent'); title.set_wrap(False)
        header.set_title_widget(title)
        self.set_titlebar(header)
        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.CROSSFADE, hexpand=True, vexpand=True)
        self.status = label('준비되었습니다.', 'status')
        self.status.set_selectable(True)
        body = box(False, 0)
        sidebar = Gtk.StackSidebar(stack=self.stack)
        sidebar.set_size_request(155, -1); sidebar.add_css_class('sidebar')
        body.append(sidebar); body.append(self.stack)
        outer.append(body); outer.append(self.status)
        self.set_child(outer)
        self.stack.add_titled(ScenesPage(self), 'scenes', '① 작업 환경')
        self.stack.add_titled(ShelfPage(self), 'shelf', '② 파일 선반')
        self.stack.add_titled(OverviewPage(self), 'overview', '③ 전체 창')
        self.stack.add_titled(PastePage(self), 'paste', '④ 붙여넣기')
        self.stack.add_titled(SearchPage(self), 'search', '⑤ 문서 검색')
        self.stack.add_titled(SnippetsPage(self), 'snippets', '⑥ 문구 입력')
        self.target = None
        self.pages = {}
        key = Gtk.EventControllerKey()
        key.connect('key-pressed', self.keypress)
        self.add_controller(key)

    def keypress(self, _controller, key, code, mods):
        if key == Gdk.KEY_Escape:
            self.close(); return True
        return False

    def paste_text(self, value):
        target = self.target
        try:
            copy_text(value)
            live = hypr('clients')
            if not target or not any(c['address'] == target['address'] and c['pid'] == target['pid'] for c in live):
                self.status.set_text('이전 창이 없어 결과만 복사했습니다. 원하는 창에서 붙여넣으세요.'); return
            self.set_visible(False)
            dispatch('focus', window='address:' + target['address'])
            def send():
                try:
                    time.sleep(0.2)
                    if hypr('activewindow').get('address') != target['address']:
                        return
                    terminal = any(x in target.get('class', '').lower() for x in ('foot', 'alacritty', 'kitty', 'ghostty', 'terminal'))
                    args = ['wtype', '-M', 'ctrl']
                    if terminal: args += ['-M', 'shift']
                    args += ['-k', 'v']
                    if terminal: args += ['-m', 'shift']
                    run(args + ['-m', 'ctrl'])
                except Exception as e:
                    message = str(e)
                    GLib.idle_add(lambda: self.status.set_text('붙여넣기 실패 · 결과는 복사됨: ' + message))
            threading.Thread(target=send, daemon=True).start()
        except Exception as e:
            self.status.set_text(str(e))


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='io.lovehouse.OrbitTools', flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.window = None
        self.page = 'scenes'

    def do_activate(self):
        if self.window is None:
            theme()
            self.window = Window(self)
            self.window.connect('destroy', lambda _: setattr(self, 'window', None))
        if self.window.stack.get_child_by_name(self.page):
            self.window.stack.set_visible_child_name(self.page)
        self.window.present()
        child=self.window.stack.get_visible_child()
        if hasattr(child,'query'): child.query.grab_focus()
        if self.page=='search':
            from orbit import search
            if time.time()-search.last_indexed()>300: child.reindex()

    def do_command_line(self, command):
        args = command.get_arguments()[1:]
        if args and args[0] == '--quit':
            self.quit(); return 0
        self.page = args[0] if args else 'scenes'
        target = None
        try:
            candidate = hypr('activewindow')
            if candidate.get('class') != 'io.lovehouse.OrbitTools': target = candidate
        except Exception:
            pass
        self.activate()
        if target: self.window.target = target
        return 0


if __name__ == '__main__':
    raise SystemExit(App().run(sys.argv))
