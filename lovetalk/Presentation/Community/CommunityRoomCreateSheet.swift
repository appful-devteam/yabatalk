import SwiftUI
import PhotosUI

// MARK: - Palette

private enum CreateSheetPalette {
    static let headerBg = MeloColors.Surface.pinkPale
    static let headerBorder = MeloColors.Surface.pinkPale
    static let koiPink = MeloColors.Brand.pink
    static let fieldBorder = MeloColors.Text.primary
    static let fieldBg = Color.white
    // 旧 716463 茶 → 黒系 1E1E1E (テキスト用)
    static let textMain = MeloColors.Text.primary
    // 薄茶 DACDC4 → 薄灰 B6B6B6
    static let textPlaceholder = MeloColors.Text.secondary
    static let labelGray = MeloColors.Text.primary
}

// MARK: - Create Sheet

/// 新しい相談部屋を作成する入力シート。
/// 必要項目: タイトル / ヘッダー画像 / アイコン画像（正方形）/ 説明文
struct CommunityRoomCreateSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onCreate: (_ title: String, _ subtitle: String, _ iconImageData: Data?, _ headerImageData: Data?) -> Void

    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var iconItem: PhotosPickerItem?
    @State private var headerItem: PhotosPickerItem?
    @State private var iconData: Data?
    @State private var headerData: Data?

    @FocusState private var focused: Field?

    private enum Field { case title, subtitle }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ヘッダー画像
                    headerImagePicker

                    // アイコン画像（正方形）
                    iconImagePicker

                    // タイトル
                    labeledField(label: "タイトル") {
                        TextField("例: 失恋した人、集まれ", text: $title)
                            .font(MeloFonts.zenMaruMedium(16))
                            .foregroundColor(CreateSheetPalette.textMain)
                            .focused($focused, equals: .title)
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(CreateSheetPalette.fieldBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(CreateSheetPalette.fieldBorder, lineWidth: 1)
                                    )
                            )
                    }

                    // 説明文
                    labeledField(label: "説明文") {
                        ZStack(alignment: .topLeading) {
                            if subtitle.isEmpty {
                                Text("どんな話題・雰囲気の部屋かを書きましょう")
                                    .font(MeloFonts.zenMaruMedium(14))
                                    .foregroundColor(CreateSheetPalette.textPlaceholder)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $subtitle)
                                .font(MeloFonts.zenMaruMedium(14))
                                .foregroundColor(CreateSheetPalette.textMain)
                                .focused($focused, equals: .subtitle)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .frame(minHeight: 120)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(CreateSheetPalette.fieldBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(CreateSheetPalette.fieldBorder, lineWidth: 1)
                                )
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("相談部屋を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(CreateSheetPalette.textMain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.medium()
                        onCreate(title, subtitle, iconData, headerData)
                        dismiss()
                    } label: {
                        Text("作成")
                            .font(MeloFonts.zenMaruOrFallback(16))
                            .foregroundColor(.white)
                            .tracking(0.48)
                            .padding(.horizontal, 20)
                            .frame(height: 32)
                            .background(
                                Capsule()
                                    .fill(canSubmit ? CreateSheetPalette.koiPink : CreateSheetPalette.koiPink.opacity(0.4))
                            )
                    }
                    .disabled(!canSubmit)
                }
            }
            .onChange(of: iconItem) { _, new in
                Task {
                    if let new, let data = try? await new.loadTransferable(type: Data.self) {
                        await MainActor.run { iconData = data }
                    }
                }
            }
            .onChange(of: headerItem) { _, new in
                Task {
                    if let new, let data = try? await new.loadTransferable(type: Data.self) {
                        await MainActor.run { headerData = data }
                    }
                }
            }
        }
    }

    // MARK: - Header Image Picker (バナー用)

    private var headerImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ヘッダー画像")
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(CreateSheetPalette.labelGray)
                .tracking(0.42)

            PhotosPicker(selection: $headerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CreateSheetPalette.headerBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(CreateSheetPalette.fieldBorder, lineWidth: 1)
                        )
                    if let headerData, let uiImage = UIImage(data: headerData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 28, weight: .regular))
                                .foregroundColor(CreateSheetPalette.koiPink)
                            Text("タップしてヘッダー画像を選択")
                                .font(MeloFonts.zenMaruMedium(12))
                                .foregroundColor(CreateSheetPalette.textPlaceholder)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Icon Image Picker (正方形)

    private var iconImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("アイコン画像（正方形）")
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(CreateSheetPalette.labelGray)
                .tracking(0.42)

            HStack(spacing: 12) {
                PhotosPicker(selection: $iconItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(CreateSheetPalette.headerBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(CreateSheetPalette.fieldBorder, lineWidth: 1)
                            )
                        if let iconData, let uiImage = UIImage(data: iconData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(CreateSheetPalette.koiPink)
                        }
                    }
                    .frame(width: 80, height: 80)
                }
                .buttonStyle(.plain)

                Text("一覧カードに表示される正方形アイコンです。")
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(CreateSheetPalette.textPlaceholder)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func labeledField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(MeloFonts.zenMaruOrFallback(14))
                .foregroundColor(CreateSheetPalette.labelGray)
                .tracking(0.42)
            content()
        }
    }
}

#Preview {
    CommunityRoomCreateSheet { _, _, _, _ in }
}
