import SwiftUI

struct AppInformationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "版本 \(version)（\(build)）"
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    KeduSheetHeader(title: "关于刻度", subtitle: Self.version, closeIdentifier: "about.close") { dismiss() }
                    section("时间的依据", identifier: "about.calculation") {
                        Text("生之始从生日当天的午夜累计。死之终从此刻计算到你设定的预计寿命对应的生日，并非死亡预测。")
                        Text("织面已织入的部分表示过去，未织入的经线表示尚余。铜色织口按真实区间进度推进；织口上的点只放大当前一分钟，每分钟在两端换向，连续流动，不代表人生进度加速。")
                        Text("此刻的百分比表示这一设定区间中已度过的比例。达到设定终点后，尚余归零，已度过继续累计。")
                        Text("生日使用公历。人生采用你保存生日时的时区作为固定计算依据，旅行或系统时区变化不会改变人生累计。闰日生日在非闰年按二月二十八日计算。")
                        Text("日、月、年的起止跟随所在时区的日历；小数天数统一按 86400 秒换算，夏令时切换日可能并非整整一天。")
                    }
                    section("刻点", identifier: "about.events") {
                        Text("一次性刻点保存在刻点集中。每年、每月、每天的刻点分别出现在年、月、日时间场中，轻点标记即可编辑。刻点用于记录，不发送通知。")
                        Text("每月的日期超过当月天数时，按当月最后一天显示；每年二月二十九日的刻点在非闰年按二月二十八日显示。周期刻点保留你设定的本地日期和时间。")
                    }
                    section("隐私与本地数据", identifier: "about.privacy") {
                        Text("刻度无需账号，没有广告、追踪或分析服务。App 不主动联网，不收集或上传生日、预计寿命、偏好及刻点，也不申请通讯录、系统日历、照片、位置、健康、麦克风、相机或通知权限。")
                        Text("这些数据保存在设备的应用存储中。系统设备备份由你的系统设置控制；删除 App 可能删除本地数据。你可以在设置中导出备份，并自行选择保存位置。")
                        Text("备份文件包含生日与全部刻点，未加密。只有在你主动导出时才交给系统文件服务；若选择 iCloud 等文件位置，该服务按其自身设置存储文件。恢复备份前会显示摘要，由你确认是否替换。")
                    }
                }
                .padding(20)
            }
        }
    }

    private func section<Content: View>(_ title: String, identifier: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content().font(.subheadline).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(identifier)
    }
}
