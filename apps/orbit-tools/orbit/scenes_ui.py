from gi.repository import Gtk
from .ui import Page, box, button, label, clear, scroll
from . import scenes
from .common import STATE, read_json


class ScenesPage(Page):
    def __init__(self, window):
        super().__init__(window, '작업 환경', '앱과 작업 공간을 한 번에 준비하세요. 창을 닫거나 실행 중인 작업을 종료하지 않습니다.')
        row = box(False)
        self.name = Gtk.Entry(placeholder_text='현재 구성을 저장할 이름', hexpand=True)
        row.append(self.name)
        row.append(button('현재 창 구성 저장', self.save, 'suggested-action'))
        self.append(row)
        self.only_current = Gtk.CheckButton(label='현재 작업 공간만 저장')
        self.append(self.only_current)
        self.rows = box()
        self.append(scroll(self.rows))
        self.append(button('직전 복원 전 상태로 돌아가기', self.undo))
        self.append(label('타일 창은 작업 공간을 복원하고 자동 배치합니다. 떠 있는 창은 위치·크기도 복원합니다. 앱 내부 문서와 터미널 실행 내용은 저장하지 않습니다.', 'muted'))
        scenes.seed()
        self.refresh()

    def save(self):
        try:
            scenes.save(self.name.get_text(), self.only_current.get_active())
            self.name.set_text(''); self.refresh(); self.status('작업 환경을 저장했습니다.')
        except Exception as e:
            self.status(str(e))

    def refresh(self):
        clear(self.rows)
        for scene in scenes.all_scenes():
            row = box(False); row.add_css_class('card')
            info = box(); info.set_hexpand(True)
            info.append(label(scene['name'], 'accent'))
            info.append(label(' · '.join(f"{w['class']} → {w['workspace']}" for w in scene['windows']) or '빈 환경', 'muted'))
            row.append(info)
            row.append(button('복원', lambda s=scene: self.work(lambda: scenes.restore(s))))
            row.append(button('삭제', lambda s=scene: self.delete(s)))
            self.rows.append(row)

    def delete(self, scene):
        scenes.remove(scene['id']); self.refresh(); self.status('저장 목록에서 제거했습니다. 실행 중인 창은 그대로입니다.')

    def undo(self):
        scene = read_json(STATE / 'before-restore.json', None)
        if scene:
            self.work(lambda: scenes.restore(scene, launch_missing=False))
        else:
            self.status('아직 복원 전 기록이 없습니다.')
