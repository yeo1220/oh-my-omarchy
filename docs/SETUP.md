# 설치·백업·복원

기존 Omarchy 설치에 선택적으로 적용하는 사용자 설정입니다. `/usr/share/omarchy`를 수정하지 않습니다.

## 백업

적용할 설정은 먼저 별도 디렉터리에 백업합니다. 아래 예시는 음악 앰비언트만 설치합니다.

```bash
backup_dir="$HOME/.local/state/oh-my-omarchy/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir/scripts" "$backup_dir/systemd"
for name in music-ambient.py music-ambient.sh; do
  test ! -e "$HOME/.config/hypr/scripts/$name" || cp -a "$HOME/.config/hypr/scripts/$name" "$backup_dir/scripts/"
done
test ! -e "$HOME/.config/systemd/user/music-ambient.service" || cp -a "$HOME/.config/systemd/user/music-ambient.service" "$backup_dir/systemd/"
printf 'Backup: %s\n' "$backup_dir"
```

다른 기능도 대상 파일을 같은 방식으로 먼저 백업하세요. 기존에 없던 파일은 별도로 기록해 두어 복원 시 새로 설치한 파일만 제거합니다.

## 음악 앰비언트

필수: Python 3 + Pillow, `playerctl`, `hyprctl`, Omarchy CLI, 사용자 systemd 및 실행 중인 그래픽 세션. 로컬 오디오 커버 추출에는 `ffmpeg`가 필요합니다. Arch 패키지 이름은 `python-pillow`, `playerctl`, `ffmpeg`입니다.

기존 버전이 실행 중이면 먼저 `systemctl --user stop music-ambient.service`로 중지해 원래 배경을 복원합니다. 서비스가 아직 없다면 이 단계는 생략합니다.

```bash
mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/systemd/user"
install -m 755 config/hypr/scripts/music-ambient.py config/hypr/scripts/music-ambient.sh "$HOME/.config/hypr/scripts/"
install -m 644 config/systemd/user/music-ambient.service "$HOME/.config/systemd/user/"
systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
systemctl --user daemon-reload
systemctl --user enable --now music-ambient.service
```

`config/hypr/autostart.lua`의 앰비언트 시작 줄을 기존 `~/.config/hypr/autostart.lua`에 병합하면 세션 환경을 가져온 뒤 서비스를 시작합니다. 이미 있으면 중복 추가하지 않습니다.

```bash
systemctl --user status music-ambient.service
journalctl --user -u music-ambient.service -n 30
```

복원: 서비스를 중지·비활성화하고 백업한 스크립트·서비스를 원래 위치에 복사합니다. 이번에 처음 추가한 파일은 제거합니다. 추가한 autostart 줄도 제거한 뒤 `systemctl --user daemon-reload`를 실행하세요. `recovery.json`은 배경 복원이 완료되기 전에 지우지 마세요.

## 셸·테마·Hyprland

1. `~/.config/omarchy/`와 `~/.config/hypr/`에서 변경할 파일을 백업합니다.
2. 사용할 `config/omarchy/plugins/lovehouse.*` 폴더를 같은 사용자 설정 경로로 복사합니다.
3. `config/omarchy/shell.json`의 사용할 플러그인 항목을 현재 설정에 병합합니다. 플러그인과 셸 설정의 ID를 맞춥니다.
4. 테마는 `config/omarchy/themes/<이름>`을 `~/.config/omarchy/themes/`에, 추가 배경은 `config/omarchy/backgrounds/`를 대응 경로에 복사합니다.
5. `omarchy theme set graphite-atelier` 또는 `omarchy theme set midnight-orbit`으로 적용합니다.
6. Hyprland 설정은 모니터, 단축키 충돌, 음성 입력 요구사항을 확인한 뒤 필요한 부분을 병합하고 `hyprctl reload`, `hyprctl configerrors`로 확인합니다.

셸의 AI 표시에는 `bin/omarchy-agent-usage-*`가 필요합니다. 수집기는 사용자의 로컬 로그인 및 설치된 CLI를 사용하며 로그인 파일은 배포하지 않습니다. Gemini 수집기는 Antigravity CLI, Cursor 수집기는 Cursor CLI 로그인을 전제로 합니다.

## Orbit·원격 작업·기타 도구

- `apps/orbit-tools/` → `~/.local/share/oh-my-omarchy/orbit-tools/`
- 사용할 `bin/` 파일 → `~/.local/bin/` (실행 권한 유지, 이 경로를 PATH에 포함)
- `applications/` → `~/.local/share/applications/`
- `config/clipse/`, 터미널 폴더 → 각각 `~/.config/`의 대응 폴더
- Orbit UI: Python PyGObject + GTK 4. 클립보드: `wl-clipboard`, 입력: `wtype`, PDF 검색: `pdftotext`, 파일 공유: LocalSend. 창 미리보기에는 해당 Quickshell 플러그인이 필요합니다.
- 원격 작업: `examples/remote-work-hosts.json`을 `~/.config/remote-work/hosts.json`으로 복사하고 본인 장비명으로 수정합니다. Tailscale·SSH, RDP에는 FreeRDP가 필요합니다. 계정 파일은 Git에 넣지 않습니다.
- Voxtype: `large-v3-turbo` 모델 및 AMD Vulkan 바이너리 경로를 본인 설치에 맞춥니다. GPU override는 해당 환경에서만 설치합니다.
- `switch-view`: MS2109 캡처카드 경로와 오디오 소스를 본인 장치에 맞춥니다.
- 앱 업데이트·충돌 알림 스크립트는 기존 동작을 보존한 소스입니다. 이 저장소의 설치 과정에서 실행하지 않습니다.

기능별 설정을 되돌릴 때는 백업을 복사하고 해당 서비스/앱만 다시 불러옵니다. 셸 플러그인을 제거하면 `shell.json`의 참조도 함께 제거하세요.
