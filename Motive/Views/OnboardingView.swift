import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    @EnvironmentObject private var appState: MotiveAppState

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What should Motive understand?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MotiveTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Choose a few themes or write your own context. These become profile signals for future quotes.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MotiveTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(StressTopic.allCases) { topic in
                        MotiveChip(title: topic.rawValue, isSelected: appState.profile.selectedTopics.contains(topic)) {
                            toggle(topic, in: &appState.profile)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Biggest problem")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MotiveTheme.secondaryText)

                    TextField(text: $appState.profile.biggestProblem, axis: .vertical) {
                        Text("Example: I keep putting off important work")
                            .foregroundStyle(MotiveTheme.secondaryText)
                    }
                    .lineLimit(2...4)
                    .motiveField()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything else")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MotiveTheme.secondaryText)

                    ZStack(alignment: .topLeading) {
                        if appState.profile.customContext.trimmed.isEmpty {
                            Text("Add details that should shape future quotes")
                                .foregroundStyle(MotiveTheme.secondaryText)
                                .padding(.top, 22)
                                .padding(.horizontal, 18)
                        }

                        TextEditor(text: $appState.profile.customContext)
                            .foregroundStyle(MotiveTheme.primaryText)
                            .foregroundColor(MotiveTheme.primaryText)
                            .tint(MotiveTheme.accent)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                    .motiveField()
                }

                MotivePrimaryButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    isDisabled: !appState.profile.isComplete
                ) {
                    Task {
                        await appState.saveProfileAndContinue()
                    }
                }
            }
            .padding(MotiveTheme.pagePadding)
        }
        .motiveScreen()
        .dismissKeyboardOnTap()
    }

    private func toggle(_ topic: StressTopic, in profile: inout UserProfile) {
        selectionFeedback()
        if profile.selectedTopics.contains(topic) {
            profile.selectedTopics.remove(topic)
        } else {
            profile.selectedTopics.insert(topic)
        }
    }

    private func selectionFeedback() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(MotiveAppState())
    }
}
