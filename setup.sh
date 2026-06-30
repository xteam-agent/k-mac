#!/bin/bash
# k-mac — opinionated Mac setup for Korean users
# https://github.com/djohnkang/k-mac
# Usage: curl -fsSL djohnkang.github.io/setup.sh | bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

confirm() {
    read -rp "$1 (Y/n) " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
}

echo ""
echo "========================================="
echo "  Fresh Mac Bootstrap"
echo "========================================="
echo ""

# macOS 버전 확인 (Ventura 13.0 이상 권장)
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 13 ]]; then
    warn "macOS $MACOS_VERSION 감지 — 이 스크립트는 Ventura(13.0) 이상을 권장합니다"
    confirm "계속 진행하시겠습니까?" || exit 0
else
    info "macOS $MACOS_VERSION"
fi

echo ""

# =========================================================
# Phase 1: macOS System Settings (no dependencies)
# =========================================================
echo "--- macOS 시스템 설정 ---"
echo ""

# 키보드
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
info "키보드 설정 완료 (빠른 반복, 자동교정 끔)"

# 마우스
defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0
defaults write com.apple.AppleMultitouchMouse MouseButtonMode -string "TwoButton"
defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode -string "TwoButton"
defaults write com.apple.AppleMultitouchMouse MouseOneFingerDoubleTapGesture -int 1
defaults write com.apple.driver.AppleBluetoothMultitouch.mouse MouseOneFingerDoubleTapGesture -int 1
info "마우스 설정 완료 (최고 속도, 보조 클릭, 스마트 줌)"

# Dock (기본 설정만 — 앱 정리는 Homebrew 설치 후 dockutil로 처리)
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
info "Dock 기본 설정 완료 (크기, 최근 항목 끔, 최소화 방식)"

# Finder
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Downloads/"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "glyv"
killall Finder 2>/dev/null || true
info "Finder 설정 완료 (Downloads, 경로막대, 상태막대, 갤러리 뷰)"

# 스크린샷
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
mkdir -p "${HOME}/Screenshots"
info "스크린샷 저장 위치: ~/Screenshots"

echo ""

# =========================================================
# Phase 2: Keyboard Remapping (sudo 필요)
# =========================================================
echo "--- 키보드 리매핑 (한/영 전환) ---"
echo ""

# hidutil 스크립트 생성 (Right Command → F18, Caps Lock → Ctrl)
# sudo 없이 사용자 레벨로 설치 — SIP 충돌 방지
mkdir -p ~/.local/bin
cat > ~/.local/bin/userkeymapping << 'SCRIPT'
#!/bin/bash
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x7000000e7,"HIDKeyboardModifierMappingDst":0x70000006d},
  {"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x7000000e0}
]}'
SCRIPT
chmod 755 ~/.local/bin/userkeymapping

# LaunchAgent (사용자 레벨)
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/userkeymapping.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>userkeymapping</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/Shared/bin/userkeymapping</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/userkeymapping.plist 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/userkeymapping.plist
~/.local/bin/userkeymapping > /dev/null 2>&1
info "키 리매핑 완료 (Right Cmd → F18, Caps Lock → Ctrl)"

# 입력 소스 전환 단축키 → F18
defaults write com.apple.symbolichotkeys.plist AppleSymbolicHotKeys -dict-add 61 \
  "<dict>
    <key>enabled</key><true/>
    <key>value</key><dict>
      <key>type</key><string>standard</string>
      <key>parameters</key><array>
        <integer>65535</integer>
        <integer>79</integer>
        <integer>0</integer>
      </array>
    </dict>
  </dict>"

# 변경 즉시 반영
ACTIVATE="/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
if [[ -x "$ACTIVATE" ]]; then
    "$ACTIVATE" -u
    info "입력 소스 단축키 → F18 완료"
else
    warn "activateSettings 없음 — 입력 소스 단축키를 수동 설정하세요"
    open "x-apple.systempreferences:com.apple.Keyboard"
    echo "  → 키보드 단축키 > 입력 소스 > F18 지정"
fi

echo ""

# =========================================================
# Phase 3: Homebrew
# =========================================================
echo "--- Homebrew ---"
echo ""

if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

if command -v brew &>/dev/null; then
    info "Homebrew 이미 설치됨"
