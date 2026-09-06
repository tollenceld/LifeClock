import SwiftUI

struct TimeFieldView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let source: ClockPresentationSnapshot
    let target: ClockPresentationSnapshot
    let progress: Double
    let onMarkerTap: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let effectiveProgress = reduceMotion ? (progress < 0.5 ? 0.0 : 1.0) : progress
            let sourceLayout = ClockVisualLayout(presentation: source, size: proxy.size)
            let targetLayout = ClockVisualLayout(presentation: target, size: proxy.size)
            let activePresentation = effectiveProgress < 0.5 ? source : target
            let activeLayout = effectiveProgress < 0.5 ? sourceLayout : targetLayout

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                    MorphingClockCanvas(
                        source: source,
                        target: target,
                        progress: effectiveProgress,
                        pulse: reduceMotion ? 0.36 : pulseValue(at: timeline.date),
                        size: proxy.size,
                        theme: theme,
                        colorScheme: colorScheme
                    )
                }
                .accessibilityHidden(true)

                Text("\(activePresentation.scale.accessibilityTitle)主图")
                    .font(.system(size: 1))
                    .foregroundStyle(Color.primary.opacity(0.001))
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(activePresentation.scale.accessibilityTitle)主图")
                    .accessibilityValue(
                        "\(activePresentation.stageTitle)，\(activePresentation.clock.progressText)，\(activePresentation.remainingText)"
                    )
                    .accessibilityIdentifier("timefield.\(activePresentation.scale.rawValue)")

                Group {
                    ForEach(sourceLayout.annotations) { annotation in
                        annotationLabel(annotation)
                            .opacity(1 - effectiveProgress)
                            .offset(x: -8 * effectiveProgress)
                    }

                    if source.scale != target.scale {
                        ForEach(targetLayout.annotations) { annotation in
                            annotationLabel(annotation)
                                .opacity(effectiveProgress)
                                .offset(x: 8 * (1 - effectiveProgress))
                        }
                    }
                }

                ForEach(activePresentation.clock.markers) { marker in
                    Button {
                        onMarkerTap(marker.id)
                    } label: {
                        Circle()
                            .fill(.clear)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(activeLayout.markerPoint(for: marker))
                    .accessibilityLabel(marker.title)
                    .accessibilityValue(marker.occurrence.formatted(date: .abbreviated, time: .shortened))
                    .accessibilityHint("轻点编辑刻点")
                    .accessibilityIdentifier("marker.\(marker.id.uuidString)")
                }
            }
        }
    }

    private func annotationLabel(_ annotation: ClockVisualAnnotation) -> some View {
        Text(annotation.text)
            .font(.system(size: annotation.size, weight: .medium, design: .monospaced))
            .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
            .monospacedDigit()
            .position(annotation.point)
            .accessibilityHidden(true)
    }

    private func pulseValue(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2
        return (sin(cycle * .pi * 2 - .pi / 2) + 1) / 2
    }
}

private struct MorphingClockCanvas: View {
    let source: ClockPresentationSnapshot
    let target: ClockPresentationSnapshot
    let progress: Double
    let pulse: Double
    let size: CGSize
    let theme: AppTheme
    let colorScheme: ColorScheme

