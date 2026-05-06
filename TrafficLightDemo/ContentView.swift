import SwiftUI

struct ContentView: View {

    // MARK: – Vehicle signal

    private enum VehicleLight {
        case red, yellow, green
        var color: Color {
            switch self {
            case .red:    return .red
            case .yellow: return .yellow
            case .green:  return .green
            }
        }
    }

    // MARK: – Intersection phase state machine

    private enum Phase: Int, CaseIterable {
        case nsGreen   // NS cars go  / EW pedestrians walk
        case nsYellow  // NS cars slow / all pedestrians stop
        case ewGreen   // EW cars go  / NS pedestrians walk
        case ewYellow  // EW cars slow / all pedestrians stop

        var title: String {
            switch self {
            case .nsGreen:   return "North/South GO"
            case .nsYellow:  return "North/South READY"
            case .ewGreen:   return "East/West GO"
            case .ewYellow:  return "East/West READY"
            }
        }

        var durationInSeconds: UInt64 {
            switch self {
            case .nsGreen, .ewGreen:     return 3
            case .nsYellow, .ewYellow:   return 1
            }
        }

        // Vehicle lights
        var northSouthLight: VehicleLight {
            switch self {
            case .nsGreen:           return .green
            case .nsYellow:          return .yellow
            case .ewGreen, .ewYellow: return .red
            }
        }

        var eastWestLight: VehicleLight {
            switch self {
            case .ewGreen:           return .green
            case .ewYellow:          return .yellow
            case .nsGreen, .nsYellow: return .red
            }
        }

        // Pedestrian WALK signals
        // NS pedestrians cross the NS road → safe only while EW cars are moving (ewGreen)
        var nsPedWalk: Bool {
            self == .ewGreen
        }

        // EW pedestrians cross the EW road → safe only while NS cars are moving (nsGreen)
        var ewPedWalk: Bool {
            self == .nsGreen
        }
    }

    @State private var activePhase: Phase = .nsGreen
    @State private var isAutoModeOn = true
    @State private var cycleTask: Task<Void, Never>?

    // MARK: – Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.09),
                         Color(red: 0.16, green: 0.17, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("4-Way Traffic Crossing")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(activePhase.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .animation(.easeInOut(duration: 0.2), value: activePhase)

                legend

                intersectionView

                HStack(spacing: 12) {
                    Button("Next Phase") {
                        advancePhase()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Toggle("Auto", isOn: $isAutoModeOn)
                        .toggleStyle(.switch)
                        .foregroundStyle(.white)
                        .onChange(of: isAutoModeOn) { enabled in
                            if enabled {
                                runAutoCycle()
                            } else {
                                cycleTask?.cancel()
                                cycleTask = nil
                            }
                        }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .task {
            if isAutoModeOn { runAutoCycle() }
        }
        .onDisappear {
            cycleTask?.cancel()
        }
    }

    // MARK: – Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .red,   label: "Stop")
            legendItem(color: .yellow, label: "Slow")
            legendItem(color: .green, label: "Go / Walk")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    // MARK: – Intersection canvas

    private var intersectionView: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let roadFraction = 0.26
            let roadW = side * roadFraction

            ZStack {
                // Pavement
                Color(red: 0.14, green: 0.15, blue: 0.17)

                // Roads
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.23, blue: 0.26))
                    .frame(width: roadW, height: side)

                Rectangle()
                    .fill(Color(red: 0.22, green: 0.23, blue: 0.26))
                    .frame(width: side, height: roadW)

                // Centre lines
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 2, height: side)

                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: side, height: 2)

                // Zebra crossings (dashed white stripes near intersection)
                zebraCrossing(horizontal: false, roadW: roadW, side: side)
                zebraCrossing(horizontal: true,  roadW: roadW, side: side)

                // ── Vehicle + Pedestrian signal poles ──
                // N/S poles: pedestrians walk north-south, crossing the NS road.
                // They need NS cars to be RED → nsPedWalk (true during ewGreen).
                VStack {
                    signalPole(
                        direction: "N",
                        vehicle: activePhase.northSouthLight,
                        pedWalk: activePhase.nsPedWalk
                    )
                    Spacer()
                    signalPole(
                        direction: "S",
                        vehicle: activePhase.northSouthLight,
                        pedWalk: activePhase.nsPedWalk
                    )
                }
                .padding(.vertical, 16)

