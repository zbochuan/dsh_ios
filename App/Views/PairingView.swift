import SwiftUI
import DSHCore

/// "连接电脑": scan the code shown by the computer, or fall back to signing in manually.
struct PairingView: View {
    @Environment(AppStore.self) private var store
    @Environment(ConnectionStore.self) private var connection
    @State private var showingManual = false
    @State private var copied = false
    private let command = "dsh pair"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // TODO: Replace the placeholder with live QR scanning (AVCaptureSession + camera usage description).
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.06))
                    ViewfinderCorners()
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .padding(28)
                    VStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 40, weight: .light))
                        Text("扫码连接即将支持").font(.footnote)
                    }
                    .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(width: 240, height: 240)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("二维码取景框，扫码连接即将支持")

                VStack(spacing: 10) {
                    Text("扫描电脑上显示的二维码")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("代码、文件和模型密钥都留在电脑上。手机只用来查看进度、发指令和确认操作。")
                        .font(.subheadline).foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("在电脑终端运行").font(.footnote).foregroundStyle(Color.white.opacity(0.7))
                    // TODO: ds-harness-remote must provide `dsh pair` to print a pairing code.
                    Button {
                        copyText(command)
                        copied = true
                    } label: {
                        HStack {
                            Text("$ \(command)").font(.body.monospaced()).foregroundStyle(.white)
                            Spacer()
                            Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .labelStyle(.iconOnly).foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(.horizontal, 16).frame(minHeight: 50)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressStyle(scalesOnPress: false))
                    .accessibilityLabel(copied ? "已复制 \(command)" : "复制命令 \(command)")
                    .accessibilityIdentifier("pairing.copy")
                }

                VStack(spacing: 4) {
                    Button("手动输入服务地址和账号") { showingManual = true }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("pairing.manual")
                    Button("先看一个示例任务") { store.enterDemo(showing: DemoContent.exampleTitle) }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("pairing.example")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 24).padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .background(DSHTheme.terminal.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("连接电脑")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { store.presentedPanel = nil }
                    .accessibilityIdentifier("pairing.cancel")
            }
        }
        .sheet(isPresented: $showingManual) { ConnectionView() }
        .onChange(of: connection.isSignedIn) { _, signedIn in
            if signedIn { store.presentedPanel = .computers }
        }
    }
}

private struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 28
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}