    var body: some View {
        Canvas { context, _ in
            let sourceLayout = ClockVisualLayout(presentation: source, size: size)
            let targetLayout = ClockVisualLayout(presentation: target, size: size)
            let maximumCount = max(sourceLayout.count, targetLayout.count)
            let overallProgress = min(1, max(0, progress))

            drawGuides(
                context: &context,
                sourceLayout: sourceLayout,
                targetLayout: targetLayout,
                progress: overallProgress
            )

            for index in 0..<maximumCount {
                let phase = maximumCount > 1 ? Double(index) / Double(maximumCount - 1) : 0
                let stagger = phase * 0.12
                let localProgress = smoothStep(min(1, max(0, (overallProgress - stagger) / (1 - stagger))))
                let sourceItem = sourceLayout.itemOrMappedAnchor(at: index, domainCount: maximumCount)
                let targetItem = targetLayout.itemOrMappedAnchor(at: index, domainCount: maximumCount)
                let sourceExists = index < sourceLayout.count
                let targetExists = index < targetLayout.count

                var width = interpolate(sourceItem.size.width, targetItem.size.width, localProgress)
                var height = interpolate(sourceItem.size.height, targetItem.size.height, localProgress)
                let position = CGPoint(
                    x: interpolate(sourceItem.center.x, targetItem.center.x, localProgress),
                    y: interpolate(sourceItem.center.y, targetItem.center.y, localProgress)
                )

                if sourceExists && !targetExists {
                    let exitScale = 1 - 0.88 * sin(localProgress * .pi / 2)
                    width *= exitScale
                    height *= exitScale
                } else if !sourceExists && targetExists {
                    let entranceScale = 0.12 + 0.88 * sin(localProgress * .pi / 2)
                    width *= entranceScale
                    height *= entranceScale
                } else if sourceLayout.count != targetLayout.count {
                    let elasticity = 1 + sin(localProgress * .pi) * (0.07 + CGFloat(phase) * 0.04)
                    width *= elasticity
                    height *= elasticity
                }

                let rect = CGRect(
                    x: position.x - width / 2,
                    y: position.y - height / 2,
                    width: max(0.5, width),
                    height: max(0.5, height)
                )
                let path = Path(roundedRect: rect, cornerRadius: min(width, height) / 2)

                if sourceExists {
                    context.fill(
                        path,
                        with: .color(color(for: index, presentation: source, layout: sourceLayout)
                            .opacity(1 - localProgress))
                    )
                }
                if targetExists {
                    context.fill(
                        path,
                        with: .color(color(for: index, presentation: target, layout: targetLayout)
                            .opacity(localProgress))
                    )
                }
            }

            drawMonthLabels(
                context: &context,
                presentation: source,
                layout: sourceLayout,
                opacity: 1 - overallProgress
            )
            drawMonthLabels(
                context: &context,
                presentation: target,
                layout: targetLayout,
                opacity: overallProgress
            )
            drawFineProgress(
                context: &context,
                presentation: source,
                layout: sourceLayout,
                opacity: source.scale == target.scale ? 1 : 1 - overallProgress
            )
            if source.scale != target.scale {
                drawFineProgress(
                    context: &context,
                    presentation: target,
                    layout: targetLayout,
                    opacity: overallProgress
                )
            }

            if source.scale == target.scale {
                drawLivingEdge(context: &context, layout: sourceLayout, opacity: 1)
            } else {
                drawLivingEdge(context: &context, layout: sourceLayout, opacity: 1 - overallProgress)
                drawLivingEdge(context: &context, layout: targetLayout, opacity: overallProgress)
            }
        }
    }

