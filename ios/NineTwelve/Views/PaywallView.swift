import SwiftUI
import UIKit
import StoreKit

/// 未訂閱時，命盤／運程／合盤三頁顯示的解鎖畫面。
struct PaywallView: View {
    /// 這一頁原本的標題，用於導覽列。
    let title: String

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var sub: Subscription

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    VStack(spacing: 10) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(Theme.accent)
                        Text(t("解鎖完整功能", "Unlock the full app",
                               "Desbloquea la app completa", "Sblocca l'app completa"))
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(t("命盤、運程與合盤需要會員。今日的日運永遠免費。",
                               "The chart, fortune and synastry pages need a membership. The daily reading stays free.",
                               "Las páginas de carta, destino y sinastría requieren membresía. La lectura diaria sigue siendo gratuita.",
                               "Le pagine carta, sorte e sinastria richiedono l'abbonamento. La lettura giornaliera resta gratuita."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 24)

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            perk(icon: "circle.grid.3x3.fill",
                                 text: t("本命十二宮盤與三柱", "Your natal twelve-palace chart and pillars",
                                         "Tu carta natal de doce palacios y sus pilares",
                                         "La tua carta natale a dodici palazzi e i pilastri"))
                            perk(icon: "chart.line.uptrend.xyaxis",
                                 text: t("大運、流年、月運", "Luck Pillars, annual and monthly luck",
                                         "Pilares de Suerte, suerte anual y mensual",
                                         "Pilastri della Sorte, sorte annuale e mensile"))
                            perk(icon: "person.2.fill",
                                 text: t("與任何人合盤", "Synastry with anyone",
                                         "Sinastría con cualquier persona",
                                         "Sinastria con chiunque"))
                            perk(icon: "text.magnifyingglass",
                                 text: t("每一列的完整推算與宮位含義",
                                         "Full workings and palace meanings for every row",
                                         "Cálculo completo y significados de cada fila",
                                         "Calcolo completo e significati per ogni riga"))
                        }
                    }

                    purchaseSection

                    Text(t("訂閱每月自動續訂，可隨時在「設定 → Apple 帳戶 → 訂閱」取消。付款於確認購買時由 Apple 向你的 Apple 帳戶收取。",
                           "The subscription renews monthly and can be cancelled any time in Settings → Apple Account → Subscriptions. Payment is charged to your Apple Account on confirmation.",
                           "La suscripción se renueva cada mes y puede cancelarse en cualquier momento en Ajustes → Cuenta de Apple → Suscripciones. El pago se cobra a tu cuenta de Apple al confirmar.",
                           "L'abbonamento si rinnova ogni mese e può essere annullato in qualsiasi momento in Impostazioni → Account Apple → Abbonamenti. Il pagamento viene addebitato sul tuo account Apple alla conferma."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .background(PageBackground())
            .navigationTitle(title)
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 10) {
            if sub.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let product = sub.product {
                Button {
                    Task { await sub.purchase() }
                } label: {
                    VStack(spacing: 2) {
                        Text(t("成為會員", "Become a member",
                               "Hazte miembro", "Diventa membro"))
                            .font(.headline)
                        Text(t("\(product.displayPrice) / 月", "\(product.displayPrice) / month",
                               "\(product.displayPrice) / mes", "\(product.displayPrice) / mese"))
                            .font(.subheadline)
                            .opacity(0.9)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.accent)
                    )
                    .foregroundStyle(Theme.onAccent)
                }
                .disabled(sub.isPurchasing)
                .opacity(sub.isPurchasing ? 0.6 : 1)
            } else {
                // 通常是還沒在 App Store Connect 建立商品，或裝置離線
                Text(t("目前無法取得訂閱資訊，請稍後再試。",
                       "Subscription information is unavailable right now. Please try again later.",
                       "La información de la suscripción no está disponible ahora. Inténtalo más tarde.",
                       "Le informazioni sull'abbonamento non sono disponibili ora. Riprova più tardi."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            }

            Button {
                Task { await sub.restore() }
            } label: {
                Text(t("回復購買", "Restore purchases",
                       "Restaurar compras", "Ripristina acquisti"))
                    .font(.subheadline)
            }
            .disabled(sub.isPurchasing)

            if let message = sub.errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func perk(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
