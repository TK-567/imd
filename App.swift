import SwiftUI
import AppKit
import WebKit
import UniformTypeIdentifiers

// MARK: - Model

struct Heading: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let title: String
    let sourceRange: NSRange
}

struct Block: Identifiable {
    let id: UUID
    let heading: Heading?
    let body: String
    init(heading: Heading) { self.id = heading.id; self.heading = heading; self.body = "" }
    init(body: String) { self.id = UUID(); self.heading = nil; self.body = body }
}

enum ActiveTab: String, Hashable { case preview = "预览", source = "源码" }

struct ScrollRequest: Equatable {
    let id = UUID()
    let headingID: UUID
}

struct MDDoc: Identifiable {
    let id = UUID()
    var text: String
    var fileURL: URL?
    var dirty: Bool = false
    var headings: [Heading] = []
    var blocks: [Block] = []
    var name: String { fileURL?.lastPathComponent ?? "未命名.md" }
}

// MARK: - Controller

final class EditorController: ObservableObject {
    @Published var docs: [MDDoc] = []
    @Published var active: Int = 0
    @Published var recentFiles: [URL] = []
    @Published var scrollRequest: ScrollRequest? = nil

    private let recentKey = "recentFiles"

    init() { loadRecent() }

    var activeDoc: MDDoc? {
        docs.indices.contains(active) ? docs[active] : nil
    }
    var activeText: String { activeDoc?.text ?? "" }
    var activeHeadings: [Heading] { activeDoc?.headings ?? [] }
    var activeBlocks: [Block] { activeDoc?.blocks ?? [] }

    // MARK: file ops

    func openDialog() {
        let panel = NSOpenPanel()
        panel.title = "打开 Markdown 文件"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown")].compactMap { $0 }
        if panel.runModal() == .OK {
            for url in panel.urls { open(url: url) }
        }
    }

    func open(url: URL) {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { NSSound.beep(); return }
        if let idx = docs.firstIndex(where: { $0.fileURL == url }) {
            docs[idx].text = s
            docs[idx].dirty = false
            active = idx
        } else {
            var d = MDDoc(text: s, fileURL: url)
            let (h, b) = parseDocument(s)
            d.headings = h
            d.blocks = b
            docs.append(d)
            active = docs.count - 1
        }
        reparseActive()
        pushRecent(url)
    }

    func newDoc() {
        var d = MDDoc(text: "", fileURL: nil)
        let (h, b) = parseDocument("")
        d.headings = h
        d.blocks = b
        docs.append(d)
        active = docs.count - 1
    }

    func closeDoc(at idx: Int) {
        guard docs.indices.contains(idx) else { return }
        docs.remove(at: idx)
        if docs.isEmpty { active = 0 }
        else if active >= docs.count { active = docs.count - 1 }
        else if active > idx { active -= 1 }
    }

    func selectTab(_ idx: Int) {
        if docs.indices.contains(idx) { active = idx }
    }

    func setText(_ s: String) {
        guard docs.indices.contains(active) else { return }
        if docs[active].text == s { return }
        docs[active].text = s
        docs[active].dirty = true
        let (h, b) = parseDocument(s)
        docs[active].headings = h
        docs[active].blocks = b
    }

    func reparseActive() {
        guard docs.indices.contains(active) else { return }
        let s = docs[active].text
        let (h, b) = parseDocument(s)
        docs[active].headings = h
        docs[active].blocks = b
    }

    func save() {
        guard let d = activeDoc else { return }
        if let url = d.fileURL {
            do {
                try d.text.write(to: url, atomically: true, encoding: .utf8)
                docs[active].dirty = false
                pushRecent(url)
            } catch { NSSound.beep() }
        } else {
            saveAs()
        }
    }

    func saveAs() {
        guard docs.indices.contains(active) else { return }
        let panel = NSSavePanel()
        panel.title = "保存为"
        panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
        panel.nameFieldStringValue = activeDoc?.name ?? "未命名.md"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try docs[active].text.write(to: url, atomically: true, encoding: .utf8)
                docs[active].fileURL = url
                docs[active].dirty = false
                pushRecent(url)
            } catch { NSSound.beep() }
        }
    }

    func jump(to heading: Heading) {
        scrollRequest = ScrollRequest(headingID: heading.id)
    }

    func headingByID(_ id: UUID) -> Heading? {
        activeHeadings.first { $0.id == id }
    }

    // MARK: recent

    func loadRecent() {
        recentFiles = (UserDefaults.standard.array(forKey: recentKey) as? [String] ?? [])
            .compactMap { URL(string: $0) }
    }

    func pushRecent(_ url: URL) {
        let s = url.absoluteString
        var list = recentFiles.map { $0.absoluteString }.filter { $0 != s }
        list.insert(s, at: 0)
        if list.count > 12 { list = Array(list.prefix(12)) }
        UserDefaults.standard.set(list, forKey: recentKey)
        loadRecent()
    }

    func clearRecent() {
        UserDefaults.standard.removeObject(forKey: recentKey)
        recentFiles = []
    }
}

