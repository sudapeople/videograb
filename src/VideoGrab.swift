import SwiftUI
import AppKit

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

// 등록한 유튜브 채널. 등록할 때 이미 있던 영상(baseline) 밖의 영상이 "새 영상" 이다.
struct Channel: Codable, Identifiable {
    let id: String          // UC 로 시작하는 채널 ID
    var name: String
    let url: String
    var folder: String      // 이 채널 영상을 저장하는 곳
    let baseline: [String]
    let addedAt: Date

    // yt-dlp 가 받은 영상 ID 를 적어 두는 파일. 전체 받기와 자동 받기가 같이 쓴다.
    var archive: URL { dataDir.appendingPathComponent("\(id).txt") }
}

@main
struct VideoGrabApp: App {
    @State private var store = DownloadStore()

    init() {
        // ./scripts/build.sh 가 빌드 직후 돌리는 자체 점검
        if CommandLine.arguments.contains("--selftest") { DownloadStore.selfTest(); exit(0) }
    }

    var body: some Scene {
        Window("VideoGrab", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 680, height: 440)
        .commands {
            // 텍스트 입력칸이 없는 앱이라 붙여넣기 메뉴를 통째로 링크 붙여넣기로 바꾼다.
            CommandGroup(replacing: .pasteboard) {
                Button("링크 붙여넣기") { store.pasteFromClipboard() }
                    .keyboardShortcut("v")
            }
        }
    }
}

// MARK: - 모델

@MainActor @Observable
final class DownloadItem: Identifiable {
    enum Status: Equatable {
        case running, done, cancelled
        case failed(String)
    }

    let id = UUID()
    let url: String
    let folder: String?         // nil 이면 창 아래 저장 위치. 채널 영상은 채널 폴더
    let archive: String?        // 채널 영상만: 받은 영상 기록 파일
    let batchName: String?      // 채널 전체 받기일 때 채널 이름
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
        status = code == 0 ? .done : .failed(batchName == nil ? error : "\(count)개 받음, 일부 실패 · \(error)")
    }
}

@MainActor @Observable
final class DownloadStore {
    var items: [DownloadItem] = []

    func pasteFromClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let urls = Self.extractURLs(text)
        if urls.isEmpty { NSSound.beep(); return }
        for url in urls {
            if let channel = Self.channelURL(url) {
                register(channel)
            } else if !items.contains(where: { $0.url == url && $0.status == .running }) {
                start(DownloadItem(url: url))
            }
        }
    }

    func start(_ item: DownloadItem) {
        items.insert(item, at: 0)
        run(item)
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
        p.arguments = args
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
        }
    }

    func cancel(_ item: DownloadItem) {
        item.status = .cancelled
        item.process?.terminate()
    }

    func clearFinished() {
        items.removeAll { $0.status != .running }
    }

    // MARK: 채널

    var channels: [Channel] = DownloadStore.loadChannels()
    var registering: [String] = []          // 등록 중인 채널 주소
    var channelStatus: [String: String] = [:]
    var alert: String?
    private var checking = false
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
    static func listChannel(_ url: String, latest: Int? = nil) async -> [String] {
        var args = ["--flat-playlist",
                    "--print", "playlist:CH %(channel_id)s %(channel)s",
                    "--print", "%(id)s %(live_status)s"]
        if let latest { args += ["-I", ":\(latest)"] }
        guard let (p, pipe) = ytdlp(args + [url]), (try? p.run()) != nil else { return [] }
        var lines: [String] = []
        do {
            for try await line in pipe.fileHandleForReading.bytes.lines { lines.append(line) }
        } catch {}
        return lines
    }

    func register(_ url: String) {
        if registering.contains(url) { return }
        registering.append(url)
        Task { @MainActor in
            defer { registering.removeAll { $0 == url } }
            let lines = await Self.listChannel(url)
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
            let folder = Self.outputDir + "/" + name.replacingOccurrences(of: "/", with: "_")
            channels.append(Channel(id: f[1], name: name, url: "https://www.youtube.com/channel/\(f[1])",
                                    folder: folder, baseline: Self.videoIDs(lines), addedAt: .now))
            saveChannels()
        }
    }

    func remove(_ channel: Channel) {
        channels.removeAll { $0.id == channel.id }
        saveChannels()
    }

    func setFolder(_ channel: Channel, _ folder: String) {
        guard let i = channels.firstIndex(where: { $0.id == channel.id }) else { return }
        channels[i].folder = folder
        saveChannels()
    }

    func isDownloadingAll(_ channel: Channel) -> Bool {
        items.contains { $0.batchName != nil && $0.url == channel.url && $0.status == .running }
    }

    /// 채널 영상 전체 받기. yt-dlp 하나가 차례로 받고, 받은 영상은 기록 파일 덕에 다시 받지 않는다.
    func downloadAll(_ channel: Channel) {
        if isDownloadingAll(channel) { return }
        start(DownloadItem(url: channel.url, folder: channel.folder,
                           archive: channel.archive.path, batchName: channel.name))
    }

    /// 앱이 켜져 있는 동안 등록한 채널의 새 영상을 확인한다. 켤 때 한 번, 그 뒤로 30분마다.
    func watch() async {
        while !Task.isCancelled {
            await checkAll()
            try? await Task.sleep(for: .seconds(30 * 60))
        }
    }

    func checkAll() async {
        if checking { return }
        checking = true
        defer { checking = false }
        for channel in channels { await check(channel) }
    }

    private func check(_ channel: Channel) async {
        channelStatus[channel.id] = "새 영상 확인 중"
        // ponytail: 탭마다 최신 30개만 본다(요청 1번). 앱을 꺼 둔 사이 한 탭에 30개 넘게 올라오면
        // 그 앞 영상은 놓친다. 필요해지면 아는 영상이 나올 때까지 더 읽게 바꾼다.
        let lines = await Self.listChannel(channel.url, latest: 30)
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        if lines.contains(where: { $0.hasPrefix("ERROR:") }) || !lines.contains(where: { $0.hasPrefix("CH UC") }) {
            channelStatus[channel.id] = "\(time) 확인 실패"
            return
        }
        let archived = (try? String(contentsOf: channel.archive, encoding: .utf8))?
            .split(separator: "\n").compactMap { $0.split(separator: " ").last.map(String.init) } ?? []
        let known = Set(channel.baseline).union(archived)
        let fresh = Self.videoIDs(lines).filter { !known.contains($0) && attempted.insert($0).inserted }
        for id in fresh {
            start(DownloadItem(url: "https://www.youtube.com/watch?v=\(id)",
                               folder: channel.folder, archive: channel.archive.path))
        }
        channelStatus[channel.id] = "\(time) 확인" + (fresh.isEmpty ? "" : " · 새 영상 \(fresh.count)개")
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
        print("자체 점검 통과")
    }
}

