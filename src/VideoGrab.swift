import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications
import CryptoKit

// 저장 위치 기본값. 사용자가 바꾸면 UserDefaults "outputDir" 에 남는다.
let defaultOutputDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Downloads").path

// 등록한 채널과 받은 영상 기록을 두는 곳. defaults 의 "dataDir" 로 바꿀 수 있다.
var dataDir: URL {
    let dir = UserDefaults.standard.string(forKey: "dataDir").map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoGrab")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

// 채널 영상의 종류. 값은 유튜브 채널 주소 뒤에 붙는 탭 이름이다 (채널주소/videos 등).
enum Kind: String, CaseIterable, Identifiable {
    case videos, shorts, streams

    var id: String { rawValue }
    var label: String {
        switch self {
        case .videos: "동영상"
        case .shorts: "쇼츠"
        case .streams: "라이브"
        }
    }
    var detail: String {
        switch self {
        case .videos: "동영상 (롱폼)"
        case .shorts: "쇼츠 (숏폼)"
        case .streams: "라이브 (지난 방송)"
        }
    }
}

// 등록한 유튜브 채널. 등록할 때 이미 있던 영상(baseline) 밖의 영상이 "새 영상" 이다.
struct Channel: Codable, Identifiable {
    let id: String          // UC 로 시작하는 채널 ID
    var name: String
    let url: String
    var folder: String      // 이 채널 영상을 저장하는 곳
    let baseline: [String]
    let addedAt: Date
    var paused: Bool?       // 1.2 까지의 기록: true 면 새 영상 자동 받기를 꺼 둔 채널
    var auto: [String]?     // 새 영상을 자동으로 받을 종류. 없으면(1.2 까지의 기록) paused 를 따른다

    var autoKinds: Set<Kind> {
        if let auto { return Set(auto.compactMap(Kind.init(rawValue:))) }
        return paused == true ? [] : Set(Kind.allCases)
    }

    // yt-dlp 가 받은 영상 ID 를 적어 두는 파일. 전체 받기와 자동 받기가 같이 쓴다.
    var archive: URL { dataDir.appendingPathComponent("\(id).txt") }
}

// GitHub 에 올라온, 지금 버전보다 새 릴리스
struct AppRelease {
    let version: String
    let zip: URL            // 내려받을 zip
    let sha256: String      // GitHub 이 알려 주는 zip 의 확인값
}

struct UpdateError: Error { let message: String }

// 채널 추가 창에 미리 채워 둘 주소
struct AddDraft: Identifiable {
    let id = UUID()
    let url: String
}

func tilde(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 로그인 때 자동으로 켜졌으면 Dock 아이콘 없이 상단바로만 시작한다
        if DownloadStore.launchedHidden { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DownloadStore.sweepOrphans()
        // 창이 열리고 닫힐 때마다 Dock 아이콘을 맞춘다. 닫힌 뒤의 상태를 봐야 해서 한 박자 늦춘다.
        for name in [NSWindow.willCloseNotification, NSWindow.didBecomeKeyNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { AppDelegate.updateDockIcon() } }
            }
        }
        if DownloadStore.launchedHidden {
            DispatchQueue.main.async { NSApp.windows.filter(\.canBecomeMain).forEach { $0.close() } }
        }
    }

    /// "상단바에서 계속 실행" 일 때 창이 하나도 없으면 Dock 아이콘을 숨기고, 창이 있으면 보인다.
    @MainActor static func updateDockIcon() {
        if NSApp.isHidden { return }
        let hasWindow = NSApp.windows.contains { ($0.isVisible || $0.isMiniaturized) && $0.canBecomeMain }
        let keep = UserDefaults.standard.bool(forKey: "keepInMenuBar")
        let wanted: NSApplication.ActivationPolicy = hasWindow || !keep ? .regular : .accessory
        if NSApp.activationPolicy() != wanted { NSApp.setActivationPolicy(wanted) }
        DownloadStore.shared.installIfDeferred()    // 창을 닫아서 미뤄 둔 업데이트를 설치할 수 있게 됐는지
    }

    /// 창(최소화한 창 포함)이 하나라도 있는지
    @MainActor static var hasWindow: Bool {
        NSApp.windows.contains { ($0.isVisible || $0.isMiniaturized) && $0.canBecomeMain }
    }

    // "상단바에서 계속 실행" 이 꺼져 있으면 창을 모두 닫을 때 끝낸다. 창 없이 뒤에서 도는 프로세스를 남기지 않는다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: "keepInMenuBar")
    }

    // 받는 중에 끝내려 하면 한 번 묻는다. 취소하면 윈도우 메뉴(⌘1)나 Dock, 상단바 아이콘으로 창을 다시 연다.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let active = DownloadStore.shared.items.filter(\.isActive).count
        if active == 0 { return .terminateNow }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "받는 중인 항목이 \(active)개 있습니다. 끝낼까요?"
        alert.informativeText = "끝내면 받기를 멈춥니다. 받던 영상은 다음에 이어서 받습니다."
        alert.addButton(withTitle: "끝내기")
        alert.addButton(withTitle: "취소")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct VideoGrabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = DownloadStore.shared
    @AppStorage("keepInMenuBar") private var keepInMenuBar = false

    init() {
        // ./scripts/build.sh 가 빌드 직후 돌리는 자체 점검
        if CommandLine.arguments.contains("--selftest") { DownloadStore.selfTest(); exit(0) }
        NSWindow.allowsAutomaticWindowTabbing = false   // 창이 둘뿐이라 탭 메뉴는 뺀다
    }

    var body: some Scene {
        Window("VideoGrab", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 680, height: 440)
        .keyboardShortcut("1")
        .commands {
            // ⌘V: 글자 입력칸에 커서가 있으면 평소처럼 붙여넣고, 아니면 클립보드의 링크를 받는다.
            CommandGroup(replacing: .pasteboard) {
                Button("오려두기") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                    .keyboardShortcut("x")
                Button("복사하기") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                    .keyboardShortcut("c")
                Button("붙여넣기") {
                    if let text = NSApp.keyWindow?.firstResponder as? NSText {
                        text.paste(nil)
                    } else {
                        store.pasteFromClipboard()
                    }
                }
                .keyboardShortcut("v")
                Button("전체 선택") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    .keyboardShortcut("a")
            }
            CommandGroup(after: .appInfo) {
                Button("업데이트 확인…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    Task { await store.checkForUpdate() }
                }
            }
            CommandGroup(replacing: .help) {
                Button("VideoGrab 도움말") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sudapeople/videograb#readme")!)
                }
            }
        }

        Window("채널 관리", id: "channels") {
            ChannelManager(store: store)
        }
        .defaultSize(width: 760, height: 480)
        .keyboardShortcut("2")

        Settings {
            SettingsView(store: store)
        }

        // 설정의 "상단바에서 계속 실행" 을 켰을 때만 상단바에 아이콘을 둔다
        MenuBarExtra(isInserted: $keepInMenuBar) {
            MenuBarMenu(store: store)
        } label: {
            Image(systemName: store.items.contains(where: \.isActive) ? "arrow.down.circle.fill" : "arrow.down.circle")
        }
    }
}

// MARK: - 모델

@MainActor @Observable
final class DownloadItem: Identifiable {
    enum Status: Equatable {
        case waiting, running, done, cancelled
        case failed(String)
    }

