import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ChatModel
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.green.opacity(0.5))
            ScrollViewReader { proxy in
                ScrollView { messagesList }
                    .onChange(of: model.messages.count) { _ in
                        if let last = model.messages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
            }
            inputBar
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
    }

    var header: some View {
        HStack {
            Text("ottotext")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.green)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    var messagesList: some View {
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

    var inputBar: some View {
        HStack(spacing: 8) {
            TextField("type a message…", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.addUser(text)
        Task { await model.convert(text: text) }
        input = ""
    }
}
