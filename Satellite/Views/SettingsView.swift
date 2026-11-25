import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(AccentTheme.storageKey) private var theme: AccentTheme = .standard
    @AppStorage(AccentTheme.matchIconKey) private var matchIcon = false
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @AppStorage(Typeface.storageKey) private var typeface: Typeface = .system
    @AppStorage(ReaderStyle.scaleKey) private var textScale = 1.0
    @AppStorage(ReadingQueue.windowKey) private var windowDays = 7
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Article> { $0.readAt == nil }) private var unread: [Article]
    @State private var confirmMarkAll = false

    private let columns = [GridItem(.adaptive(minimum: 58), spacing: 14)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LogoView(theme: theme)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
                        .shadow(color: theme.color.opacity(0.35), radius: 20, y: 6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .animation(.easeInOut(duration: 0.25), value: theme)
                }

                Section("Appearance") {
                    HStack(spacing: 10) {
                        ForEach(AppAppearance.allCases) { option in
                            AppearanceCard(option: option, selected: option == appearance) {
                                withAnimation(.easeInOut(duration: 0.2)) { appearance = option }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(AccentTheme.allCases) { option in
                            Swatch(theme: option, selected: option == theme) {
                                withAnimation(.snappy) { theme = option }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    Toggle("Match App Icon", isOn: $matchIcon)
                } header: {
                    Text("Colour")
                } footer: {
                    Text("Also changes the app icon on the Home Screen.")
                }

                Section {
                    Picker("Typeface", selection: $typeface) {
                        ForEach(Typeface.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    TextSizeControl(scale: $textScale, typeface: typeface)
                    Text("The quick brown fox reads the whole article, then swipes to the next.")
                        .font(.system(size: 17 * textScale, design: typeface.design))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("Reading")
                } footer: {
                    Text("Text size also follows the size set in iOS Settings → Display & Brightness.")
                }

                Section {
                    Picker("Unread Articles From", selection: $windowDays) {
                        ForEach([3, 7, 14, 30], id: \.self) { Text("Last \($0) days").tag($0) }
                    }
                } footer: {
                    Text("Older articles drop out of the reader without being marked read, so time away never leaves a pile.")
                }

                Section {
                    Button("Mark All as Read") { confirmMarkAll = true }
                        .disabled(unread.isEmpty)
                        .confirmationDialog("Mark ^[\(unread.count) article](inflect: true) as read?",
                                            isPresented: $confirmMarkAll, titleVisibility: .visible) {
                            Button("Mark All as Read", role: .destructive) { queue.markAllRead(context) }
                        } message: {
                            Text("Every unread article disappears from the reader. Saved articles stay in Saved.")
                        }
                } footer: {
                    Text("Read articles disappear as you swipe past them. Mark one unread to keep it.")
                }

                Section("About") {
                    LabeledContent("Developer", value: "Warhound")
                    LabeledContent("Version", value: Self.version)
                    LabeledContent("Built", value: Self.buildDate)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: theme) { _, new in new.applyIcon(matchIcon) }
            .onChange(of: matchIcon) { _, new in theme.applyIcon(new) }
            .onChange(of: windowDays) { queue.rebuild(context) }
        }
    }

    /// When this copy was built in Xcode, read from the app binary's date.
    private static var buildDate: String {
        guard let url = Bundle.main.executableURL,
              let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return "Unknown" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

/// Smaller and larger buttons either side of the current step.
private struct TextSizeControl: View {
    @Binding var scale: Double
    let typeface: Typeface

    private var step: Int {
        ReaderStyle.scales.firstIndex { $0 >= scale - 0.001 } ?? 2
    }

    var body: some View {
        HStack {
            Button { move(-1) } label: {
                Image(systemName: "textformat.size.smaller").frame(width: 44, height: 32)
            }
            .disabled(step == 0)
            .accessibilityLabel("Smaller Text")
            Spacer()
            HStack(spacing: 6) {
                ForEach(ReaderStyle.scales.indices, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Spacer()
            Button { move(1) } label: {
                Image(systemName: "textformat.size.larger").frame(width: 44, height: 32)
            }
            .disabled(step == ReaderStyle.scales.count - 1)
            .accessibilityLabel("Larger Text")
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(Int(scale * 100)) percent")
    }

    private func move(_ by: Int) {
        let next = min(max(0, step + by), ReaderStyle.scales.count - 1)
        withAnimation(.snappy) { scale = ReaderStyle.scales[next] }
    }
}

private struct Swatch: View {
    let theme: AccentTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.gradient)
                        .frame(width: 44, height: 44)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(.black)
                    }
                }
                .padding(4)
                .overlay {
                    Circle().strokeBorder(selected ? theme.color : .clear, lineWidth: 2.5)
                }
                Text(theme.name)
                    .font(.caption2.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
