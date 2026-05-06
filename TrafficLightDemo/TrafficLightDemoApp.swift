import SwiftUI

@main
struct TrafficLightDemoApp: App {
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        isShowingSplash = false
                    }
                }
            }
        }
    }
}

