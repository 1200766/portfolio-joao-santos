import SwiftUI
import UIKit

struct InstallationValidityView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var service = InstallationReminderService.shared

    var body: some View {
        List {
            validitySection
            reminderSection
            renewalSection
            limitationsSection
        }
        .navigationTitle("Validade da instalação")
        .navigationBarTitleDisplayMode(.inline)
        .task { await service.refresh() }
    }

    private var validitySection: some View {
        Section {
            if let expirationDate = service.expirationDate {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Validade indicada pelo perfil")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(expirationDate, format: dateFormat)
                        .font(.headline)
                    if expirationDate <= .now {
                        Label("A data indicada já passou", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Label("Data indisponível", systemImage: "questionmark.circle")
                    .font(.headline)
                Text("Não foi possível determinar a data nesta instalação. Isto não significa que a assinatura seja permanente. É normal no simulador.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !service.status.isEmpty {
                Text(service.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await service.refresh() }
            } label: {
                HStack {
                    Label("Atualizar estado", systemImage: "arrow.clockwise")
                    if service.isRefreshing {
                        Spacer()
                        ProgressView().accessibilityLabel("A atualizar o estado")
                    }
                }
            }
            .disabled(service.isRefreshing)
        } header: {
            Text("Instalação atual")
        } footer: {
            Text("A data indicada pelo perfil é informativa; a Apple pode revogar a assinatura antes.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Avisar antes da data indicada", isOn: Binding(
                get: { service.enabled },
                set: { enabled in
                    Task { await service.configure(enabled: enabled, leadHours: service.leadHours) }
                }
            ))
            .disabled(service.isRefreshing)

            Picker("Antecedência", selection: Binding(
                get: { service.leadHours },
                set: { hours in
                    Task { await service.configure(enabled: service.enabled, leadHours: hours) }
                }
            )) {
                Text("6 horas antes").tag(6)
                Text("12 horas antes").tag(12)
                Text("24 horas antes").tag(24)
                Text("48 horas antes").tag(48)
            }
            .disabled(service.isRefreshing)

            if let reminderDate = service.reminderDate {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Próximo aviso agendado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(reminderDate, format: dateFormat)
                        .font(.body.weight(.medium))
                }
                .accessibilityElement(children: .combine)
            }

            if service.permissionDenied {
                Text("As notificações estão desativadas para esta aplicação. Podes autorizá-las nas Definições do iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Abrir definições de notificações", systemImage: "gearshape") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .disabled(service.isRefreshing)
            } else if service.permissionNotDetermined {
                Button("Permitir notificações", systemImage: "bell.badge") {
                    Task { await service.refresh(requestAuthorization: true) }
                }
                .disabled(service.isRefreshing || !service.enabled || service.expirationDate == nil)
            }

            if let error = service.lastError, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Lembrete")
        } footer: {
            Text("Depois de agendado, o aviso não precisa de uma tarefa da app em segundo plano. As permissões, os modos de Concentração e outras definições do iPhone podem silenciá-lo ou atrasá-lo.")
        }
    }

    private var renewalSection: some View {
        Section("Como atualizar a instalação") {
            instruction(
                "1. Atualiza pelo Xcode",
                detail: "Liga o iPhone ao Mac e abre o mesmo projeto. Mantém a mesma equipa e o mesmo identificador da aplicação, seleciona o iPhone e carrega em Run."
            )
            instruction(
                "2. Não desinstales a aplicação",
                detail: "Atualiza por cima da instalação existente para preservar os dados. Apagar a aplicação pode apagar também os seus dados locais."
            )
            instruction(
                "3. Confirma a nova data",
                detail: "Abre a app depois de cada atualização pelo Xcode para atualizar o lembrete. Confirma aqui se a data indicada mudou: o Run pode reutilizar o mesmo perfil."
            )
        }
    }

    private var limitationsSection: some View {
        Section("Sobre este aviso") {
            Text("A app tenta ler a data do perfil de assinatura incluído nesta instalação. Sem uma data disponível, não é possível agendar este lembrete.")
            Text("Este lembrete apenas avisa. Não renova nem prolonga a assinatura, e não garante que a app continue a abrir até à data indicada.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var dateFormat: Date.FormatStyle {
        .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "pt_PT"))
    }

    private func instruction(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