    private func drawGuides(
        context: inout GraphicsContext,
        sourceLayout: ClockVisualLayout,
        targetLayout: ClockVisualLayout,
        progress: Double
    ) {
        for rect in sourceLayout.guideRects {
            context.fill(
                Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2),
                with: .color(theme.futureDot(for: colorScheme).opacity((1 - progress) * 0.72))
            )
        }
        for rect in targetLayout.guideRects {
            context.fill(
                Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2),
                with: .color(theme.futureDot(for: colorScheme).opacity(progress * 0.72))
            )
        }
    }

    private func drawMonthLabels(
        context: inout GraphicsContext,
        presentation: ClockPresentationSnapshot,
        layout: ClockVisualLayout,
        opacity: Double
    ) {
        guard presentation.scale == .month, opacity > 0.03 else { return }
        for index in presentation.units.indices {
            let unit = presentation.units[index]
            guard !unit.isPlaceholder, let label = unit.label else { continue }
            let foreground: Color
            if unit.progress >= 0.999 {
                foreground = theme.background(for: colorScheme)
            } else if unit.progress > 0 {
                foreground = .black
            } else {
                foreground = theme.secondaryLabel(for: colorScheme)
            }
            context.draw(
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(foreground.opacity(opacity)),
                at: layout.item(at: index).center
            )
        }
    }

    private func drawFineProgress(
        context: inout GraphicsContext,
        presentation: ClockPresentationSnapshot,
        layout: ClockVisualLayout,
        opacity: Double
    ) {
        guard opacity > 0.03, let progress = presentation.fineProgress else { return }
        let completed = Int(floor(progress * Double(layout.fineRects.count)))
        let current = min(layout.fineRects.count - 1, max(0, completed))

        for (index, rect) in layout.fineRects.enumerated() {
            let color: Color
            if index < completed {
                color = theme.completedDot(for: colorScheme)
            } else if index == current {
                color = theme.accent.opacity(0.86 + pulse * 0.14)
            } else {
                color = theme.futureDot(for: colorScheme)
            }
            context.fill(
                Path(roundedRect: rect, cornerRadius: rect.width / 2),
                with: .color(color.opacity(opacity))
            )
        }
    }

    private func drawLivingEdge(
        context: inout GraphicsContext,
        layout: ClockVisualLayout,
        opacity: Double
    ) {
        guard opacity > 0.04, layout.count > 0 else { return }
        let item = layout.item(at: layout.currentIndex)
        let reveal = min(1, opacity)
        let core = max(5, min(11, item.size.width * 0.88))
        let breathingScale = 1.35 + CGFloat(pulse) * 1.05
        let haloRect = CGRect(
            x: item.center.x - core * breathingScale / 2,
            y: item.center.y - core * breathingScale / 2,
            width: core * breathingScale,
            height: core * breathingScale
        )

        context.drawLayer { layer in
            layer.addFilter(.shadow(
                color: theme.accent.opacity((0.20 + pulse * 0.16) * reveal),
                radius: 4 + pulse * 3
            ))
            layer.stroke(
                Path(ellipseIn: haloRect),
                with: .color(theme.accent.opacity((1 - pulse) * 0.30 * reveal)),
                lineWidth: 1
            )
        }
    }

    private func color(
        for index: Int,
        presentation: ClockPresentationSnapshot,
        layout: ClockVisualLayout
    ) -> Color {
        let unit = presentation.units[index]
        if unit.isPlaceholder {
            return theme.futureDot(for: colorScheme).opacity(0.24)
        }
        if let marker = layout.marker(at: index) {
            return marker.color.color.opacity(marker.isPast ? 0.55 : 1)
        }
        if unit.progress >= 0.999 {
            return theme.completedDot(for: colorScheme)
        }
        if unit.progress > 0 {
            return theme.accent
        }
        return theme.futureDot(for: colorScheme)
    }

    private func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: Double) -> CGFloat {
        from + (to - from) * CGFloat(progress)
    }

    private func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }
}

private struct ClockVisualItem {
    let center: CGPoint
    let size: CGSize
}

private struct ClockVisualAnnotation: Identifiable {
    let id: String
    let text: String
    let point: CGPoint
    let size: CGFloat

    init(id: String, text: String, point: CGPoint, size: CGFloat = 9) {
        self.id = id
        self.text = text
        self.point = point
        self.size = size
    }
}

private struct ClockVisualLayout {
    let presentation: ClockPresentationSnapshot
    let size: CGSize
    let guideRects: [CGRect]
    let annotations: [ClockVisualAnnotation]
    let fineRects: [CGRect]

    private let items: [ClockVisualItem]

    var count: Int { items.count }

    var currentIndex: Int {
        if let partial = presentation.units.firstIndex(where: { !$0.isPlaceholder && $0.progress > 0 && $0.progress < 1 }) {
            return partial
        }
        return presentation.units.lastIndex(where: { !$0.isPlaceholder && $0.progress >= 1 }) ?? 0
    }

    init(presentation: ClockPresentationSnapshot, size: CGSize) {
        self.presentation = presentation
        self.size = size

        let layout: (
            items: [ClockVisualItem],
            guides: [CGRect],
            annotations: [ClockVisualAnnotation],
            fineRects: [CGRect]
        )
        switch presentation.scale {
        case .life:
            layout = Self.makeLifeItems(count: presentation.units.count, size: size)
        case .year:
            layout = Self.makeYearItems(count: presentation.units.count, size: size)
        case .month:
            layout = Self.makeMonthItems(size: size)
        case .week:
            layout = Self.makeWeekItems(size: size)
        case .day:
            layout = Self.makeDayItems(count: presentation.units.count, size: size)
        }
        items = layout.items
        guideRects = layout.guides
        annotations = layout.annotations
        fineRects = layout.fineRects
    }

    func item(at index: Int) -> ClockVisualItem {
        items[min(items.count - 1, max(0, index))]
    }

    func itemOrMappedAnchor(at index: Int, domainCount: Int) -> ClockVisualItem {
        guard index >= items.count else { return items[index] }
        guard items.count > 1, domainCount > 1 else {
            let anchor = item(at: currentIndex)
            return ClockVisualItem(center: anchor.center, size: CGSize(width: 1, height: 1))
        }
        let ratio = Double(index) / Double(domainCount - 1)
        let mappedIndex = Int((ratio * Double(items.count - 1)).rounded())
        let anchor = item(at: mappedIndex)
        return ClockVisualItem(center: anchor.center, size: CGSize(width: 1, height: 1))
    }

