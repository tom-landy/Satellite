import Foundation
import SwiftData

/// Sample sources and articles for screenshots and trying the app without a network.
/// Launch with -demo. Also: -demoSheet articles|sources|settings|addSource, -demoIndex 2, -demoWelcome YES, -demoEnd YES, -demoScope today|yesterday|week.
@MainActor
enum DemoData {
    nonisolated static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    nonisolated static var showsWelcome: Bool { isActive && UserDefaults.standard.bool(forKey: "demoWelcome") }

    private struct Post {
        let source: Int
        let hoursAgo: Double
        let title: String
        let author: String
        let html: String
    }

    private static let sources: [(title: String, site: String)] = [
        ("The Long Game", "https://longgame.example.com/"),
        ("Painted Armies", "https://paintedarmies.example.com/"),
        ("Field Notes", "https://fieldnotes.example.org/"),
        ("Lowercase", "https://lowercase.example.net/"),
    ]

    private static let posts: [Post] = [
        Post(source: 0, hoursAgo: 1.5, title: "Why nobody finishes the marathon", author: "Sam Okafor", html: """
        <p>Every January the same thing happens. A wave of people sign up for a spring marathon, buy the shoes, download the plan, and by March most of them have quietly stopped. It isn't laziness. It's that the plan was built for someone else's life.</p>
        <p>The plans assume you can run five days a week, that nothing will go wrong, and that the long run on Sunday will always happen on Sunday. Real weeks don't look like that.</p>
        <h2>Plan for the bad week</h2>
        <p>The runners who make it to the start line have one thing in common: they decided in advance what a bad week looks like and what they'll still do in it. Two short runs instead of four. A long run on Tuesday instead of Sunday.</p>
        <blockquote>A plan you can follow badly beats a plan you can only follow perfectly.</blockquote>
        <p>It's the same with saving, with learning a language, with anything that takes months. The schedule is a guess. The habit is what you're actually building.</p>
        <ul><li>Write down your minimum week.</li><li>Decide what you'll drop first when life gets busy.</li><li>Never skip twice in a row.</li></ul>
        <p>That last rule does more work than the other two combined.</p>
        """),
        Post(source: 1, hoursAgo: 3, title: "Batch painting forty knights without losing your mind", author: "Rhian Hale", html: """
        <p>Forty identical models is a lot of models. The temptation is to paint one to a finish you love and then grind out the other thirty-nine. Don't. You'll be sick of them by number six.</p>
        <p>Instead, work in stages across the whole batch, and give yourself a finished model early so you can see where it's going.</p>
        <h2>The order that works</h2>
        <ol><li>Prime everything in one go, outdoors, on a dry day.</li><li>Base coat the armour across all forty. Put a film on.</li><li>Wash. This is where they start to look like an army.</li><li>Pick five to take all the way to the end. Line them up where you can see them.</li></ol>
        <p>Those five do two jobs. They prove the scheme works, and they keep you going through the boring middle.</p>
        <p>Bases last. Always bases last.</p>
        """),
        Post(source: 2, hoursAgo: 7, title: "The swifts are leaving early", author: "Field Notes", html: """
        <p>The swifts went quiet over the town this week, a good fortnight before I'd usually expect it. One evening the sky was full of them screaming round the church tower; the next it was empty.</p>
        <p>They'll be over France by now, heading for the Congo, and they won't land until they come back next May. Swifts eat, sleep and even mate on the wing.</p>
        <p>Short, but there's nothing else to say. Look up while they're still here next year.</p>
        """),
        Post(source: 3, hoursAgo: 10, title: "Small software is a choice", author: "Ines Varga", html: """
        <p>Most apps get bigger every year. Each release adds a tab, a feed, a badge, a reason to come back. It's rarely anyone's plan. It's what happens when growth is the only number on the dashboard.</p>
        <p>Small software takes a decision to stay small, and then a hundred more decisions to keep saying no.</p>
        <h2>What small looks like</h2>
        <p>One screen that does the job. Settings you can read in a minute. Nothing that pulls at you when you've finished.</p>
        <pre><code>if feature.serves(theMainThing) == false {
            return .no
        }</code></pre>
        <p>It sounds obvious written down. It is very hard to do with a team, a roadmap and a quarter to hit.</p>
        """),
        Post(source: 0, hoursAgo: 26, title: "Compound interest, explained badly", author: "Sam Okafor", html: """
        <p>Every explanation of compound interest starts with a chart that curves upward and a sentence about Einstein that he probably never said. Here's a worse one.</p>
        <p>Put a pound in a jar. Every year, the jar adds a little to whatever's already in it, including what it added before. For a long time nothing seems to happen. Then, a long way down the line, the jar is mostly made of what it added itself.</p>
        <p>The hard part isn't understanding it. It's leaving the jar alone for the boring decades.</p>
        """),
        Post(source: 1, hoursAgo: 30, title: "Edge highlights in five minutes", author: "Rhian Hale", html: """
        <p>Edge highlighting has a reputation for being slow and fiddly. It's slow and fiddly if you use a tiny brush and try to be neat. Use the side of a medium brush and be quick.</p>
        <p>Drag, don't paint. Let the edge catch the paint. Accept the odd miss; from arm's length nobody will see it.</p>
        """),
        Post(source: 3, hoursAgo: 49, title: "Notes from a week without notifications", author: "Ines Varga", html: """
        <p>I turned off every notification on my phone for a week except calls and messages from three people. The first day I checked it constantly. By Wednesday I'd stopped noticing.</p>
        <p>Nothing important was missed. Plenty of unimportant things were, and I didn't miss them either.</p>
        """),
    ]

