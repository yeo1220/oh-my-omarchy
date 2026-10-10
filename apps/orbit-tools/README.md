# Orbit Tools

Lovehouse의 Omarchy에 추가한 여섯 가지 데스크톱 유틸입니다.
**상단 바 ◉ Orbit → Orbit Tools** 또는 앱 메뉴에서 **Orbit**를 검색해 실행합니다.
추가 패키지 설치 없이 현재 시스템의 GTK 4, Quickshell, Hyprland, Python으로 구현했습니다.

| 순서 | 기능 | 단축키 | 터미널 명령 |
|---|---|---|---|
| 1 | 작업 환경 저장·복원 | Super + Ctrl + Alt + 1 | `orbit-tools scenes` |
| 2 | 파일 선반 | Super + Ctrl + Alt + 2 | `orbit-tools shelf` |
| 3 | 전체 창 미리보기 | Super + Ctrl + Alt + 3 | `orbit-tools overview` |
| 4 | 똑똑한 붙여넣기 | Super + Ctrl + Alt + 4 | `orbit-tools paste` |
| 5 | 문서 통합 검색 | Super + Ctrl + Alt + 5 | `orbit-tools search` |
| 6 | 문구 자동 입력 | Super + Ctrl + Alt + 6 | `orbit-tools snippets` |

기존 Orbit Desk 단축키 **Super + Ctrl + Shift + O**는 그대로 사용할 수 있습니다.

## 1. 작업 환경 저장·복원

‘개발 / 원격 / 방송’ 프리셋을 제공하며, 이름을 입력하고 **현재 창 구성 저장**을 누르면
자신만의 구성을 추가할 수 있습니다. 현재 작업 공간만 저장할 수도 있습니다.

- 개발: 터미널·Chromium → 2, 작업 폴더 → 3
- 원격: 기존 원격 작업 선택 도구·Chromium → 4
- 방송: OBS·Chromium → 5. 방송 시작/종료 버튼은 자동으로 누르지 않습니다.
- 같은 세션에서는 창의 고유 ID로 찾아 제목이 바뀌어도 복원합니다.
- 앱이 닫혀 있으면 지원하는 앱을 다시 실행합니다. 현재 지원 목록은 Foot,
  Alacritty, Kitty, Ghostty, Chromium, Nautilus, OBS입니다.
- 타일 창은 작업 공간을 복원하고 Hyprland가 배치합니다. 분할 트리와 비율을 완전히
  재현하지는 않습니다. 떠 있는 창은 좌표·크기와 전체 화면 상태를 복원합니다.
- 브라우저 탭·편집 중인 문서·터미널 내부 프로세스는 저장하지 않습니다.
  지원하지 않는 닫힌 앱은 건너뛰고 결과에 표시합니다.
- **직전 복원 전 상태로 돌아가기**는 기존 창의 배치를 돌려놓습니다.
  복원 도중 새로 연 앱은 닫지 않습니다.

## 2. 파일 선반

파일 관리자에서 파일·폴더를 끌어다 놓거나, **파일 추가 / 폴더 추가**로 선택합니다.
웹 주소는 입력창에 넣거나 링크를 드래그합니다.

체크한 항목을 **선택 파일을 여기서 드래그** 버튼에서 다른 앱으로 끌어갈 수 있습니다.
**선택 항목 ZIP**은 `~/Downloads`에 새 ZIP을 생성합니다.
**선택 항목 공유**는 LocalSend의 수신 기기 선택 화면으로 연결합니다.
파일과 링크를 함께 공유하면 ZIP으로 묶습니다.

선반은 원본 경로를 기억합니다. **선반에서 제거**해도 원본은 지워지지 않습니다.
원본 파일을 다른 곳으로 옮기면 새 경로로 다시 추가하세요.
압축은 10,000개 파일 / 2GB까지 지원하며, 디렉터리 안의 심볼릭 링크는 따라가지 않습니다.

## 3. 전체 창 미리보기

실시간 창 미리보기에서 클릭하거나 제목·앱 이름을 검색해 **Enter**로 전환합니다.
위쪽 숫자를 누르면 해당 작업 공간의 창만 보여 줍니다.
창을 위쪽 **1–10** 버튼으로 드래그하면 그 작업 공간으로 이동합니다.
**Esc**로 닫습니다. 미리보기는 파일로 저장하지 않습니다.

## 4. 똑똑한 붙여넣기

**클립보드 가져오기** 또는 **HTML 가져오기** → 형식 선택 → **변환** 순서로 사용합니다.
결과는 수정한 뒤 복사, 파일 저장, 이전 창에 붙여넣기가 가능합니다.

지원 형식: 서식 없는 텍스트, JSON 정리·압축, HTML→Markdown, HTML→텍스트,
CSV/TSV→Markdown 표. 기본 제목·강조·링크·목록을 지원하며 웹 레이아웃 전체를 변환하지는 않습니다.

