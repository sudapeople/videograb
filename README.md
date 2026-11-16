<img src="docs/icon.png" width="128" alt="VideoGrab 아이콘">

# VideoGrab

[![최신 릴리스](https://img.shields.io/github/v/release/sudapeople/videograb)](https://github.com/sudapeople/videograb/releases/latest)
[![다운로드 수](https://img.shields.io/github/downloads/sudapeople/videograb/total)](https://github.com/sudapeople/videograb/releases)
[![라이선스](https://img.shields.io/github/license/sudapeople/videograb)](LICENSE)
[![플랫폼](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20Apple%20Silicon-blue?logo=apple)](#내려받기)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](#빌드설치)
[![Homebrew](https://img.shields.io/badge/Homebrew-yt--dlp%20%7C%20ffmpeg%20%7C%20deno-FBB040?logo=homebrew&logoColor=white)](#필요한-것)<br>
[![GitHub 스타](https://img.shields.io/github/stars/sudapeople/videograb?style=flat)](https://github.com/sudapeople/videograb/stargazers)
[![마지막 커밋](https://img.shields.io/github/last-commit/sudapeople/videograb)](https://github.com/sudapeople/videograb/commits/main)
[![이슈](https://img.shields.io/github/issues/sudapeople/videograb)](https://github.com/sudapeople/videograb/issues)
[![Discord](https://img.shields.io/discord/1321141059753086996?style=flat&logo=discord&logoColor=white&label=Discord&color=5865F2)](https://discord.gameboy.kr)
[![YouTube](https://img.shields.io/badge/YouTube-%EC%88%98%EB%8B%A4%20SUDA-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/channel/UCcm7Jc50537eMixvkVNU8-Q)
[![치지직](https://img.shields.io/badge/CHZZK-%EC%88%98%EB%8B%A4%20SUDA-00FFA3)](https://chzzk.naver.com/bcf71dbdafcdddae524d82490db546c0)

한국어 | [English](#english)

유튜브 링크를 복사한 뒤 창에서 `⌘V` 를 누르면 최고 화질로 바로 받는 맥 앱.
4K Video Downloader+ 의 "스마트 모드(붙여넣기 한 번에 정해진 설정으로 저장)" 만 떼어 낸 것이다.

- 화질 : 항상 최고 화질 영상 + 최고 음질 오디오 (`bv*+ba/b`). 4K·8K·HDR·60fps 그대로
- 파일명 : 영상 제목 그대로 (`제목.mp4`)
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

1. 브라우저에서 유튜브 주소를 복사한다 (주소창, 공유 버튼, 글 속 링크 모두 됨)
2. VideoGrab 창에서 `⌘V` (또는 툴바의 붙여넣기 버튼)
3. 끝나면 돋보기 버튼으로 Finder 에서 파일을 바로 연다

그 밖의 동작

- 클립보드에 링크가 여러 개면 모두 동시에 받는다
- `watch?v=...&list=...` 처럼 재생목록이 붙은 링크도 그 영상 하나만 받는다
- 이미 받은 파일이 있으면 다시 받지 않고 바로 "완료" 로 표시한다
- 취소하면 받던 조각(`.part`)은 남는다. "다시 받기" 를 누르면 이어서 받는다
- 링크가 없으면 경고음만 난다
- 유튜브 외에도 yt-dlp 가 지원하는 사이트(치지직, 트위치, X 등)는 그대로 된다

## 필요한 것

Homebrew 로 설치된 도구 3개를 쓴다. 앱 안에 넣지 않은 이유는 유튜브가 자주 바뀌어
yt-dlp 를 자주 갱신해야 하기 때문이다.

```bash
brew install yt-dlp ffmpeg deno
```

- `yt-dlp` : 유튜브 주소 해석·다운로드
- `ffmpeg` : 영상·오디오 합치기
- `deno` : 유튜브 서명 해독용 자바스크립트 실행기 (yt-dlp 가 자동으로 씀)

유튜브에서 갑자기 안 받아지면 먼저 갱신한다.

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
│   └── screenshots/                     README 용 화면
├── src/
│   ├── VideoGrab.swift       앱 전체 (SwiftUI, 약 270줄)
│   └── Info.plist
├── scripts/
│   ├── build.sh              빌드·설치·릴리스 zip
│   └── make-icon.swift       아이콘 생성
└── build/                    빌드 산출물 (지워도 다시 만들어짐)
```

## 설정 저장 위치

`defaults read com.sudapeople.videograb outputDir` 로 저장 위치를 볼 수 있다.
값을 지우면 기본값(`~/Downloads`)으로 돌아간다.

## 라이선스

[MIT](LICENSE). 자유롭게 쓰고 고치고 배포할 수 있다.

앱이 불러 쓰는 yt-dlp(Unlicense), FFmpeg(LGPL/GPL), Deno(MIT)는 앱에 들어 있지 않고
사용자가 Homebrew 로 따로 설치하므로 각자의 라이선스를 따른다.
영상을 받을 때는 유튜브 이용약관과 저작권을 지켜야 한다.

---

## English

A macOS app that downloads a YouTube video in the best available quality the moment you press `⌘V` in its window.
It is a minimal take on the "Smart Mode" of 4K Video Downloader+ (paste once, save with preset settings).

- Quality : always the best video stream + best audio stream (`bv*+ba/b`). 4K, 8K, HDR and 60fps are kept as is
- File name : the video title (`Title.mp4`)
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

1. Copy a YouTube URL in your browser (address bar, share button, or a link inside any text)
2. Press `⌘V` in the VideoGrab window (or click the paste button in the toolbar)
3. When it finishes, click the magnifier button to reveal the file in Finder

Other behavior

- Several links on the clipboard are downloaded at the same time
- A link with a playlist attached (`watch?v=...&list=...`) downloads only that one video
- If the file already exists, it is not downloaded again and is shown as done right away
- Cancelling keeps the partial file (`.part`). Press retry to resume
- If the clipboard has no link, the app just beeps
- Any site supported by yt-dlp works too (Twitch, X and more)

### Requirements

The app uses three tools installed with Homebrew. They are not bundled because YouTube changes often
and yt-dlp needs frequent updates.

```bash
brew install yt-dlp ffmpeg deno
```

- `yt-dlp` : resolves and downloads the video
- `ffmpeg` : merges video and audio
- `deno` : JavaScript runtime yt-dlp uses for YouTube signature decoding

If YouTube downloads suddenly fail, update yt-dlp first.

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

`defaults read com.sudapeople.videograb outputDir` shows the save location.
Delete the value to go back to the default (`~/Downloads`).

### License

[MIT](LICENSE). Free to use, modify and distribute.

yt-dlp (Unlicense), FFmpeg (LGPL/GPL) and Deno (MIT) are not bundled with the app.
You install them separately with Homebrew, and each follows its own license.
Respect YouTube's Terms of Service and copyright when downloading videos.