    var isActive: Bool { status == .running || status == .waiting }
    // 채널의 새 영상을 자동으로 받는 항목. 한 번에 하나씩만 받는다
    var isAuto: Bool { archive != nil && batchName == nil }

    let id = UUID()
    let url: String
    let folder: String?         // nil 이면 창 아래 저장 위치. 채널 영상은 채널 폴더
    let archive: String?        // 채널 영상만: 받은 영상 기록 파일
    let batchName: String?      // 채널 전체 받기일 때 채널 이름
    var channelName: String?    // 새 영상 자동 받기일 때 채널 이름 (알림에 쓴다)
    var count = 0               // 받은 파일 수
    var title: String?
    var progress: Double = 0
    var status: Status = .running
    var filePath: String?
    var lastError: String?
    var process: Process?

    init(url: String, folder: String? = nil, archive: String? = nil, batchName: String? = nil) {
        self.url = url
        self.folder = folder
        self.archive = archive
        self.batchName = batchName
    }

    func handle(_ line: String) {
        if line.hasPrefix("TITLE ") {
            title = String(line.dropFirst(6))
        } else if line.hasPrefix("PROG ") {
            progress = min(max((Double(line.dropFirst(5)) ?? 0) / 100, 0), 1)
        } else if line.hasPrefix("FILE ") {
            filePath = String(line.dropFirst(5))
            count += 1
        } else if line.hasPrefix("ERROR:") {
            lastError = line
        }
    }

    func finish(_ code: Int32) {
        process = nil
        if status == .cancelled { return }
        let error = lastError ?? "yt-dlp 종료 코드 \(code)"
        // 쇼츠나 라이브를 올린 적 없는 채널에서 그 종류를 전체 받기 한 경우
        if code != 0, error.contains("does not have a") {
            status = .failed("이 채널에는 그 종류의 영상이 없습니다")
            return
        }
        status = code == 0 ? .done : .failed(batchName == nil ? error : "\(count)개 받음, 일부 실패 · \(error)")
    }
}

@MainActor @Observable
final class DownloadStore {
    static let shared = DownloadStore()
    var items: [DownloadItem] = []

