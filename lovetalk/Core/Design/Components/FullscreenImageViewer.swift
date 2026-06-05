import SwiftUI

struct FullscreenImageViewer: View {
    let imageURLs: [String]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0
    @GestureState private var magnification: CGFloat = 1.0
    @State private var steadyZoom: CGFloat = 1.0

    private var currentZoom: CGFloat {
        steadyZoom * magnification
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                    ZoomableImagePage(urlString: urlString)
                        .tag(index)
                        .offset(y: dragOffset.height)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close button
            VStack {
                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    Spacer()

                    // Page indicator text
                    if imageURLs.count > 1 {
                        Text("\(selectedIndex + 1) / \(imageURLs.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let vertical = value.translation.height
                    // Only handle clearly vertical drags
                    if abs(vertical) > abs(value.translation.width) * 1.5 {
                        dragOffset = CGSize(width: 0, height: vertical)
                        backgroundOpacity = max(0.3, 1.0 - Double(abs(vertical)) / 400.0)
                    }
                }
                .onEnded { value in
                    if abs(value.translation.height) > 120 && abs(value.translation.height) > abs(value.translation.width) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = .zero
                            backgroundOpacity = 1.0
                        }
                    }
                }
        )
        .statusBarHidden(true)
    }
}

// MARK: - Zoomable Image Page

private struct ZoomableImagePage: View {
    let urlString: String

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                let newScale = lastScale * value.magnification
                                scale = min(max(newScale, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                if scale < 1.0 {
                                    withAnimation { scale = 1.0 }
                                }
                                lastScale = scale
                                if scale == 1.0 {
                                    withAnimation {
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        scale > 1.0 ?
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            if scale > 1.0 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { loadImage() }
            }
        }
    }

    private func loadImage() {
        guard let url = URL(string: urlString) else { return }

        if let cached = ImageCache.shared.get(url) {
            image = cached
            return
        }

        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let uiImage = UIImage(data: data) else { return }
            ImageCache.shared.set(uiImage, data: data, for: url)
            await MainActor.run { image = uiImage }
        }
    }
}
