import Foundation

public struct ResolvedPodcastAudio: Equatable, Sendable {
    public let pageURL: URL
    public let audioURL: URL
    public let title: String?
    public let platform: String
    public let feedURL: URL?

    public init(pageURL: URL, audioURL: URL, title: String?, platform: String, feedURL: URL? = nil) {
        self.pageURL = pageURL
        self.audioURL = audioURL
        self.title = title
        self.platform = platform
        self.feedURL = feedURL
    }
}

public enum PodcastAudioImportError: LocalizedError {
    case invalidURL
    case noPublicAudio
    case invalidRSS

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "请输入有效的 http 或 https 链接。"
        case .noPublicAudio:
            "没有找到公开音频地址。请确认链接可公开访问，或改用本地音频文件。"
        case .invalidRSS:
            "播客 RSS 无法解析。"
        }
    }
}

public final class PodcastAudioImporter {
    public typealias DataLoader = @Sendable (URL) async throws -> Data

    fileprivate static let audioExtensions: Set<String> = ["mp3", "m4a", "mp4", "m4b", "wav", "aac", "flac", "ogg", "opus"]
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

    private let configuration: AppConfiguration
    private let dataLoader: DataLoader

    public convenience init(configuration: AppConfiguration) {
        self.init(configuration: configuration, dataLoader: PodcastAudioImporter.defaultDataLoader)
    }

    public init(configuration: AppConfiguration, dataLoader: @escaping DataLoader) {
        self.configuration = configuration
        self.dataLoader = dataLoader
    }

    public func resolveAudioURL(from pageURL: URL) async throws -> ResolvedPodcastAudio {
        guard pageURL.scheme == "http" || pageURL.scheme == "https" else {
            throw PodcastAudioImportError.invalidURL
        }

        let platform = platformName(for: pageURL)
        if isAudioURL(pageURL) {
            return ResolvedPodcastAudio(pageURL: pageURL, audioURL: pageURL, title: nil, platform: platform)
        }

        if platform == "ximalaya", let ximalayaAudio = try await resolveXimalayaAudio(from: pageURL) {
            return ResolvedPodcastAudio(
                pageURL: pageURL,
                audioURL: ximalayaAudio.audioURL,
                title: ximalayaAudio.title,
                platform: platform
            )
        }

        if platform == "ximalaya", let feedURL = ximalayaAlbumFeedURL(from: pageURL),
           let resolved = try await resolveRSSFeed(feedURL: feedURL, pageURL: pageURL, title: nil, platform: platform) {
            return resolved
        }

        let pageHTML = decodeHTML(try await dataLoader(pageURL))
        let title = extractTitle(from: pageHTML)

        if looksLikeFeed(pageHTML),
           let item = try pickRSSItem(from: pageHTML, matching: title) {
            return ResolvedPodcastAudio(
                pageURL: pageURL,
                audioURL: item.audioURL,
                title: title ?? item.title,
                platform: platform,
                feedURL: pageURL
            )
        }

        if let audioURL = firstMetaAudioURL(in: pageHTML, baseURL: pageURL) ?? firstAudioURL(in: pageHTML, baseURL: pageURL) {
            return ResolvedPodcastAudio(pageURL: pageURL, audioURL: audioURL, title: title, platform: platform)
        }

        var feedURL = firstFeedURL(in: pageHTML, baseURL: pageURL)
        if feedURL == nil, platform == "apple_podcasts" {
            feedURL = try await lookupAppleFeedURL(from: pageURL)
        }

        if let feedURL {
            if let resolved = try await resolveRSSFeed(feedURL: feedURL, pageURL: pageURL, title: title, platform: platform) {
                return resolved
            }
        }

        throw PodcastAudioImportError.noPublicAudio
    }