**이전 창에 붙여넣기**는 유틸을 열기 전의 창을 확인하고 그곳으로 포커스를 돌립니다.
대상 창이 사라졌다면 복사만 합니다. 터미널에는 Ctrl+Shift+V, 일반 앱에는 Ctrl+V를 보냅니다.
자체 붙여넣기 단축키가 다른 앱은 **결과 복사** 후 해당 앱의 단축키를 사용하세요.
자동 입력 직전에 다른 창으로 포커스를 바꾸면 입력을 중단하고 클립보드에만 남깁니다.

## 5. 문서 통합 검색

기본 검색 폴더는 `~/Documents`, `~/Work`, `~/Downloads`입니다.
파일명·폴더명·설치된 앱과 문서 내용을 검색합니다.
**폴더 추가 / 검색 범위에서 제외**로 범위를 조정할 수 있습니다.

- 텍스트·Markdown·코드·PDF·DOCX의 내용을 검색합니다.
- 두 글자 이상 한글 부분 검색을 지원합니다. 한 글자는 파일명만 검색합니다.
- PDF는 첫 100쪽, 문서는 최대 20MB 파일에서 최대 2MB의 텍스트를 색인합니다.
- 이미지로만 된 PDF에는 OCR을 실행하지 않습니다.
- 숨김 폴더, node_modules, 가상 환경, 빌드 결과, 백업 폴더는 제외합니다.
- 검색을 열 때 마지막 색인 후 5분이 지났으면 갱신합니다. **색인 갱신**으로 즉시 반영할 수도 있습니다.
- 로컬 SQLite 색인을 사용하며 검색 내용을 외부 서버로 보내지 않습니다.

## 6. 문구 자동 입력

단축키로 열고 `date`, `reply`, `review`, `meeting`, `status` 같은 키워드를 입력합니다.
**Enter**를 누르면 일치하는 문구를 선택합니다. 빈칸이 없으면 이전 앱에 바로 입력합니다.
빈칸이 있으면 값을 채우고 **이전 앱에 입력**을 누릅니다.

**새 문구**에서 제목·키워드·내용을 저장할 수 있습니다.
`{{이름}}`은 입력할 빈칸, `{{date}}`, `{{time}}`, `{{datetime}}`은 자동 값입니다.
문구 내용이나 빈칸을 코드·명령으로 실행하지 않습니다.

이 기능은 **단축키 → 키워드 → Enter** 방식입니다.
모든 앱의 키 입력을 상시 감시해 `;email` 같은 문자열을 자동 치환하는 데몬은 설치하지 않았습니다.

## 저장 위치와 유지 관리

- 소스: `~/.local/share/oh-my-omarchy/orbit-tools/`
- 설정: `~/.config/orbit-tools/` — 검색 폴더와 문구
- 상태: `~/.local/state/orbit-tools/` — 작업 환경, 선반, 검색 색인
- 전체 창 플러그인: `~/.config/omarchy/plugins/lovehouse.overview/`
- 실행 명령: `~/.local/bin/orbit-tools`
- 이전 단독 설치의 설정 백업: `~/.local/share/oh-my-omarchy/orbit-tools/backups/`

Omarchy 패키지 파일은 수정하지 않았습니다. 테마 색상은 앱을 다시 열 때 반영되며,
전체 창 보기와 Orbit Desk는 셸 테마를 따릅니다.

앱 종료: `orbit-tools --quit`

이 저장소에서는 루트 README의 백업·복원 절차를 사용합니다.

## 검증

`/usr/bin/python3 ~/.local/share/oh-my-omarchy/orbit-tools/tests/test_tools.py` — 25개 단위 테스트.

실제 데스크톱에서 추가로 검증한 항목:

- 검증용 창의 작업 공간·떠 있는 크기 복원
- 네이티브 파일 드래그 제공 데이터와 JSON 미리보기
- 문구 선택·빈칸·입력 미리보기
- 임시 GTK 앱에 한글·여러 줄 텍스트를 실제 붙여넣기
- 다른 작업 공간에 있는 창의 검색·Enter 전환·작업 공간 이동
- Hyprland 설정 오류 없음, 6개 단축키 등록, 기존 Orbit Desk 상태 유지

LocalSend의 실제 전송은 수신 기기를 선택하는 사용자 동작이 필요하므로 전송하지 않았습니다.

구현 시 참고한 공식 API: [Hyprland Dispatchers](https://wiki.hypr.land/Configuring/Basics/Dispatchers/),
[Window Rules](https://wiki.hypr.land/Configuring/Basics/Window-Rules/),
[Quickshell ScreencopyView](https://master.quickshell.org/docs/types/Quickshell.Wayland/ScreencopyView).
