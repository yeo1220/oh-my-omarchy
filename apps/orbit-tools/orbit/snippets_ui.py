from .ui import Page, Gtk, box, button, label, clear, scroll, textview, text
from .common import copy_text
from . import snippets


class SnippetsPage(Page):
    def __init__(self,window):
        super().__init__(window,'문구 자동 입력','키워드로 문구를 찾고 빈칸을 채우세요. Enter로 선택하고 이전 앱에 입력할 수 있습니다.')
        self.item=None; self.inputs={}
        row=box(False)
        self.query=Gtk.SearchEntry(placeholder_text='date, reply, review…',hexpand=True)
        self.query.connect('search-changed',lambda _:self.refresh())
        self.query.connect('activate',lambda _:self.activate_query())
        row.append(self.query); row.append(button('새 문구',lambda:self.select(None))); self.append(row)
        split=Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL,wide_handle=True,vexpand=True)
        self.list=box(); split.set_start_child(scroll(self.list)); split.set_position(230)
        editor=box(); self.keyword=Gtk.Entry(placeholder_text='키워드'); self.name=Gtk.Entry(placeholder_text='문구 제목')
        row=box(False); row.append(self.keyword); self.name.set_hexpand(True); row.append(self.name); editor.append(row)
        self.body=textview(); body_scroll=scroll(self.body); body_scroll.set_min_content_height(110); editor.append(body_scroll)
        self.body.get_buffer().connect('changed',lambda _:self.update_fields())
        self.fields_box=box(spacing=6); editor.append(self.fields_box)
        self.preview=textview(False); preview_scroll=scroll(self.preview); preview_scroll.set_min_content_height(90)
        editor.append(label('입력될 내용','accent')); editor.append(preview_scroll)
        actions=box(False)
        actions.append(button('저장',self.save)); actions.append(button('삭제',self.delete))
        actions.append(button('복사',lambda:copy_text(text(self.preview))))
        actions.append(button('이전 앱에 입력',self.paste,'suggested-action')); editor.append(actions)
        split.set_end_child(scroll(editor)); self.append(split)
        self.append(label('{{이름}}처럼 빈칸을 만들 수 있습니다. {{date}}, {{time}}은 자동으로 채워집니다. 문구와 입력 내용은 이 기기에서만 처리합니다.','muted'))
        self.refresh(); self.select(None)

    def refresh(self):
        query=self.query.get_text().casefold(); self.matches=[s for s in snippets.all_snippets() if query in (s['keyword']+' '+s['name']).casefold()]
        clear(self.list)
        for item in self.matches:
            self.list.append(button(item['keyword']+'\n'+item['name'],lambda s=item:self.select(s)))

    def activate_query(self):
        if not self.matches:return
        exact=next((s for s in self.matches if s['keyword'].casefold()==self.query.get_text().casefold()),self.matches[0])
        self.select(exact)
        if self.inputs: next(iter(self.inputs.values())).grab_focus()
        else: self.paste()

    def select(self,item):
        self.item=item
        self.keyword.set_text(item['keyword'] if item else '')
        self.name.set_text(item['name'] if item else '')
        self.inputs={}; self.body.get_buffer().set_text(item['body'] if item else '')
        self.update_fields()

    def update_fields(self):
        body=text(self.body); wanted=snippets.fields(body)
        if list(self.inputs)!=wanted:
            previous={k:v.get_text() for k,v in self.inputs.items()}
            clear(self.fields_box); self.inputs={}
            for name in wanted:
                row=box(False); row.append(label(name))
                entry=Gtk.Entry(placeholder_text=name,hexpand=True); entry.set_text(previous.get(name,''))
                entry.connect('changed',lambda _:self.update_preview())
                entry.connect('activate',lambda _:self.paste())
                self.inputs[name]=entry; row.append(entry); self.fields_box.append(row)
        self.update_preview()

    def update_preview(self):
        self.preview.get_buffer().set_text(snippets.render(text(self.body),{k:v.get_text() for k,v in self.inputs.items()}))

    def save(self):
        try:
            data=dict(keyword=self.keyword.get_text(),name=self.name.get_text(),body=text(self.body))
            if self.item:data['id']=self.item['id']
            self.item=snippets.save(data); self.refresh(); self.status('문구를 저장했습니다.')
        except Exception as e:self.status(str(e))

    def delete(self):
        if self.item:
            snippets.remove(self.item['id']); self.select(None); self.refresh(); self.status('문구를 삭제했습니다.')

    def paste(self):
        if any(not v.get_text().strip() for v in self.inputs.values()):
            self.status('빈칸을 모두 채워 주세요.'); return
        self.update_preview(); self.window.paste_text(text(self.preview))