    public func importAudio(from pageURL: URL) async throws -> URL {
        let resolved = try await resolveAudioURL(from: pageURL)
        let destinationDirectory = configuration.supportDirectory.appendingPathComponent("remote-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        var request = URLRequest(url: resolved.audioURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let destination = uniqueDestination(
            in: destinationDirectory,
            title: resolved.title,
            audioURL: resolved.audioURL,
            suggestedFilename: response.suggestedFilename
        )
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func defaultDataLoader(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    private func lookupAppleFeedURL(from pageURL: URL) async throws -> URL? {
        guard let showID = appleShowID(from: pageURL),
              let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(showID)&entity=podcast") else {
            return nil
        }
        let data = try await dataLoader(lookupURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = object["results"] as? [[String: Any]] else {
            return nil
        }
        for result in results {
            if let feed = result["feedUrl"] as? String, let url = URL(string: feed) {
                return url
            }
        }
        return nil
    }

    private func resolveXimalayaAudio(from pageURL: URL) async throws -> (audioURL: URL, title: String?)? {
        guard let soundID = ximalayaSoundID(from: pageURL),
              let apiURL = URL(string: "https://www.ximalaya.com/revision/play/v1/audio?id=\(soundID)&ptype=1") else {
            return nil
        }
        let data: Data
        do {
            data = try await dataLoader(apiURL)
        } catch {
            return nil
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["data"] as? [String: Any] else {
            return nil
        }
        let audioValue = payload["src"] as? String
            ?? payload["playUrl64"] as? String
            ?? payload["playUrl32"] as? String
        guard let audioValue, let audioURL = URL(string: audioValue) else {
            return nil
        }
        let title = payload["trackName"] as? String ?? payload["title"] as? String
        return (audioURL, title)
    }

    private func resolveRSSFeed(feedURL: URL, pageURL: URL, title: String?, platform: String) async throws -> ResolvedPodcastAudio? {
        let rssText: String
        do {
            rssText = decodeHTML(try await dataLoader(feedURL))
        } catch {
            return nil
        }
        guard let item = try? pickRSSItem(from: rssText, matching: title) else {
            return nil
        }
        return ResolvedPodcastAudio(
            pageURL: pageURL,
            audioURL: item.audioURL,
            title: title ?? item.title,
            platform: platform,
            feedURL: feedURL
        )
    }
}

private func platformName(for url: URL) -> String {
    let host = url.host?.lowercased() ?? ""
    if host.contains("podcasts.apple.com") {
        return "apple_podcasts"
    }
    if host.contains("xiaoyuzhoufm.com") {
        return "xiaoyuzhou"
    }
    if host.contains("ximalaya.com") {
        return "ximalaya"
    }
    return "generic"
}

private func isAudioURL(_ url: URL) -> Bool {
    PodcastAudioImporter.audioExtensions.contains(url.pathExtension.lowercased())
}

private func decodeHTML(_ data: Data) -> String {
    String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .isoLatin1)
        ?? String(decoding: data, as: UTF8.self)
}

private func extractTitle(from html: String) -> String? {
    let patterns = [
        #"<meta\b[^>]*(?:property|name)=["']og:title["'][^>]*content=["']([^"']+)["']"#,
        #"<meta\b[^>]*content=["']([^"']+)["'][^>]*(?:property|name)=["']og:title["']"#,
        #"<title[^>]*>(.*?)</title>"#,
    ]
    for pattern in patterns {
        if let value = firstCapture(pattern: pattern, in: html, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let title = decodeHTMLEntities(value).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }
    }
    return nil
}

private func firstMetaAudioURL(in html: String, baseURL: URL) -> URL? {
    let tags = matches(pattern: #"<meta\b[^>]*>"#, in: html, options: [.caseInsensitive])
    for tag in tags {
        let attrs = parseAttributes(tag)
        let key = (attrs["property"] ?? attrs["name"] ?? "").lowercased()
        if ["og:audio", "og:audio:url", "twitter:player:stream"].contains(key),
           let content = attrs["content"],
           let url = absoluteURL(from: content, baseURL: baseURL) {
            return url
        }
    }
    return nil
}

private func firstAudioURL(in html: String, baseURL: URL) -> URL? {
    let normalized = decodeHTMLEntities(html).replacingOccurrences(of: "\\/", with: "/")
    let extensionPattern = PodcastAudioImporter.audioExtensions.sorted().joined(separator: "|")
    let pattern = #"https?://[^\s"'<>]+?\.(?:\#(extensionPattern))(?:\?[^\s"'<>]*)?"#
    for candidate in matches(pattern: pattern, in: normalized, options: [.caseInsensitive]) {
        let clean = candidate.trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
        if let url = absoluteURL(from: clean, baseURL: baseURL), isAudioURL(url) {
            return url
        }
    }
    return nil
}

private func firstFeedURL(in html: String, baseURL: URL) -> URL? {
    let linkTags = matches(pattern: #"<link\b[^>]*>"#, in: html, options: [.caseInsensitive])
    for tag in linkTags {
        let attrs = parseAttributes(tag)
        let type = attrs["type"]?.lowercased() ?? ""
        if (type.contains("rss") || type.contains("xml")),
           let href = attrs["href"],
           let url = absoluteURL(from: href, baseURL: baseURL) {
            return url
        }
    }

    let normalized = decodeHTMLEntities(html).replacingOccurrences(of: "\\/", with: "/")
    for candidate in matches(pattern: #"https?://[^\s"'<>]+"#, in: normalized, options: [.caseInsensitive]) {
        let clean = candidate.trimmingCharacters(in: CharacterSet(charactersIn: ".,);]"))
        let lowercased = clean.lowercased()
        if lowercased.contains("rss") || lowercased.contains("feed") || lowercased.hasSuffix(".xml"),
           let url = absoluteURL(from: clean, baseURL: baseURL) {
            return url
        }
    }
    return nil
}

private func appleShowID(from url: URL) -> String? {
    firstCapture(pattern: #"/id(\d+)"#, in: url.path, options: [])
}

private func ximalayaSoundID(from url: URL) -> String? {
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        for name in ["id", "trackId"] {
            if let value = components.queryItems?.first(where: { $0.name == name })?.value,
               value.allSatisfy(\.isNumber) {
                return value
            }
        }
    }
    for component in url.pathComponents.reversed() where component.allSatisfy(\.isNumber) {
        return component
    }
    return nil
}

private func ximalayaAlbumFeedURL(from url: URL) -> URL? {
    let path = url.path
    guard let albumID = firstCapture(pattern: #"/album/(\d+)(?:\.xml)?/?$"#, in: path, options: []) else {
        return nil
    }
    return URL(string: "https://www.ximalaya.com/album/\(albumID).xml")
}

private func pickRSSItem(from rss: String, matching title: String?) throws -> RSSAudioItem? {
    let parser = XMLParser(data: Data(rss.utf8))
    let delegate = RSSParserDelegate()
    parser.delegate = delegate
    guard parser.parse() else {
        throw PodcastAudioImportError.invalidRSS
    }
    guard !delegate.items.isEmpty else {
        return nil
    }
    guard let title else {
        return delegate.items.first
    }
    let needle = normalizeTitle(title)
    return delegate.items.first { item in
        let haystack = normalizeTitle(item.title ?? "")
        return !haystack.isEmpty && (needle.contains(haystack) || haystack.contains(needle))
    } ?? delegate.items.first
}

private func looksLikeFeed(_ text: String) -> Bool {
    let prefix = text.prefix(500).lowercased()
    return prefix.contains("<rss") || prefix.contains("<feed")
}

private struct RSSAudioItem {
    var title: String?
    var audioURL: URL
}

private struct MutableRSSAudioItem {
    var title: String?
    var audioURL: URL?
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    private(set) var items: [RSSAudioItem] = []
    private var currentItem: MutableRSSAudioItem?
    private var currentElement: String?
    private var textBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = (qName ?? elementName).lowercased()
        if name == "item" {
            currentItem = MutableRSSAudioItem()
            return
        }
        guard currentItem != nil else { return }
        if name == "title" {
            currentElement = "title"
            textBuffer = ""
        }
        if name == "enclosure" || name.hasSuffix(":content") || name == "content" {
            if let rawURL = attributeDict["url"], let url = URL(string: rawURL) {
                currentItem?.audioURL = url
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "title" {
            textBuffer.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = (qName ?? elementName).lowercased()
        if name == "title", currentElement == "title" {
            let title = decodeHTMLEntities(textBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            currentItem?.title = title.isEmpty ? nil : title
            currentElement = nil
            textBuffer = ""
        }
        if name == "item" {
            if let currentItem, let audioURL = currentItem.audioURL {
                items.append(RSSAudioItem(title: currentItem.title, audioURL: audioURL))
            }
            currentItem = nil
        }
    }
}

private func parseAttributes(_ tag: String) -> [String: String] {
    var attrs: [String: String] = [:]
    let pattern = #"([:\w-]+)\s*=\s*(["'])(.*?)\2"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
        return attrs
    }
    let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
    regex.enumerateMatches(in: tag, range: range) { match, _, _ in
        guard let match,
              let nameRange = Range(match.range(at: 1), in: tag),
              let valueRange = Range(match.range(at: 3), in: tag) else {
            return
        }
        attrs[String(tag[nameRange]).lowercased()] = decodeHTMLEntities(String(tag[valueRange]))
    }
    return attrs
}

private func matches(pattern: String, in text: String, options: NSRegularExpression.Options) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        return []
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        Range(match.range, in: text).map { String(text[$0]) }
    }
}

private func firstCapture(pattern: String, in text: String, options: NSRegularExpression.Options) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
        return nil
    }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1,
          let valueRange = Range(match.range(at: 1), in: text) else {
        return nil
    }
    return String(text[valueRange])
}

private func absoluteURL(from value: String, baseURL: URL) -> URL? {
    let decoded = decodeHTMLEntities(value).replacingOccurrences(of: "\\/", with: "/").trimmingCharacters(in: .whitespacesAndNewlines)
    return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
}

private func normalizeTitle(_ value: String) -> String {
    let excluded = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(.symbols)
    return String(value.lowercased().unicodeScalars.filter { !excluded.contains($0) })
}

private func decodeHTMLEntities(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
}

private func uniqueDestination(in directory: URL, title: String?, audioURL: URL, suggestedFilename: String?) -> URL {
    let fileExtension = audioExtension(audioURL: audioURL, suggestedFilename: suggestedFilename)
    let rawName = title ?? audioURL.deletingPathExtension().lastPathComponent
    let baseName = safeFilename(rawName.isEmpty ? "podcast-audio" : rawName)
    let initial = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
    if !FileManager.default.fileExists(atPath: initial.path) {
        return initial
    }
    for index in 1..<1000 {
        let candidate = directory.appendingPathComponent("\(baseName)-\(index)").appendingPathExtension(fileExtension)
        if !FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
    }
    return directory.appendingPathComponent("\(baseName)-\(UUID().uuidString.prefix(8))").appendingPathExtension(fileExtension)
}

private func audioExtension(audioURL: URL, suggestedFilename: String?) -> String {
    let extensionFromURL = audioURL.pathExtension.lowercased()
    if PodcastAudioImporter.audioExtensions.contains(extensionFromURL) {
        return extensionFromURL
    }
    if let suggested = suggestedFilename {
        let extensionFromSuggestion = URL(fileURLWithPath: suggested).pathExtension.lowercased()
        if PodcastAudioImporter.audioExtensions.contains(extensionFromSuggestion) {
            return extensionFromSuggestion
        }
    }
    return "mp3"
}

private func safeFilename(_ value: String) -> String {
    let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
    let parts = value.components(separatedBy: invalid).filter { !$0.isEmpty }
    let cleaned = parts.joined(separator: "-").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".-")))
    if cleaned.isEmpty {
        return "podcast-audio"
    }
    return String(cleaned.prefix(90))
}
