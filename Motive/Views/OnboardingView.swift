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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 34) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What should motivate you?")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MotiveTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Choose a few topics or add your own context. Your quotes will be personalized around what you select.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MotiveTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(StressTopic.groupedFocusAreas) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(MotiveTheme.secondaryText)

                            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                                ForEach(group.topics) { topic in
                                    MotiveChip(title: topic.rawValue, isSelected: appState.profile.selectedTopics.contains(topic)) {
                                        toggle(topic, in: &appState.profile)
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What's on your mind?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MotiveTheme.secondaryText)

                    TextField(text: $appState.profile.biggestProblem, axis: .vertical) {
                        Text("Example: I keep putting off important work")
                            .foregroundStyle(MotiveTheme.secondaryText)
                    }
                    .lineLimit(2...8)
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
