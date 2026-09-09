import SwiftUI

/// 旭日图几何计算:把树映射为扇区角度
struct SunburstSegment: Identifiable {
    let id: URL
    let node: FileSystemNode
    let kind: FileKind
    let startAngle: Double   // 度,-90 = 12点方向
    let endAngle: Double
    let ring: Int            // 0 = 根环

    var midAngle: Double { (startAngle + endAngle) / 2 }
    var sweep: Double { endAngle - startAngle }
}

struct SunburstGeometry {
    /// 可见根(点击下钻后的焦点节点)
    let focus: FileSystemNode
    /// 展示环数(焦点为第 0 环,向下 depthRings 层)
    let segments: [SunburstSegment]

    static func build(focus: FileSystemNode, depthRings: Int = 5) -> SunburstGeometry {
        var segments: [SunburstSegment] = []
        let total = max(focus.size, 1)
        var angle = -90.0

        // 第 0 环 = 焦点自身(整环)
        segments.append(SunburstSegment(id: focus.id, node: focus, kind: .folder, startAngle: -90, endAngle: 270, ring: 0))

        // 递归铺环:按 children 的 size 占比切角
        func layout(node: FileSystemNode, ring: Int, startA: Double, sweepA: Double) {
            guard ring <= depthRings, !node.children.isEmpty, sweepA > 0.15 else { return }
            // 过滤微小项(<0.05% 或 <8KB 丢弃,防碎片噪声)
            let minSize = UInt64(max(Double(total) * 0.0005, 8_192))
            let visible = node.children.filter { $0.size >= minSize }
            let hiddenSize = node.children.reduce(UInt64(0)) { $0 + $1.size } - visible.reduce(UInt64(0)) { $0 + $1.size }
            let visibleTotal = max(visible.reduce(UInt64(0)) { $0 + $1.size }, 1)
            let usable = sweepA - (hiddenSize > 0 && !visible.isEmpty ? 0.6 : 0)
            guard usable > 0.05 else { return }

            var a = startA
            for child in visible {
                let frac = Double(child.size) / Double(visibleTotal)
                let sw = frac * usable
                if sw > 0.02 {
                    segments.append(
                        SunburstSegment(id: child.id, node: child, kind: FileKind(node: child),
                                        startAngle: a, endAngle: a + sw, ring: ring)
                    )
                }
                a += sw
                if child.isDirectory {
                    layout(node: child, ring: ring + 1, startA: a - sw, sweepA: sw)
                }
            }
        }
        layout(node: focus, ring: 1, startA: angle, sweepA: 360)

        // 按环排序稳定渲染
        segments.sort { ($0.ring, $0.startAngle) < ($1.ring, $1.startAngle) }
        return SunburstGeometry(focus: focus, segments: segments)
    }
}

/// Canvas 旭日图渲染 + 点击命中测试 + 下钻
struct SunburstView: View {
    let focus: FileSystemNode
    var onPick: (FileSystemNode) -> Void

    @State private var hoverSegment: SunburstSegment?
    @State private var animateIn: Double = 0

    private let innerRatio: CGFloat = 0.18
    private let ringWidth: CGFloat = 0.15   // 相对半径

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outer = size / 2
            let geometry = SunburstGeometry.build(focus: focus)

            ZStack {
                Canvas { ctx, _ in
                    for seg in geometry.segments {
                        let r0: CGFloat
                        let r1: CGFloat
                        if seg.ring == 0 {
                            r0 = 0
                            r1 = outer * innerRatio * 1.6
                        } else {
                            r0 = outer * (innerRatio + CGFloat(seg.ring - 1) * ringWidth) * 1.6 / 1.6
                            r1 = r0 + outer * ringWidth
                        }
                        guard r1 <= outer + 0.5 else { continue }

                        var path = Path()
                        path.addArc(center: center, radius: r0,
                                    startAngle: .degrees(seg.startAngle), endAngle: .degrees(seg.endAngle),
                                    clockwise: false)
                        path.addArc(center: center, radius: r1,
                                    startAngle: .degrees(seg.endAngle), endAngle: .degrees(seg.startAngle),
                                    clockwise: true)
                        path.closeSubpath()

                        let isHover = hoverSegment?.id == seg.id
                        let color = color(for: seg, isHover: isHover)
                        ctx.fill(path, with: .color(color))
                        if isHover {
                            ctx.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 2)
                        }
                    }
                }
                .animation(.easeOut(duration: 0.15), value: hoverSegment?.id)

                // 中心信息
                VStack(spacing: 2) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: size * 0.045))
                        .foregroundStyle(.secondary)
                    Text(focus.name)
                        .font(.system(size: size * 0.032, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, outer * innerRatio * 0.9)
                    Text(Fmt.bytes(focus.size))
                        .font(.system(size: size * 0.028, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(String(format: I18n.t("sunburst.items"), Fmt.itemCount(focus.itemCount)))
                        .font(.system(size: size * 0.022))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: outer * innerRatio * 2.6)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverSegment = hitTest(point: point, center: center, outer: outer, geometry: geometry)
                case .ended:
                    hoverSegment = nil
                }
            }
            .onTapGesture {
                if let seg = hoverSegment, seg.ring > 0 {
                    onPick(seg.node)
                }
            }
            .help(hoverSegment.map { "\($0.node.name) — \(Fmt.bytes($0.node.size))" } ?? "")
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { animateIn = 1 } }
    }

    // MARK: - 命中测试

    private func hitTest(point: CGPoint, center: CGPoint, outer: CGFloat, geometry: SunburstGeometry) -> SunburstSegment? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        var angle = atan2(dy, dx) * 180 / .pi // [-180,180]
        if angle < -90 { angle += 360 }       // 归一到 [-90, 270)
        if angle < -90 { angle = -90 }

        for seg in geometry.segments {
            let r0: CGFloat
            let r1: CGFloat
            if seg.ring == 0 {
                r0 = 0; r1 = outer * innerRatio * 1.6
            } else {
                r0 = outer * (innerRatio + CGFloat(seg.ring - 1) * ringWidth)
                r1 = r0 + outer * ringWidth
            }
            if dist >= r0 && dist <= r1 && angle >= seg.startAngle && angle <= seg.endAngle {
                return seg
            }
        }
        return nil
    }

    // MARK: - 配色

    private func color(for seg: SunburstSegment, isHover: Bool) -> Color {
        var hue: Double
        var sat: Double
        var bri: Double

        if seg.ring == 0 {
            hue = 0.58; sat = 0.55; bri = 0.55
        } else if seg.node.isDirectory {
            // 目录:名称哈希稳定色相
            hue = SunburstColor.hueOffset(for: seg.node.name)
            sat = 0.62
            bri = 0.55 + 0.12 * (Double(seg.ring % 2))
        } else {
            switch seg.kind {
            case .image: hue = 0.32; sat = 0.65; bri = 0.6
            case .video: hue = 0.78; sat = 0.6; bri = 0.62
            case .audio: hue = 0.12; sat = 0.65; bri = 0.62
            case .archive: hue = 0.07; sat = 0.6; bri = 0.58
            case .code: hue = 0.45; sat = 0.55; bri = 0.58
            case .document: hue = 0.55; sat = 0.45; bri = 0.6
            case .folder: hue = 0.6; sat = 0.6; bri = 0.55
            case .other: hue = SunburstColor.hueOffset(for: seg.node.name); sat = 0.3; bri = 0.45
            }
        }
        if isHover {
            bri = min(bri + 0.18, 1)
            sat = min(sat + 0.15, 1)
        }
        return Color(hue: hue, saturation: sat, brightness: bri)
    }
}
