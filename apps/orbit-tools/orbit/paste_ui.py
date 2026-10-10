from pathlib import Path
from .ui import Page, Gtk, GLib, box, button, label, scroll, textview, text
from .common import clipboard, copy_text, run
from .paste import transform

MODES = [('서식 없는 텍스트', 'plain'), ('JSON 정리', 'json'), ('JSON 압축', 'compact'), ('HTML → Markdown', 'markdown'), ('HTML → 텍스트', 'html-text'), ('CSV/TSV → 표', 'table')]


class PastePage(Page):
    def __init__(self, window):
        super().__init__(window, '똑똑한 붙여넣기', '변환 결과를 확인한 뒤 복사하거나 파일로 저장하세요.')
        row = box(False)
        row.append(button('클립보드 가져오기', self.load))
        row.append(button('HTML 가져오기', self.load_html))
        self.mode = Gtk.DropDown.new_from_strings([m[0] for m in MODES])
        row.append(self.mode)
        row.append(button('변환', self.convert, 'suggested-action'))
        self.append(row)
        split = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL, wide_handle=True, vexpand=True)
        self.source = textview(); self.output = textview()
        left = box(); left.append(label('원본')); left.append(scroll(self.source))
        right = box(); right.append(label('결과 · 직접 수정 가능')); right.append(scroll(self.output))
        split.set_start_child(left); split.set_end_child(right); split.set_position(370)
        self.append(split)
        actions = box(False)
        actions.append(button('결과 복사', lambda: self.copy()))
        actions.append(button('이전 창에 붙여넣기', lambda: self.window.paste_text(text(self.output)), 'suggested-action'))
        actions.append(button('파일로 저장', self.save))
        self.append(actions)
        self.append(label('HTML의 기본 제목·링크·목록·강조를 변환합니다. 웹 페이지 레이아웃 전체를 재현하지는 않습니다.', 'muted'))

    def load(self):
        try:
            self.source.get_buffer().set_text(clipboard()); self.status('클립보드 텍스트를 가져왔습니다.')
        except Exception as e:
            self.status(str(e))

    def load_html(self):
        try:
            self.source.get_buffer().set_text(run(['wl-paste', '--no-newline', '--type', 'text/html']))
            self.mode.set_selected(3); self.status('클립보드 HTML을 가져왔습니다.')
        except Exception:
            self.status('클립보드에 HTML이 없습니다. 웹 페이지에서 내용을 복사해 주세요.')

    def convert(self):
        try:
            value = transform(text(self.source), MODES[self.mode.get_selected()][1])
            self.output.get_buffer().set_text(value); self.status('변환 완료 · 복사하기 전 결과를 확인하세요.')
        except Exception as e:
            self.status(str(e))

    def copy(self):
        try:
            copy_text(text(self.output)); self.status('결과를 클립보드에 복사했습니다.')
        except Exception as e:
            self.status(str(e))

    def save(self):
        dialog = Gtk.FileChooserNative(title='변환 결과 저장', transient_for=self.window, action=Gtk.FileChooserAction.SAVE, accept_label='저장', cancel_label='취소')
        mode = MODES[self.mode.get_selected()][1]
        dialog.set_current_name('converted.' + ('json' if mode in ('json', 'compact') else 'md' if mode in ('markdown', 'table') else 'txt'))
        def response(d, code):
            if code == Gtk.ResponseType.ACCEPT:
                try:
                    Path(d.get_file().get_path()).write_text(text(self.output)); self.status('파일을 저장했습니다.')
                except Exception as e:
                    self.status(str(e))
            d.destroy()
        dialog.connect('response', response); dialog.show()
