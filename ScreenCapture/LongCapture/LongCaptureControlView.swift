import SwiftUI

struct LongCapturePreviewView: View {
    @ObservedObject var session: LongCaptureSession

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(session.previewSegments.enumerated()), id: \.offset) { index, image in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .id(index)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: session.frameCount) {
                guard !session.previewSegments.isEmpty else { return }
                proxy.scrollTo(session.previewSegments.count - 1, anchor: .bottom)
            }
        }
    }
}

struct LongCaptureActionBarView: View {
    @ObservedObject var session: LongCaptureSession

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: session.errorMessage == nil ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(session.errorMessage == nil ? Color.accentColor : Color.red)
                Text(session.errorMessage ?? session.status)
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(session.errorMessage == nil ? Color.primary : Color.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: session.cancel) {
                Image(systemName: "xmark")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .help("取消长截图")

            Divider()
                .frame(height: 24)

            Button(action: session.finish) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(session.frameCount == 0)
            .help("完成长截图")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 9, y: 3)
        .padding(8)
    }
}