    func pasteFromClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let urls = Self.extractURLs(text)
        if urls.isEmpty { NSSound.beep(); return }
        for url in urls {
            if let channel = Self.channelURL(url) {
                addDraft = AddDraft(url: channel)   // 채널은 채널 관리 창에서 폴더를 정해 등록한다
            } else if !items.contains(where: { $0.url == url && $0.isActive }) {
                start(DownloadItem(url: url))
            }
        }
    }

    func start(_ item: DownloadItem) {
        // 앱을 오래 켜 두면 끝난 항목이 쌓인다. 끝난 것은 최근 200개만 남긴다.
        var finished = 0
        items.removeAll { item in
            if item.isActive { return false }
            finished += 1
            return finished > 200
        }
        items.insert(item, at: 0)
        if item.isAuto {
            item.status = .waiting
            startNextAuto()
        } else {
            run(item)
        }
    }

    /// 자동 받기는 한 번에 하나씩. 받는 중인 것이 없으면 가장 오래 기다린 항목을 시작한다.
    private func startNextAuto() {
        if items.contains(where: { $0.isAuto && $0.status == .running }) { return }
        if let next = items.last(where: { $0.isAuto && $0.status == .waiting }) { run(next) }
    }

    static func extractURLs(_ text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let found = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { $0.url?.absoluteString }
            .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        var seen = Set<String>()
        return found.filter { seen.insert($0).inserted }
    }

    static func findTool(_ name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var outputDir: String {
        UserDefaults.standard.string(forKey: "outputDir") ?? defaultOutputDir
    }

    /// yt-dlp 프로세스를 만든다. 출력(표준 출력 + 오류)은 돌려주는 파이프로 읽는다.
    static func ytdlp(_ args: [String]) -> (Process, Pipe)? {
        guard let path = findTool("yt-dlp") else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["--socket-timeout", "20"] + args   // 응답 없는 서버에 매달려 있지 않게
        // 앱은 셸 PATH 를 물려받지 않는다. ffmpeg·deno 를 yt-dlp 가 찾을 수 있게 넣어 준다.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        return (p, pipe)
    }

    /// 파일명 = 영상 제목. 인스타그램·X 는 제목이 "Video by 계정" 처럼 서로 겹쳐서 영상 ID 를 붙인다.
    /// B 는 바이트 수 제한이다 (파일명 한도 255바이트).
    static func nameTemplate(_ url: String) -> String {
        let host = URLComponents(string: url)?.host?.lowercased() ?? ""
        let needsID = ["instagram.com", "x.com", "twitter.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        return needsID ? "%(title).180B [%(id)s].%(ext)s" : "%(title).200B.%(ext)s"
    }

    func run(_ item: DownloadItem) {
        item.status = .running
        item.progress = 0
        item.count = 0
        item.lastError = nil

        var args = [
            "--no-playlist",                 // watch?v=..&list=.. 링크도 영상 하나만
            "-f", "bv*+ba/b",                // 최고 화질 영상 + 최고 음질 오디오
            "--merge-output-format", "mp4",
            "--no-mtime",                    // 파일 날짜 = 받은 날짜
            "-P", item.folder ?? Self.outputDir,
            "-o", Self.nameTemplate(item.url),
            "--newline", "--progress",
            "--print", "before_dl:TITLE %(title)s",
            "--print", "after_move:FILE %(filepath)s",
            "--progress-template", "download:PROG %(progress._percent)s",
        ]
        if let archive = item.archive {
            // 채널 영상: 받은 영상은 다시 받지 않고, 방송 중·예정 영상은 끝난 뒤에 받는다
            args += ["--download-archive", archive,
                     "--match-filters", "live_status!=?is_live & live_status!=?is_upcoming"]
        }
        guard let (p, pipe) = Self.ytdlp(args + [item.url]) else {
            item.status = .failed("yt-dlp 가 없습니다. 터미널에서 brew install yt-dlp ffmpeg deno")
            return
        }

        do {
            try p.run()
        } catch {
            item.status = .failed(error.localizedDescription)
            return
        }
        item.process = p

        let handle = pipe.fileHandleForReading
        Task { @MainActor in
            do {
                for try await line in handle.bytes.lines { item.handle(line) }
            } catch {}
            // ponytail: 50ms 폴링. 출력이 끝난 뒤라 대개 첫 확인에서 끝난다.
            while p.isRunning { try? await Task.sleep(for: .milliseconds(50)) }
            item.finish(p.terminationStatus)
            announce(item)
            startNextAuto()
            installIfDeferred()
        }
    }

    /// 채널 영상 받기가 끝나면 알림을 낸다 (설정에서 켰을 때만). 창을 닫아 둔 동안에도 결과를 알 수 있게.
    private func announce(_ item: DownloadItem) {
        guard item.archive != nil, UserDefaults.standard.bool(forKey: "notifyNew") else { return }
        let content = UNMutableNotificationContent()
        switch item.status {
        case .done where item.count > 0 && item.batchName != nil:
            content.title = "채널 전체 받기를 마쳤습니다"
            content.body = "\(item.batchName ?? "") · \(item.count)개 받음"
        case .done where item.count > 0:
            content.title = "새 영상을 받았습니다"
            content.body = [item.channelName, item.title].compactMap { $0 }.joined(separator: " · ")
        case .failed(let message):
            content.title = "채널 영상을 받지 못했습니다"
            content.body = [item.batchName ?? item.channelName, message].compactMap { $0 }.joined(separator: " · ")
        default:
            return
        }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: nil))
    }

    /// 상단바 메뉴 맨 위에 보이는 한 줄
    var statusLine: String {
        let active = items.filter(\.isActive).count
        if active > 0 { return "받는 중 \(active)개" }
        if lastCheck == .distantPast { return "새 영상을 아직 확인하지 않음" }
        return "마지막 확인 \(lastCheck.formatted(date: .omitted, time: .shortened))" + (lastCheckFailed ? " (실패, 곧 다시 확인)" : "")
    }

    /// 상단바 메뉴에 보일 최근 받은 영상 (최대 5개)
    var recentDone: [DownloadItem] {
        Array(items.filter { $0.status == .done && $0.filePath != nil }.prefix(5))
    }

    /// 로그인 항목으로 켜져서 창 없이 시작해야 하는지. "상단바에서 계속 실행" 이 켜져 있을 때만 해당한다.
    static let launchedHidden: Bool = {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "keepInMenuBar") else { return false }
        if defaults.bool(forKey: "startHidden") { return true }   // 직접 지정 (예: open ... --args -startHidden YES)
        guard SMAppService.mainApp.status == .enabled else { return false }
        // ponytail: 로그인 항목으로 켜졌는지 알려 주는 공식 방법이 없어, Dock 이 뜬 지 2분 안이면
        // 로그인 직후로 본다. 틀려도 창이 안 뜰 뿐이고 상단바 아이콘으로 열 수 있다.
        let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.launchDate
        return dock.map { Date.now.timeIntervalSince($0) < 120 } ?? false
    }()

    func cancel(_ item: DownloadItem) {
        item.status = .cancelled
        if let p = item.process { Self.stop(p) }
        startNextAuto()
    }

    func clearFinished() {
        items.removeAll { !$0.isActive }
    }

    // MARK: 프로세스 정리

    /// yt-dlp 를 멈춘다. SIGINT 를 받으면 yt-dlp 가 자기가 띄운 ffmpeg 까지 정리하고 끝난다.
    /// 3초 안에 안 끝나면 강제로 끝낸다.
    static func stop(_ p: Process) {
        guard p.isRunning else { return }
        p.interrupt()
        Task {
            try? await Task.sleep(for: .seconds(3))
            forceKill(p)
        }
    }

    /// 자식 프로세스(ffmpeg)부터 강제로 끝낸다.
    static func forceKill(_ p: Process) {
        guard p.isRunning else { return }
        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-KILL", "-P", "\(p.processIdentifier)"]
        try? pkill.run()
        pkill.waitUntilExit()
        kill(p.processIdentifier, SIGKILL)
    }

    /// 지난 실행이 비정상으로 끝나(강제 종료·충돌) 남은 yt-dlp 를 거둔다.
    /// 이 앱이 띄운 것(출력 틀로 구분) 가운데 부모가 사라져 launchd 밑으로 간 것만 멈춘다.
    static func sweepOrphans() {
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", #"ps -axwwo pid=,ppid=,command= | awk '$2 == 1 && /yt-dlp/ && (/TITLE %\(title\)s/ || /CH %\(channel_id\)s/) { print $1 }' | xargs kill -INT 2>/dev/null"#]
        sh.standardOutput = FileHandle.nullDevice
        sh.standardError = FileHandle.nullDevice
        if (try? sh.run()) != nil { sh.waitUntilExit() }
    }

    /// 앱을 끝낼 때: 예약과 돌고 있는 yt-dlp 를 모두 멈춘다. 뒤에 남는 프로세스가 없게 한다.
    func shutdown() {
        watchTask?.cancel()
        updateTask?.cancel()
        let running = items.compactMap(\.process) + listing
        running.forEach { $0.interrupt() }
        let deadline = Date.now.addingTimeInterval(3)
        while running.contains(where: \.isRunning) && Date.now < deadline { usleep(50_000) }
        running.forEach(Self.forceKill)
    }

    // MARK: 채널

    var channels: [Channel] = DownloadStore.loadChannels()
    var registering: [String] = []          // 등록 중인 채널 주소
    var channelStatus: [String: String] = [:]
    var alert: String?
    var addDraft: AddDraft?                 // nil 이 아니면 채널 추가 창을 띄운다
    private var checking = false
    private(set) var lastCheck = Date.distantPast
    private(set) var lastCheckFailed = false    // 실패했으면 주기를 기다리지 않고 5분 뒤 다시 확인한다
    private var watchTask: Task<Void, Never>?   // 다음 새 영상 확인 예약. 확인할 채널이 없으면 nil
    private var listing: [Process] = []         // 목록 조회·도구 실행처럼 출력을 모으는 중인 프로세스
    private var attempted = Set<String>()   // 이번 실행에서 자동 받기를 건 영상. 실패한 영상을 30분마다 되풀이하지 않게

    static var channelsFile: URL { dataDir.appendingPathComponent("channels.json") }

    static func loadChannels() -> [Channel] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: channelsFile) else { return [] }
        return (try? decoder.decode([Channel].self, from: data)) ?? []
    }

    func saveChannels() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        do {
            try encoder.encode(channels).write(to: Self.channelsFile, options: .atomic)
        } catch {
            alert = "채널 목록을 저장하지 못했습니다. \(error.localizedDescription)"
        }
    }

    /// 유튜브 채널 주소면 탭(/videos 등)과 쿼리를 뗀 주소를, 아니면 nil 을 돌려준다.
    static func channelURL(_ url: String) -> String? {
        guard let c = URLComponents(string: url), let host = c.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        let parts = c.percentEncodedPath.split(separator: "/")
        guard let first = parts.first else { return nil }
        if first.hasPrefix("@") { return "https://www.youtube.com/\(first)" }
        if ["channel", "c", "user"].contains(first), parts.count >= 2 {
            return "https://www.youtube.com/\(first)/\(parts[1])"
        }
        return nil
    }

    /// yt-dlp 가 찍은 "영상ID 방송상태" 줄에서 받을 수 있는 영상 ID 만 고른다.
    /// 방송 중·예정 영상은 끝난 뒤 새 영상으로 잡히도록 뺀다.
    static func videoIDs(_ lines: [String]) -> [String] {
        lines.compactMap { line in
            let f = line.split(separator: " ")
            guard f.count == 2, f[0].count == 11,
                  f[0].allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
                  f[1] != "is_live", f[1] != "is_upcoming" else { return nil }
            return String(f[0])
        }
    }

    /// 채널의 영상 목록을 가져온다. latest 가 있으면 탭(동영상·쇼츠·라이브)마다 최신 그만큼만.
    func listChannel(_ url: String, latest: Int? = nil) async -> [String] {
        var args = ["--flat-playlist",
                    "--print", "playlist:CH %(channel_id)s %(channel)s",
                    "--print", "%(id)s %(live_status)s"]
        if let latest { args += ["-I", ":\(latest)"] }
        guard let (p, pipe) = Self.ytdlp(args + [url]) else { return [] }
        // 시간 제한: 최신 목록 확인은 2분, 채널 전체 목록(등록할 때)은 10분
        return await collect(p, pipe, limit: latest == nil ? 600 : 120)
    }

    /// 프로세스를 돌려 출력 줄을 모은다. 시간 제한을 넘으면 끝내고, 앱을 끝낼 때도 같이 멈춘다.
    func collect(_ p: Process, _ pipe: Pipe, limit: Int) async -> [String] {
        guard (try? p.run()) != nil else { return [] }
        listing.append(p)
        defer { listing.removeAll { $0 === p } }
        let timer = Task {
            guard (try? await Task.sleep(for: .seconds(limit))) != nil else { return }
            Self.forceKill(p)
        }
        defer { timer.cancel() }
        var lines: [String] = []
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines { lines.append(line) }
        } catch {}
        while p.isRunning { try? await Task.sleep(for: .milliseconds(50)) }
        return lines
    }

    /// folder 가 nil 이면 "저장 위치/채널 이름" 에 저장한다.
    func register(_ url: String, folder: String? = nil) {
        if registering.contains(url) { return }
        registering.append(url)
        Task { @MainActor in
            defer { registering.removeAll { $0 == url } }
            let lines = await listChannel(url)
            let error = lines.last { $0.hasPrefix("ERROR:") }
            // 목록을 끝까지 못 읽었으면 등록하지 않는다. 빠진 옛 영상이 새 영상으로 잡히기 때문이다.
            guard error == nil, let head = lines.first(where: { $0.hasPrefix("CH UC") }) else {
                alert = error ?? "채널을 찾지 못했습니다. yt-dlp 가 없으면 터미널에서 brew install yt-dlp ffmpeg deno"
                return
            }
            let f = head.split(separator: " ", maxSplits: 2).map(String.init)
            if channels.contains(where: { $0.id == f[1] }) {
                alert = "이미 등록한 채널입니다."
                return
            }
            let name = f.count > 2 ? f[2] : f[1]
            let folder = folder ?? Self.outputDir + "/" + name.replacingOccurrences(of: "/", with: "_")
            channels.append(Channel(id: f[1], name: name, url: "https://www.youtube.com/channel/\(f[1])",
                                    folder: folder, baseline: Self.videoIDs(lines), addedAt: .now))
            saveChannels()
            scheduleWatch()
        }
    }

    func remove(_ channel: Channel) {
        channels.removeAll { $0.id == channel.id }
        channelStatus[channel.id] = nil
        saveChannels()
        scheduleWatch()
    }

    func setFolder(_ channel: Channel, _ folder: String) {
        guard let i = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        channels[i].folder = folder
        saveChannels()
    }

    /// 이 채널에서 한 종류(동영상·쇼츠·라이브)의 새 영상 자동 받기를 켜고 끈다.
    func setAuto(_ channel: Channel, _ kind: Kind, _ on: Bool) {
        guard let i = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        var kinds = channels[i].autoKinds
        if on { kinds.insert(kind) } else { kinds.remove(kind) }
        channels[i].auto = Kind.allCases.filter(kinds.contains).map(\.rawValue)
        channels[i].paused = nil
        saveChannels()
        scheduleWatch()
    }

    /// 이 채널에서 받은 영상 ID (yt-dlp 기록 파일의 "youtube 영상ID" 줄)
    func downloadedIDs(_ channel: Channel) -> [String] {
        (try? String(contentsOf: channel.archive, encoding: .utf8))?
            .split(separator: "\n").compactMap { $0.split(separator: " ").last.map(String.init) } ?? []
    }

    func isDownloadingAll(_ channel: Channel, _ kind: Kind) -> Bool {
        items.contains { $0.batchName != nil && $0.url == "\(channel.url)/\(kind.rawValue)" && $0.status == .running }
    }

    /// 채널의 한 종류(동영상·쇼츠·라이브)를 전체 받기. yt-dlp 하나가 차례로 받고,
    /// 받은 영상은 기록 파일 덕에 다시 받지 않는다.
    func downloadAll(_ channel: Channel, _ kind: Kind) {
        if isDownloadingAll(channel, kind) { return }
        start(DownloadItem(url: "\(channel.url)/\(kind.rawValue)", folder: channel.folder,
                           archive: channel.archive.path, batchName: "\(channel.name) \(kind.label)"))
    }

    init() {
        scheduleWatch()
        scheduleUpdateCheck()
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        }
    }

    /// 다음 새 영상 확인을 예약한다. 채널이나 설정이 바뀔 때마다 다시 부른다.
    /// 자동 받기를 켠 채널이 없거나 확인 주기가 "안 함" 이면 아무것도 돌리지 않는다.
    /// 앱이 켜져 있는 동안만 돈다. 켠 직후 한 번 확인하고, 그 뒤로 주기마다 한 번 깨어난다.
    func scheduleWatch() {
        watchTask?.cancel()
        watchTask = nil
        let defaults = UserDefaults.standard
        let minutes = defaults.object(forKey: "checkMinutes") == nil ? 30 : defaults.integer(forKey: "checkMinutes")
        guard minutes > 0, channels.contains(where: { !$0.autoKinds.isEmpty }) else { return }
        watchTask = Task {
            while !Task.isCancelled {
                let interval = Double((lastCheckFailed ? min(minutes, 5) : minutes) * 60)
                let wait = lastCheck.addingTimeInterval(interval).timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                } else {
                    await checkAll()
                }
            }
        }
    }

    /// 자동 받기를 켜 둔 채널을 모두 확인한다.
    func checkAll() async {
        if checking { return }
        checking = true
        defer { checking = false }
        lastCheck = .now
        var failed = false
        for channel in channels where !channel.autoKinds.isEmpty {
            if !(await check(channel)) { failed = true }
        }
        lastCheckFailed = failed
    }

    /// 채널에서 자동 받기를 켠 종류의 새 영상을 찾아 받기를 건다. 하나라도 확인하지 못하면 false.
    @discardableResult
    func check(_ channel: Channel) async -> Bool {
        channelStatus[channel.id] = "새 영상 확인 중"
        let known = Set(channel.baseline).union(downloadedIDs(channel))
        var fresh: [String] = []
        var failed = false
        for kind in Kind.allCases where channel.autoKinds.contains(kind) {
            // ponytail: 종류마다 최신 30개만 본다(요청 1번). 앱을 꺼 둔 사이 한 종류에 30개 넘게 올라오면
            // 그 앞 영상은 놓친다. 필요해지면 아는 영상이 나올 때까지 더 읽게 바꾼다.
            let lines = await listChannel("\(channel.url)/\(kind.rawValue)", latest: 30)
            if let error = lines.last(where: { $0.hasPrefix("ERROR:") }) {
                // 쇼츠나 라이브를 올린 적 없는 채널은 그 탭이 없다. 실패가 아니다
                if !error.contains("does not have a") { failed = true }
                continue
            }
            if !lines.contains(where: { $0.hasPrefix("CH UC") }) { failed = true; continue }
            fresh += Self.videoIDs(lines).filter { !known.contains($0) && attempted.insert($0).inserted }
        }
        for id in fresh {
            let item = DownloadItem(url: "https://www.youtube.com/watch?v=\(id)",
                                    folder: channel.folder, archive: channel.archive.path)
            item.channelName = channel.name
            start(item)
        }
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        channelStatus[channel.id] = "\(time) 확인" + (failed ? " 실패" : "") + (fresh.isEmpty ? "" : " · 새 영상 \(fresh.count)개")
        return !failed
    }

    // MARK: 업데이트

    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    static let launchedAt = Date.now

    private(set) var newRelease: AppRelease?    // 지금 버전보다 새 릴리스가 있으면
    private(set) var updateStatus = ""          // 설정 창에 보일 한 줄
    private(set) var ytdlpVersion: String?
    private(set) var toolStatus = ""            // 설정 창의 받기 도구 칸에 보일 한 줄
    private(set) var toolBusy = false
    private var updateTask: Task<Void, Never>?  // 하루 한 번 업데이트 확인 예약. 확인을 꺼 두면 nil
    private var installing = false
    private var installDeferred = false         // 받는 중이거나 창이 열려 있어 설치를 미뤄 둔 상태

    /// 0 확인 안 함, 1 새 버전이 있으면 알림(기본값), 2 자동으로 설치
    static var updateMode: Int {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "updateMode") == nil ? 1 : defaults.integer(forKey: "updateMode")
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedDescending
    }

    /// 업데이트 확인 예약. 켤 때 한 번, 그 뒤로 하루에 한 번. "확인 안 함" 이면 아무것도 돌리지 않는다.
    func scheduleUpdateCheck() {
        updateTask?.cancel()
        updateTask = nil
        guard Self.updateMode > 0 else { return }
        updateTask = Task {
            while !Task.isCancelled {
                await checkForUpdate()
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    /// GitHub 의 최신 릴리스를 지금 버전과 비교한다. "자동으로 설치" 면 이어서 설치한다.
    func checkForUpdate() async {
        updateStatus = "확인 중"
        // 한 번 쓰고 닫는 세션. 연결을 남겨 두지 않는다
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/sudapeople/videograb/releases/latest")!)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else {
            updateStatus = "업데이트를 확인하지 못했습니다"
            return
        }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.isNewer(version, than: Self.currentVersion) else {
            newRelease = nil
            updateStatus = "최신 버전입니다"
            return
        }
        let asset = (json["assets"] as? [[String: Any]])?.first { ($0["name"] as? String)?.hasSuffix("-arm64.zip") == true }
        guard let link = asset?["browser_download_url"] as? String, let zip = URL(string: link),
              let digest = asset?["digest"] as? String, digest.hasPrefix("sha256:") else {
            updateStatus = "새 버전 \(version) 이 있지만 설치 파일을 찾지 못했습니다"
            return
        }
        newRelease = AppRelease(version: version, zip: zip, sha256: String(digest.dropFirst(7)))
        updateStatus = "새 버전 \(version) 이 있습니다"
        if Self.updateMode == 2 {
            await installUpdate(automatic: true)
        } else if UserDefaults.standard.string(forKey: "notifiedVersion") != version {
            // 같은 버전은 한 번만 알린다 (알림을 허용해 둔 경우에만 보인다)
            UserDefaults.standard.set(version, forKey: "notifiedVersion")
            let content = UNMutableNotificationContent()
            content.title = "VideoGrab \(version) 이 나왔습니다"
            content.body = "설정 창에서 설치할 수 있습니다."
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "update-\(version)", content: content, trigger: nil))
        }
    }

    /// 미뤄 둔 설치가 있고 이제 설치할 수 있으면 설치한다. 받기가 끝날 때와 창이 닫힐 때 부른다.
    func installIfDeferred() {
        guard installDeferred, !installing else { return }
        Task { await installUpdate(automatic: true) }
    }

    /// 새 버전을 받아 확인값을 대조하고, 앱을 바꾼 뒤 다시 켠다.
    /// automatic 이면 쓰는 중에 갑자기 꺼지지 않게, 받는 중이거나 창이 열려 있을 때는 미룬다
    /// (앱을 막 켠 1분 안은 예외로 바로 설치한다).
    func installUpdate(automatic: Bool) async {
        guard let release = newRelease, !installing else { return }
        if items.contains(where: \.isActive) {
            installDeferred = true
            updateStatus = "새 버전 \(release.version): 받는 중인 항목이 끝나면 설치합니다"
            return
        }
        if automatic, AppDelegate.hasWindow, Date.now.timeIntervalSince(Self.launchedAt) > 60 {
            installDeferred = true
            updateStatus = "새 버전 \(release.version): 창을 모두 닫으면 설치합니다"
            return
        }
        installDeferred = false
        let app = Bundle.main.bundlePath
        guard !app.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: (app as NSString).deletingLastPathComponent) else {
            updateStatus = "새 버전 \(release.version): 앱을 응용 프로그램 폴더로 옮긴 뒤에 설치할 수 있습니다"
            return
        }
        installing = true
        defer { installing = false }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("VideoGrab-update-\(UUID().uuidString)")
        var handedOver = false      // 바꿔치기 스크립트에 넘겼으면 임시 폴더는 스크립트가 지운다
        defer { if !handedOver { try? FileManager.default.removeItem(at: temp) } }
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        do {
            try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
            updateStatus = "\(release.version) 내려받는 중"
            var request = URLRequest(url: release.zip)
            request.timeoutInterval = 60
            let (file, response) = try await session.download(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError(message: "내려받지 못했습니다") }
            let zip = temp.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: file, to: zip)
            let hash = SHA256.hash(data: try Data(contentsOf: zip)).map { String(format: "%02x", $0) }.joined()
            guard hash == release.sha256 else { throw UpdateError(message: "내려받은 파일이 릴리스의 확인값과 다릅니다") }
            let unpacked = temp.appendingPathComponent("unpacked")
            try Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
            let fresh = unpacked.appendingPathComponent("VideoGrab-\(release.version)/VideoGrab.app")
            guard let bundle = Bundle(url: fresh), bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
                  bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.version else {
                throw UpdateError(message: "받은 파일이 VideoGrab \(release.version) 이 아닙니다")
            }
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", fresh.path])
            // 이 앱이 끝나기를 기다렸다가(최대 30초) 앱을 바꾸고 다시 켠 뒤 임시 폴더를 지우는 스크립트.
            // 바꾸다 실패하면 원래 앱을 되돌린다. 다시 켤 때는 처음 켤 때 받은 실행 인자를 그대로 넘기고,
            // 창 없이 상단바에만 있었으면 창 없이 켠다.
            let script = """
                pid="$1"; app="$2"; fresh="$3"; temp="$4"; shift 4
                i=0; while kill -0 "$pid" 2>/dev/null && [ $i -lt 150 ]; do sleep 0.2; i=$((i+1)); done
                if ! kill -0 "$pid" 2>/dev/null; then
                    rm -rf "$app.old"
                    if mv "$app" "$app.old"; then
                        if mv "$fresh" "$app"; then rm -rf "$app.old"; else mv "$app.old" "$app"; fi
                    fi
                fi
                rm -rf "$temp"
                if [ $# -gt 0 ]; then open "$app" --args "$@"; else open "$app"; fi
                """
            var relaunch = Array(CommandLine.arguments.dropFirst())
            if let i = relaunch.firstIndex(of: "-startHidden") { relaunch.removeSubrange(i...min(i + 1, relaunch.count - 1)) }
            if !AppDelegate.hasWindow && UserDefaults.standard.bool(forKey: "keepInMenuBar") { relaunch += ["-startHidden", "YES"] }
            let sh = Process()
            sh.executableURL = URL(fileURLWithPath: "/bin/sh")
            sh.arguments = ["-c", script, "sh", "\(ProcessInfo.processInfo.processIdentifier)", app, fresh.path, temp.path] + relaunch
            sh.standardInput = FileHandle.nullDevice
            sh.standardOutput = FileHandle.nullDevice
            sh.standardError = FileHandle.nullDevice
            try sh.run()
            handedOver = true
            updateStatus = "\(release.version) 을 설치하고 다시 켭니다"
            NSApp.terminate(nil)
        } catch {
            updateStatus = "설치하지 못했습니다. " + ((error as? UpdateError)?.message ?? error.localizedDescription)
        }
    }

    /// 짧게 끝나는 도구를 돌리고 끝날 때까지 기다린다. 실패하면 던진다.
    static func run(_ path: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw UpdateError(message: "\((path as NSString).lastPathComponent) 가 실패했습니다") }
    }

    /// 설치된 yt-dlp 의 버전을 읽는다 (설정 창을 열 때).
    func refreshToolVersion() async {
        guard let (p, pipe) = Self.ytdlp(["--version"]) else { ytdlpVersion = nil; return }
        ytdlpVersion = await collect(p, pipe, limit: 20).first { $0.first?.isNumber == true }
    }

    /// Homebrew 로 yt-dlp 를 최신으로 올린다. 유튜브가 바뀌어 갑자기 안 받아질 때 쓴다.
    func upgradeYtdlp() async {
        guard !toolBusy else { return }
        guard let brew = Self.findTool("brew") else {
            toolStatus = "Homebrew 를 찾지 못했습니다. 터미널에서 brew upgrade yt-dlp"
            return
        }
        toolBusy = true
        defer { toolBusy = false }
        toolStatus = "yt-dlp 업데이트 중 (1~2분 걸릴 수 있습니다)"
        let before = ytdlpVersion
        let p = Process()
        p.executableURL = URL(fileURLWithPath: brew)
        p.arguments = ["upgrade", "yt-dlp"]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        let lines = await collect(p, pipe, limit: 600)
        await refreshToolVersion()
        if p.terminationStatus != 0 {
            toolStatus = "yt-dlp 업데이트 실패: " + (lines.last { $0.hasPrefix("Error") } ?? lines.last ?? "알 수 없는 오류")
        } else if ytdlpVersion == before {
            toolStatus = "yt-dlp 는 이미 최신입니다"
        } else {
            toolStatus = "yt-dlp 를 \(ytdlpVersion ?? "새 버전")(으)로 올렸습니다"
        }
    }

    static func selfTest() {
        precondition(channelURL("https://www.youtube.com/@sudapeople/videos") == "https://www.youtube.com/@sudapeople")
        precondition(channelURL("https://youtube.com/channel/UCabc?si=x") == "https://www.youtube.com/channel/UCabc")
        precondition(channelURL("https://www.youtube.com/watch?v=l5UC2--WFq8") == nil)
        precondition(channelURL("https://www.youtube.com/shorts/0v4erqt4FW8") == nil)
        precondition(channelURL("https://www.instagram.com/@someone") == nil)
        precondition(videoIDs(["l5UC2--WFq8 NA", "CH UCcm7Jc50537eMixvkVNU8-Q SUDA", "abcdefghijk is_live",
                               "abcdefghijk is_upcoming", "ERROR: failed", "0v4erqt4FW8 was_live"])
                     == ["l5UC2--WFq8", "0v4erqt4FW8"])
        precondition(nameTemplate("https://www.instagram.com/reel/abc/").contains("[%(id)s]"))
        precondition(nameTemplate("https://x.com/a/status/1").contains("[%(id)s]"))
        precondition(!nameTemplate("https://www.youtube.com/watch?v=l5UC2--WFq8").contains("%(id)s"))
        precondition(isNewer("1.10", than: "1.9") && isNewer("2.0", than: "1.99") && !isNewer("1.3", than: "1.3"))
        var channel = Channel(id: "UCx", name: "x", url: "u", folder: "f", baseline: [], addedAt: .now)
        precondition(channel.autoKinds == Set(Kind.allCases))    // 기록이 없으면 모두 켜짐
        channel.paused = true
        precondition(channel.autoKinds.isEmpty)                  // 1.2 까지의 "꺼 둔 채널"
        channel.auto = ["shorts", "모르는 값"]
        precondition(channel.autoKinds == [.shorts])             // 새 기록이 있으면 그것을 따른다
        print("자체 점검 통과")
    }
}

