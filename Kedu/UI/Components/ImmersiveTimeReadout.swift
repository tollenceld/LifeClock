import SwiftUI

/// Stable facts; precision flows quietly below the weight of the whole days.
struct ImmersiveTimeReadout: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var precisionSize: CGFloat = 15
    let title: String
    let value: Double
    let unit: String
    let ink: Color
    let identifier: String
    var alignment: HorizontalAlignment = .leading
    var detail: String? = nil
    var showsTitle = true
    var stacksPrecision = false
    var digitScale: CGFloat = 1
    var precisionScale: CGFloat = 1

    var body: some View {
        let formatted = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), max(0, value))
        let parts = formatted.split(separator: ".", omittingEmptySubsequences: false)
        VStack(alignment: alignment, spacing: 10) {
            if showsTitle { ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    titleText
                    detailText
                }.fixedSize()
                VStack(alignment: alignment, spacing: 6) {
                    titleText
                    detailText
                }
            }
            .contentTransition(.opacity)
            }
            if stacksPrecision {
                stackedNumber(parts)
            } else { ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    integer(parts)
                    decimal(parts)
                    Text(unit).font(.caption).padding(.leading, 8)
                }.fixedSize()
                stackedNumber(parts)
            } }
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : (alignment == .center ? .center : .leading))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + (detail.map { "，" + $0 } ?? "") + "，" + unit)
        .accessibilityValue(formatted)
        .accessibilityIdentifier(identifier)
        .transaction { $0.animation = nil }
    }

    private var titleText: some View {
        Text(title).font(.subheadline).tracking(2)
    }

    @ViewBuilder private var detailText: some View {
        if let detail {
            Text(detail).font(.caption).foregroundStyle(ink)
        }
    }

    private func integer(_ parts: [Substring]) -> some View {
        Text(String(parts.first ?? "0"))
            .font(.system(size: digitSize * digitScale, weight: .light)).monospacedDigit()
    }

    private func decimal(_ parts: [Substring]) -> some View {
        Text("." + String(parts.last ?? "00000000"))
            .font(.system(size: precisionSize * precisionScale, weight: .regular)).monospacedDigit()
    }

    private func stackedNumber(_ parts: [Substring]) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            integer(parts)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                decimal(parts)
                Text(unit).font(.caption)
            }
        }.fixedSize()
    }
}

struct LifeEquivalentReadout: View {
    let years: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                yearsText
                Text("·").accessibilityHidden(true)
                monthsText
            }.fixedSize()
            VStack(alignment: .leading, spacing: 8) {
                yearsText
                monthsText
            }
        }
        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("时间换算")
        .accessibilityValue("\(years.formatted(.number.precision(.fractionLength(4)))) 年，\((years * 12).formatted(.number.precision(.fractionLength(2)))) 个月")
        .accessibilityIdentifier("life.equivalent")
    }

    private var yearsText: some View {
        Text("≈ \(years.formatted(.number.precision(.fractionLength(4)))) 年")
    }

    private var monthsText: some View {
        Text("\((years * 12).formatted(.number.precision(.fractionLength(2)))) 个月")
    }
}
