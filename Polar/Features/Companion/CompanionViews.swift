import SwiftUI

enum CoherenceClock {
    static let period: TimeInterval = 10

    static func phase(elapsed: TimeInterval) -> Double {
        let wrapped = elapsed.truncatingRemainder(dividingBy: period)
        let positive = wrapped < 0 ? wrapped + period : wrapped
        return positive / period
    }

    /// 0 à poumons vides, 1 à poumons pleins. Une sinusoïde, sans à-coup au sommet.
    static func amplitude(phase: Double) -> Double {
        (1 - cos(2 * Double.pi * phase)) / 2
    }

    static func inhaling(phase: Double) -> Bool {
        phase < 0.5
    }

    static func secondsLeft(phase: Double) -> Int {
        let elapsed = phase * period
        let remaining = elapsed < 5 ? 5 - elapsed : period - elapsed
        return min(5, max(1, Int(ceil(remaining - 0.0001))))
    }

    /// Le mot bascule dans les 350 ms qui précèdent le sommet et le creux.
    static func inspireOpacity(phase: Double) -> Double {
        let fade = 0.035
        if phase < 0.5 - fade { return 1 }
        if phase < 0.5 {
            return 1 - smooth((phase - (0.5 - fade)) / fade)
        }
        if phase < 1 - fade { return 0 }
        return smooth((phase - (1 - fade)) / fade)
    }

    private static func smooth(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}

struct CoherenceStage: View {
    var asleep: Bool
    var pulse: Int

    @Environment(AppLock.self) private var lock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var origin = Date.now
    @State private var pausedAt: Date?
    @State private var parked: TimeInterval = 0
    @State private var loop = 0
    @State private var turn = 0

    var body: some View {
        let paused = pausedAt != nil
        TimelineView(reduceMotion ? .animation(minimumInterval: 0.25, paused: paused) : .animation(paused: paused)) { timeline in
            let elapsed = elapsed(at: pausedAt ?? timeline.date)
            let phase = CoherenceClock.phase(elapsed: elapsed)
            let amplitude = CoherenceClock.amplitude(phase: phase)
            let inspire = CoherenceClock.inspireOpacity(phase: phase)
            let seconds = CoherenceClock.secondsLeft(phase: phase)

            VStack(spacing: 4) {
                CoherenceOrb(
                    amplitude: reduceMotion ? 0.35 : amplitude,
                    phase: phase,
                    asleep: asleep,
                    pulse: pulse,
                    still: reduceMotion || paused,
                    showDot: !reduceMotion
                )

                VStack(spacing: 0) {
                    ZStack {
                        Text("Inspire")
                            .opacity(paused ? 0 : inspire)
                        Text("Expire")
                            .opacity(paused ? 0 : 1 - inspire)
                        Text("En pause")
                            .foregroundStyle(Palette.inkMuted)
                            .opacity(paused ? 1 : 0)
                    }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .frame(height: 26)

                    Text("\(seconds)")
                        .font(.title3.weight(.regular))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .opacity(paused ? 0 : 1)
                        .frame(height: 28)
                }

                if reduceMotion {
                    Text("Cinq secondes, puis cinq secondes.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .frame(height: 28)
                } else {
                    CoherenceWave(phase: phase)
                        .frame(height: 28)
                        .padding(.horizontal, 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(paused ? "En pause" : (CoherenceClock.inhaling(phase: phase) ? "Inspire" : "Expire"))
            .accessibilityHint(paused ? "Touche pour reprendre" : "Touche pour pauser")
            .accessibilityAddTraits(.isButton)
        }
        .contentShape(.rect)
        .onTapGesture { togglePause() }
        .sensoryFeedback(.impact(weight: .light), trigger: turn)
        .task(id: loop) { await guideTurns() }
        .onAppear {
            if !lock.isLocked { restart() }
        }
        .onChange(of: lock.isLocked) { _, locked in
            if !locked { restart() }
        }
    }

    private func elapsed(at date: Date) -> TimeInterval {
        let end = pausedAt ?? date
        return max(0, end.timeIntervalSince(origin) - parked)
    }

    private func restart() {
        origin = .now
        pausedAt = nil
        parked = 0
        loop += 1
    }

    private func togglePause() {
        if let pausedAt {
            parked += Date.now.timeIntervalSince(pausedAt)
            self.pausedAt = nil
        } else {
            pausedAt = .now
        }
        loop += 1
    }

    private func guideTurns() async {
        guard pausedAt == nil, !lock.isLocked else { return }
        while !Task.isCancelled {
            let elapsed = Date.now.timeIntervalSince(origin) - parked
            let into = elapsed.truncatingRemainder(dividingBy: 5)
            let wait = into < 0.05 ? 5 : 5 - into
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, pausedAt == nil, !lock.isLocked else { return }
            turn += 1
        }
    }
}

private struct CoherenceOrb: View {
    var amplitude: Double
    var phase: Double
    var asleep: Bool
    var pulse: Int
    var still: Bool
    var showDot: Bool

    private let ring: CGFloat = 168

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.hairline, lineWidth: 1)
                .frame(width: ring, height: ring)
            Circle()
                .stroke(Palette.hairline, lineWidth: 1)
                .frame(width: ring, height: ring)
                .scaleEffect(0.70)

            ZStack {
                Circle()
                    .fill(Palette.surface)
                    .frame(width: ring * 0.56, height: ring * 0.56)
                CompanionSphere(asleep: asleep, pulse: pulse, still: still)
                    .frame(width: ring, height: ring)
                Circle()
                    .stroke(Palette.ink, lineWidth: 1.5)
                    .frame(width: ring, height: ring)
            }
            .scaleEffect(0.70 + 0.28 * amplitude)

            if showDot {
                Circle()
                    .fill(Palette.ink)
                    .frame(width: 8, height: 8)
                    .offset(y: -ring / 2)
                    .rotationEffect(.degrees(phase * 360))
            }
        }
        .frame(width: ring + 12, height: ring + 12)
        .accessibilityHidden(true)
    }
}

private struct CoherenceWave: View {
    var phase: Double

