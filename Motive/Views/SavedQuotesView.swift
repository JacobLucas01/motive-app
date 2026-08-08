import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SavedQuotesView: View {
    @EnvironmentObject private var appState: MotiveAppState
    @State private var copiedQuoteID: SavedQuote.ID?
    @State private var isShowingQuoteScanner = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                topBar

                if appState.savedQuotes.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(appState.savedQuotes) { quote in
                            savedQuoteRow(quote)
                        }
                    }
                }
            }
            .padding(MotiveTheme.pagePadding)
        }
        .motiveScreen()
        .fullScreenCover(isPresented: $isShowingQuoteScanner) {
            QuoteCameraScannerView(
                onCancel: {
                    isShowingQuoteScanner = false
                },
                onSave: { quote in
                    appState.saveScannedQuote(quote)
                    isShowingQuoteScanner = false
                },
                onError: { message in
                    appState.errorMessage = message
                }
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button {
                appState.route = .home
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.primaryText)

            Spacer()

            Text("Saved quotes")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MotiveTheme.primaryText)

            Spacer()

            Button {
                isShowingQuoteScanner = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MotiveTheme.primaryText)
        }
        .frame(height: 42)
        .padding(.bottom, -8)
    }
    
    private var emptyState: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No saved quotes yet")
                    .font(.system(size: 18, weight: .bold))

                Text("Tap the bookmark or scan a quote. Saved quotes can show up in your notifications.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "bookmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(MotiveTheme.accent)
                .frame(width: 22, height: 22)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(MotiveTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius + 8, style: .continuous))
        .motiveGlass(cornerRadius: MotiveTheme.radius + 8, tint: MotiveTheme.surface, interactive: false)
    }

    private func savedQuoteRow(_ quote: SavedQuote) -> some View {
        HStack(spacing: 14) {
            Text(quote.text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MotiveTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                quoteActionButton(
                    systemImage: copiedQuoteID == quote.id ? "checkmark" : "doc.on.doc",
                    foreground: copiedQuoteID == quote.id ? MotiveTheme.accent : MotiveTheme.primaryText
                ) {
                    copy(quote)
                }

                quoteActionButton(systemImage: "trash", foreground: MotiveTheme.warning) {
                    appState.removeSavedQuote(quote)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MotiveTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius + 8, style: .continuous))
        .motiveGlass(cornerRadius: MotiveTheme.radius + 8, tint: MotiveTheme.surface, interactive: false)
    }

    private func quoteActionButton(systemImage: String, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(MotiveTheme.elevatedSurface)
        .clipShape(Circle())
        .motiveGlass(cornerRadius: 19, tint: MotiveTheme.elevatedSurface, interactive: true)
    }

    private func copy(_ quote: SavedQuote) {
        #if canImport(UIKit)
        UIPasteboard.general.string = quote.text
        #endif
        copiedQuoteID = quote.id
    }
}

struct SavedQuotesView_Previews: PreviewProvider {
    static var previews: some View {
        SavedQuotesView()
            .environmentObject(MotiveAppState())
    }
}
