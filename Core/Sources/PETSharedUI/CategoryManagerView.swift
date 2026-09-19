import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color(hex: "#4D96FF")
    @State private var errorMessage: String?
    @State private var renamingCategory: ExpenseCategory?
    @State private var renameText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Categories") {
                    ForEach(categories) { category in
                        HStack {
                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { Color(hex: category.colorHex) },
                                    set: { recolor(category, to: $0) }
                                )
                            )
                            .labelsHidden()
                            .frame(width: 24)
                            Label(category.name, systemImage: category.symbolName)
                            Spacer()
                            if category.isSystemDefault {
                                Text("Built-in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Rename…") {
                                renamingCategory = category
                                renameText = category.name
                            }
                            if !category.isSystemDefault {
                                Button("Delete", role: .destructive) {
                                    delete(category)
                                }
                            }
                        }
                    }
                }
                Section("New Category") {
                    TextField("Name", text: $newCategoryName)
                    ColorPicker("Color", selection: $newCategoryColor)
                    Button("Add Category") { addCategory() }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Manage Categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Rename Category",
                isPresented: Binding(
                    get: { renamingCategory != nil },
                    set: { isPresented in if !isPresented { renamingCategory = nil } }
                )
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingCategory = nil }
                Button("Save") {
                    if let category = renamingCategory {
                        rename(category, to: renameText)
                    }
                    renamingCategory = nil
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    private func addCategory() {
        do {
            try CategoryRepository(context: modelContext).create(
                name: newCategoryName,
                colorHex: newCategoryColor.toHex(),
                symbolName: "tag.fill"
            )
            newCategoryName = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recolor(_ category: ExpenseCategory, to color: Color) {
        try? CategoryRepository(context: modelContext).recolor(category, colorHex: color.toHex())
    }

    private func rename(_ category: ExpenseCategory, to newName: String) {
        do {
            try CategoryRepository(context: modelContext).rename(category, to: newName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ category: ExpenseCategory) {
        do {
            try CategoryRepository(context: modelContext).delete(category, reassigningTransactionsTo: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
