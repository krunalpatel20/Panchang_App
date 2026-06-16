import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Binding var seenOnboarding: Bool

    @State private var page = 0
    @State private var locationManager = LocationManager()

    var body: some View {
        TabView(selection: $page) {
            WelcomePage(onContinue: { page = 1 })
                .tag(0)
            AbsolutionPage(onContinue: { page = 2 })
                .tag(1)
            LocationPage(locationManager: locationManager, onContinue: {
                seenOnboarding = true
            })
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: page)
        .ignoresSafeArea()
    }
}

// MARK: - Screen 1: Welcome

private struct WelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text("Panchang")
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)

                Text("The shape of the month, in your pocket.\nThe Hindu lunar calendar — festivals, fasting days, and the rhythm of the year — rebuilt for wherever you are now.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            ContinueButton(label: "Continue", action: onContinue)
                .padding(.bottom, 52)
        }
    }
}

// MARK: - Screen 2: Absolution

private struct AbsolutionPage: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                Text("A note before we begin")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(.primary)

                Text("You don't have to have done this perfectly to start now. You don't have to have grown up with it, or observed every fast, or known the Sanskrit words, or had a grandmother who explained things. The tradition survived a lot — centuries of travel, partition, diaspora, intermarriage, forgetting. It can survive you coming to it late. You're here now. That's the beginning.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            Spacer()
            ContinueButton(label: "Continue", action: onContinue)
                .padding(.bottom, 52)
        }
    }
}

// MARK: - Screen 3: Location

private struct LocationPage: View {
    var locationManager: LocationManager
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                Image(systemName: "location.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Sunrise and sunset times")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(.primary)

                Text("Panchang times shift with the sun. Your location lets the app show accurate tithi changes, sunrise, and sunset for where you actually are.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 16) {
                ContinueButton(label: "Allow location", action: {
                    locationManager.requestLocation()
                    onContinue()
                })
                Button("Skip for now", action: onContinue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Shared button

private struct ContinueButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primary)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 32)
    }
}