// MARK: - Markdown parsing

private let headingRegex: NSRegularExpression = {
    do { return try NSRegularExpression(pattern: "^(#{1,6})\\s+(.+?)\\s*#*$") }
    catch { fatalError("invalid regex") }
}()

private func matchHeading(_ line: String) -> (level: Int, title: String)? {
    let ns = line as NSString
    guard let m = headingRegex.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else {
        return nil
    }
    let level = ns.substring(with: m.range(at: 1)).count
    let title = ns.substring(with: m.range(at: 2))
    return (level, title)
}

func parseDocument(_ src: String) -> (headings: [Heading], blocks: [Block]) {
    var heads: [Heading] = []
    var blocks: [Block] = []
    var body = ""
    var offset = 0
    var inFence = false

    func flushBody() {
        if !body.isEmpty { blocks.append(Block(body: body)); body = "" }
    }

    src.enumerateLines { line, _ in
        let ns = line as NSString
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            inFence.toggle()
            body += line + "\n"
            offset += ns.length + 1
            return
        }
        if !inFence, let h = matchHeading(line) {
            flushBody()
            let heading = Heading(level: h.level, title: h.title, sourceRange: NSRange(location: offset, length: ns.length))
            heads.append(heading)
            blocks.append(Block(heading: heading))
        } else {
            body += line + "\n"
        }
        offset += ns.length + 1
    }
    flushBody()
    return (heads, blocks)
}

// MARK: - Preview (WKWebView + marked.js)

private let previewCSS = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: #ffffff; color: #1d1d1f;
  font: 16px/1.65 -apple-system, "Helvetica Neue", "PingFang SC", sans-serif;
  -webkit-font-smoothing: antialiased; }
