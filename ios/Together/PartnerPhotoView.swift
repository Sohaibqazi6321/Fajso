import Photos
import PhotosUI
import SwiftUI
import UIKit
import WidgetKit

struct PartnerPhotoView: View {
    @ObservedObject var supabaseService: TogetherSupabaseService
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var isBusy = false
    @State private var snapshot = TogetherDemo.partnerPhoto()

    private let refreshTimer = Timer.publish(every: 75, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Partner Photo")
                    .font(.largeTitle.bold())

                photoView
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(snapshot.statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button {
                        takePicture()
                    } label: {
                        Label("Take Picture", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)

                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        Label("Upload Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)

                    Button {
                        Task {
                            await refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                }

                Text(supabaseService.photoStatusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .navigationTitle("Partner Photo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let image else {
                    return
                }

                Task {
                    await upload(image)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else {
                return
            }

            Task {
                await upload(item)
                selectedItem = nil
            }
        }
        .task {
            await refresh()
        }
        .onReceive(refreshTimer) { _ in
            guard !isBusy else {
                return
            }

            Task {
                await refresh()
            }
        }
    }

    @ViewBuilder
    private var photoView: some View {
        if let image = snapshot.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            fallbackImage
                .resizable()
                .scaledToFill()
        }
    }

    private var fallbackImage: Image {
        guard
            let data = Data(base64Encoded: TogetherDemo.testPhotoBase64),
            let image = UIImage(data: data)
        else {
            return Image(systemName: "person.crop.square.fill")
        }

        return Image(uiImage: image)
    }

    private func takePicture() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            supabaseService.setPhotoStatus("Camera is not available on this device.")
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
                supabaseService.setPhotoStatus("Could not read that photo.")
                return
            }

            await upload(image)
        } catch {
            supabaseService.setPhotoStatus("Photo upload failed: \(error.localizedDescription)")
        }
    }

    private func upload(_ image: UIImage) async {
        isBusy = true
        defer { isBusy = false }

        if await supabaseService.uploadPartnerPhoto(image: image) != nil {
            await refresh()
        }
    }

    private func refresh() async {
        isBusy = true
        defer { isBusy = false }

        if let latest = await supabaseService.refreshLatestPartnerPhoto() {
            snapshot = latest
        } else {
            snapshot = TogetherDemo.partnerPhoto()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "TogetherPartnerPhotoWidget")
    }
}

private extension TogetherPartnerPhotoSnapshot {
    var image: UIImage? {
        data.flatMap(UIImage.init(data:))
    }
}