    func marker(at visualIndex: Int) -> EventMarkerSnapshot? {
        guard presentation.units.indices.contains(visualIndex) else { return nil }
        let ids = presentation.units[visualIndex].markerIDs
        return presentation.clock.markers.first { ids.contains($0.id) }
    }

    func markerPoint(for marker: EventMarkerSnapshot) -> CGPoint {
        let visualIndex = presentation.units.firstIndex { $0.markerIDs.contains(marker.id) } ?? currentIndex
        return item(at: visualIndex).center
    }

    private static func makeLifeItems(
        count: Int,
        size: CGSize
    ) -> (items: [ClockVisualItem], guides: [CGRect], annotations: [ClockVisualAnnotation], fineRects: [CGRect]) {
        let columns = 10
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let left: CGFloat = 28
        let right: CGFloat = 18
        let top: CGFloat = 24
        let bottom: CGFloat = 24
        let horizontalStep = (size.width - left - right) / CGFloat(columns - 1)
        let verticalStep = (size.height - top - bottom) / CGFloat(max(1, rows - 1))
        let diameter = min(8, max(4.5, min(horizontalStep, verticalStep) * 0.25))
        let items = gridItems(
            count: count,
            columns: columns,
            origin: CGPoint(x: left, y: top),
            horizontalStep: horizontalStep,
            verticalStep: verticalStep,
            itemSize: CGSize(width: diameter, height: diameter)
        )
        let annotations = stride(from: 0, to: count, by: 10).map { age in
            ClockVisualAnnotation(
                id: "life-\(age)",
                text: "\(age)",
                point: CGPoint(x: 10, y: items[age].center.y),
                size: 8
            )
        }
        return (items, [], annotations, [])
    }

    private static func makeYearItems(
        count: Int,
        size: CGSize
    ) -> (items: [ClockVisualItem], guides: [CGRect], annotations: [ClockVisualAnnotation], fineRects: [CGRect]) {
        let columns = 20
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let inset: CGFloat = 12
        let horizontalStep = (size.width - inset * 2) / CGFloat(columns - 1)
        let verticalStep = (size.height - 28) / CGFloat(max(1, rows - 1))
        let step = min(horizontalStep, verticalStep)
        let contentWidth = CGFloat(columns - 1) * step
        let contentHeight = CGFloat(rows - 1) * step
        let origin = CGPoint(
            x: size.width / 2 - contentWidth / 2,
            y: size.height / 2 - contentHeight / 2
        )
        let diameter = min(5.2, max(3.4, step * 0.30))
        return (
            gridItems(
                count: count,
                columns: columns,
                origin: origin,
                horizontalStep: step,
                verticalStep: step,
                itemSize: CGSize(width: diameter, height: diameter)
            ),
            [],
            [],
            []
        )
    }

    private static func makeMonthItems(
        size: CGSize
    ) -> (items: [ClockVisualItem], guides: [CGRect], annotations: [ClockVisualAnnotation], fineRects: [CGRect]) {
        let columns = 7
        let left: CGFloat = 30
        let right: CGFloat = 20
        let top: CGFloat = 42
        let bottom: CGFloat = 22
        let horizontalStep = (size.width - left - right) / CGFloat(columns - 1)
        let verticalStep = (size.height - top - bottom) / 5
        let itemSize = CGSize(width: 25, height: 25)
        let items = gridItems(
            count: 42,
            columns: columns,
            origin: CGPoint(x: left, y: top),
            horizontalStep: horizontalStep,
            verticalStep: verticalStep,
            itemSize: itemSize
        )
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        let annotations = weekdays.enumerated().map { index, text in
            ClockVisualAnnotation(
                id: "month-\(index)",
                text: text,
                point: CGPoint(x: left + CGFloat(index) * horizontalStep, y: 14)
            )
        }
        return (items, [], annotations, [])
    }

