import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Aplicação") {
                    NavigationLink {
                        InstallationValidityView()
                    } label: {
                        Label("Validade da instalação", systemImage: "clock.badge.exclamationmark")
                    }
                }

                Section("Organização") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Categorias", systemImage: "tag")
                    }

                    NavigationLink {
                        CategorizationRulesView()
                    } label: {
                        Label("Regras de categorização", systemImage: "wand.and.stars")
                    }
                }

                Section("Privacidade") {
                    LabeledContent("Armazenamento", value: "Apenas neste iPhone")
                    Text("Esta versão não cria conta, não liga a bancos e não envia dados para servidores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Primeira versão") {
                    Text("Face ID e sincronização ficam reservados para uma versão futura.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Definições")
        }
    }
}
