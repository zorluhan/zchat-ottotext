import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ChatModel
    @State private var input: String = ""

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.messages) { m in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("[\(m.timeString)] * \(m.role) *")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text(m.text)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .id(m.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: model.messages.count) { _ in
                    if let last = model.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .background(Color.black)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("ottotext")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.green)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack(spacing: 8) {
                        TextField("type a message…", text: $input)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(send)
                        Button(action: send) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                        }
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.addUser(text)
        Task { await model.convert(text: text) }
        input = ""
    }
}
