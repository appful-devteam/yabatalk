import SwiftUI
import PhotosUI

// MARK: - Profile Setup View
/// 新規アカウント作成後のプロフィール設定フロー
struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = BoardAuthService.shared

    @State private var currentStep: SetupStep = .name
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var selectedMBTI: LoveTypeBadge?
    @State private var isPrivate: Bool = false
    @State private var profileImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showCancelConfirm = false

    private let firestoreService = BoardFirestoreService.shared

    enum SetupStep: Int, CaseIterable {
        case name = 0
        case photo = 1
        case mbti = 2
        case bio = 3
        case privacy = 4

        var title: String {
            switch self {
            case .name: return String(localized: "ニックネーム", bundle: LanguageManager.appBundle)
            case .photo: return String(localized: "プロフィール画像", bundle: LanguageManager.appBundle)
            case .mbti: return "MBTI"
            case .bio: return String(localized: "自己紹介", bundle: LanguageManager.appBundle)
            case .privacy: return String(localized: "公開設定", bundle: LanguageManager.appBundle)
            }
        }

        var subtitle: String {
            switch self {
            case .name: return String(localized: "みんなに表示される名前を決めよう", bundle: LanguageManager.appBundle)
            case .photo: return String(localized: "アイコンを設定しよう", bundle: LanguageManager.appBundle)
            case .mbti: return String(localized: "あなたのMBTIタイプを選んでね", bundle: LanguageManager.appBundle)
            case .bio: return String(localized: "ひとことプロフィールを書いてみよう", bundle: LanguageManager.appBundle)
            case .privacy: return String(localized: "アカウントの公開範囲を選んでね", bundle: LanguageManager.appBundle)
            }
        }
    }

    private let mbtiTypes: [(code: String, group: String)] = [
        ("INTJ", "Analysts"), ("INTP", "Analysts"),
        ("ENTJ", "Analysts"), ("ENTP", "Analysts"),
        ("INFJ", "Diplomats"), ("INFP", "Diplomats"),
        ("ENFJ", "Diplomats"), ("ENFP", "Diplomats"),
        ("ISTJ", "Sentinels"), ("ISFJ", "Sentinels"),
        ("ESTJ", "Sentinels"), ("ESFJ", "Sentinels"),
        ("ISTP", "Explorers"), ("ISFP", "Explorers"),
        ("ESTP", "Explorers"), ("ESFP", "Explorers"),
    ]
    private let groups = ["Analysts", "Diplomats", "Sentinels", "Explorers"]

    private func groupLabel(_ group: String) -> String {
        switch group {
        case "Analysts": return String(localized: "分析家", bundle: LanguageManager.appBundle)
        case "Diplomats": return String(localized: "外交官", bundle: LanguageManager.appBundle)
        case "Sentinels": return String(localized: "番人", bundle: LanguageManager.appBundle)
        case "Explorers": return String(localized: "探検家", bundle: LanguageManager.appBundle)
        default: return group
        }
    }

    var body: some View {
        ZStack {
            MeloColors.Dark.bg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // プログレスバー + キャンセル
                HStack(spacing: 12) {
                    progressBar

                    Button {
                        showCancelConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(MeloColors.Dark.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(MeloColors.Dark.bgElevated))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                // ヘッダー
                VStack(spacing: 6) {
                    Text(currentStep.title)
                        .font(MeloFonts.zenMaruOrFallback(20))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    Text(currentStep.subtitle)
                        .font(MeloFonts.zenMaruOrFallback(13))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                }
                .padding(.top, 24)

                // コンテンツ
                Spacer()

                Group {
                    switch currentStep {
                    case .name: nameStep
                    case .photo: photoStep
                    case .mbti: mbtiStep
                    case .bio: bioStep
                    case .privacy: privacyStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // ボタン
                VStack(spacing: 10) {
                    Button {
                        HapticManager.medium()
                        if currentStep == .privacy {
                            Task { await saveAndFinish() }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                goToNextStep()
                            }
                        }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(MeloColors.Dark.onAccent)
                            } else {
                                Text(currentStep == .privacy
                                     ? String(localized: "はじめる", bundle: LanguageManager.appBundle)
                                     : String(localized: "次へ", bundle: LanguageManager.appBundle))
                                    .font(MeloFonts.zenMaruOrFallback(15))
                                    .foregroundColor(MeloColors.Dark.onAccent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(MeloColors.Dark.accentGradient)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentStep == .name && displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(currentStep == .name && displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 32)

                    if currentStep != .name {
                        Button {
                            HapticManager.light()
                            if currentStep == .privacy {
                                Task { await saveAndFinish() }
                            } else {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    goToNextStep()
                                }
                            }
                        } label: {
                            Text(String(localized: "スキップ", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(13))
                                .foregroundColor(MeloColors.Dark.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }

            // ローディング
            if authService.isLoading || isSaving {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            displayName = authService.currentUser?.displayName ?? ""
            if displayName == String(localized: "ゲスト", bundle: LanguageManager.appBundle) {
                displayName = ""
            }
        }
        .interactiveDismissDisabled()
        .alert(
            String(localized: "アカウント作成をキャンセル", bundle: LanguageManager.appBundle),
            isPresented: $showCancelConfirm
        ) {
            Button(String(localized: "続ける", bundle: LanguageManager.appBundle), role: .cancel) {}
            Button(String(localized: "キャンセル", bundle: LanguageManager.appBundle), role: .destructive) {
                Task {
                    await authService.cancelAccountSetup()
                    dismiss()
                }
            }
        } message: {
            Text(String(localized: "アカウントは作成されません。あとからいつでもサインインできます。", bundle: LanguageManager.appBundle))
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        let total = SetupStep.allCases.count
        let current = currentStep.rawValue + 1

        return HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < current
                          ? MeloColors.Dark.accent
                          : MeloColors.Dark.track)
                    .frame(height: 3)
            }
        }
    }

    // MARK: - Name Step

    private var nameStep: some View {
        VStack(spacing: 20) {
            TextField(
                String(localized: "ニックネームを入力", bundle: LanguageManager.appBundle),
                text: $displayName
            )
            .font(MeloFonts.zenMaruOrFallback(16))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(MeloColors.Dark.card)
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 40)

            Text(String(localized: "あとから変更できます", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
        }
    }

    // MARK: - Photo Step

    private var photoStep: some View {
        VStack(spacing: 20) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(MeloColors.Dark.accent.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [MeloColors.Dark.card, MeloColors.Dark.card],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)

                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(MeloColors.Dark.accent)
                            Text(String(localized: "タップして選択", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruOrFallback(10))
                                .foregroundColor(MeloColors.Dark.accent)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _ in
                Task {
                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = uiImage
                    }
                }
            }
        }
    }

    // MARK: - MBTI Step

    private var mbtiStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 非表示オプション
                Button {
                    HapticManager.light()
                    selectedMBTI = nil
                } label: {
                    Text(String(localized: "非表示", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(selectedMBTI == nil ? MeloColors.Dark.onAccent : MeloColors.Dark.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selectedMBTI == nil ? MeloColors.Dark.accent : MeloColors.Dark.card)
                                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)

                ForEach(groups, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(mbtiTypes.filter { $0.group == group }, id: \.code) { mbti in
                                let isSelected = selectedMBTI?.typeCode == mbti.code
                                let color = MeloColors.mbtiColor(for: mbti.code)

                                Button {
                                    HapticManager.light()
                                    selectedMBTI = LoveTypeBadge(typeCode: mbti.code, typeName: mbti.code, totalScore: 0)
                                } label: {
                                    Text(mbti.code)
                                        .font(MeloFonts.zenMaruOrFallback(15))
                                        .foregroundColor(isSelected ? .white : color)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? color : color.opacity(0.12))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Bio Step

    private var bioStep: some View {
        VStack(spacing: 16) {
            TextField(
                String(localized: "ひとことを入力...", bundle: LanguageManager.appBundle),
                text: $bio,
                axis: .vertical
            )
            .font(MeloFonts.zenMaruOrFallback(14))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .lineLimit(3...5)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(MeloColors.Dark.card)
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 32)

            Text("\(bio.count)/100")
                .font(MeloFonts.zenMaruRegular(11))
                .foregroundColor(MeloColors.Dark.textSecondary)
        }
        .onChange(of: bio) { _ in
            if bio.count > 100 {
                bio = String(bio.prefix(100))
            }
        }
    }

    // MARK: - Privacy Step

    private var privacyStep: some View {
        VStack(spacing: 16) {
            privacyOption(
                isSelected: !isPrivate,
                icon: "globe",
                title: String(localized: "公開アカウント", bundle: LanguageManager.appBundle),
                description: String(localized: "誰でも投稿やプロフィールを見ることができます", bundle: LanguageManager.appBundle)
            ) {
                HapticManager.light()
                isPrivate = false
            }

            privacyOption(
                isSelected: isPrivate,
                icon: "lock.fill",
                title: String(localized: "非公開アカウント", bundle: LanguageManager.appBundle),
                description: String(localized: "承認したフォロワーだけが投稿を見ることができます", bundle: LanguageManager.appBundle)
            ) {
                HapticManager.light()
                isPrivate = true
            }
        }
        .padding(.horizontal, 24)
    }

    private func privacyOption(isSelected: Bool, icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? MeloColors.Dark.accent : MeloColors.Dark.textSecondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MeloFonts.zenMaruOrFallback(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                    Text(description)
                        .font(MeloFonts.zenMaruOrFallback(11))
                        .foregroundColor(MeloColors.Dark.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? MeloColors.Dark.accent : MeloColors.Dark.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? MeloColors.Dark.bgElevated : MeloColors.Dark.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? MeloColors.Dark.accent.opacity(0.3) : MeloColors.Dark.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private func goToNextStep() {
        guard let nextIndex = SetupStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextIndex
    }

    // MARK: - Save

    private func saveAndFinish() async {
        guard let userId = authService.currentUser?.id else {
            dismiss()
            return
        }
        isSaving = true

        var imageURL: String?

        // 画像アップロード
        if let image = profileImage,
           let data = image.jpegData(compressionQuality: 0.7) {
            imageURL = try? await firestoreService.uploadProfileImage(userId: userId, imageData: data)
        }

        let finalName = displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ? (authService.currentUser?.displayName ?? "ユーザー")
            : displayName.trimmingCharacters(in: .whitespaces)

        // 表示名更新
        await authService.updateDisplayName(finalName)

        // プロフィール保存
        try? await firestoreService.updateProfile(
            userId: userId,
            displayName: finalName,
            bio: bio,
            profileImageURL: imageURL
        )

        // MBTI保存
        try? await firestoreService.saveUserProfile(
            userId: userId,
            displayName: finalName,
            badge: selectedMBTI
        )

        // 非公開設定
        if isPrivate {
            try? await firestoreService.togglePrivacy(userId: userId, isPrivate: true)
        }

        // 過去の投稿にプロフィール変更を反映
        try? await firestoreService.updatePostsAuthorInfo(
            userId: userId,
            displayName: finalName,
            profileImageURL: imageURL,
            badge: selectedMBTI
        )

        authService.needsProfileSetup = false
        isSaving = false
        HapticManager.success()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupView()
}
