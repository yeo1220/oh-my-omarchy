import datetime as dt
import re
import uuid
from .common import CONFIG, atomic_json, read_json, update_json

PATH = CONFIG / 'snippets.json'
FIELD = re.compile(r'\{\{([^{}\n]{1,40})\}\}')


def seed():
    if PATH.exists(): return
    examples=[
        ('date','오늘 날짜','{{date}}'),
        ('reply','답변 인사','안녕하세요, {{이름}}님.\n\n문의하신 {{주제}}에 대해 확인한 뒤 안내드리겠습니다.\n감사합니다.'),
        ('review','코드 리뷰 요청','다음 변경을 검토해 주세요.\n\n목적: {{목적}}\n확인할 항목: 오류 처리, 경계 조건, 기존 동작과의 호환성\n답변에는 문제 위치와 수정안을 함께 적어 주세요.'),
        ('meeting','회의 메모','{{date}} · {{제목}}\n\n참석자: {{참석자}}\n논의:\n- \n\n결정:\n- \n\n다음 할 일:\n- '),
        ('status','작업 상황 공유','진행한 작업: {{작업}}\n현재 상태: {{상태}}\n다음 단계: {{다음 단계}}')]
    atomic_json(PATH,[dict(id=uuid.uuid4().hex,keyword=k,name=n,body=b) for k,n,b in examples])


def all_snippets():
    seed(); return read_json(PATH,[])


def fields(body):
    return list(dict.fromkeys(x for x in FIELD.findall(body) if x not in ('date','time','datetime')))


def render(body, values, now=None):
    now=now or dt.datetime.now()
    builtins={'date':now.strftime('%Y-%m-%d'),'time':now.strftime('%H:%M'),'datetime':now.strftime('%Y-%m-%d %H:%M')}
    return FIELD.sub(lambda m:builtins.get(m[1],values.get(m[1],m[0])),body)


def save(item):
    item=dict(item)
    item['keyword']=item['keyword'].strip()
    if not re.fullmatch(r'[^\s]{1,40}',item['keyword']):
        raise ValueError('키워드는 공백 없이 1–40자로 입력하세요.')
    if not item['name'].strip() or not item['body']:
        raise ValueError('제목과 내용을 입력하세요.')
    if len(item['body'])>20000:
        raise ValueError('문구는 20,000자 이하로 입력하세요.')
    item.setdefault('id',uuid.uuid4().hex)
    def mutate(rows):
        if any(r['keyword'].casefold()==item['keyword'].casefold() and r['id']!=item['id'] for r in rows):
            raise ValueError('같은 키워드가 이미 있습니다.')
        rows[:]=[r for r in rows if r['id']!=item['id']]+[item]
    update_json(PATH,[],mutate)
    return item


def remove(item_id):
    update_json(PATH,[],lambda rows:rows.__setitem__(slice(None),[r for r in rows if r['id']!=item_id]))
