import SwiftUI

/// First-run onboarding shell for derived apps.
/// Replace the copy and steps with the shortest path to the user's first value moment.
struct OnboardingView: View {
    @Environment(AnalyticsService.self) private var analyticsService

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void = {}) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("Welcome to Boilerplate")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Your starting point for building great iOS apps")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            PrimaryButton(title: "Get Started") {
                analyticsService.track(.onboardingCompleted)
                UserDefaultsWrapper.hasCompletedOnboarding = true
                onComplete()
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            analyticsService.track(.onboardingStarted)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AnalyticsService())
}
