from pathlib import Path
from .ui import Page, Gtk, Gdk, Gio, GLib, box, button, label, clear, scroll
from . import shelf
from .common import copy_text, run


class ShelfPage(Page):
    def __init__(self, window):
        super().__init__(window, '파일 선반', '파일·폴더·웹 링크를 끌어다 놓으세요. 원본은 제자리에 두고 선반에 모읍니다.')
        row = box(False)
        row.append(button('파일 추가', lambda: self.choose(False)))
        row.append(button('폴더 추가', lambda: self.choose(True)))
        self.value = Gtk.Entry(placeholder_text='웹 링크 또는 파일 경로', hexpand=True)
        self.value.connect('activate', lambda _: self.add([self.value.get_text()]))
        row.append(self.value)
        row.append(button('추가', lambda: self.add([self.value.get_text()])))
        self.append(row)
        target = Gtk.DropTarget.new(Gdk.FileList, Gdk.DragAction.COPY)
        target.connect('drop', lambda _t, files, x, y: self.add([f.get_path() for f in files.get_files() if f.get_path()]))
        self.add_controller(target)
        text_target = Gtk.DropTarget.new(str, Gdk.DragAction.COPY)
        text_target.connect('drop', lambda _t, s, x, y: self.add(s.splitlines()))
        self.add_controller(text_target)
        self.rows = box()
        self.append(scroll(self.rows))
        actions = box(False)
        actions.append(button('선택 항목 ZIP', self.zip, 'suggested-action'))
        actions.append(button('선택 항목 공유', self.share))
        actions.append(button('선반에서 제거', self.remove))
        drag = button('↗ 선택 파일을 여기서 드래그', lambda: self.status('이 버튼을 파일 관리자나 브라우저로 드래그하세요.'))
        source = Gtk.DragSource(actions=Gdk.DragAction.COPY)
        source.connect('prepare', self.prepare_drag)
        drag.add_controller(source); actions.append(drag)
        self.append(actions)
        self.append(label('항목 옆 체크박스로 선택합니다. ZIP은 ~/Downloads에 저장하며, 공유는 LocalSend에서 받을 기기를 고릅니다.', 'muted'))
        self.refresh()

    def add(self, values):
        try:
            shelf.add(values); self.value.set_text(''); self.refresh(); self.status('선반에 추가했습니다.'); return True
        except Exception as e:
            self.status(str(e)); return False

    def refresh(self):
        clear(self.rows); self.checks = []
        rows = shelf.items()
        if not rows:
            empty = label('여기로 파일을 끌어다 놓으세요\n\n여러 폴더의 자료를 모으고 한 번에 전달할 수 있습니다.', 'card')
            self.rows.append(empty)
        for item in rows:
            row = box(False); row.add_css_class('card')
            check = Gtk.CheckButton(active=True)
            self.checks.append((check, item)); row.append(check)
            info = box(spacing=4); info.set_hexpand(True)
            info.append(label(item['name'], 'accent'))
            info.append(label(item['value'], 'muted'))
            row.append(info)
            row.append(button('열기', lambda i=item: Gio.AppInfo.launch_default_for_uri(Path(i['value']).as_uri() if i['kind']=='file' else i['value'], None)))
            self.rows.append(row)

    def selected(self):
        return [item for check, item in self.checks if check.get_active()]

    def remove(self):
        shelf.remove([r['id'] for r in self.selected()]); self.refresh(); self.status('선반에서 제거했습니다. 원본 파일은 그대로입니다.')

    def zip(self):
        rows = self.selected()
        if rows:
            self.work(lambda: shelf.archive(rows), lambda p: self.status('ZIP 저장: ' + p))
        else:
            self.status('압축할 항목을 선택하세요.')

    def share(self):
        rows = self.selected()
        if not rows:
            self.status('공유할 항목을 선택하세요.'); return
        if all(r['kind'] == 'url' for r in rows):
            copy_text('\n'.join(r['value'] for r in rows))
            self.work(lambda: run(['omarchy', 'share', 'clipboard'], timeout=300))
        elif any(r['kind'] == 'url' for r in rows):
            self.work(lambda: run(['omarchy','share','file',shelf.archive(rows)],timeout=300))
        else:
            self.work(lambda: run(['omarchy', 'share', 'file', *[r['value'] for r in rows]], timeout=300))

    def prepare_drag(self, source, x, y):
        rows=self.selected()
        files = [Gio.File.new_for_path(r['value']) for r in rows if r['kind'] == 'file' and Path(r['value']).exists()]
        links = [r['value'] for r in rows if r['kind'] == 'url']
        if not files and not links:
            return None
        uris = '\r\n'.join([f.get_uri() for f in files]+links) + '\r\n'
        providers=[Gdk.ContentProvider.new_for_bytes('text/uri-list', GLib.Bytes.new(uris.encode())),Gdk.ContentProvider.new_for_value(uris)]
        if not links: providers.insert(0,Gdk.ContentProvider.new_for_value(Gdk.FileList.new_from_array(files)))
        return Gdk.ContentProvider.new_union(providers)

    def choose(self, folders):
        dialog = Gtk.FileChooserNative(title='선반에 추가', transient_for=self.window, action=Gtk.FileChooserAction.SELECT_FOLDER if folders else Gtk.FileChooserAction.OPEN, accept_label='추가', cancel_label='취소')
        dialog.set_select_multiple(True)
        def response(d, code):
            if code == Gtk.ResponseType.ACCEPT:
                files = d.get_files()
                self.add([files.get_item(i).get_path() for i in range(files.get_n_items())])
            d.destroy()
        dialog.connect('response', response); dialog.show()
