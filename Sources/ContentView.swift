import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var model: ChatModel
    @State private var input: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
            .padding(.top, 1) // A minimal padding to push content from the absolute top edge
        }
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
                        .textSelection(.enabled)
                        .contextMenu {
                            Button(action: { UIPasteboard.general.string = m.text }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .onTapGesture {
                            // Quick tap-to-copy convenience
                            UIPasteboard.general.string = m.text
                        }
                }
                .id(m.id)
            }
            if model.isTyping {
                TypingIndicator()
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
        .padding(.bottom, 8) // Add some padding for devices without a bottom safe area
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.addUser(text)
        Task { await model.convert(text: text) }
        input = ""
    }
}

struct TypingIndicator: View {
    @State private var dotScales: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScales[i])
                    .foregroundColor(.green)
                    .animation(Animation.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: dotScales[i])
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .onAppear {
            dotScales = [1, 1, 1]
        }
    }
}
