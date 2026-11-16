<img src="docs/icon.png" width="128" alt="VideoGrab 아이콘">

# VideoGrab

유튜브 링크를 복사한 뒤 창에서 `⌘V` 를 누르면 최고 화질로 바로 받는 맥 앱.
4K Video Downloader+ 의 "스마트 모드(붙여넣기 한 번에 정해진 설정으로 저장)" 만 떼어 낸 것이다.

- 화질 : 항상 최고 화질 영상 + 최고 음질 오디오 (`bv*+ba/b`). 4K·8K·HDR·60fps 그대로
- 파일명 : 영상 제목 그대로 (`제목.mp4`)
- 저장 위치 : 창 아래 "저장 위치 변경…" 으로 바꾼다. 기본값 `~/Downloads`
- 컨테이너 : mp4 (코덱은 원본 그대로, 다시 인코딩하지 않는다)

| 처음 화면 | 받는 중 |
|---|---|
| ![처음 화면](docs/screenshots/empty.png) | ![받는 중](docs/screenshots/downloading.png) |

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

Xcode 프로젝트 없이 `swiftc` 한 번으로 빌드한다. macOS 14 이상, Apple Silicon.

```bash
./scripts/build.sh
```

```bash
./scripts/build.sh install
```

`install` 을 붙이면 `/Applications/VideoGrab.app` 으로 복사한다.
서명은 애드혹(`codesign -s -`)이라 이 맥에서만 쓰는 용도다.

## 폴더 구조

```
videograb/
├── README.md                 이 문서
├── docs/
│   ├── 01-4K-Video-Downloader-분석.md   원본 앱 분석 기록
│   ├── 02-설계와-검증.md                설계 결정과 시험 결과
│   ├── icon.png                         README 용 아이콘
│   └── screenshots/                     README 용 화면
├── src/
│   ├── VideoGrab.swift       앱 전체 (SwiftUI, 약 270줄)
│   └── Info.plist
├── scripts/
│   ├── build.sh              빌드·설치
│   └── make-icon.swift       아이콘 생성
└── build/                    빌드 산출물 (지워도 다시 만들어짐)
```

## 설정 저장 위치

`defaults read com.sudapeople.videograb outputDir` 로 저장 위치를 볼 수 있다.
값을 지우면 기본값(`~/Downloads`)으로 돌아간다.