#content { width: 90%; max-width: 1100px; margin: 0 auto; padding: 28px 0 80px; }
h1 { font-size: 30px; font-weight: 700; margin: 20px 0 10px; line-height: 1.25; }
h2 { font-size: 26px; font-weight: 700; margin: 22px 0 10px; line-height: 1.25; }
h3 { font-size: 22px; font-weight: 600; margin: 20px 0 8px; }
h4 { font-size: 19px; font-weight: 600; margin: 18px 0 6px; }
h5 { font-size: 17px; font-weight: 600; margin: 16px 0 6px; }
h6 { font-size: 15px; font-weight: 600; margin: 14px 0 6px; color: #6e6e73; }
p { margin: 0 0 12px; }
a { color: #0066cc; text-decoration: none; }
a:hover { text-decoration: underline; }
ul, ol { margin: 0 0 12px; padding-left: 26px; }
li { margin: 2px 0; }
hr { border: none; border-top: 1px solid #d2d2d7; margin: 18px 0; }
img { max-width: 100%; height: auto; }
code { font-family: "SF Mono", ui-monospace, Menlo, monospace; font-size: 14px;
  background: rgba(0,0,0,0.06); padding: 2px 5px; border-radius: 5px; }
pre { background: #f5f5f7; padding: 14px 16px; border-radius: 10px; overflow: auto; margin: 0 0 14px; }
pre code { background: none; padding: 0; font-size: 13px; line-height: 1.5; }
blockquote { border-left: 4px solid #d2d2d7; margin: 0 0 12px; padding: 6px 16px;
  color: #4a4a4f; background: rgba(0,0,0,0.03); border-radius: 0 6px 6px 0; }
table { border-collapse: collapse; width: 100%; margin: 0 0 14px; font-size: 14px; display: block; overflow-x: auto; }
th, td { border: 1px solid #d2d2d7; padding: 7px 12px; text-align: left; }
th { background: rgba(0,0,0,0.04); font-weight: 600; }
@media (prefers-color-scheme: dark) {
  body { background: #1d1d1f; color: #e8e8ea; }
  a { color: #4ea2ff; }
  h6 { color: #8e8e93; }
  hr { border-color: #3a3a3c; }
  code { background: rgba(255,255,255,0.10); }
  pre { background: #161617; }
  pre code { color: #e8e8ea; }
  blockquote { border-color: #3a3a3c; color: #b0b0b5; background: rgba(255,255,255,0.04); }
  th, td { border-color: #3a3a3c; }
  th { background: rgba(255,255,255,0.06); }
}
"""

private func shellHTML() -> String {
    var markedSrc = "/* marked missing */"
    if let url = Bundle.main.url(forResource: "marked", withExtension: "min.js"),
       let src = try? String(contentsOf: url, encoding: .utf8) {
        markedSrc = src
    }
    return """
<!DOCTYPE html><html><head><meta charset="utf-8">
<style>\(previewCSS)</style>
<script>\(markedSrc)</script>
</head><body><div id="content"></div>
<script>
marked.setOptions({ gfm: true, breaks: true });
function renderMd(md){ var el=document.getElementById('content'); try { el.innerHTML = marked.parse(md); } catch(e){ el.textContent = String(e); } }
function scrollToHeading(i){ var hs=document.querySelectorAll('h1,h2,h3,h4,h5,h6'); if(hs[i]){ hs[i].scrollIntoView({behavior:'smooth', block:'start'}); } }
</script>
</body></html>
"""
}

private func jsString(_ s: String) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: [s], options: [])) ?? Data()
    var raw = String(data: data, encoding: .utf8) ?? "[\"\"]"
    raw.removeFirst()
    raw.removeLast()
    return raw
}

struct PreviewView: NSViewRepresentable {
    @EnvironmentObject var controller: EditorController
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        web.loadHTMLString(shellHTML(), baseURL: nil)
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        let c = context.coordinator
        if c.ready {
            if c.lastText != text {
                c.lastText = text
                web.evaluateJavaScript("renderMd(\(jsString(text)))")
            }
            if let req = controller.scrollRequest, c.lastScrollID != req.id {
                c.lastScrollID = req.id
                if let idx = controller.activeHeadings.firstIndex(where: { $0.id == req.headingID }) {
                    web.evaluateJavaScript("scrollToHeading(\(idx))")
                }
            }
        } else {
            c.pendingText = text
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var ready = false
        var pendingText: String? = nil
        var lastText: String = ""
        var lastScrollID: UUID? = nil

        func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if let p = pendingText {
                webView?.evaluateJavaScript("renderMd(\(jsString(p)))")
                lastText = p
                pendingText = nil
            }
        }
    }
}

// MARK: - Source editor

struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var controller: EditorController

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.drawsBackground = true
        tv.backgroundColor = NSColor.textBackgroundColor
        tv.textColor = NSColor.textColor
        tv.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.autoresizingMask = [.width]
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.size = NSSize(width: 0, height: 0)
        tv.insertionPointColor = NSColor.controlAccentColor
        let scroll = NSScrollView()
        scroll.documentView = tv
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        tv.delegate = context.coordinator
        context.coordinator.textView = tv
        tv.string = text
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text {
            let selected = tv.selectedRange()
            tv.string = text
            tv.setSelectedRange(selected)
        }
        if let req = controller.scrollRequest,
           context.coordinator.lastScrollID != req.id,
           let h = controller.headingByID(req.headingID) {
            context.coordinator.lastScrollID = req.id
            scrollToHeadingTop(tv, range: h.sourceRange)
        }
    }

    private func scrollToHeadingTop(_ tv: NSTextView, range: NSRange) {
        guard let lm = tv.layoutManager, let tc = tv.textContainer else { return }
        let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
        guard let scroll = tv.enclosingScrollView else {
            tv.scrollRangeToVisible(range)
            return
        }
        let pad: CGFloat = 8
        let originY = max(0, rect.minY - pad)
        let visible = NSRect(x: 0, y: originY, width: scroll.bounds.width, height: scroll.bounds.height)
        _ = tv.scrollToVisible(visible)
        tv.setSelectedRange(NSRange(location: range.location, length: 0))
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var binding: Binding<String>
        weak var textView: NSTextView?
        var lastScrollID: UUID?

        init(text: Binding<String>) { self.binding = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let new = tv.string
            if new != binding.wrappedValue {
                binding.wrappedValue = new
            }
        }
    }
}

// MARK: - TOC

struct TocView: View {
    @EnvironmentObject var controller: EditorController

    var body: some View {
        List {
            ForEach(controller.activeHeadings) { h in
                tocRow(h)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func tocRow(_ h: Heading) -> some View {
        Button {
            controller.jump(to: h)
        } label: {
            Text(h.title)
                .font(rowFont(h.level))
                .lineLimit(1)
                .foregroundColor(.primary)
                .padding(.leading, CGFloat((h.level - 1) * 12))
        }
        .buttonStyle(.plain)
    }

    private func rowFont(_ level: Int) -> Font {
        let size = CGFloat(max(11, 16 - (level - 1)))
        return .system(size: size, weight: level <= 2 ? .semibold : .regular)
    }
}

// MARK: - Tab bar

struct TabBar: View {
    @EnvironmentObject var controller: EditorController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(controller.docs.enumerated()), id: \.element.id) { idx, doc in
                    tabItem(idx: idx, doc: doc)
                }
                Button { controller.newDoc() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 30)
                }
                .buttonStyle(.plain)
                .help("新建标签")
            }
        }
        .frame(height: 30)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func tabItem(idx: Int, doc: MDDoc) -> some View {
        let isActive = idx == controller.active
        HStack(spacing: 6) {
            Text(doc.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(isActive ? .primary : .secondary)
            if doc.dirty {
                Circle().fill(Color.secondary).frame(width: 5, height: 5)
            }
            Button {
                controller.closeDoc(at: idx)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("关闭标签")
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(isActive ? Color(NSColor.textBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive { Rectangle().fill(Color.accentColor).frame(height: 2) }
        }
        .contentShape(Rectangle())
        .onTapGesture { controller.selectTab(idx) }
        .contextMenu {
            Button("关闭") { controller.closeDoc(at: idx) }
            Button("保存") { controller.selectTab(idx); controller.save() }
        }
    }
}

// MARK: - Content

struct ContentView: View {
    @EnvironmentObject var controller: EditorController
    @State private var tab: ActiveTab = .preview
    @State private var dragOver = false

    private var textBinding: Binding<String> {
        Binding(
            get: { controller.activeText },
            set: { controller.setText($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TabBar()
            Divider()
            HSplitView {
                TocView()
                    .frame(minWidth: 200, idealWidth: 260, maxWidth: 420)

                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("预览").tag(ActiveTab.preview)
                        Text("源码").tag(ActiveTab.source)
                    }
                    .pickerStyle(.segmented)
                    .padding(8)

                    Divider()

                    if controller.docs.isEmpty {
                        emptyState
                    } else {
                        switch tab {
                        case .preview: PreviewView(text: controller.activeText)
                        case .source: SourceEditor(text: textBinding)
                        }
                    }
                }
                .frame(minWidth: 480)
            }
        }
        .background(dragOver ? Color.accentColor.opacity(0.12) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            handleDrop(providers)
        }
        .onOpenURL { url in
            let u = url.isFileURL ? url : URL(fileURLWithPath: url.path)
            if ["md", "markdown", "mdown", "mkd"].contains(u.pathExtension.lowercased()) {
                controller.open(url: u)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tertiary)
            Text("拖拽 .md 文件到此  ·  或菜单 文件 > 打开")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if providers.isEmpty { return false }
        var handled = false
        for p in providers where p.canLoadObject(ofClass: URL.self) {
            handled = true
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    guard let url = url as? URL else { return }
                    let u = url.isFileURL ? url : URL(fileURLWithPath: url.path)
                    if ["md", "markdown"].contains(u.pathExtension.lowercased()) {
                        controller.open(url: u)
                    }
                }
            }
        }
        return handled
    }
}

// MARK: - App

@main
struct MDApp: App {
    @StateObject private var controller = EditorController()

    var body: some Scene {
        Window("imd", id: "main") {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 900, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建标签") { controller.newDoc() }.keyboardShortcut("n", modifiers: .command)
                Button("打开…") { controller.openDialog() }.keyboardShortcut("o", modifiers: .command)
                Divider()
                Menu("最近打开") {
                    if controller.recentFiles.isEmpty {
                        Text("无").foregroundStyle(.secondary)
                    } else {
                        ForEach(controller.recentFiles, id: \.self) { url in
                            Button(url.lastPathComponent) { controller.open(url: url) }
                        }
                        Divider()
                        Button("清除最近列表") { controller.clearRecent() }
                    }
                }
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") { controller.save() }.keyboardShortcut("s", modifiers: .command)
                Button("另存为…") { controller.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("关闭标签") {
                    if controller.docs.isEmpty == false { controller.closeDoc(at: controller.active) }
                }.keyboardShortcut("w", modifiers: .command)
            }
        }
    }
}
