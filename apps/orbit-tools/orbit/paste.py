import csv
import io
import json
import re
from html.parser import HTMLParser
from pathlib import Path


class HtmlText(HTMLParser):
    def __init__(self, markdown=False):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.markdown = markdown
        self.skip = 0
        self.links = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'style'):
            self.skip += 1
        if self.skip:
            return
        if tag in ('p', 'div', 'br', 'tr', 'section'):
            self.parts.append('\n')
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            self.parts.append('\n' + ('#' * int(tag[1]) + ' ' if self.markdown else ''))
        if tag == 'li':
            self.parts.append('\n- ')
        if self.markdown:
            if tag in ('strong', 'b'): self.parts.append('**')
            if tag in ('em', 'i'): self.parts.append('*')
            if tag == 'code': self.parts.append('`')
            if tag == 'a':
                href = attrs.get('href', '')
                self.links.append(href if re.match(r'^(https?://|mailto:|/|#)', href) else '')
                self.parts.append('[')

    def handle_endtag(self, tag):
        if tag in ('script', 'style'):
            self.skip = max(0, self.skip - 1)
            return
        if self.skip:
            return
        if tag in ('p', 'div', 'tr', 'section', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            self.parts.append('\n')
        if self.markdown:
            if tag in ('strong', 'b'): self.parts.append('**')
            if tag in ('em', 'i'): self.parts.append('*')
            if tag == 'code': self.parts.append('`')
            if tag == 'a' and self.links:
                href = self.links.pop().replace(')', '%29').replace(' ', '%20')
                self.parts.append('](' + href + ')' if href else ']')

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)

    def output(self):
        return re.sub(r'\n[ \t]*\n(?:[ \t]*\n)+', '\n\n', ''.join(self.parts)).strip()


def transform(value, mode):
    if len(value.encode()) > 4 * 1024**2:
        raise ValueError('텍스트 변환은 최대 4MB까지 지원합니다.')
    if mode == 'plain':
        return value
    if mode in ('json', 'compact'):
        data = json.loads(value)
        return json.dumps(data, ensure_ascii=False, indent=2 if mode == 'json' else None,
                          separators=None if mode == 'json' else (',', ':'))
    if mode in ('html-text', 'markdown'):
        parser = HtmlText(mode == 'markdown'); parser.feed(value); return parser.output()
    if mode == 'table':
        dialect = '\t' if '\t' in value.split('\n')[0] else ','
        rows = list(csv.reader(io.StringIO(value), delimiter=dialect))
        if not rows:
            return ''
        width = max(map(len, rows))
        if width > 100 or len(rows) > 10000:
            raise ValueError('표가 너무 큽니다.')
        def line(row):
            cells = [c.replace('|', '\\|').replace('\n', '<br>') for c in row] + [''] * (width - len(row))
            return '| ' + ' | '.join(cells) + ' |'
        return '\n'.join([line(rows[0]), line(['---'] * width), *[line(r) for r in rows[1:]]])
    raise ValueError('알 수 없는 변환 형식입니다.')
