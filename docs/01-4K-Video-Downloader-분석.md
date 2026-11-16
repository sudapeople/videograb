# 4K Video Downloader+ 분석

분석일 : 2026-11-16
대상 : `/Applications/4K Video Downloader+.app` 26.3 (26.3.5.0396), 번들 ID `com.openmedia.4kvideodownloaderplus`

## 1. 앱 구성

| 항목 | 내용 |
|---|---|
| UI | Qt 6 QML (QtQuick, QtQuickControls2, QtWebEngine 로그인 창) |
| 실행 파일 | `Contents/MacOS/4kvideodownloaderplus` 147MB, 단일 바이너리 |
| 미디어 처리 | 번들 FFmpeg 4.2 계열 (`libavformat.58`, `libavcodec.58` 등) |
| 기타 라이브러리 | OpenSSL 1.1, ONNX Runtime 1.21 + `liblalalai_proc` (AI 음성 분리 기능), PortAudio |
| 시스템 프레임워크 | Cocoa, UserNotifications(완료 알림), ServiceManagement(로그인 시 실행), ScriptingBridge |
| 오류 보고 | Sentry (minidump 업로드) |

## 2. 유튜브 처리 방식

바이너리 문자열에서 `%1%/youtubei/v1/%2%?prettyPrint=false`,
`https://music.youtube.com/youtubei/v1/browse` 가 보인다.
yt-dlp 같은 외부 도구를 쓰지 않고 유튜브 내부 API(InnerTube)를 C++ 로 직접 호출해 스트림 주소를 얻고,
번들 FFmpeg 로 영상·오디오를 합친다. 자체 구현이라 유튜브가 바뀌면 앱 업데이트를 기다려야 한다.

## 3. 붙여넣기 동작

- 문자열 `clipboardLinkService`, `No valid link was found in the clipboard.` 가 있다
- 창 어디서든 붙여넣기 단축키를 누르면 클립보드에서 링크를 찾아 바로 받는다. 링크가 없으면 위 메시지를 띄운다

## 4. 설정 (현재 이 맥의 값)

설정 파일 : `~/Library/Preferences/com.4kdownload.4K Video Downloader+.plist`

| 키 | 값 | 뜻 |
|---|---|---|
| `SmartMode.enabled` | true | 붙여넣기 즉시 받기 (스마트 모드) |
| `SmartMode.preferences` | container MP4, video codec H264, resolution Original, fps maximum, audio Any | 스마트 모드 포맷 |
| `Settings.outputPath` | `~/Downloads/4K Video Downloader+` | 저장 위치 |
| `Settings.skipDuplicates` | true | 이미 받은 영상 건너뛰기 |
| `Settings.threadsNum` | 1 | 동시 다운로드 수 |
| `Settings.removeCompletedDownloads` | true | 완료 항목 목록에서 자동 제거 |
| `Limits.dayDownloadCount` | 0 | 무료판 하루 제한 카운터 |

참고 : 지금 설정은 코덱이 H264 로 고정돼 있다. 유튜브는 H264 를 보통 1080p 까지만 주므로
"Original" 이라도 실제로는 1080p 가 상한이다. VideoGrab 은 코덱 제한 없이 최고 화질을 받는다.

## 5. 다운로드 기록

`~/Library/Application Support/4kdownload.com/4K Video Downloader+/4K Video Downloader+/<id>.sqlite`

주요 테이블

- `download_item(id, filename, state, position, timestampNs)`
- `media_item_description(download_item_id, title, duration, publishing_timestamp)`
- `video_info(codec, dimension, resolution, fps, bitrate, hdr, video_360)`
- 그 밖에 `subscription_*` (채널 구독 자동 받기), `subtitle*`, `thumbnails`

## 6. VideoGrab 으로 가져온 것과 뺀 것

가져온 것

- 붙여넣기 한 번에 정해진 설정으로 받기 (스마트 모드)
- 파일명 = 제목, 저장 위치 설정
- 중복 건너뛰기 (yt-dlp 가 같은 파일명이 있으면 받지 않음)
- 진행률, 취소, 다시 받기, Finder 에서 보기

뺀 것 (요청 범위 밖)

- 포맷·해상도·코덱 선택 UI (항상 최고 화질)
- 재생목록·채널 전체 받기, 구독, 자막, 오디오만 받기, AI 음성 분리
- 로그인(QtWebEngine), 하루 제한, 광고 알림, 오류 보고

추출 엔진은 자체 구현 대신 yt-dlp 를 썼다. 유튜브 변경에 가장 빨리 대응하는 오픈소스이고,
`brew upgrade yt-dlp` 한 줄로 앱을 다시 빌드하지 않고 고칠 수 있다.
