import Foundation

enum BehaviorClassificationConfig {
    static let communicationBundleIds: Set<String> = [
        "com.apple.mail",
        "com.tinyspeck.slackmacgap",
        "com.microsoft.teams",
        "com.apple.iChat",
        "com.microsoft.Outlook",
        "com.readdle.smartemail-Mac",
        "com.postbox-inc.postboxapp",
    ]

    /// Fallback only. Passive should be judged by web context first.
    static let passiveFallbackBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.apple.news",
        "com.reederapp.macOS",
        "com.apple.Preview",
    ]

    static let passiveDomainKeywords: [String] = [
        "youtube.com", "youtu.be",
        "bilibili.com",
        "x.com", "twitter.com",
        "weibo.com",
        "reddit.com",
        "news.ycombinator.com",
        "medium.com",
        "zhihu.com",
        "instagram.com",
        "facebook.com",
        "tiktok.com",
    ]

    static let communicationDomainKeywords: [String] = [
        "slack.com",
        "discord.com",
        "teams.microsoft.com",
        "mail.google.com",
        "outlook.office.com",
        "web.whatsapp.com",
        "wechat.com",
    ]

    static func extractDomain(from activity: Activity) -> String? {
        if let domain = activity.domain, !domain.isEmpty {
            return normalizeHost(domain)
        }
        if let urlString = activity.webUrl,
           let url = URL(string: urlString),
           let host = url.host {
            return normalizeHost(host)
        }
        return nil
    }

    static func contextLabel(for activity: Activity) -> String {
        if let title = activity.appTitle, !title.isEmpty {
            return title
        }
        if let domain = extractDomain(from: activity) {
            return domain
        }
        if let path = activity.filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return activity.appName
    }

    static func isPassiveDomain(_ domain: String) -> Bool {
        matches(domain: domain, keywords: passiveDomainKeywords)
    }

    static func isCommunicationDomain(_ domain: String) -> Bool {
        matches(domain: domain, keywords: communicationDomainKeywords)
    }

    static func normalizeHost(_ host: String) -> String {
        let lower = host.lowercased()
        if lower.hasPrefix("www.") {
            return String(lower.dropFirst(4))
        }
        return lower
    }

    private static func matches(domain: String, keywords: [String]) -> Bool {
        let normalized = normalizeHost(domain)
        return keywords.contains { keyword in
            normalized == keyword || normalized.hasSuffix(".\(keyword)")
        }
    }
}