// MARK: - 화면

struct ContentView: View {
    let store: DownloadStore
    @AppStorage("outputDir") private var outputDir = defaultOutputDir

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty && store.channels.isEmpty && store.registering.isEmpty {
                ContentUnavailableView {
                    Label("링크를 붙여넣으세요", systemImage: "arrow.down.circle")
                } description: {
                    Text("유튜브·인스타그램·X 영상 주소를 복사한 뒤 이 창에서 ⌘V 를 누르면\n최고 화질로 바로 받습니다.\n유튜브 채널 주소를 붙여넣으면 채널을 등록해 새 영상을 자동으로 받습니다.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !store.channels.isEmpty || !store.registering.isEmpty {
                        Section("채널") {
                            ForEach(store.registering, id: \.self) { url in
                                HStack(spacing: 8) {
                                    ProgressView().controlSize(.small)
                                    Text("채널 등록 중  \(url)")
                                        .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                                }
                            }
                            ForEach(store.channels) { channel in
                                ChannelRow(channel: channel, store: store)
                            }
                        }
                    }
                    if !store.items.isEmpty {
                        Section("받기") {
                            ForEach(store.items) { item in
                                ItemRow(item: item, store: store)
                            }
                        }
                    }
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 300)
        .task { await store.watch() }
        .alert("VideoGrab", isPresented: Binding(get: { store.alert != nil }, set: { if !$0 { store.alert = nil } })) {
        } message: {
            Text(store.alert ?? "")
        }
        .toolbar {
            Button("링크 붙여넣기", systemImage: "doc.on.clipboard") { store.pasteFromClipboard() }
                .help("클립보드의 링크 받기 (⌘V)")
            Button("새 영상 확인", systemImage: "arrow.clockwise") { Task { await store.checkAll() } }
                .help("등록한 채널의 새 영상을 지금 확인")
                .disabled(store.channels.isEmpty)
            Button("끝난 항목 지우기", systemImage: "trash") { store.clearFinished() }
                .disabled(!store.items.contains { $0.status != .running })
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

struct ChannelRow: View {
    let channel: Channel
    let store: DownloadStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.tv")
                .font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name).lineLimit(1)
                Text("\((channel.folder as NSString).abbreviatingWithTildeInPath)  ·  \(status)")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button("전체 받기") { store.downloadAll(channel) }
                .disabled(store.isDownloadingAll(channel))
                .help("이 채널의 영상을 모두 받기. 이미 받은 영상은 건너뜀")
            Menu {
                Button("저장 폴더 변경…") {
                    if let path = pickFolder(startingAt: channel.folder) { store.setFolder(channel, path) }
                }
                Button("Finder 에서 열기") {
                    try? FileManager.default.createDirectory(atPath: channel.folder, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(URL(fileURLWithPath: channel.folder))
                }
                Button("채널 페이지 열기") {
                    if let url = URL(string: channel.url) { NSWorkspace.shared.open(url) }
                }
                Divider()
                Button("등록 해제", role: .destructive) { store.remove(channel) }
            } label: {
                Label("채널 메뉴", systemImage: "ellipsis.circle").labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private var status: String {
        store.channelStatus[channel.id]
            ?? "새 영상 자동 받기 · \(channel.addedAt.formatted(date: .numeric, time: .omitted)) 등록"
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
            case .running:
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
