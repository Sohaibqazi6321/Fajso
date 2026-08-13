import PhotosUI
import SwiftUI
import UIKit

struct PartnerPhotoView: View {
    @ObservedObject var supabaseService: TogetherSupabaseService
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isBusy = false

    var body: some View {
        ZStack {
            TogetherPalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    photoView
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    Text(photoCaption)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        takePicture()
                    } label: {
                        Label("Take a photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)

                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("Refresh partner photo", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    if !supabaseService.photoStatusText.isEmpty {
                        Text(supabaseService.photoStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(22)
            }
        }
        .navigationTitle("Partner Photo")
        .navigationBarTitleDisplayMode(.inline)
        .tint(TogetherPalette.accent)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let image else { return }
                Task { await upload(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                await upload(item)
                selectedItem = nil
            }
        }
        .task { await refresh() }
    }

    @ViewBuilder
    private var photoView: some View {
        if
            let data = CoupleWidgetCache.photoData(for: supabaseService.widgetState),
            let image = UIImage(data: data)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                TogetherPalette.lavender.opacity(0.7)
                VStack(spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 48))
                    Text("Waiting for a photo")
                        .font(.headline)
                }
                .foregroundStyle(TogetherPalette.accent)
            }
        }
    }

    private var photoCaption: String {
        guard let reference = supabaseService.widgetState.partnerPhoto else {
            return "A photo from your partner will stay here and in the widget, even while offline."
        }
        return TogetherDistanceFormatter.ageText(since: reference.updatedAt)
    }

    private func takePicture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            supabaseService.setPhotoStatus("Camera isn't available on this device.")
            return
        }
        showingCamera = true
    }

    private func upload(_ item: PhotosPickerItem) async {
        isBusy = true
        defer { isBusy = false }
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                supabaseService.setPhotoStatus("That photo couldn't be read.")
                return
            }
            _ = await supabaseService.uploadPartnerPhoto(image: image)
        } catch {
            supabaseService.setPhotoStatus("That photo couldn't be read. Try another one.")
        }
    }

    private func upload(_ image: UIImage) async {
        isBusy = true
        defer { isBusy = false }
        _ = await supabaseService.uploadPartnerPhoto(image: image)
    }

    private func refresh() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await supabaseService.refreshLatestPartnerPhoto()
    }
}