// MARK: - 화면

struct ContentView: View {
    let store: DownloadStore
    @AppStorage("outputDir") private var outputDir = defaultOutputDir
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                ContentUnavailableView {
                    Label("링크를 붙여넣으세요", systemImage: "arrow.down.circle")
                } description: {
                    Text("유튜브·인스타그램·X 영상 주소를 복사한 뒤 이 창에서 ⌘V 를 누르면\n최고 화질로 바로 받습니다.\n유튜브 채널은 채널 관리(⌘2)에서 등록합니다.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.items) { item in
                    ItemRow(item: item, store: store)
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 300)
        // 채널 주소를 붙여넣었으면 채널 관리 창을 열어 추가 창을 띄운다
        .onChange(of: store.addDraft?.id) { _, id in
            if id != nil { openWindow(id: "channels") }
        }
        .toolbar {
            Button("링크 붙여넣기", systemImage: "doc.on.clipboard") { store.pasteFromClipboard() }
                .help("클립보드의 링크 받기 (⌘V)")
            Button("채널 관리", systemImage: "play.tv") { openWindow(id: "channels") }
                .help("유튜브 채널 등록·삭제, 채널별 저장 폴더 (⌘2)")
            SettingsLink { Label("설정", systemImage: "gearshape") }
                .help("설정 (⌘,)")
            Button("끝난 항목 지우기", systemImage: "trash") { store.clearFinished() }
                .disabled(!store.items.contains { !$0.isActive })
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(outputDir)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
            if let release = store.newRelease {
                Button("새 버전 \(release.version) 설치") { Task { await store.installUpdate(automatic: false) } }
                    .help("VideoGrab \(release.version) 을 내려받아 설치하고 다시 켭니다")
            }
            Button("Finder 에서 열기") {
                NSWorkspace.shared.open(URL(fileURLWithPath: outputDir))
            }
            Button("저장 위치 변경…") {
                if let path = pickFolder(startingAt: outputDir) { outputDir = path }
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

@MainActor
func pickFolder(startingAt path: String) -> String? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.prompt = "선택"
    panel.directoryURL = URL(fileURLWithPath: path)
    return panel.runModal() == .OK ? panel.url?.path : nil
}

// MARK: 상단바 메뉴

struct MenuBarMenu: View {
    let store: DownloadStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(store.statusLine)
        Divider()
        Button("VideoGrab 열기") { show { openWindow(id: "main") } }
        Button("채널 관리") { show { openWindow(id: "channels") } }
        Button("지금 새 영상 확인") { Task { await store.checkAll() } }
            .disabled(store.channels.isEmpty)
        if !store.recentDone.isEmpty {
            Divider()
            Text("최근 받은 영상")
            ForEach(store.recentDone) { item in
                Button(String((item.title ?? "받은 영상").prefix(40))) {
                    if let path = item.filePath {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                }
            }
        }
        Divider()
        if let release = store.newRelease {
            Button("새 버전 \(release.version) 설치") { Task { await store.installUpdate(automatic: false) } }
        }
        Button("설정…") { show { openSettings() } }
        Divider()
        Button("VideoGrab 종료") { NSApp.terminate(nil) }
    }

    // 창 없이 상단바에만 있을 때는 Dock 아이콘이 없는 상태라, 먼저 보통 앱으로 돌린 뒤 창을 연다
    private func show(_ open: () -> Void) {
        NSApp.setActivationPolicy(.regular)
        open()
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: 설정 창

struct SettingsView: View {
    let store: DownloadStore
    @AppStorage("outputDir") private var outputDir = defaultOutputDir
    @AppStorage("checkMinutes") private var checkMinutes = 30
    @AppStorage("keepInMenuBar") private var keepInMenuBar = false
    @AppStorage("notifyNew") private var notifyNew = false
    @AppStorage("updateMode") private var updateMode = 1
    @State private var loginItem = SMAppService.mainApp.status == .enabled
    @State private var note: String?    // 백그라운드 절에 보일 안내·오류
    @Environment(\.openWindow) private var openWindow

    private func setLoginItem(_ on: Bool) {
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            note = "응용 프로그램 폴더에 설치한 앱에서만 로그인 자동 실행을 켤 수 있습니다."
            return
        }
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            note = nil
        } catch {
            note = "로그인 자동 실행을 바꾸지 못했습니다. \(error.localizedDescription)"
        }
        loginItem = SMAppService.mainApp.status == .enabled
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                if granted { return }
                notifyNew = false
                note = "알림이 막혀 있습니다. 시스템 설정 > 알림에서 VideoGrab 을 허용한 뒤 다시 켜 주세요."
            }
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("저장 위치") {
                    Text(tilde(outputDir))
                        .lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                    Button("변경…") {
                        if let path = pickFolder(startingAt: outputDir) { outputDir = path }
                    }
                }
            } header: {
                Text("영상 받기")
            } footer: {
                Text("주소를 붙여넣어 받는 영상을 저장하는 곳입니다. 채널 영상은 채널마다 정한 폴더에 저장합니다.")
            }
            Section {
                Picker("새 영상 확인", selection: $checkMinutes) {
                    Text("15분마다").tag(15)
                    Text("30분마다").tag(30)
                    Text("1시간마다").tag(60)
                    Text("3시간마다").tag(180)
                    Divider()
                    Text("자동으로 확인 안 함").tag(0)
                }
                Button("채널 관리 열기…") { openWindow(id: "channels") }
            } header: {
                Text("채널")
            } footer: {
                Text("앱이 켜져 있는 동안에만 확인합니다. 켤 때 한 번 확인하고, 그 뒤로 이 주기마다 확인합니다. 새 영상은 한 번에 하나씩 받습니다.")
            }
            .onChange(of: checkMinutes) { store.scheduleWatch() }
            Section {
                Toggle("상단바에서 계속 실행", isOn: $keepInMenuBar)
                Toggle("로그인할 때 자동으로 실행", isOn: Binding(get: { loginItem }, set: setLoginItem))
                Toggle("채널 영상을 받으면 알림", isOn: $notifyNew)
            } header: {
                Text("백그라운드")
            } footer: {
                Text(note ?? "상단바에서 계속 실행을 켜면 창을 모두 닫아도 상단바 아이콘으로 남아 새 영상을 확인합니다. Dock 아이콘은 창이 열려 있을 때만 보입니다. 끄면 창을 닫을 때 앱이 끝납니다. 둘 다 켜면 로그인할 때 창 없이 상단바로 시작합니다.")
            }
            .onChange(of: keepInMenuBar) { AppDelegate.updateDockIcon() }
            .onChange(of: notifyNew) { _, on in if on { requestNotifications() } }
            Section {
                Picker("앱 업데이트", selection: $updateMode) {
                    Text("새 버전이 있으면 알림").tag(1)
                    Text("자동으로 설치").tag(2)
                    Divider()
                    Text("확인 안 함").tag(0)
                }
                LabeledContent("지금 버전") {
                    Text(store.updateStatus.isEmpty ? DownloadStore.currentVersion
                         : "\(DownloadStore.currentVersion) · \(store.updateStatus)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("지금 확인") { Task { await store.checkForUpdate() } }
                    if let release = store.newRelease {
                        Button("\(release.version) 설치") { Task { await store.installUpdate(automatic: false) } }
                    }
                }
            } header: {
                Text("업데이트")
            } footer: {
                Text("앱을 켤 때와 켜 둔 동안 하루에 한 번 GitHub 릴리스를 확인합니다. 설치할 때는 받은 파일의 확인값(SHA-256)을 릴리스와 대조합니다. 자동으로 설치는 받는 중이 아니고 창이 모두 닫혀 있을 때 설치하고 다시 켭니다.")
            }
            .onChange(of: updateMode) { store.scheduleUpdateCheck() }
            Section {
                ForEach(["yt-dlp", "ffmpeg", "deno"], id: \.self) { tool in
                    LabeledContent(tool) {
                        if let path = DownloadStore.findTool(tool) {
                            Text(tool == "yt-dlp" && store.ytdlpVersion != nil ? "\(store.ytdlpVersion ?? "") · \(path)" : path)
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        } else {
                            Text("없음").foregroundStyle(.red)
                        }
                    }
                }
                HStack {
                    Button("yt-dlp 업데이트") { Task { await store.upgradeYtdlp() } }
                        .disabled(store.toolBusy)
                    Text(store.toolStatus).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } header: {
                Text("받기 도구")
            } footer: {
                Text("유튜브가 바뀌어 갑자기 안 받아지면 yt-dlp 를 업데이트합니다(Homebrew 의 brew upgrade yt-dlp 를 실행). 없는 도구는 터미널에서 brew install yt-dlp ffmpeg deno 로 설치합니다.")
            }
            .task { await store.refreshToolVersion() }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: 채널 관리 창

struct ChannelManager: View {
    @Bindable var store: DownloadStore
    @State private var selection: Channel.ID?
    @State private var deleting: Channel?

    private var selected: Channel? { store.channels.first { $0.id == selection } }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.registering, id: \.self) { _ in
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("채널 등록 중").foregroundStyle(.secondary)
                    }
                    .selectionDisabled()
                }
                ForEach(store.channels) { channel in
                    Label(channel.name, systemImage: channel.autoKinds.isEmpty ? "pause.circle" : "play.tv")
                        .contextMenu {
                            Button("채널 삭제…", role: .destructive) { deleting = channel }
                        }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
            .onDeleteCommand { deleting = selected }
        } detail: {
            if let channel = selected {
                ChannelDetail(channel: channel, store: store)
            } else {
                ContentUnavailableView {
                    Label(store.channels.isEmpty ? "등록한 채널이 없습니다" : "채널을 선택하세요", systemImage: "play.tv")
                } description: {
                    Text("유튜브 채널을 등록하면 채널 영상을 한꺼번에 받거나\n새로 올라오는 영상을 자동으로 받습니다.")
                } actions: {
                    Button("채널 추가…") { add() }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 380)
        .toolbar {
            Button("채널 추가", systemImage: "plus") { add() }
                .help("유튜브 채널 추가")
            Button("채널 삭제", systemImage: "trash") { deleting = selected }
                .help("선택한 채널 삭제")
                .disabled(selected == nil)
            Button("새 영상 확인", systemImage: "arrow.clockwise") { Task { await store.checkAll() } }
                .help("자동 받기를 켠 채널의 새 영상을 지금 확인")
                .disabled(store.channels.isEmpty)
        }
        .sheet(item: $store.addDraft) { draft in
            AddChannelSheet(draft: draft, store: store)
        }
        .confirmationDialog("「\(deleting?.name ?? "")」 채널을 삭제할까요?",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { channel in
            Button("삭제", role: .destructive) { store.remove(channel) }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("이 채널의 새 영상을 더는 확인하지 않습니다. 받은 파일은 그대로 남습니다.")
        }
        .alert("VideoGrab", isPresented: Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })) {
        } message: {
            Text(store.alert ?? "")
        }
        .onAppear { selection = selection ?? store.channels.first?.id }
        .onChange(of: store.channels.map(\.id)) { old, new in
            // 새로 등록한 채널을 고르고, 고른 채널이 지워졌으면 첫 채널로 옮긴다
            if let added = new.first(where: { !old.contains($0) }) {
                selection = added
            } else if let current = selection, !new.contains(current) {
                selection = new.first
            }
        }
    }

    private func add() {
        // 클립보드에 채널 주소가 있으면 미리 채워 둔다
        let clip = NSPasteboard.general.string(forType: .string) ?? ""
        store.addDraft = AddDraft(url: DownloadStore.extractURLs(clip).compactMap(DownloadStore.channelURL).first ?? "")
    }
}

struct ChannelDetail: View {
    let channel: Channel
    let store: DownloadStore

    var body: some View {
        Form {
            Section {
                LabeledContent("채널") {
                    if let url = URL(string: channel.url) { Link(channel.name, destination: url) }
                }
                LabeledContent("등록한 날") {
                    Text(channel.addedAt.formatted(date: .long, time: .shortened))
                }
            }
            Section {
                LabeledContent("저장 폴더") {
                    Text(tilde(channel.folder))
                        .lineLimit(2).truncationMode(.middle)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                HStack {
                    Button("폴더 변경…") {
                        if let path = pickFolder(startingAt: channel.folder) { store.setFolder(channel, path) }
                    }
                    Button("Finder 에서 열기") {
                        try? FileManager.default.createDirectory(atPath: channel.folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(URL(fileURLWithPath: channel.folder))
                    }
                }
            } footer: {
                Text("이 채널의 영상만 저장하는 폴더입니다. 바꾼 뒤에 받는 영상부터 새 폴더에 저장합니다.")
            }
            Section {
                ForEach(Kind.allCases) { kind in
                    Toggle(kind.detail, isOn: Binding(get: { channel.autoKinds.contains(kind) },
                                                      set: { store.setAuto(channel, kind, $0) }))
                }
                LabeledContent("확인 결과") {
                    Text(store.channelStatus[channel.id] ?? "아직 확인하지 않음").foregroundStyle(.secondary)
                }
                Button("지금 확인") { Task { await store.check(channel) } }
                    .disabled(channel.autoKinds.isEmpty)
            } header: {
                Text("새 영상 자동 받기")
            } footer: {
                Text("켜 둔 종류만, 등록한 뒤에 올라온 영상을 받습니다. 등록할 때 이미 있던 영상 \(channel.baseline.count)개는 자동으로 받지 않습니다.")
            }
            Section {
                LabeledContent("받은 영상") {
                    Text("\(store.downloadedIDs(channel).count)개").foregroundStyle(.secondary)
                }
                HStack {
                    ForEach(Kind.allCases) { kind in
                        Button(store.isDownloadingAll(channel, kind) ? "\(kind.label) 받는 중" : "\(kind.label) 전체") {
                            store.downloadAll(channel, kind)
                        }
                        .disabled(store.isDownloadingAll(channel, kind))
                    }
                }
            } header: {
                Text("전체 받기")
            } footer: {
                Text("종류별로 이미 올라와 있는 영상을 모두 받습니다. 이미 받은 영상은 건너뜁니다. 진행 상황은 VideoGrab 창(⌘1)에 나옵니다.")
            }
        }
        .formStyle(.grouped)
    }
}

struct AddChannelSheet: View {
    let store: DownloadStore
    @State private var url: String
    @State private var folder: String?
    @Environment(\.dismiss) private var dismiss

    init(draft: AddDraft, store: DownloadStore) {
        self.store = store
        _url = State(initialValue: draft.url)
    }

    // 입력한 주소가 유튜브 채널 주소면 정리한 주소, 아니면 nil. https:// 를 빼고 적어도 받는다.
    private var channelURL: String? {
        let text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return DownloadStore.channelURL(text.contains("://") ? text : "https://" + text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("채널 추가").font(.headline)
            Form {
                TextField("채널 주소", text: $url, prompt: Text("https://www.youtube.com/@이름"))
                LabeledContent("저장 폴더") {
                    Text(folder.map(tilde) ?? tilde(DownloadStore.outputDir) + "/채널 이름")
                        .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button("선택…") {
                        if let path = pickFolder(startingAt: folder ?? DownloadStore.outputDir) { folder = path }
                    }
                }
            }
            if !url.isEmpty && channelURL == nil {
                Text(verbatim: "유튜브 채널 주소가 아닙니다. 예: https://www.youtube.com/@이름")
                    .font(.caption).foregroundStyle(.red)
            } else {
                Text("등록한 뒤에 올라오는 영상부터 자동으로 받습니다. 이미 있는 영상은 등록한 뒤 「채널 영상 전체 받기」로 받습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("취소", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("등록") {
                    if let channelURL { store.register(channelURL, folder: folder) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(channelURL == nil)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

struct ItemRow: View {
    let item: DownloadItem
    let store: DownloadStore

    private var runningText: String {
        let percent = item.title == nil ? "정보 가져오는 중" : item.progress >= 1 ? "마무리 중" : "\(Int(item.progress * 100))%"
        guard item.batchName != nil, let title = item.title else { return percent }
        return "\(item.count)개 받음 · \(percent) · \(title)"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.batchName.map { "\($0) 전체 받기" } ?? item.title ?? item.url)
                    .lineLimit(1)
                    .truncationMode(.middle)
                switch item.status {
                case .waiting:
                    Text("대기 중").font(.caption).foregroundStyle(.secondary)
                case .running:
                    ProgressView(value: item.progress)
                    Text(runningText)
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        .lineLimit(1).truncationMode(.middle)
                case .done:
                    Text(item.batchName == nil ? "완료" : "완료 · \(item.count)개 받음")
                        .font(.caption).foregroundStyle(.secondary)
                case .cancelled:
                    Text("취소됨").font(.caption).foregroundStyle(.secondary)
                case .failed(let message):
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(2).textSelection(.enabled)
                }
            }
            Spacer()
            switch item.status {
            case .waiting, .running:
                Button("취소", systemImage: "xmark.circle") { store.cancel(item) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
            case .done:
                Button("Finder 에서 보기", systemImage: "magnifyingglass") {
                    if let path = item.filePath {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }
                }
                .labelStyle(.iconOnly).buttonStyle(.borderless)
            case .failed, .cancelled:
                Button("다시 받기", systemImage: "arrow.clockwise") { store.run(item) }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("링크 복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url, forType: .string)
            }
        }
    }
}