    static func seed(_ context: ModelContext) {
        var made: [Source] = []
        for (i, s) in sources.enumerated() {
            let source = Source(feedURL: URL(string: s.site + "feed")!, title: s.title)
            source.siteURL = URL(string: s.site)
            source.lastRefreshed = .now.addingTimeInterval(-Double(i) * 60)
            context.insert(source)
            made.append(source)
        }
        for (i, post) in posts.enumerated() {
            let source = made[post.source]
            let link = URL(string: sources[post.source].site + "posts/\(i)")!
            let text = post.html.htmlPlainText
            let article = Article(key: source.feedURL.absoluteString + "#\(i)", itemID: "\(i)", title: post.title,
                                  author: post.author, date: .now.addingTimeInterval(-post.hoursAgo * 3600), link: link,
                                  html: post.html, excerpt: HTMLText.excerpt(fromPlainText: text),
                                  wordCount: HTMLText.wordCount(text), imageURL: nil, audioURL: nil)
            context.insert(article)
            article.source = source
            if i == 1 { article.savedAt = .now }
        }
        try? context.save()
        UserDefaults.standard.set(Date.now.addingTimeInterval(-4 * 60).timeIntervalSince1970, forKey: ReadingQueue.lastRefreshKey)
    }

    /// Puts the app in the state a screenshot asks for. Returns the sheet to show, if any.
    static func apply(queue: ReadingQueue, context: ModelContext) -> ReaderSheet? {
        let defaults = UserDefaults.standard
        // The samples span two days, so show This Week unless a screenshot asks for another view.
        let scope = defaults.string(forKey: "demoScope").flatMap(ReaderScope.init(rawValue:)) ?? .week
        if queue.scope == scope { queue.rebuild(context, keepPlace: false) } else { queue.setScope(scope, context) }
        if defaults.bool(forKey: "demoEnd") {
            queue.jump(to: queue.entries.count)
        } else if defaults.integer(forKey: "demoIndex") > 0 {
            queue.jump(to: defaults.integer(forKey: "demoIndex"))
        }
        return defaults.string(forKey: "demoSheet").flatMap(ReaderSheet.init(rawValue:))
    }
}
