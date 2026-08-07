import SwiftUI
import VisionKit
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
struct QuoteCameraScannerView: View {
    let onCancel: () -> Void
    let onSave: (String) -> Void
    let onError: (String) -> Void

    @State private var capturedImage: UIImage?
    @State private var quoteText = ""
    @State private var isShowingCamera = false
    @State private var isShowingEntry = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MotiveTheme.primaryText)
                
                Group {
                    if isShowingEntry {
                        quoteEntryView
                    } else if let capturedImage {
                        imagePreviewView(capturedImage)
                    } else {
                        cameraStartView
                    }
                }
                .motiveScreen()
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            QuoteCameraPicker(
                isPresented: $isShowingCamera,
                image: $capturedImage,
                onCancel: {
                    isShowingCamera = false
                    if capturedImage == nil {
                        onCancel()
                    }
                }
            )
            .ignoresSafeArea()
        }
    }

    private var cameraStartView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            
            VStack(spacing: 6) {
                Text("Add a quote from a photo")
                    .font(.system(size: 26, weight: .bold))
                
                Text("Take a picture and highlight the quote you'd like to save, or enter it manually.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MotiveTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()

            VStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    MotivePrimaryButton(title: "Take photo", systemImage: "camera") {
                        isShowingCamera = true
                    }
                }

                MotiveSecondaryButton(title: "Enter manually", systemImage: "keyboard") {
                    isShowingEntry = true
                }
            }
        }
        .padding(MotiveTheme.pagePadding)
    }

    private func imagePreviewView(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Copy quote text")
                .font(.system(size: 26, weight: .bold))

            LiveTextQuoteImageView(image: image)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius + 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MotiveTheme.radius + 8, style: .continuous)
                        .stroke(MotiveTheme.border, lineWidth: 1)
                )

            HStack(spacing: 10) {
                MotiveSecondaryButton(title: "Retake", systemImage: "camera") {
                    capturedImage = nil
                    quoteText = ""
                    isShowingCamera = true
                }

                MotivePrimaryButton(title: "Next", systemImage: "arrow.right", placesIconTrailing: true) {
                    isShowingEntry = true
                }
            }
        }
        .padding(MotiveTheme.pagePadding)
    }

    private var quoteEntryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Paste quote")
                .font(.system(size: 26, weight: .bold))

            TextEditor(text: $quoteText)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(MotiveTheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 220)
                .background(MotiveTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous)
                        .stroke(MotiveTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MotiveTheme.radius, style: .continuous))

            HStack(spacing: 10) {
                MotiveSecondaryButton(title: "Paste", systemImage: "doc.on.clipboard") {
                    quoteText = UIPasteboard.general.string?.trimmed ?? quoteText
                }

                MotivePrimaryButton(
                    title: "Save",
                    systemImage: "bookmark.fill",
                    isDisabled: quoteText.trimmed.isEmpty
                ) {
                    saveQuote()
                }
            }

            Spacer()
        }
        .padding(MotiveTheme.pagePadding)
    }

    private func saveQuote() {
        let cleanQuote = quoteText.trimmed
        guard !cleanQuote.isEmpty else {
            onError("Paste or type a quote before saving.")
            return
        }
        onSave(cleanQuote)
    }
}

private struct QuoteCameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var image: UIImage?
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, image: $image, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var isPresented: Bool
        @Binding private var image: UIImage?
        private let onCancel: () -> Void

        init(isPresented: Binding<Bool>, image: Binding<UIImage?>, onCancel: @escaping () -> Void) {
            _isPresented = isPresented
            _image = image
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image = info[.originalImage] as? UIImage
            isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isPresented = false
            onCancel()
        }
    }
}

private struct LiveTextQuoteImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(MotiveTheme.surface)
        container.clipsToBounds = true

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        context.coordinator.imageView = imageView
        configureLiveTextIfAvailable(for: imageView, context: context)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.imageView?.image = image
        analyzeImageIfAvailable(image, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func configureLiveTextIfAvailable(for imageView: UIImageView, context: Context) {
        guard #available(iOS 16.0, *) else { return }
        let liveText = LiveTextAnalyzerBox()
        guard ImageAnalyzer.isSupported else { return }
        liveText.interaction.preferredInteractionTypes = .textSelection
        imageView.addInteraction(liveText.interaction)
        context.coordinator.liveText = liveText
    }

    private func analyzeImageIfAvailable(_ image: UIImage, context: Context) {
        guard #available(iOS 16.0, *),
              let liveText = context.coordinator.liveText as? LiveTextAnalyzerBox else {
            return
        }

        let imageIdentifier = ObjectIdentifier(image)
        guard liveText.imageIdentifier != imageIdentifier else { return }
        liveText.imageIdentifier = imageIdentifier

        Task { @MainActor in
            let configuration = ImageAnalyzer.Configuration([.text])
            liveText.interaction.analysis = try? await liveText.analyzer.analyze(image, configuration: configuration)
        }
    }

    final class Coordinator {
        weak var imageView: UIImageView?
        var liveText: AnyObject?
    }
}

@available(iOS 16.0, *)
private final class LiveTextAnalyzerBox {
    let analyzer = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    var imageIdentifier: ObjectIdentifier?
}
#endif
