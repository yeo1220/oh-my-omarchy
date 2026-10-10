from .ui import Page, button, label
from .common import run


class OverviewPage(Page):
    def __init__(self, window):
        super().__init__(window, '전체 창 한눈에', '열린 창을 실시간 미리보기로 살펴보고 작업 공간을 정리하세요.')
        self.append(button('전체 창 펼치기', self.open, 'suggested-action'))
        self.append(label('창을 클릭하면 그 창으로 이동합니다. 창을 위쪽 1–10 작업 공간 버튼으로 드래그하면 옮길 수 있습니다.\n\n제목 검색 · 방향키 선택 · Enter 전환 · Esc 닫기', 'card'))

    def open(self):
        self.work(lambda: run(['omarchy', 'shell', 'shell', 'summon', 'lovehouse.overview']))
