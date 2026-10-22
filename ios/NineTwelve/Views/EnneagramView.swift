import SwiftUI
import UIKit

extension Theme {
    /// 九型人格每一型的代表色。
    static func color(enneagram type: Int) -> Color {
        let c = Enneagram.rgb(type)
        return Color(red: c.red, green: c.green, blue: c.blue)
    }
}

/// 命盤上的九型人格入口：靈數幾就是第幾型。點開看完整內容。
struct EnneagramCard: View {
    let lifeNumber: Int
    let lang: Lang

    @State private var showing = false

    private var t: T { T(lang) }
    private var type: Int { Enneagram.type(forLifeNumber: lifeNumber) }

    var body: some View {
        Button {
            showing = true
        } label: {
            // 圓圈靠右，上下對整張卡置中
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("九型人格", "Enneagram", "Eneagrama", "Enneagramma"))
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(Enneagram.label(type, lang: lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Enneagram.name(type, lang: lang))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Enneagram.tagline(type, lang: lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                TypeBadge(type: type, size: 54)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(CardBackground())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            NavigationStack {
                EnneagramDetailView(type: type, lang: lang)
            }
        }
    }
}

/// 圓形的型號標記，填該型的代表色。
struct TypeBadge: View {
    let type: Int
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle().fill(Theme.color(enneagram: type))
            Text("\(Num.r9(type))")
                .font(.system(size: size * 0.44, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// 某一型的完整內容。
struct EnneagramDetailView: View {
    let type: Int
    let lang: Lang

    @Environment(\.dismiss) private var dismiss

    private var t: T { T(lang) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 頂部：整片色塊，型號與型名
                VStack(alignment: .leading, spacing: 10) {
                    Text(Enneagram.label(type, lang: lang))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(Enneagram.name(type, lang: lang))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Enneagram.tagline(type, lang: lang))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.color(enneagram: type))
                )

                Card {
                    Text(Enneagram.summary(type, lang: lang))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(0..<Enneagram.sectionCount, id: \.self) { i in
                    Card(title: Enneagram.sectionTitle(i, lang: lang)) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(Enneagram.section(type, i, lang: lang).enumerated()),
                                    id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Theme.color(enneagram: type))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    Text(line)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle(t("九型人格", "Enneagram", "Eneagrama", "Enneagramma"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(t("完成", "Done", "Listo", "Fatto")) { dismiss() }
            }
        }
    }
}