                // E/W poles: pedestrians walk east-west, crossing the EW road.
                // They need EW cars to be RED → ewPedWalk (true during nsGreen).
                HStack {
                    signalPole(
                        direction: "W",
                        vehicle: activePhase.eastWestLight,
                        pedWalk: activePhase.ewPedWalk
                    )
                    Spacer()
                    signalPole(
                        direction: "E",
                        vehicle: activePhase.eastWestLight,
                        pedWalk: activePhase.ewPedWalk
                    )
                }
                .padding(.horizontal, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
        }
        .frame(height: 390)
    }

    // Zebra stripes drawn near each side of the intersection
    @ViewBuilder
    private func zebraCrossing(horizontal: Bool, roadW: CGFloat, side: CGFloat) -> some View {
        let stripeCount = 5
        let crossingLength = roadW * 0.82
        let crossingWidth  = roadW * 0.22
        let stripeW = crossingLength / CGFloat(stripeCount * 2 - 1)

        ForEach(0..<stripeCount, id: \.self) { i in
            let offset = CGFloat(i) * stripeW * 2 - crossingLength / 2 + stripeW / 2
            Group {
                if horizontal {
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: stripeW, height: crossingWidth)
                        .offset(x: offset, y: side * 0.5 - crossingWidth * 1.3)
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: stripeW, height: crossingWidth)
                        .offset(x: offset, y: -(side * 0.5 - crossingWidth * 1.3))
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: crossingWidth, height: stripeW)
                        .offset(x: side * 0.5 - crossingWidth * 1.3, y: offset)
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: crossingWidth, height: stripeW)
                        .offset(x: -(side * 0.5 - crossingWidth * 1.3), y: offset)
                }
            }
        }
    }

    // MARK: – Signal pole: vehicle head + pedestrian head side by side

    private func signalPole(
        direction: String,
        vehicle: VehicleLight,
        pedWalk: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text(direction)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))

            HStack(alignment: .top, spacing: 5) {
                vehicleHead(vehicle)
                pedestrianHead(pedWalk)
            }
        }
    }

    // 3-bulb vehicle traffic light
    private func vehicleHead(_ active: VehicleLight) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.black.opacity(0.78))
            .frame(width: 54, height: 114)
            .overlay {
                VStack(spacing: 8) {
                    vehicleDot(.red,    isOn: active == .red)
                    vehicleDot(.yellow, isOn: active == .yellow)
                    vehicleDot(.green,  isOn: active == .green)
                }
            }
    }

    private func vehicleDot(_ color: VehicleLight, isOn: Bool) -> some View {
        Circle()
            .fill(color.color.opacity(isOn ? 1 : 0.15))
            .overlay { Circle().stroke(Color.white.opacity(0.14), lineWidth: 1) }
            .frame(width: 22, height: 22)
            .shadow(color: isOn ? color.color.opacity(0.9) : .clear, radius: 9)
            .animation(.easeInOut(duration: 0.25), value: activePhase)
    }

    // 2-bulb pedestrian crossing signal (red = stop, green = walk)
    private func pedestrianHead(_ walking: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.78))
            .frame(width: 34, height: 74)
            .overlay {
                VStack(spacing: 7) {
                    // Red – don't walk
                    pedestrianDot(color: .red, isOn: !walking)
                    // Green – walk
                    pedestrianDot(color: .green, isOn: walking)
                }
            }
            .overlay(alignment: .bottom) {
                Text("PED")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 3)
            }
    }

    private func pedestrianDot(color: Color, isOn: Bool) -> some View {
        Circle()
            .fill(color.opacity(isOn ? 1 : 0.15))
            .overlay { Circle().stroke(Color.white.opacity(0.14), lineWidth: 1) }
            .frame(width: 18, height: 18)
            .shadow(color: isOn ? color.opacity(0.9) : .clear, radius: 8)
            .animation(.easeInOut(duration: 0.25), value: activePhase)
    }

    // MARK: – Phase control

    private func advancePhase() {
        let nextRaw = (activePhase.rawValue + 1) % Phase.allCases.count
        if let next = Phase(rawValue: nextRaw) {
            activePhase = next
        }
    }

    private func runAutoCycle() {
        cycleTask?.cancel()
        cycleTask = Task {
            while isAutoModeOn {
                let nanoseconds = activePhase.durationInSeconds * 1_000_000_000
                try? await Task.sleep(nanoseconds: nanoseconds)
                await MainActor.run {
                    guard isAutoModeOn else { return }
                    advancePhase()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
