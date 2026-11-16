import SwiftUI
import AppKit

// 저장 위치 기본값. 사용자가 바꾸면 UserDefaults "outputDir" 에 남는다.
let defaultOutputDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Downloads").path

@main
struct VideoGrabApp: App {
    @State private var store = DownloadStore()

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
    var title: String?
    var progress: Double = 0
    var status: Status = .running
    var filePath: String?
    var lastError: String?
    var process: Process?

    init(url: String) { self.url = url }

    func handle(_ line: String) {
        if line.hasPrefix("TITLE ") {
            title = String(line.dropFirst(6))
        } else if line.hasPrefix("PROG ") {
            progress = min(max((Double(line.dropFirst(5)) ?? 0) / 100, 0), 1)
        } else if line.hasPrefix("FILE ") {
            filePath = String(line.dropFirst(5))
        } else if line.hasPrefix("ERROR:") {
            lastError = line
        }
    }

    func finish(_ code: Int32) {
        process = nil
        if status == .cancelled { return }
        status = code == 0 ? .done : .failed(lastError ?? "yt-dlp 종료 코드 \(code)")
    }
}

@MainActor @Observable
final class DownloadStore {
    var items: [DownloadItem] = []

    func pasteFromClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        let urls = Self.extractURLs(text)
        if urls.isEmpty { NSSound.beep(); return }
        for url in urls where !items.contains(where: { $0.url == url && $0.status == .running }) {
            let item = DownloadItem(url: url)
            items.insert(item, at: 0)
            run(item)
        }
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

    func run(_ item: DownloadItem) {
        item.status = .running
        item.progress = 0
        item.lastError = nil

        guard let ytdlp = Self.findTool("yt-dlp") else {
            item.status = .failed("yt-dlp 가 없습니다. 터미널에서 brew install yt-dlp ffmpeg deno")
            return
        }
        let outputDir = UserDefaults.standard.string(forKey: "outputDir") ?? defaultOutputDir

        let p = Process()
        p.executableURL = URL(fileURLWithPath: ytdlp)
        p.arguments = [
            "--no-playlist",                 // watch?v=..&list=.. 링크도 영상 하나만
            "-f", "bv*+ba/b",                // 최고 화질 영상 + 최고 음질 오디오
            "--merge-output-format", "mp4",
            "--no-mtime",                    // 파일 날짜 = 받은 날짜
            "-P", outputDir,
            "-o", "%(title)s.%(ext)s",       // 파일명 = 영상 제목
            "--newline", "--progress",
            "--print", "before_dl:TITLE %(title)s",
            "--print", "after_move:FILE %(filepath)s",
            "--progress-template", "download:PROG %(progress._percent)s",
            item.url,
        ]
        // 앱은 셸 PATH 를 물려받지 않는다. ffmpeg·deno 를 yt-dlp 가 찾을 수 있게 넣어 준다.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice

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
}

// MARK: - 화면

struct ContentView: View {
    let store: DownloadStore
    @AppStorage("outputDir") private var outputDir = defaultOutputDir

    var body: some View {
        VStack(spacing: 0) {
            if store.items.isEmpty {
                ContentUnavailableView {
                    Label("링크를 붙여넣으세요", systemImage: "arrow.down.circle")
                } description: {
                    Text("유튜브 주소를 복사한 뒤 이 창에서 ⌘V 를 누르면\n최고 화질로 바로 받습니다.")
                }
            } else {
                List(store.items) { item in
                    ItemRow(item: item, store: store)
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 300)
        .toolbar {
            Button("링크 붙여넣기", systemImage: "doc.on.clipboard") { store.pasteFromClipboard() }
                .help("클립보드의 링크 받기 (⌘V)")
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
            Button("저장 위치 변경…") { chooseFolder() }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "선택"
        panel.directoryURL = URL(fileURLWithPath: outputDir)
        if panel.runModal() == .OK, let url = panel.url {
            outputDir = url.path
        }
    }
}

struct ItemRow: View {
    let item: DownloadItem
    let store: DownloadStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? item.url)
                    .lineLimit(1)
                    .truncationMode(.middle)
                switch item.status {
                case .running:
                    ProgressView(value: item.progress)
                    Text(item.title == nil ? "정보 가져오는 중" : item.progress >= 1 ? "마무리 중" : "\(Int(item.progress * 100))%")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                case .done:
                    Text("완료").font(.caption).foregroundStyle(.secondary)
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
