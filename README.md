<img src="docs/icon.png" width="128" alt="VideoGrab 아이콘">

# VideoGrab

[![최신 릴리스](https://img.shields.io/github/v/release/sudapeople/videograb)](https://github.com/sudapeople/videograb/releases/latest)
[![릴리스 날짜](https://img.shields.io/github/release-date/sudapeople/videograb)](https://github.com/sudapeople/videograb/releases/latest)
[![다운로드 수](https://img.shields.io/github/downloads/sudapeople/videograb/total)](https://github.com/sudapeople/videograb/releases)
[![라이선스](https://img.shields.io/github/license/sudapeople/videograb)](LICENSE)<br>
[![플랫폼](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20Apple%20Silicon-blue?logo=apple)](#내려받기)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](#빌드설치)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF?logo=swift&logoColor=white)](src/VideoGrab.swift)
[![yt-dlp 기반](https://img.shields.io/badge/powered%20by-yt--dlp-blueviolet)](https://github.com/yt-dlp/yt-dlp)
[![Homebrew](https://img.shields.io/badge/Homebrew-yt--dlp%20%7C%20ffmpeg%20%7C%20deno-FBB040?logo=homebrew&logoColor=white)](#필요한-것)
![Made in Korea](https://img.shields.io/badge/Made%20in-Korea-CD2E3A?labelColor=0047A0)<br>
[![GitHub 스타](https://img.shields.io/github/stars/sudapeople/videograb?style=flat)](https://github.com/sudapeople/videograb/stargazers)
[![포크](https://img.shields.io/github/forks/sudapeople/videograb?style=flat)](https://github.com/sudapeople/videograb/forks)
[![방문자 수](https://hits.sh/github.com/sudapeople/videograb.svg?label=visitors&color=007ec6)](https://hits.sh/github.com/sudapeople/videograb/)
[![마지막 커밋](https://img.shields.io/github/last-commit/sudapeople/videograb)](https://github.com/sudapeople/videograb/commits/main)
[![이슈](https://img.shields.io/github/issues/sudapeople/videograb)](https://github.com/sudapeople/videograb/issues)
[![주 언어](https://img.shields.io/github/languages/top/sudapeople/videograb)](src)<br>
[![Discord](https://img.shields.io/discord/1321141059753086996?style=flat&logo=discord&logoColor=white&label=Discord&color=5865F2)](https://discord.gameboy.kr)
[![YouTube](https://img.shields.io/badge/YouTube-%EC%88%98%EB%8B%A4%20SUDA-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/channel/UCcm7Jc50537eMixvkVNU8-Q)
[![치지직](https://img.shields.io/badge/CHZZK-%EC%88%98%EB%8B%A4%20SUDA-00FFA3)](https://chzzk.naver.com/bcf71dbdafcdddae524d82490db546c0)
[![Instagram](https://img.shields.io/badge/Instagram-%40sudapeople-E4405F?logo=instagram&logoColor=white)](https://www.instagram.com/sudapeople/)
[![X](https://img.shields.io/badge/X-%40sudapeople-000000?logo=x&logoColor=white)](https://x.com/sudapeople)

한국어 | [English](#english)

유튜브·인스타그램·X 영상 링크를 복사한 뒤 창에서 `⌘V` 를 누르면 최고 화질로 바로 받는 맥 앱.
4K Video Downloader+ 의 "스마트 모드(붙여넣기 한 번에 정해진 설정으로 저장)" 만 떼어 낸 것이다.
유튜브 채널을 등록해 두면 채널 영상을 한꺼번에 받거나, 새로 올라오는 영상을 자동으로 받는다.

- 화질 : 항상 최고 화질 영상 + 최고 음질 오디오 (`bv*+ba/b`). 4K·8K·HDR·60fps 그대로
- 파일명 : 영상 제목 그대로 (`제목.mp4`). 인스타그램·X 는 제목이 서로 겹쳐서 `제목 [영상ID].mp4`
- 저장 위치 : 창 아래 "저장 위치 변경…" 으로 바꾼다. 기본값 `~/Downloads`
- 컨테이너 : mp4 (코덱은 원본 그대로, 다시 인코딩하지 않는다)

| 처음 화면 | 받는 중 |
|---|---|
| ![처음 화면](docs/screenshots/empty.png) | ![받는 중](docs/screenshots/downloading.png) |

## 내려받기

[최신 릴리스](https://github.com/sudapeople/videograb/releases/latest) 에서 `VideoGrab-버전-arm64.zip` 을 받는다.
macOS 14 이상, Apple Silicon (M1 이상).

1. 압축을 풀고 `VideoGrab.app` 을 응용 프로그램 폴더로 옮긴다
2. 받기 도구를 설치한다 (아래 "필요한 것" 참고)

```bash
brew install yt-dlp ffmpeg deno
```

3. 공증(notarization)을 받지 않은 앱이라 처음 열 때 macOS 가 막는다. 둘 중 하나로 연다
   - 시스템 설정 > 개인정보 보호 및 보안 에서 "그래도 열기"
   - 터미널에서 `xattr -dr com.apple.quarantine /Applications/VideoGrab.app`

## 사용법

1. 브라우저에서 유튜브 영상, 인스타그램 릴스·영상, X 영상 글의 주소를 복사한다 (주소창, 공유 버튼, 글 속 링크 모두 됨)
2. VideoGrab 창에서 `⌘V` (또는 툴바의 붙여넣기 버튼)
3. 끝나면 돋보기 버튼으로 Finder 에서 파일을 바로 연다

그 밖의 동작

- 클립보드에 링크가 여러 개면 모두 동시에 받는다
- `watch?v=...&list=...` 처럼 재생목록이 붙은 링크도 그 영상 하나만 받는다
- 이미 받은 파일이 있으면 다시 받지 않고 바로 "완료" 로 표시한다
- 취소하면 받던 조각(`.part`)은 남는다. "다시 받기" 를 누르면 이어서 받는다
- 링크가 없으면 경고음만 난다
- 그 밖에 yt-dlp 가 지원하는 사이트(치지직, 트위치 등)도 그대로 된다
- 그냥 받기에 실패하면 크롬에 로그인된 쿠키를 쓰고 크롬인 척 접속해 한 번 더 받는다. 로그인해야 보이는 영상, 봇 차단 사이트도 이렇게 받힌다
  (처음 한 번 macOS 가 키체인의 "Chrome Safe Storage" 접근을 묻는다. "항상 허용" 을 누르면 다음부터 묻지 않는다)
- 재생 버튼을 누르거나 광고가 끝나야 영상 주소가 생기는 페이지는 받지 못한다 (페이지를 읽기만 하고 실행하지는 않는다)
- 인스타그램은 영상·릴스 주소 하나씩만 받는다. 계정을 등록해 새 글을 자동으로 받는 기능은 없다
  (yt-dlp 의 인스타그램 계정 목록 기능이 동작하지 않는다)

### 유튜브 채널 관리

채널은 영상 받기와 따로, "채널 관리" 창에서 다룬다. 툴바의 채널 버튼이나 `⌘2` 로 연다.

![채널 관리 창](docs/screenshots/channels.png)

- 추가 : `+` 를 누르고 채널 주소(`youtube.com/@이름`, `youtube.com/channel/UC...`)와 저장 폴더를 정한다.
  메인 창에 채널 주소를 붙여넣어도 이 추가 창이 주소가 채워진 채로 뜬다
- 삭제 : 채널을 고르고 휴지통 버튼(또는 `delete` 키). 받은 파일은 그대로 남는다
- 저장 폴더 : 채널마다 따로 정한다. 기본값은 `저장 위치/채널 이름` 이고 언제든 바꿀 수 있다
- 새 영상 자동 받기 : 채널마다, 종류별로 켜고 끈다. 종류는 동영상(롱폼), 쇼츠(숏폼), 라이브(지난 방송) 세 가지다.
  예를 들어 쇼츠만 켜 두면 새 쇼츠만 받는다. 등록한 뒤에 올라온 영상만 받고, 등록할 때 이미 있던 영상은 받지 않는다.
  앱을 꺼 둔 사이 올라온 영상은 다음에 켤 때 받는다 (종류마다 최신 30개까지)
- 전체 받기 : 종류별 버튼(동영상 전체, 쇼츠 전체, 라이브 전체)으로 그 종류만 차례로 받는다.
  받은 영상은 기록해 두므로 중간에 취소하고 다시 눌러도 이어서 받는다
- 방송 중이거나 예정인 라이브는 끝난 뒤 다음 확인 때 받는다

### 설정

앱 메뉴의 "설정…" (`⌘,`) 또는 툴바의 톱니바퀴.

- 저장 위치 : 주소를 붙여넣어 받는 영상을 저장하는 곳
- 새 영상 확인 : 15분, 30분(기본값), 1시간, 3시간마다 또는 "자동으로 확인 안 함"
- 상단바에서 계속 실행, 로그인할 때 자동으로 실행, 채널 영상을 받으면 알림 (모두 기본값 꺼짐. 아래 참고)
- 앱 업데이트 : 새 버전이 있으면 알림(기본값), 자동으로 설치, 확인 안 함 (아래 참고)
- 받기 도구 : yt-dlp, ffmpeg, deno 가 설치되어 있는지와 yt-dlp 버전을 보여 주고, "yt-dlp 업데이트" 버튼이 있다

### 업데이트

앱을 켤 때와 켜 둔 동안 하루에 한 번 GitHub 릴리스의 최신 버전을 확인한다.
앱 메뉴의 "업데이트 확인…" 이나 설정의 "지금 확인" 으로 바로 볼 수도 있다.

- 새 버전이 있으면 알림 (기본값) : 설정 창, 메인 창 아래, 상단바 메뉴에 "새 버전 설치" 버튼이 생긴다
- 자동으로 설치 : 받는 중인 영상이 없고 창이 모두 닫혀 있을 때 스스로 설치하고 다시 켠다.
  창이 열려 있으면 닫을 때까지 미룬다 (앱을 막 켠 1분 안에는 바로 설치한다)
- 설치 과정 : zip 을 받아 SHA-256 을 릴리스의 값과 대조하고, 서명을 확인한 뒤 앱을 바꾸고 다시 켠다.
  바꾸다 실패하면 원래 앱으로 되돌린다
- 공증을 받지 않은 앱이라 "누가 만든 파일인지" 는 확인하지 못한다. 그래서 기본값은 자동 설치가 아니라 알림이다
- 켜 둔 동안 디스크의 앱이 바뀌면 (`./scripts/build.sh install`, Finder 로 덮어쓰기 등) 새 앱으로 다시 켠다.
  자동 설치와 같은 기준으로 받는 중이거나 창이 열려 있으면 미룬다. "상단바에서 계속 실행" 이 꺼져 있으면
  창을 닫을 때 앱이 끝나므로 다시 켜지 않는다 (다음에 켤 때 새 앱이 열린다)
- yt-dlp 업데이트 : 유튜브가 바뀌어 갑자기 안 받아지면 설정의 "yt-dlp 업데이트" 를 누른다.
  Homebrew 의 `brew upgrade yt-dlp` 를 실행한다

### 상단바에서 계속 실행

새 영상 확인은 앱이 켜져 있어야 돈다. 창을 닫아 두고도 계속 받으려면 설정에서 "상단바에서 계속 실행" 을 켠다.

- 창을 모두 닫아도 앱이 끝나지 않고 상단바 아이콘으로 남는다. Dock 아이콘은 창이 열려 있을 때만 보인다
- 상단바 메뉴 : 지금 상태(받는 중 개수, 마지막 확인 시각), VideoGrab 열기, 채널 관리, 지금 새 영상 확인,
  최근 받은 영상(누르면 Finder 에서 보여 줌), 설정, 종료
- 받는 중에는 아이콘이 채워진 모양으로 바뀐다
- "로그인할 때 자동으로 실행" 을 같이 켜면 로그인할 때 창 없이 상단바로 시작한다.
  macOS 의 로그인 항목(시스템 설정 > 일반 > 로그인 항목)에 등록되고, 끄면 지워진다
- "채널 영상을 받으면 알림" 을 켜면 새 영상을 받았을 때, 전체 받기를 마쳤을 때, 받지 못했을 때 알림을 낸다
- 확인에 실패하면(네트워크 끊김 등) 주기를 기다리지 않고 5분 뒤에 다시 확인한다

### 리소스

새 영상 자동 받기는 앱이 켜져 있는 동안에만 돌고, 쓰지 않을 때는 아무것도 돌리지 않는다.

- 따로 도는 백그라운드 서비스가 없다. "상단바에서 계속 실행" 을 켜도 떠 있는 것은 앱 하나뿐이고,
  꺼 두면 창을 모두 닫을 때 앱이 끝난다
- 확인할 채널이 없거나 확인을 꺼 두면 타이머도 없다. 있을 때도 확인 주기마다 한 번만 깨어난다.
  상단바에서 기다리는 동안 CPU 는 쓰지 않고, 메모리는 100MB 안팎이다
- 새 영상은 한 번에 하나씩 받는다
- 앱을 끝내면 받고 있던 yt-dlp 와 ffmpeg 를 모두 멈춘다. 받던 조각(`.part`)은 남아서 다음에 이어 받는다
- 앱이 강제 종료되거나 죽어서 yt-dlp 가 남았으면, 다음에 켤 때 찾아서 멈춘다
- 채널 확인에는 시간 제한(2분)이 있어, 응답 없는 서버에 매달린 프로세스가 남지 않는다
- 끝난 항목은 최근 200개만 목록에 남긴다
- 업데이트 확인은 하루에 한 번만 깨어나고, 꺼 두면 돌지 않는다. 설치할 때 쓴 임시 파일은 끝나면 지운다

## 필요한 것

Homebrew 로 설치된 도구 3개를 쓴다. 앱 안에 넣지 않은 이유는 유튜브가 자주 바뀌어
yt-dlp 를 자주 갱신해야 하기 때문이다.

```bash
brew install yt-dlp ffmpeg deno
```

- `yt-dlp` : 유튜브 주소 해석·다운로드
- `ffmpeg` : 영상·오디오 합치기
- `deno` : 유튜브 서명 해독용 자바스크립트 실행기 (yt-dlp 가 자동으로 씀)

유튜브에서 갑자기 안 받아지면 먼저 갱신한다. 설정 창의 "yt-dlp 업데이트" 버튼이 같은 일을 한다.

```bash
brew upgrade yt-dlp
```

## 빌드·설치

Xcode 프로젝트 없이 `swiftc` 한 번으로 빌드한다. macOS 14 이상, Apple Silicon, Swift 5.9 이상(Xcode 15 이상). Swift 6.4.2 로 시험했다.

```bash
./scripts/build.sh
```

```bash
./scripts/build.sh install
```

`install` 을 붙이면 `/Applications/VideoGrab.app` 으로 복사한다.
서명은 애드혹(`codesign -s -`)이라 이 맥에서만 쓰는 용도다.

```bash
./scripts/build.sh zip
```

`zip` 을 붙이면 릴리스에 올릴 `build/VideoGrab-<버전>-arm64.zip` 을 만들고 SHA-256 을 출력한다.
버전은 `src/Info.plist` 의 `CFBundleShortVersionString` 을 따르고,
zip 안에는 `VideoGrab-<버전>/` 폴더에 `VideoGrab.app` 과 `LICENSE` 가 들어간다.
새 버전을 낼 때는 이렇게 한다.

1. `src/Info.plist` 의 `CFBundleShortVersionString` 과 `CFBundleVersion` 을 올린다
2. `./scripts/build.sh zip`
3. `gh release create v<버전> build/VideoGrab-<버전>-arm64.zip`

## 폴더 구조

```
videograb/
├── README.md                 이 문서
├── LICENSE                   MIT 라이선스
├── docs/
│   ├── 01-4K-Video-Downloader-분석.md   원본 앱 분석 기록
│   ├── 02-설계와-검증.md                설계 결정과 시험 결과
│   ├── icon.png                         README 용 아이콘
│   ├── social-preview.png               GitHub 대표 이미지 (링크 공유 때 표시)
│   └── screenshots/                     README 용 화면
├── src/
│   ├── VideoGrab.swift       앱 전체 (SwiftUI, 약 1500줄)
│   └── Info.plist
├── scripts/
│   ├── build.sh              빌드·설치·릴리스 zip
│   ├── make-icon.swift       아이콘 생성
│   └── make-social-preview.swift  대표 이미지 생성
└── build/                    빌드 산출물 (지워도 다시 만들어짐)
```

## 설정 저장 위치

설정 창의 값은 `defaults read com.sudapeople.videograb` 로 볼 수 있다
(`outputDir` 저장 위치, `checkMinutes` 새 영상 확인 주기, `keepInMenuBar` 상단바에서 계속 실행,
`notifyNew` 알림, `updateMode` 앱 업데이트: 0 확인 안 함, 1 알림, 2 자동 설치). 값을 지우면 기본값으로 돌아간다.

등록한 채널은 `~/Library/Application Support/VideoGrab/channels.json` 에,
채널별로 받은 영상 기록은 같은 폴더의 `채널ID.txt` 에 남는다.

## 라이선스

[MIT](LICENSE). 자유롭게 쓰고 고치고 배포할 수 있다.

앱이 불러 쓰는 yt-dlp(Unlicense), FFmpeg(LGPL/GPL), Deno(MIT)는 앱에 들어 있지 않고
사용자가 Homebrew 로 따로 설치하므로 각자의 라이선스를 따른다.
영상을 받을 때는 각 서비스의 이용약관과 저작권을 지켜야 한다.

---

## English

A macOS app that downloads a YouTube, Instagram or X video in the best available quality the moment you press `⌘V` in its window.
It is a minimal take on the "Smart Mode" of 4K Video Downloader+ (paste once, save with preset settings).
Register a YouTube channel to download all of its videos, or to download new uploads automatically.

- Quality : always the best video stream + best audio stream (`bv*+ba/b`). 4K, 8K, HDR and 60fps are kept as is
- File name : the video title (`Title.mp4`). Instagram and X titles collide, so those use `Title [video id].mp4`
- Save location : change it with the "저장 위치 변경…" (Change location) button at the bottom. Default is `~/Downloads`
- Container : mp4 (original codecs, no re-encoding)

The app UI is in Korean. The documents in `docs/` are in Korean too.

### Download

Get `VideoGrab-<version>-arm64.zip` from the [latest release](https://github.com/sudapeople/videograb/releases/latest).
Requires macOS 14 or later on Apple Silicon (M1 or later).

1. Unzip it and move `VideoGrab.app` to Applications
2. Install the download tools (see Requirements below)

```bash
brew install yt-dlp ffmpeg deno
```

3. The app is not notarized, so macOS blocks it on first launch. Open it with either of these
   - System Settings > Privacy & Security, then "Open Anyway"
   - In Terminal: `xattr -dr com.apple.quarantine /Applications/VideoGrab.app`

### Usage

1. Copy the URL of a YouTube video, an Instagram reel or video, or an X post with a video (address bar, share button, or a link inside any text)
2. Press `⌘V` in the VideoGrab window (or click the paste button in the toolbar)
3. When it finishes, click the magnifier button to reveal the file in Finder

Other behavior

- Several links on the clipboard are downloaded at the same time
- A link with a playlist attached (`watch?v=...&list=...`) downloads only that one video
- If the file already exists, it is not downloaded again and is shown as done right away
- Cancelling keeps the partial file (`.part`). Press retry to resume
- If the clipboard has no link, the app just beeps
- Any other site supported by yt-dlp works too (Twitch and more)
- If a download fails, it retries once with your Chrome login cookies while posing as Chrome. This covers videos that need a login and sites with bot protection
  (the first time, macOS asks to allow access to "Chrome Safe Storage" in the keychain; choose "Always Allow")
- Pages where the video URL only appears after pressing play or after an ad ends are not supported (the page is read, not run)
- Instagram works one video or reel URL at a time. Registering an account for automatic downloads is not supported
  (yt-dlp's Instagram user listing does not work)

#### YouTube channels

Channels are managed in their own window, "채널 관리" (Channels). Open it with the channel button in the toolbar or `⌘2`.

![Channels window](docs/screenshots/channels.png)

- Add : press `+`, then enter the channel URL (`youtube.com/@name`, `youtube.com/channel/UC...`) and pick a folder.
  Pasting a channel URL in the main window opens the same sheet with the URL filled in
- Remove : select a channel and press the trash button (or the `delete` key). Downloaded files stay
- Folder : each channel has its own. The default is `save location/channel name`, and you can change it at any time
- New uploads : switches per channel and per kind. The kinds are videos (long-form), Shorts, and live (past streams).
  With only Shorts on, for example, only new Shorts are downloaded. Only videos uploaded after you added the channel are downloaded.
  Uploads made while the app was closed are picked up at the next launch (up to the latest 30 per kind)
- Download all : one button per kind (videos, Shorts, live) downloads just that kind in order.
  Finished videos are recorded, so you can cancel and start again to continue
- Live streams that are on air or scheduled are downloaded at a later check, after they end

#### Settings

"설정…" in the app menu (`⌘,`) or the gear button in the toolbar.

- Save location : where pasted videos are saved
- New upload check : every 15 minutes, 30 minutes (default), 1 hour, 3 hours, or never
- Keep running in the menu bar, launch at login, notify on channel downloads (all off by default, see below)
- App updates : notify when a new version is out (default), install automatically, or never check (see below)
- Tools : shows whether yt-dlp, ffmpeg and deno are installed, the yt-dlp version, and an "yt-dlp 업데이트" (Update yt-dlp) button

#### Updates

The app checks the latest GitHub release at launch and once a day while it is running.
"업데이트 확인…" (Check for Updates) in the app menu or "지금 확인" (Check now) in Settings checks right away.

- Notify (default) : an install button appears in Settings, at the bottom of the main window, and in the menu bar menu
- Install automatically : installs and relaunches by itself when nothing is downloading and all windows are closed.
  With a window open it waits until you close it (within the first minute after launch it installs right away)
- Install steps : downloads the zip, compares its SHA-256 with the value from the release, verifies the signature,
  swaps the app and relaunches. If the swap fails, the previous app is put back
- The app is not notarized, so the publisher of a file cannot be verified. That is why the default is to notify, not to install
- If the app on disk is replaced while it is running (`./scripts/build.sh install`, overwriting it in Finder, and so on), it relaunches as the new app.
  Like automatic installs, it waits while something is downloading or a window is open. With "Keep running in the menu bar" off,
  closing the window quits the app, so it does not relaunch (the new app opens next time)
- Update yt-dlp : if YouTube changes and downloads suddenly fail, press "yt-dlp 업데이트" in Settings.
  It runs Homebrew's `brew upgrade yt-dlp`

#### Keep running in the menu bar

New uploads are checked only while the app is running. To keep downloading with the windows closed,
turn on "상단바에서 계속 실행" (Keep running in the menu bar) in Settings.

- Closing every window no longer quits the app. It stays as a menu bar icon, and the Dock icon shows only while a window is open
- Menu : current status (active downloads, last check time), open VideoGrab, Channels, check now,
  recent downloads (click to reveal in Finder), Settings, Quit
- The icon is filled while something is downloading
- With "로그인할 때 자동으로 실행" (Launch at login) also on, the app starts in the menu bar without a window at login.
  It is registered as a macOS login item (System Settings > General > Login Items) and removed when you turn it off
- "채널 영상을 받으면 알림" (Notify on channel downloads) posts a notification when a new upload is downloaded,
  when "download all" finishes, and when a download fails
- If a check fails (for example, no network), it is retried after 5 minutes instead of waiting for the full interval

#### Resources

Automatic downloads run only while the app is running, and nothing runs when the feature is not in use.

- There is no separate background service. With the menu bar option on, the only thing running is the app itself.
  With it off, the app quits when all windows are closed
- With no channel to check, or with checking turned off, there is no timer at all. Otherwise it wakes once per interval.
  While idle in the menu bar it uses no CPU and about 100 MB of memory
- New uploads are downloaded one at a time
- Quitting stops every running yt-dlp and ffmpeg. Partial files (`.part`) stay and are resumed next time
- If the app was killed or crashed and left a yt-dlp behind, the next launch finds and stops it
- A channel check has a time limit (2 minutes), so no process hangs on a silent server
- Only the latest 200 finished items are kept in the list
- The update check wakes once a day and does not run when turned off. Temporary files used for an install are removed afterwards

### Requirements

The app uses three tools installed with Homebrew. They are not bundled because YouTube changes often
and yt-dlp needs frequent updates.

```bash
brew install yt-dlp ffmpeg deno
```

- `yt-dlp` : resolves and downloads the video
- `ffmpeg` : merges video and audio
- `deno` : JavaScript runtime yt-dlp uses for YouTube signature decoding

If YouTube downloads suddenly fail, update yt-dlp first. The "yt-dlp 업데이트" button in Settings does the same thing.

```bash
brew upgrade yt-dlp
```

### Build and install

Built with a single `swiftc` call, no Xcode project. Requires macOS 14 or later on Apple Silicon and Swift 5.9 or later (Xcode 15 or later). Tested with Swift 6.4.2.

```bash
./scripts/build.sh
```

```bash
./scripts/build.sh install
```

With `install`, the app is copied to `/Applications/VideoGrab.app`.
It is ad-hoc signed (`codesign -s -`), meant for use on your own Mac.

```bash
./scripts/build.sh zip
```

With `zip`, it creates `build/VideoGrab-<version>-arm64.zip` for a release and prints its SHA-256.
The version comes from `CFBundleShortVersionString` in `src/Info.plist`,
and the zip contains `VideoGrab.app` and `LICENSE` inside a `VideoGrab-<version>/` folder.
To ship a new version:

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `src/Info.plist`
2. `./scripts/build.sh zip`
3. `gh release create v<version> build/VideoGrab-<version>-arm64.zip`

### Settings

`defaults read com.sudapeople.videograb` shows the values from the settings window
(`outputDir` save location, `checkMinutes` check interval, `keepInMenuBar` menu bar mode, `notifyNew` notifications,
`updateMode` app updates: 0 never, 1 notify, 2 install automatically). Delete a value to go back to its default.

Registered channels are stored in `~/Library/Application Support/VideoGrab/channels.json`,
and the per-channel record of downloaded videos in `<channel id>.txt` in the same folder.

### License

[MIT](LICENSE). Free to use, modify and distribute.

yt-dlp (Unlicense), FFmpeg (LGPL/GPL) and Deno (MIT) are not bundled with the app.
You install them separately with Homebrew, and each follows its own license.
Respect each service's Terms of Service and copyright when downloading videos.