else
    echo "Homebrew 설치 중..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || fail "Homebrew 설치 실패"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    info "Homebrew 설치 완료"
fi

echo ""

# =========================================================
# Phase 3.5: Dock 앱 정리 (dockutil — macOS 버전 무관하게 안정적)
# =========================================================
echo "--- Dock 앱 정리 ---"
echo ""

brew install dockutil 2>/dev/null || true

if command -v dockutil &>/dev/null; then
    dockutil --remove all --no-restart 2>/dev/null || true

    for app in \
        "/System/Applications/Messages.app" \
        "/System/Applications/Calendar.app"; do
        if [[ -d "$app" ]]; then
            dockutil --add "$app" --no-restart 2>/dev/null || true
        fi
    done

    # macOS 13+ 은 System Settings, 이전 버전은 System Preferences
    if [[ -d "/System/Applications/System Settings.app" ]]; then
        dockutil --add "/System/Applications/System Settings.app" --no-restart 2>/dev/null || true
    elif [[ -d "/System/Applications/System Preferences.app" ]]; then
        dockutil --add "/System/Applications/System Preferences.app" --no-restart 2>/dev/null || true
    fi

    killall Dock 2>/dev/null || true
    info "Dock 정리 완료 (Messages, Calendar, System Settings)"
else
    warn "dockutil 설치 실패 — Dock 앱을 수동으로 정리하세요"
fi

echo ""

# =========================================================
# Phase 4: 기본 앱 설치 (bundles)
# =========================================================
echo "--- 기본 앱 설치 ---"
echo ""

try_install() {
    local label="$1"; shift
    if "$@" 2>/dev/null; then
        info "$label 설치 완료"
    else
        warn "$label 설치 실패 — 나중에 수동으로 설치하세요"
    fi
}

# 브라우저
if confirm "브라우저 설치? (Chrome)"; then
    try_install "Chrome" brew install --cask google-chrome
else
    warn "브라우저 설치 건너뜀"
fi

# 터미널
if confirm "터미널 설치? (iTerm2)"; then
    try_install "iTerm2" brew install --cask iterm2
else
    warn "터미널 설치 건너뜀"
fi

# 개발 도구
if confirm "개발 도구 설치? (GitHub CLI - gh)"; then
    try_install "GitHub CLI (gh)" brew install gh
else
    warn "GitHub CLI 설치 건너뜀"
fi

# 런처
if confirm "런처 설치? (Raycast)"; then
    try_install "Raycast" brew install --cask raycast
else
    warn "런처 설치 건너뜀"
fi

# AI 도구
if confirm "AI 도구 설치? (Claude, Claude Code, ChatGPT, Codex, Gemini CLI)"; then
    try_install "Claude"      brew install --cask claude
    try_install "Claude Code" brew install --cask claude-code
    try_install "ChatGPT"     brew install --cask chatgpt
    try_install "Codex (CLI)" brew install --cask codex
    try_install "Codex (App)" brew install --cask codex-app
    try_install "Gemini CLI"  brew install gemini-cli
else
    warn "AI 도구 설치 건너뜀"
fi

echo ""

# =========================================================
# Phase 5: Git 기본 설정
# =========================================================
echo "--- Git 기본 설정 ---"
echo ""

if [[ -f "$HOME/.gitconfig" ]]; then
    warn ".gitconfig 이미 존재함 — 건너뜀"
else
    read -rp "  이름 (git commit에 사용): " git_name
    read -rp "  이메일 (회사 이메일 권장): " git_email
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    info "Git 설정 완료 ($git_name <$git_email>)"
fi

echo ""

# =========================================================
# Phase 6: GitHub CLI 인증
# =========================================================
if command -v gh &>/dev/null; then
    echo "--- GitHub CLI 인증 ---"
    echo ""
    if gh auth status &>/dev/null; then
        info "GitHub CLI 이미 인증됨"
    else
        echo "  GitHub 계정 연결이 필요합니다."
        gh auth login
    fi
    echo ""
fi

echo "========================================="
echo "  Bootstrap 완료!"
echo "========================================="
echo ""
echo "  개발 환경 설정이 필요하다면 dotfiles 설정을 이어서 실행하세요:"
echo "  curl -fsSL https://raw.githubusercontent.com/x-team-dev/dotfiles/main/install.sh | bash"
echo ""