    var body: some View {
        ZStack {
            Canvas { context, size in
                let mid = size.height / 2
                let amp = size.height * 0.34
                let cycles = 1.35
                var path = Path()
                let steps = max(Int(size.width / 2), 1)
                for step in 0...steps {
                    let x = size.width * Double(step) / Double(steps)
                    let shift = (x / size.width - 0.5) * cycles
                    let y = mid + amp * cos(2 * Double.pi * (phase + shift))
                    let point = CGPoint(x: x, y: y)
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(
                    path,
                    with: .color(Palette.ink.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }

            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1)

            Canvas { context, size in
                let mid = size.height / 2
                let amp = size.height * 0.34
                let y = mid + amp * cos(2 * Double.pi * phase)
                let dot = CGRect(x: size.width / 2 - 4, y: y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dot), with: .color(Palette.ink))
            }
        }
        .accessibilityHidden(true)
    }
}

struct CompanionSphere: View {
    var asleep = false
    var pulse = 0
    var still = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let points: [SIMD3<Double>] = (0..<400).map { index in
        let k = Double(index) + 0.5
        let phi = acos(1 - 2 * k / 400)
        let theta = Double.pi * (1 + 5.0.squareRoot()) * k
        return SIMD3(cos(theta) * sin(phi), cos(phi), sin(theta) * sin(phi))
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || still)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let radius = min(size.width, size.height) * 0.44
                let spin = (reduceMotion || still) ? 0 : time * (asleep ? 0.04 : 0.12)
                let ink = Palette.ink

                for point in Self.points {
                    let x = point.x * cos(spin) + point.z * sin(spin)
                    let z = -point.x * sin(spin) + point.z * cos(spin)
                    let depth = (z + 1) / 2
                    let diameter = 1.1 + 2.2 * depth
                    let cx = size.width / 2 + x * radius
                    let cy = size.height / 2 + point.y * radius
                    let base = asleep ? 0.10 : 0.16
                    context.fill(
                        Path(ellipseIn: CGRect(x: cx - diameter / 2, y: cy - diameter / 2, width: diameter, height: diameter)),
                        with: .color(ink.opacity(base + 0.72 * depth))
                    )
                }
            }
        }
        .modifier(PulseEffect(token: pulse))
        .accessibilityHidden(true)
    }
}

private struct PulseEffect: ViewModifier {
    var token: Int
    @State private var scale = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: token) { _, _ in
                guard token > 0 else { return }
                withAnimation(.snappy(duration: 0.25)) { scale = 1.08 }
                withAnimation(.snappy(duration: 0.25).delay(0.25)) { scale = 1 }
            }
    }
}
