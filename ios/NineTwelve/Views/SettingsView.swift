import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var sub: Subscription
    @State private var editing = false

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            List {
                Section(t("本命資料", "Your birth details",
    "Tus datos de nacimiento",
    "I tuoi dati di nascita")) {
                    if let owner = state.owner {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(owner.displayName(state.lang)).font(.headline)
                                Text(t.date(owner.birth))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(t.triple(owner.birth.triple))
                                .font(.system(.subheadline, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Button(t("修改出生資料", "Edit birth details",
    "Editar datos de nacimiento",
    "Modifica i dati di nascita")) { editing = true }
                    }
                }

                Section {
                    HStack {
                        Image(systemName: sub.isActive ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(sub.isActive ? Color.green : Theme.accent)
                        Text(Subscription.isUnlocked
                             ? t("完整版", "Full version", "Versión completa", "Versione completa")
                             : sub.isActive
                             ? t("會員使用中", "Membership active", "Membresía activa", "Abbonamento attivo")
                             : t("尚未成為會員", "Not a member yet", "Aún no eres miembro", "Non sei ancora membro"))
                            .font(.subheadline)
                        Spacer()
                    }
                    if Subscription.isUnlocked {
                        EmptyView()
                    } else if sub.isActive {
                        Link(t("管理訂閱", "Manage subscription",
                               "Gestionar suscripción", "Gestisci abbonamento"),
                             destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    } else {
                        Button(t("回復購買", "Restore purchases",
                                 "Restaurar compras", "Ripristina acquisti")) {
                            Task { await sub.restore() }
                        }
                    }
                } header: {
                    Text(t("會員", "Membership", "Membresía", "Abbonamento"))
                } footer: {
                    Text(Subscription.isUnlocked
                         ? t("這個版本沒有付費機制，全部功能都開放。",
                             "This build has no payment features; everything is unlocked.",
                             "Esta versión no tiene pagos; todo está desbloqueado.",
                             "Questa versione non ha pagamenti; tutto è sbloccato.")
                         : sub.isActive
                         ? t("命盤、運程與合盤已解鎖。", "The chart, fortune and synastry pages are unlocked.",
                             "Las páginas de carta, destino y sinastría están desbloqueadas.",
                             "Le pagine carta, sorte e sinastria sono sbloccate.")
                         : t("命盤、運程與合盤需要會員；今日的日運永遠免費。",
                             "The chart, fortune and synastry pages need a membership; the daily reading stays free.",
                             "Las páginas de carta, destino y sinastría requieren membresía; la lectura diaria es siempre gratuita.",
                             "Le pagine carta, sorte e sinastria richiedono l'abbonamento; la lettura giornaliera è sempre gratuita."))
                }

                Section {
                    Picker(t("語言", "Language",
    "Idioma",
    "Lingua"), selection: $state.lang) {
                        ForEach(Lang.available, id: \.self) {
                            Text($0.title).tag($0)
                        }
                    }
                } header: {
                    Text(t("語言", "Language",
    "Idioma",
    "Lingua"))
                }

                Section {
                    NavigationLink(t("十二宮含義", "Meanings of the twelve palaces",
    "Significados de los doce palacios",
    "Significati dei dodici palazzi")) {
                        MeaningsView()
                    }
                } header: {
                    Text(t("說明", "Reference",
    "Referencia",
    "Riferimento"))
                }

                Section {
                    Picker(t("流年錨定", "Annual anchor",
    "Anclaje anual",
    "Ancoraggio annuale"), selection: $state.yearAnchor) {
                        ForEach(YearAnchor.allCases, id: \.self) {
                            Text($0.title(state.lang)).tag($0)
                        }
                    }
                } header: {
                    Text(t("流年", "Annual luck",
    "Suerte anual",
    "Sorte annuale"))
                } footer: {
                    Text(state.yearAnchor.detail(state.lang))
                }

                Section {
                } footer: {
                    Text(t("所有資料只存在本機，不會上傳任何伺服器。", "Everything is stored on this device only and is never sent to a server.",
    "Todo se guarda solo en este dispositivo y nunca se envía a ningún servidor.",
    "Tutto è salvato solo su questo dispositivo e non viene mai inviato a un server."))
                }
            }
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle(t("設定", "Settings",
    "Ajustes",
    "Impostazioni"))
            .sheet(isPresented: $editing) { EditProfileSheet() }
        }
    }
}

private struct EditProfileSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var year = 2000
    @State private var month = 1
    @State private var day = 1
    @State private var loaded = false

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            ScrollView {
                Card {
                    BirthInputView(name: $name, year: $year, month: $month,
                                   day: $day, lang: state.lang)
                }
                .padding(16)
            }
            .background(PageBackground())
            .navigationTitle(t("修改出生資料", "Edit birth details",
    "Editar datos de nacimiento",
    "Modifica i dati di nascita"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("取消", "Cancel",
    "Cancelar",
    "Annulla")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("儲存", "Save",
    "Guardar",
    "Salva")) {
                        var p = state.owner ?? Profile(
                            name: name,
                            birth: BirthDate(year: year, month: month, day: day))
                        p.name = name
                        p.birth = BirthDate(year: year, month: month, day: day)
                        state.owner = p
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !loaded, let o = state.owner else { return }
                name = o.name
                year = o.birth.year
                month = o.birth.month
                day = o.birth.day
                loaded = true
            }
        }
    }
}

/// 十二宮含義瀏覽，可用關鍵字搜尋（中英文都會一起比對）。
struct MeaningsView: View {
    @EnvironmentObject private var state: AppState
    @State private var query = ""

    private var t: T { state.t }

    /// 命中的宮位，以及該宮命中的關鍵字。
    private var matches: [(palace: Int, hits: [String])] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (1...12).compactMap { (p: Int) -> (palace: Int, hits: [String])? in
            guard !q.isEmpty else { return (p, []) }
            // 兩種語言都比對，這樣用中文也能找到英文條目，反之亦然
            let all = Palace.keywords(p, lang: .zh) + Palace.keywords(p, lang: .en)
                + [Palace.shortName(p, lang: .zh), Palace.shortName(p, lang: .en)]
            let hits = all.filter { $0.lowercased().contains(q) }
            return hits.isEmpty ? nil : (p, hits)
        }
    }

    var body: some View {
        List {
            if matches.isEmpty {
                Text(t("找不到「\(query)」", "No match for “\(query)”",
    "Sin resultados para «\(query)»",
    "Nessun risultato per «\(query)»"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(matches, id: \.palace) { m in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        PalaceChip(palace: m.palace, lang: state.lang)
                        Text(t.palaceNamed(m.palace))
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Text(t.element(Element.of(palace: m.palace)))
                            .font(.caption.bold())
                            .foregroundStyle(Theme.color(for: Element.of(palace: m.palace)))
                    }
                    if !m.hits.isEmpty {
                        Text(m.hits.joined(separator: state.lang == .zh ? "、" : ", "))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(Palace.text(m.palace, lang: state.lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PageBackground())
        .searchable(text: $query,
                    prompt: t("搜尋含義，例如：婚姻、正財", "Search meanings, e.g. marriage, wealth",
    "Buscar significados, p. ej. matrimonio, riqueza",
    "Cerca significati, es. matrimonio, ricchezza"))
        .navigationTitle(t("十二宮含義", "Palace meanings",
    "Significados de los palacios",
    "Significati dei palazzi"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
