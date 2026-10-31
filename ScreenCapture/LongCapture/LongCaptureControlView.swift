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
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill((session.errorMessage == nil ? Color(red: 0.35, green: 0.27, blue: 0.91) : Color.red).opacity(0.14))
                        .frame(width: 22, height: 22)
                    Image(systemName: session.errorMessage == nil ? "arrow.down" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(session.errorMessage == nil ? Color(red: 0.35, green: 0.27, blue: 0.91) : Color.red)
                }
                Text(session.errorMessage ?? session.status)
                    .lineLimit(1)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(session.errorMessage == nil ? Color.primary.opacity(0.88) : Color.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: session.cancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help("取消长截图")

            Button(action: session.finish) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.37, green: 0.29, blue: 0.93),
                                        Color(red: 0.29, green: 0.21, blue: 0.84)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                    )
            }
            .buttonStyle(.plain)
            .disabled(session.frameCount == 0)
            .opacity(session.frameCount == 0 ? 0.38 : 1)
            .help("完成长截图")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: .black.opacity(0.20), radius: 11, y: 4)
        .padding(8)
    }
}
