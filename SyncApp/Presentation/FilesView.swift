//
//  FilesView.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import SwiftUI

struct FilesView: View {
    private enum Prompt {
        case newFile
        case rename(FileItem)
        case addTag(FileItem)
        case editTag(Tag, FileItem)

        var title: String {
            switch self {
            case .newFile: return "New file"
            case .rename: return "Rename file"
            case .addTag: return "Add tag"
            case .editTag: return "Edit tag"
            }
        }
    }

    @State private var viewModel: FilesViewModel
    @State private var prompt: Prompt?
    @State private var input = ""

    init(viewModel: FilesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Files") {
                    ForEach(viewModel.files) { file in
                        row(for: file)
                    }
                }
#if DEBUG
                Section("Waiting to sync: \(viewModel.pendingCount)") {
                    ForEach(viewModel.operations.reversed()) { operation in
                        HStack {
                            Text(describe(operation.kind))
                            Spacer()
                            Text(operation.status.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
#endif
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu("Mock server") {
                        Button("Create file") { viewModel.simulateRemoteCreate() }
                        Button("Rename first file") { viewModel.simulateRemote(.rename) }
                        Button("Add tag to first file") { viewModel.simulateRemote(.addTag) }
                        Button("Delete first file") { viewModel.simulateRemote(.delete) }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Toggle(viewModel.isOnline ? "Online" : "Offline", isOn: $viewModel.isOnline)
                    Button("New file", systemImage: "plus") { open(.newFile, text: "") }
                }
            }
            .alert(prompt?.title ?? "", isPresented: isPromptPresented, presenting: prompt) { currentPrompt in
                TextField("Text", text: $input)
                Button("Save") { submit(currentPrompt) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: isErrorPresented) {
                Button("OK") { viewModel.dismissError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task { viewModel.start() }
    }

    private func row(for file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.name)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(file.tags) { tag in
                        Menu(tag.text) {
                            Button("Edit") { open(.editTag(tag, file), text: tag.text) }
                            Button("Remove", role: .destructive) { viewModel.removeTag(tag, from: file) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .swipeActions {
            Button("Delete", role: .destructive) { viewModel.delete(file) }
            Button("Rename") { open(.rename(file), text: file.name) }
            Button("Add tag") { open(.addTag(file), text: "") }
        }
    }

    private var isPromptPresented: Binding<Bool> {
        Binding(
            get: { prompt != nil },
            set: { isPresented in
                if !isPresented { prompt = nil }
            }
        )
    }

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.dismissError() }
            }
        )
    }

    private func open(_ newPrompt: Prompt, text: String) {
        input = text
        prompt = newPrompt
    }

    private func submit(_ currentPrompt: Prompt) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        switch currentPrompt {
        case .newFile:
            viewModel.createFile(named: text)
        case .rename(let file):
            viewModel.rename(file, to: text)
        case .addTag(let file):
            viewModel.addTag(to: file, text: text)
        case .editTag(let tag, let file):
            viewModel.editTag(tag, in: file, text: text)
        }
    }

    private func describe(_ kind: OperationKind) -> String {
        switch kind {
        case .create(let name, _): return "Create \(name)"
        case .rename(let name): return "Rename to \(name)"
        case .move: return "Move"
        case .delete: return "Delete"
        case .addTag(let tag): return "Add tag \(tag.text)"
        case .removeTag: return "Remove tag"
        case .editTag(_, let text): return "Edit tag to \(text)"
        }
    }
}