    private static func makeWeekItems(
        size: CGSize
    ) -> (items: [ClockVisualItem], guides: [CGRect], annotations: [ClockVisualAnnotation], fineRects: [CGRect]) {
        let columns = 7
        let rows = 4
        let left: CGFloat = 48
        let right: CGFloat = 18
        let top: CGFloat = 44
        let bottom: CGFloat = 20
        let horizontalStep = (size.width - left - right) / CGFloat(columns - 1)
        let verticalStep = (size.height - top - bottom) / CGFloat(rows - 1)
        let itemSize = CGSize(width: min(24, horizontalStep * 0.48), height: min(40, verticalStep * 0.66))
        let items = gridItems(
            count: columns * rows,
            columns: columns,
            origin: CGPoint(x: left, y: top),
            horizontalStep: horizontalStep,
            verticalStep: verticalStep,
            itemSize: itemSize,
            columnMajor: true,
            rows: rows
        )
        let guides = items.map {
            CGRect(
                x: $0.center.x - $0.size.width / 2,
                y: $0.center.y - $0.size.height / 2,
                width: $0.size.width,
                height: $0.size.height
            )
        }
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        var annotations = weekdays.enumerated().map { index, text in
            ClockVisualAnnotation(
                id: "week-day-\(index)",
                text: text,
                point: CGPoint(x: left + CGFloat(index) * horizontalStep, y: 14)
            )
        }
        let phases = ["凌晨", "上午", "下午", "夜间"]
        annotations.append(contentsOf: phases.enumerated().map { index, text in
            ClockVisualAnnotation(
                id: "week-phase-\(index)",
                text: text,
                point: CGPoint(x: 19, y: top + CGFloat(index) * verticalStep),
                size: 8
            )
        })
        return (items, guides, annotations, [])
    }

    private static func makeDayItems(
        count: Int,
        size: CGSize
    ) -> (items: [ClockVisualItem], guides: [CGRect], annotations: [ClockVisualAnnotation], fineRects: [CGRect]) {
        let left: CGFloat = 18
        let right: CGFloat = 18
        let usableWidth = size.width - left - right
        let step = usableWidth / CGFloat(max(1, count - 1))
        let width = min(10, max(5, step * 0.66))
        let items = (0..<count).map { index in
            ClockVisualItem(
                center: CGPoint(x: left + CGFloat(index) * step, y: 62),
                size: CGSize(width: width, height: 46)
            )
        }
        let guides = items.map {
            CGRect(
                x: $0.center.x - $0.size.width / 2,
                y: $0.center.y - $0.size.height / 2,
                width: $0.size.width,
                height: $0.size.height
            )
        }
        var annotations = stride(from: 0, to: count, by: 6).map { index in
            ClockVisualAnnotation(
                id: "day-hour-\(index)",
                text: String(format: "%02d", index),
                point: CGPoint(x: left + CGFloat(index) * step, y: 106),
                size: 8
            )
        }
        annotations.append(ClockVisualAnnotation(
            id: "day-minute-title",
            text: "当前小时 · 60分钟",
            point: CGPoint(x: size.width / 2, y: 142),
            size: 9
        ))

        let fineColumns = 15
        let fineRows = 4
        let fineLeft: CGFloat = 26
        let fineRight: CGFloat = 20
        let fineTop: CGFloat = 170
        let fineBottom: CGFloat = 18
        let fineHorizontalStep = (size.width - fineLeft - fineRight) / CGFloat(fineColumns - 1)
        let fineVerticalStep = (size.height - fineTop - fineBottom) / CGFloat(fineRows - 1)
        let fineRects = (0..<60).map { index in
            let row = index / fineColumns
            let column = index % fineColumns
            let center = CGPoint(
                x: fineLeft + CGFloat(column) * fineHorizontalStep,
                y: fineTop + CGFloat(row) * fineVerticalStep
            )
            return CGRect(x: center.x - 2, y: center.y - 6, width: 4, height: 12)
        }
        return (items, guides, annotations, fineRects)
    }

    private static func gridItems(
        count: Int,
        columns: Int,
        origin: CGPoint,
        horizontalStep: CGFloat,
        verticalStep: CGFloat,
        itemSize: CGSize,
        columnMajor: Bool = false,
        rows: Int = 0
    ) -> [ClockVisualItem] {
        (0..<count).map { index in
            let row: Int
            let column: Int
            if columnMajor {
                row = index % rows
                column = index / rows
            } else {
                row = index / columns
                column = index % columns
            }
            return ClockVisualItem(
                center: CGPoint(
                    x: origin.x + CGFloat(column) * horizontalStep,
                    y: origin.y + CGFloat(row) * verticalStep
                ),
                size: itemSize
            )
        }
    }
}
