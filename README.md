# oh-my-omarchy

Omarchy 개인화 설정과 데스크톱 개선 모음. 현재 사용 중인 설정을 Git으로 관리하고, 필요한 기능만 선택해 가져올 수 있도록 정리했습니다.

## 포함된 개선

| 영역 | 내용 | 경로 |
| --- | --- | --- |
| 음악 앰비언트 | 커버 색상 기반 배경·테두리, 중지 후 원본 복원, 재시작 복구 | `config/hypr/scripts/`, `config/systemd/user/music-ambient.service` |
| 셸 플러그인 | AI 사용량, 배경 전환, Bluetooth, 유휴 동작, 상태 표시, 키보드 레이아웃, Orbit Desk, 창 미리보기 | `config/omarchy/plugins/` |
| 테마 | Graphite Atelier, Midnight Orbit, 추가 Champagne Ridge 배경 | `config/omarchy/themes/`, `config/omarchy/backgrounds/` |
| Hyprland | 단축키, 창 규칙, 모니터, 입력, 간격·테두리 | `config/hypr/` |
| Orbit Tools | 작업 환경 저장, 파일 선반, 창 보기, 붙여넣기, 문서 검색, 문구 입력 | `apps/orbit-tools/` |
| 음성 입력 | 한국어·영어 Voxtype 설정, 입력 중 modifier 오동작 방지, Vulkan 실행 | `config/voxtype/`, `config/hypr/voxtype.lua` |
| 터미널·클립보드 | Alacritty, Foot, Kitty, Ghostty, btop, clipse | `config/` |
| 보조 도구 | AI 사용량 수집, 앱 업데이트, 충돌 알림, 원격 작업, 캡처카드 보기 | `bin/` |

## 환경과 범위

- 2026-10-11에 Omarchy **4.0.4-1**의 사용자 설정을 수집했습니다.
- Lua 설정을 사용하는 Hyprland와 Quickshell 기반 Omarchy 환경을 대상으로 합니다. 이전 `.conf` 기반 버전용이 아닙니다.
- `lovehouse.*`는 플러그인 식별자입니다. 셸 설정과 일치해야 하므로 이름을 유지했습니다.
- 현재 프로필은 LG 1366×768 디스플레이, AMD Vulkan, 한국어·영어 입력에 맞춰져 있습니다.
- 유휴 자동 잠금은 현재 프로필에서 꺼져 있습니다(`idle.lock: false`). 적용 전 본인에게 맞게 조정하세요.
- 로컬 상태·인증정보·원격 계정·클립보드 기록·개인 문구·검색 색인·기존 백업은 포함하지 않습니다.
- 방송·게임 자동화 및 다른 프로젝트의 서비스는 Omarchy 개인화 범위에서 제외했습니다.

## 가져오기와 적용

```sh
git clone https://github.com/yeo1220/oh-my-omarchy.git
cd oh-my-omarchy
python3 tools/check.py
```

[설치·백업·복원 안내](docs/SETUP.md)를 보고 필요한 부분만 적용하세요. 전체 설정을 덮어쓰는 자동 설치는 제공하지 않습니다. **이 저장소를 만드는 과정에서는 실행 중인 데스크톱 설정을 변경하지 않았습니다.**

공개판에서는 홈 경로를 일반화했고, 원격 장비 목록을 `~/.config/remote-work/hosts.json`으로 분리했습니다. 예시는 `examples/remote-work-hosts.json`입니다. Orbit Tools 공개판 실행 경로는 `~/.local/share/oh-my-omarchy/orbit-tools/`입니다.

## 음악 앰비언트

재생 중인 MPRIS 플레이어를 `playerctl`로 감지합니다. 커버가 없으면 곡 제목으로 일관된 색상 그라데이션을 생성합니다. 모든 플레이어가 중지·일시정지되면 정상 폴링 시 약 2초 안에 배경을 복원합니다. 다른 플레이어가 계속 재생 중이면 효과가 유지됩니다.

원본 경로는 `~/.local/state/omarchy/music-ambient/recovery.json`에 저장하며, 서비스 재시작 시 남은 임시 배경을 복구합니다. 복원 시 `hyprctl reload`로 디스크에 저장된 Hyprland 설정을 다시 읽습니다. 설정 파일에 없는 임시 런타임 변경은 유지되지 않을 수 있습니다.

배경은 곡이 바뀔 때 생성되는 정적 이미지이며 오디오 파형/비트에 반응하는 시각화는 아닙니다. 포커스 모니터 해상도를 기준으로 생성하고 모든 모니터에 같은 배경을 사용합니다. 이전 구현 복구용 `FALLBACK`은 Graphite Atelier 배경입니다. 다른 환경에서는 설치 전에 경로를 조정하세요.

## 변경 관리

```sh
# 필요한 로컬 변경만 저장소의 대응 경로에 반영한 뒤 확인
python3 tools/check.py
git diff --check
git diff
# 검토한 파일 경로만 명시적으로 추가
git add config/hypr/scripts/music-ambient.py
git commit -m "fix(ambient): describe the change"
git push
```

홈 디렉터리 전체를 복사하거나 인증·상태 폴더를 추가하지 않습니다. 새 설정 파일은 해당 기능의 경로에 추가하고 의존성과 동작 변화를 함께 기록합니다. GitHub Actions에서 구문 검사와 Orbit/앰비언트 테스트를 실행합니다.

## 검증과 출처

- 이번 수집: Python·셸·JSON·TOML 검사, Orbit 단위 테스트, 앰비언트 복원 회귀 테스트.
- 2026-10-10 음악 앰비언트 작업: 실제 배경·테두리 적용/복원 및 정리 없이 종료한 다음 서비스 시작 시 복구 확인.
- 유튜브 탭 재생·종료 전체 흐름, 타 하드웨어 설치, 모든 플러그인의 GUI 동작을 이번 저장소 작업에서 재검증한 것은 아닙니다.

[변경 이력](CHANGELOG.md) · [상위 프로젝트 및 자산 출처](docs/PROVENANCE.md)
