import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Post Theme
/// 投稿に付けられるテーマラベル。`label` 文字列が Firestore の `posts.themes` 配列に保存され、
/// フィードのテーマタブ (`BoardFeedCategory`) のマッチング/カードのピル表示にも使われる。
/// label を変更する場合は既存投稿との整合性に注意 (Firestore に保存済みの文字列とずれると分類不可になる)。
enum PostTheme: String, CaseIterable, Identifiable {
    case power     // パワハラ
    case sexual    // セクハラ
    case moral     // モラハラ
    case customer  // カスハラ
    case other     // その他
    case consult   // ぶっちゃけ相談

    var id: String { rawValue }

    var label: String {
        switch self {
        case .power:    return "パワハラ"
        case .sexual:   return "セクハラ"
        case .moral:    return "モラハラ"
        case .customer: return "カスハラ"
        case .other:    return "その他"
        case .consult:  return "ぶっちゃけ相談"
        }
    }

    /// 文字列ラベルから PostTheme を逆引き (カードのピル表示色分け等に使う)。
    static func from(label: String) -> PostTheme? {
        return allCases.first { $0.label == label }
    }
}

// MARK: - Draft model (internal state container)
struct BoardComposeDraft {
    var text: String = ""
    var isAnonymous: Bool = false
    var showsMbti: Bool = true
    var themes: Set<PostTheme> = []
    var hashtags: [String] = []
    var imagesData: [Data] = []
    var hasPoll: Bool = false
    var hasDiagnosis: Bool = false
    /// 添付された診断カード本体 (相談部屋など外部 onSubmit に流すため draft に持たせる)。
    var diagnosisCard: DiagnosisCard? = nil
    /// アンケートの質問と選択肢 (相談部屋など外部 onSubmit 経路で参照する)。
    var pollQuestion: String = ""
    var pollOptions: [String] = []
}

// MARK: - Persistable Draft Snapshot
/// 下書きとして UserDefaults に保存する軽量スナップショット。
/// 画像・診断カードなどの重いデータは含めず、テキスト主体で 1 件だけ保持。
struct BoardComposeDraftSnapshot: Codable {
    var text: String
    var isAnonymous: Bool
    var showsMbti: Bool
    var themeRawValues: [String]
    var hashtags: [String]
    var pollQuestion: String
    var pollOptions: [String]
    var hasPoll: Bool
    var savedAt: Date
}

enum BoardComposeDraftStorage {
    private static let key = "board.compose.draft.snapshot"

    static func load() -> BoardComposeDraftSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(BoardComposeDraftSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    static func save(_ snapshot: BoardComposeDraftSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Board Compose View V2
struct BoardComposeViewV2: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = BoardComposeDraft()
    @State private var hasSavedDraft: Bool = (BoardComposeDraftStorage.load() != nil)
    /// 投稿が無事に完了したかどうか。
    /// 完了せずに dismiss された場合は自動的に下書きとして保存し、
    /// 次回コンポーズ画面を開いた時に復元する(誤って閉じても入力内容を失わないため)。
    @State private var didSubmitSuccessfully = false
    @State private var hashtagInput: String = ""
    @State private var showThemePicker = false
    @State private var showHashtagEditor = false
    @State private var showDiagnosisPicker = false
    @State private var showMbtiPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isSubmitting = false
    /// App Store Guideline 1.2: 不適切表現で投稿がブロックされた時のアラート文言
    @State private var moderationAlertMessage: String?
    @State private var joinedRooms: [CommunityRoom] = []
    @State private var selectedCommunityRoom: CommunityRoom?

    // Quote reply — optional quoted post preview rendered above the body.
    // Stored in @State so the tap-to-remove ✕ action works.
    @State private var quotedPost: QuotedPostInfo?

    // Logged-in user profile cache
    @State private var currentProfile: BoardUserProfile?

    // Poll local state (draft doesn't carry these — kept locally, consumed by submit pipeline)
    @State private var pollQuestion: String = ""
    @State private var pollOptionTexts: [String] = ["", ""]

    // Diagnosis card local state
    @State private var selectedDiagnosisCard: DiagnosisCard?

    // MBTI override (if profile badge missing or user wants to set manually)
    @State private var manualMbtiCode: String?

    @FocusState private var isBodyFocused: Bool
    @FocusState private var isHashtagFocused: Bool

    @Query(sort: \StoredAnalysisResult.analyzedAt, order: .reverse)
    private var analysisHistory: [StoredAnalysisResult]

    private let firestoreService = BoardFirestoreService.shared
    private let authService = BoardAuthService.shared
    private let roomRepository = InMemoryCommunityRoomRepository()

    private let maxCharacters = 500
    private let maxImages = 4
    private let maxHashtags = 5
    private let maxThemes = 3
    private let maxPollOptions = 6

    /// onSubmit が指定されると V2 内部の Firestore 投稿処理を行わず、draft を呼び出し元へ委譲する。
    /// （コミュニティルームなど独自の書き込み先を持つ呼び出し側向け）
    var onSubmit: ((BoardComposeDraft) -> Void)? = nil

    /// Firestore への投稿が成功した後に、作成された投稿を渡して呼ばれるコールバック（任意）。
    /// onSubmit を使わず V2 内蔵の投稿経路を使うケースで、フィードへの楽観的挿入やトースト表示に利用する。
    var onPosted: ((BoardPost) -> Void)? = nil

    /// 「新規参加」メニュー項目から相談部屋タブを開きたい時に呼ばれる。
    /// nil の場合は「新規参加…」項目自体を出さない（部屋詳細など、相談部屋切替が文脈上不自然な提示元向け）。
    var onRequestOpenConsultRoom: (() -> Void)? = nil

    init(
        onSubmit: ((BoardComposeDraft) -> Void)? = nil,
        onPosted: ((BoardPost) -> Void)? = nil,
        onRequestOpenConsultRoom: (() -> Void)? = nil,
        quotedPost: QuotedPostInfo? = nil,
        preselectedCommunityRoom: CommunityRoom? = nil
    ) {
        self.onSubmit = onSubmit
        self.onPosted = onPosted
        self.onRequestOpenConsultRoom = onRequestOpenConsultRoom
        // 引用投稿は @State の初期値として直接セット (.task で後追いコピーするとレイアウトに反映が遅れる)
        _quotedPost = State(initialValue: quotedPost)
        _selectedCommunityRoom = State(initialValue: preselectedCommunityRoom)
    }

    // Figma colors（ダーク化: 黒地 × ホットピンク accent）
    private let koiPink = MeloColors.Dark.accent          // こいピンク確定 → accent
    private let textBrown = MeloColors.Dark.textPrimary        // 確焦茶 → 明文字
    private let lightBrown = MeloColors.Dark.textSecondary       // 確定薄茶 → 副文字
    private let softBrown = MeloColors.Dark.bgElevated  // 添付ピル等の背景 → 一段上の面
    private let softPinkLite = MeloColors.Dark.bgElevated     // 薄ピンク確定 → 一段上の面
    private let mbtiGreen = MeloColors.Dark.bgElevated        // INFP fallback bg // TODO(dark): 要確認（元 Status.successBg の薄緑。意味色ではなく placeholder 用途のため面色に置換）
    private let chipBorder = MeloColors.Dark.cardStroke
    private let placeholderGray = MeloColors.Dark.textSecondary
    private let softGray = MeloColors.Dark.bgElevated
    private let lineGray = MeloColors.Dark.divider
    // Fix #5: top strip transparent (was FFF1F4 激薄ピンク — made clear)
    private let headerBg = Color.clear

    var body: some View {
        ZStack {
            headerBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Color.clear.frame(height: 10)

                contentCard
                    .clipShape(BoardComposeV2RoundedCorners(radius: 30, corners: [.topLeft, .topRight]))
                    // .container 限定: ホームインジケーター下まで白カードを伸ばすが、
                    // キーボード safe area は尊重して ScrollView がキーボード上で収まるようにする。
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        // 余白タップでキーボードを閉じる
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        .alert(
            String(localized: "投稿できません", bundle: LanguageManager.appBundle),
            isPresented: Binding(
                get: { moderationAlertMessage != nil },
                set: { if !$0 { moderationAlertMessage = nil } }
            )
        ) {
            Button(String(localized: "OK", bundle: LanguageManager.appBundle), role: .cancel) {}
        } message: {
            Text(moderationAlertMessage ?? "")
        }
        .sheet(isPresented: $showMbtiPicker) {
            mbtiPickerSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDiagnosisPicker) {
            DiagnosisPickerView(
                analysisHistory: uniqueResults,
                selectedCard: $selectedDiagnosisCard
            )
            .presentationDetents([.medium, .large])
            .onDisappear {
                draft.hasDiagnosis = (selectedDiagnosisCard != nil)
            }
        }
        .onChange(of: photoItems) { _, newItems in
            Task { await loadPhotos(newItems) }
        }
        .task {
            await loadCurrentProfile()
            await loadJoinedRooms()
            // 前回未送信の下書きがあり、かつ今の入力欄が空なら自動復元する。
            // (誤って閉じてしまった内容をシームレスに取り戻す)
            autoRestoreDraftIfNeeded()
        }
        .onDisappear {
            // 投稿せずに閉じた場合、入力中の内容を自動的に下書きとして保存する。
            autoSaveDraftIfNeeded()
        }
    }

    // MARK: - Content card
    // 順序 (top→bottom):
    //   1. profileRow
    //   2. bodyTextArea
    //   3. attachedImagesRow       (if draft.imagesData non-empty)
    //   4. hashtagSection          (if editor open OR chips non-empty)
    //   5. pollInlineEditor        (if draft.hasPoll)
    //   6. diagnosisInlinePreview  (if selectedDiagnosisCard != nil)
    //   7. attachmentRow           (always)
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.top, 6)
                .padding(.bottom, 14)

            Rectangle().fill(lineGray).frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. profileRow
                    profileRow
                        .padding(.top, 20)

                    // 1.5 引用プレビュー（引用返信時のみ）
                    if let quote = quotedPost {
                        quotedPostPreview(quote)
                    }

                    // 2. body
                    bodyTextArea

                    // 3. attached images — directly under body
                    if !draft.imagesData.isEmpty {
                        attachedImagesRow
                    }

                    // 4. hashtag input / chips — directly under body so keyboard doesn't cover it
                    if !draft.hashtags.isEmpty || showHashtagEditor {
                        hashtagSection
                    }

                    // 5. inline poll editor
                    if draft.hasPoll {
                        pollInlineEditor
                    }

                    // 6. inline diagnosis preview
                    if let card = selectedDiagnosisCard {
                        diagnosisInlinePreview(card)
                    }

                    // 7. attachment buttons row — always sits at the bottom
                    attachmentRow

                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MeloColors.Dark.card)
    }

    // MARK: - Top bar (Cancel / Draft Menu / Title / Submit)
    // Fix #2: bigger tap targets — cancel 32pt, submit 40pt
    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "キャンセル", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(15))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .tracking(0.45)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                draftMenu

                Button {
                    Task { await submitPost() }
                } label: {
                    Text(String(localized: "投稿", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruMedium(15))
                        .foregroundColor(MeloColors.Dark.onAccent)
                        .tracking(0.48)
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                        .background(Capsule().fill((canSubmit && !isSubmitting) ? koiPink : koiPink.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit || isSubmitting)
            }

            Text(String(localized: "相談する", bundle: LanguageManager.appBundle))
                .font(MeloFonts.zenMaruOrFallback(18))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .tracking(0.54)
        }
        .frame(height: 40)
    }

    /// 下書きの保存・復元・破棄メニュー。1 件だけ保持。
    private var draftMenu: some View {
        Menu {
            Button {
                saveDraft()
            } label: {
                Label("下書きを保存", systemImage: "tray.and.arrow.down")
            }
            .disabled(!canSubmit)

            if hasSavedDraft {
                Button {
                    restoreDraft()
                } label: {
                    Label("下書きを開く", systemImage: "tray.and.arrow.up")
                }

                Button(role: .destructive) {
                    BoardComposeDraftStorage.clear()
                    hasSavedDraft = false
                } label: {
                    Label("下書きを破棄", systemImage: "trash")
                }
            }
        } label: {
            ZStack {
                Image(systemName: hasSavedDraft ? "tray.full.fill" : "tray")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .frame(width: 36, height: 36)
            }
        }
        .accessibilityLabel("下書きメニュー")
    }

    private func saveDraft() {
        let snapshot = BoardComposeDraftSnapshot(
            text: draft.text,
            isAnonymous: draft.isAnonymous,
            showsMbti: draft.showsMbti,
            themeRawValues: draft.themes.map { $0.rawValue },
            hashtags: draft.hashtags,
            pollQuestion: pollQuestion,
            pollOptions: pollOptionTexts,
            hasPoll: draft.hasPoll,
            savedAt: Date()
        )
        BoardComposeDraftStorage.save(snapshot)
        hasSavedDraft = true
        dismiss()
    }

    private func restoreDraft() {
        guard let snapshot = BoardComposeDraftStorage.load() else { return }
        draft.text = snapshot.text
        draft.isAnonymous = snapshot.isAnonymous
        draft.showsMbti = snapshot.showsMbti
        draft.themes = Set(snapshot.themeRawValues.compactMap { PostTheme(rawValue: $0) })
        draft.hashtags = snapshot.hashtags
        draft.hasPoll = snapshot.hasPoll
        pollQuestion = snapshot.pollQuestion
        // 保存時の選択肢数に合わせて再構築
        pollOptionTexts = snapshot.pollOptions.isEmpty ? ["", ""] : snapshot.pollOptions
    }

    /// コンポーズ画面オープン時に、保存済み下書きがあって現在の入力が空なら自動復元する。
    /// 引用投稿モード(`quotedPost`非nil)の時は別文脈なので復元しない。
    private func autoRestoreDraftIfNeeded() {
        guard quotedPost == nil else { return }
        guard draft.text.isEmpty,
              draft.themes.isEmpty,
              draft.hashtags.isEmpty,
              !draft.hasPoll
        else { return }
        guard BoardComposeDraftStorage.load() != nil else { return }
        restoreDraft()
    }

    /// 投稿せずに dismiss された場合、入力中の本文・テーマ・ハッシュタグ等を
    /// 下書きとして自動保存する(画像・診断カードは含めない設計を踏襲)。
    private func autoSaveDraftIfNeeded() {
        guard !didSubmitSuccessfully else { return }
        // 中身が空なら保存しない(空の下書きを残さない)
        let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContent = !trimmed.isEmpty
            || !draft.themes.isEmpty
            || !draft.hashtags.isEmpty
            || draft.hasPoll
        guard hasContent else { return }

        let snapshot = BoardComposeDraftSnapshot(
            text: draft.text,
            isAnonymous: draft.isAnonymous,
            showsMbti: draft.showsMbti,
            themeRawValues: draft.themes.map { $0.rawValue },
            hashtags: draft.hashtags,
            pollQuestion: pollQuestion,
            pollOptions: pollOptionTexts,
            hasPoll: draft.hasPoll,
            savedAt: Date()
        )
        BoardComposeDraftStorage.save(snapshot)
    }

    private var canSubmit: Bool {
        !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var roomPickerMenu: some View {
        Menu {
            Button {
                selectedCommunityRoom = nil
            } label: {
                Label("相談部屋なし", systemImage: selectedCommunityRoom == nil ? "checkmark" : "circle")
            }

            if !joinedRooms.isEmpty {
                Divider()
                ForEach(joinedRooms) { room in
                    Button {
                        selectedCommunityRoom = room
                    } label: {
                        Label(room.title, systemImage: selectedCommunityRoom?.id == room.id ? "checkmark" : "bubble.left.and.bubble.right")
                    }
                }
            }

            // テーマ部屋: PostTheme をベースにした仮想ルーム。常に全件表示。
            Divider()
            ForEach(CommunityThemeRoom.all) { room in
                Button {
                    selectedCommunityRoom = room
                } label: {
                    Label(room.title, systemImage: selectedCommunityRoom?.id == room.id ? "checkmark" : "tag")
                }
            }

            Divider()

            // 新規参加: 投稿作成を閉じて相談部屋タブに切り替え、新しい部屋を探す導線。
            // Menu Button 内で同期的に sheet dismiss + state 変更を呼ぶと、Menu のクローズ
            // アニメーションとビュー再構築が衝突して SwiftUI がハングする事象が出るため、
            // すべての副作用を一度 main async に逃がして Menu を確実に閉じきってから走らせる。
            if let onRequestOpenConsultRoom {
                Button {
                    DispatchQueue.main.async {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onRequestOpenConsultRoom()
                        }
                    }
                } label: {
                    Label("新規参加…", systemImage: "plus.circle")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12, weight: .semibold))
                Text(selectedCommunityRoom?.title ?? "相談部屋")
                    .font(MeloFonts.zenMaruMedium(12))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(MeloColors.Dark.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Capsule().fill(softPinkLite))
            .overlay(Capsule().stroke(chipBorder.opacity(0.6), lineWidth: 0.5))
            .frame(maxWidth: 132)
        }
    }

    /// 下書きを実際に Firestore に投稿。テーマラベルは #ハッシュタグ として content に含め、
    /// 既存のホーム画面カテゴリフィルタ (BoardFeedCategory.matches) で絞り込めるようにする。
    private func submitPost() async {
        guard !isSubmitting, canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        // テーマは構造化フィールド `posts.themes` に保存し、本文 (#ハッシュタグ) には付け足さない。
        // ピル + 本文中ハッシュタグの二重表示を防ぐ。テーマピル <-> ハッシュタグ検索は別機能。
        var themeLabels = draft.themes
            .sorted(by: { $0.label < $1.label })
            .map { $0.label }

        // 相談部屋メニューからテーマ部屋 ("theme:..." prefix) が選ばれた場合は、
        // そのラベルを themes に追加してテーマ部屋クエリ (themes array-contains) で
        // 拾えるようにする。communityRoomId/Title には値を載せない (実体ルームではないので
        // 共通 posts/ にゴミ ID を残さない)。
        let resolvedRoomId: String?
        let resolvedRoomTitle: String?
        if let room = selectedCommunityRoom,
           let themeLabel = CommunityThemeRoom.themeLabel(forRoomId: room.id) {
            if !themeLabels.contains(themeLabel) {
                themeLabels.append(themeLabel)
            }
            resolvedRoomId = nil
            resolvedRoomTitle = nil
        } else {
            resolvedRoomId = selectedCommunityRoom?.id
            resolvedRoomTitle = selectedCommunityRoom?.title
        }
        // ユーザー手書きの #タグだけを本文末尾に保持 (ハッシュタグ検索の対象になる)。
        let extraHashtags = draft.hashtags.map { "#\($0)" }.joined(separator: " ")
        var content = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extraHashtags.isEmpty {
            content += "\n\n" + extraHashtags
        }
        if draft.hasPoll {
            let q = pollQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                content = q + "\n\n" + content
            }
        }

        // App Store Guideline 1.2: 投稿前に不適切表現をチェックし、ブロック時はアラート表示。
        // データ層 (createPost) でも guard しているが、ここで弾くと reviewer に即フィードバックできる。
        if content.containsObjectionableContent {
            moderationAlertMessage = ContentModeration.ModerationError.objectionableContent.errorDescription
            HapticManager.error()
            return
        }

        // onSubmit クロージャがあれば投稿処理はそちらに委譲。
        // 診断カード / アンケート情報は draft に詰め直してから渡す (相談部屋等の外部経路で必要)。
        if let onSubmit {
            var outDraft = draft
            outDraft.diagnosisCard = selectedDiagnosisCard
            outDraft.pollQuestion = pollQuestion
            outDraft.pollOptions = pollOptionTexts
            onSubmit(outDraft)
            dismiss()
            return
        }

        guard authService.hasRealAccount, let user = authService.currentUser else {
            // 未サインイン時はシート閉じるだけ（従来挙動互換）
            dismiss()
            return
        }

        let badge = currentProfile?.badge
            ?? (manualMbtiCode.map { LoveTypeBadge(typeCode: $0, typeName: $0, totalScore: 0) })
        let profileImageURL = currentProfile?.profileImageURL
        let isPrivateAccount = currentProfile?.isPrivate ?? false

        let pollOptions: [PollOption]?
        if draft.hasPoll {
            let cleaned = pollOptionTexts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if cleaned.count >= 2 {
                pollOptions = cleaned.enumerated().map {
                    PollOption(id: "opt\($0.offset + 1)", text: $0.element, voteCount: 0)
                }
            } else {
                pollOptions = nil
            }
        } else {
            pollOptions = nil
        }

        let postType: BoardPostType = (pollOptions != nil) ? .poll : .normal

        do {
            let createdPost: BoardPost
            if draft.imagesData.isEmpty {
                createdPost = try await firestoreService.createPost(
                    content: content,
                    authorId: user.id,
                    authorName: user.displayName,
                    authorProfileImageURL: profileImageURL,
                    badge: badge,
                    diagnosisCard: selectedDiagnosisCard,
                    quotedPost: quotedPost,
                    postType: postType,
                    pollOptions: pollOptions,
                    isAnonymous: draft.isAnonymous,
                    authorIsPrivate: isPrivateAccount,
                    themes: themeLabels,
                    communityRoomId: resolvedRoomId,
                    communityRoomTitle: resolvedRoomTitle
                )
            } else {
                createdPost = try await firestoreService.createPostWithImages(
                    content: content,
                    authorId: user.id,
                    authorName: user.displayName,
                    authorProfileImageURL: profileImageURL,
                    badge: badge,
                    diagnosisCard: selectedDiagnosisCard,
                    quotedPost: quotedPost,
                    postType: postType,
                    pollOptions: pollOptions,
                    isAnonymous: draft.isAnonymous,
                    authorIsPrivate: isPrivateAccount,
                    themes: themeLabels,
                    communityRoomId: resolvedRoomId,
                    communityRoomTitle: resolvedRoomTitle,
                    images: draft.imagesData
                )
            }
            // 投稿成功 → 保存済み下書きをクリア (公開済みなら下書きは不要)
            BoardComposeDraftStorage.clear()
            hasSavedDraft = false

            let hasDiagnosis = (selectedDiagnosisCard != nil)
            let postKind: AnalyticsManager.BoardPostKind =
                hasDiagnosis ? .analysisShare : (postType == .poll ? .question : .text)
            AnalyticsManager.shared.boardPostCreated(
                postType: postKind,
                hasDiagnosis: hasDiagnosis,
                hasImages: !draft.imagesData.isEmpty
            )
            // 診断カード付き投稿=このアプリ唯一の結果拡散導線 → GA4 標準 share も発火
            if hasDiagnosis {
                AnalyticsManager.shared.resultShared(method: .board)
            }

            // dismiss 後の onDisappear で自動保存が走らないようフラグを立てる
            didSubmitSuccessfully = true
            // 作成した投稿を呼び出し側に渡し、フィードへ即時反映（楽観的挿入）させる。
            // リスナー到達を待たずに「投稿が反映されない」状態を防ぐ（2.1(a) 対策）。
            onPosted?(createdPost)
            dismiss()
        } catch let error as ContentModeration.ModerationError {
            // データ層フィルタで弾かれた場合のフォールバック表示
            moderationAlertMessage = error.errorDescription
            HapticManager.error()
        } catch {
            // 投稿失敗を握り潰さず必ずユーザーに伝える（黙って失敗＝「投稿したのに反映されない」を防ぐ）
            print("[ComposeV2] Post failed: \(error)")
            moderationAlertMessage = String(
                localized: "投稿に失敗しました。通信環境を確認して、もう一度お試しください。",
                bundle: LanguageManager.appBundle
            )
            HapticManager.error()
        }
    }

    // MARK: - Current profile loader (Fix #1)
    private func loadCurrentProfile() async {
        guard let user = authService.currentUser else { return }
        if let profile = try? await firestoreService.getProfile(userId: user.id) {
            await MainActor.run {
                self.currentProfile = profile
            }
        }
    }

    private func loadJoinedRooms() async {
        let rooms = (try? await roomRepository.fetchRooms()) ?? []
        let myId = authService.currentUser?.id
        let selectable = rooms.filter { room in
            room.isJoined || room.isOwnedBy(userId: myId) || room.id == selectedCommunityRoom?.id
        }
        await MainActor.run {
            self.joinedRooms = selectable
            if let selected = selectedCommunityRoom,
               let resolved = selectable.first(where: { $0.id == selected.id }) {
                self.selectedCommunityRoom = resolved
            }
        }
    }

    /// Fix #1: prefer profile badge, fall back to manual selection, else "INFP" placeholder.
    private var resolvedMbtiCode: String? {
        if let code = currentProfile?.badge?.typeCode, !code.isEmpty { return code }
        if let code = manualMbtiCode, !code.isEmpty { return code }
        return nil
    }

    private var resolvedDisplayName: String {
        if draft.isAnonymous {
            return String(localized: "匿名ユーザー", bundle: LanguageManager.appBundle)
        }
        if let name = currentProfile?.displayName, !name.isEmpty {
            return name
        }
        if let auth = authService.currentUser?.displayName, !auth.isEmpty {
            return auth
        }
        return String(localized: "ユーザー", bundle: LanguageManager.appBundle)
    }

    // MARK: - Profile row (Fix #1)
    private var profileRow: some View {
        HStack(alignment: .top, spacing: 15) {
            avatarView
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.3))

            VStack(alignment: .leading, spacing: 0) {
                // 上段: 名前 + 匿名で相談 トグル
                HStack(spacing: 8) {
                    Text(resolvedDisplayName)
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(MeloColors.Dark.textPrimary)
                        .tracking(0.42)
                        .lineLimit(1)
                    anonymousToggle
                    roomPickerMenu
                }

                Spacer(minLength: 0)

                // 下段: MBTI 表示だけにする。投稿の分類は相談部屋メニューで行う。
                HStack {
                    HStack(spacing: 4) {
                        if draft.showsMbti {
                            personalityBadge
                            toggleIcon(systemName: "minus.circle.fill") {
                                draft.showsMbti = false
                            }
                        } else {
                            toggleIcon(systemName: "plus.circle.fill") {
                                draft.showsMbti = true
                                // If no code resolved yet, open picker
                                if resolvedMbtiCode == nil { showMbtiPicker = true }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .frame(height: 50)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Fix #6: 匿名アバターは char_meromaru_doll（40x40、ピンク枠の円）
    @ViewBuilder
    private var avatarView: some View {
        if draft.isAnonymous {
            ZStack {
                Circle()
                    .fill(softPinkLite)
                    .overlay(Circle().stroke(koiPink.opacity(0.6), lineWidth: 1))
                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .clipShape(Circle())
        } else if let urlString = currentProfile?.profileImageURL,
                  let url = URL(string: urlString) {
            CachedAsyncImage(url: url) {
                initialAvatar
            }
            .clipShape(Circle())
        } else {
            initialAvatar
        }
    }

    private var initialAvatar: some View {
        ZStack {
            Circle()
                .fill(softPinkLite)
                .overlay(Circle().stroke(koiPink.opacity(0.6), lineWidth: 1))
            Text(String(resolvedDisplayName.prefix(1)))
                .font(MeloFonts.zenMaruOrFallback(18))
                .foregroundColor(koiPink)
        }
    }

    @ViewBuilder
    private var themePillRow: some View {
        let selected = Array(draft.themes).sorted(by: { $0.label < $1.label })
        HStack(spacing: 5) {
            if !selected.isEmpty {
                ForEach(selected.prefix(3)) { theme in
                    themeChip(theme.label, filled: isPrimaryTheme(theme))
                }
            }
        }
    }

    /// 先頭1つはピンク塗り、他は薄茶塗り（Figma準拠: 片思い=#FEE7EC, 両思い/他=#F5F1ED）
    private func isPrimaryTheme(_ theme: PostTheme) -> Bool {
        let first = draft.themes.sorted(by: { $0.label < $1.label }).first
        return first?.id == theme.id
    }

    private var anonymousToggle: some View {
        Button {
            HapticManager.light()
            draft.isAnonymous.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(String(localized: "匿名で相談", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .tracking(0.36)

                ZStack(alignment: draft.isAnonymous ? .trailing : .leading) {
                    Capsule()
                        // ON = 緑 / OFF = 薄茶
                        .fill(draft.isAnonymous ? MeloColors.Status.success : lightBrown)
                        .frame(width: 27, height: 12)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 17, height: 10)
                        .padding(.horizontal, 1)
                }
                .animation(.easeInOut(duration: 0.15), value: draft.isAnonymous)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(height: 19)
        }
        .buttonStyle(.plain)
    }

    /// Fix #1: dynamic MBTI (from profile.badge / manual). Fallback to "INFP" if no data yet.
    /// Fix #2: bigger — 13pt text, height 32.
    private var personalityBadge: some View {
        let code = resolvedMbtiCode ?? "INFP"
        let hasRealBadge = resolvedMbtiCode != nil
        let fill = hasRealBadge ? MeloColors.mbtiColor(for: code).opacity(0.35) : mbtiGreen
        return Button {
            showMbtiPicker = true
        } label: {
            Text(code)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(MeloColors.Dark.textPrimary)
                .tracking(0.39)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(fill))
        }
        .buttonStyle(.plain)
    }

    // Fix #2: bigger theme chip — font 13, height 32
    private func themeChip(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(MeloFonts.zenMaruMedium(13))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .tracking(0.39)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Capsule().fill(filled ? softPinkLite : softBrown))
    }

    /// MBTI / 関係性タグのトグル用アイコン (+ / −)
    private func toggleIcon(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(MeloColors.Dark.textPrimary.opacity(0.7))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body text area (Fix #6: taller)
    private var bodyTextArea: some View {
        HStack(alignment: .top, spacing: 8) {
            // 左端の縦バー (17pt, #716463)
            Rectangle()
                .fill(textBrown)
                .frame(width: 1, height: 17)
                .padding(.top, 7)

            ZStack(alignment: .topLeading) {
                if draft.text.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(localized: "何を相談したい？恋バナ、診断結果のシェア...", bundle: LanguageManager.appBundle))
                        Text(String(localized: "なんでも書いてね！", bundle: LanguageManager.appBundle))
                    }
                    .font(MeloFonts.zenMaruMedium(15))
                    .foregroundColor(lightBrown)
                    .tracking(1.35)
                    .lineSpacing(10)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $draft.text)
                    .font(MeloFonts.zenMaruMedium(15))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .tracking(0.45)
                    .focused($isBodyFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 140, maxHeight: 180)
                    .onChange(of: draft.text) { _, newValue in
                        if newValue.count > maxCharacters {
                            draft.text = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
        }
        .padding(.horizontal, 11)
    }

    // MARK: - Fix #3: Attached images row (directly under body)
    private var attachedImagesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(draft.imagesData.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(textBrown.opacity(0.6), lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(softGray)
                                .frame(width: 80, height: 80)
                        }

                        Button {
                            HapticManager.light()
                            if index < draft.imagesData.count {
                                draft.imagesData.remove(at: index)
                            }
                            if index < photoItems.count {
                                photoItems.remove(at: index)
                            }
                        } label: {
                            ZStack {
                                Circle().fill(Color.black.opacity(0.55))
                                    .frame(width: 20, height: 20)
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Fix #1: Inline poll editor (radius-10 white card, 1pt pink stroke)
    private var pollInlineEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 質問
            TextField(
                String(localized: "質問を書いてね！", bundle: LanguageManager.appBundle),
                text: $pollQuestion
            )
            .font(MeloFonts.zenMaruMedium(14))
            .foregroundColor(MeloColors.Dark.textPrimary)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(softBrown.opacity(0.5))
            )

            // 選択肢
            ForEach(Array(pollOptionTexts.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    Circle()
                        .fill(koiPink.opacity(0.5))
                        .frame(width: 8, height: 8)

                    TextField(
                        String(localized: "選択肢 \(index + 1)", bundle: LanguageManager.appBundle),
                        text: Binding(
                            get: {
                                index < pollOptionTexts.count ? pollOptionTexts[index] : ""
                            },
                            set: { newValue in
                                if index < pollOptionTexts.count {
                                    pollOptionTexts[index] = newValue
                                }
                            }
                        )
                    )
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)

                    if pollOptionTexts.count > 2 {
                        Button {
                            HapticManager.light()
                            withAnimation {
                                if index < pollOptionTexts.count {
                                    pollOptionTexts.remove(at: index)
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(placeholderGray)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(softBrown.opacity(0.5))
                )
            }

            // 選択肢を追加
            if pollOptionTexts.count < maxPollOptions {
                Button {
                    HapticManager.light()
                    withAnimation { pollOptionTexts.append("") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text(String(localized: "選択肢を追加", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(12))
                            .tracking(0.36)
                    }
                    .foregroundColor(koiPink)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(MeloColors.Dark.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(koiPink, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Quoted post preview (引用返信用・V2 デザイン準拠)
    // radius 10 / 1pt #FFD9E1 ストローク、author=Zen Maru Medium 10pt、body=Zen Maru Medium 12pt (2行まで)。
    // ✕ で引用を外して通常投稿に戻せる。
    private func quotedPostPreview(_ quote: QuotedPostInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(koiPink.opacity(0.45))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("@\(quote.authorDisplayName)")
                    .font(MeloFonts.zenMaruMedium(10))
                    .foregroundColor(MeloColors.Dark.textPrimary.opacity(0.85))
                    .tracking(0.3)
                    .lineLimit(1)

                Text(quote.content)
                    .font(MeloFonts.zenMaruMedium(12))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .tracking(0.36)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.15)) {
                    quotedPost = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(placeholderGray)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(softPinkLite.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MeloColors.Dark.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Fix #2: Inline diagnosis preview (radius-10 white card, 1pt pink stroke)
    /// 添付済み診断カードのプレビュー。投稿に表示される実カードと同じ
    /// `BoardDiagnosisCardFull` を使い、見たままが投稿される。
    private func diagnosisInlinePreview(_ card: DiagnosisCard) -> some View {
        ZStack(alignment: .topTrailing) {
            BoardDiagnosisCardFull(card: card)

            Button {
                HapticManager.light()
                withAnimation {
                    selectedDiagnosisCard = nil
                    draft.hasDiagnosis = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Attachment row (Fixes #1, #2, #5)
    // Fix #5: 横スクロールでラベル切れを防ぐ。常に本文/添付の下に表示。
    // 横スクロールではなく、画面幅で折り返してすべてのボタンが常に見える状態に。
    private var attachmentRow: some View {
        BoardComposeFlowLayout(spacing: 8, lineSpacing: 8) {
                // アンケート (Fix #1: インライン編集の表示切替)
                attachmentPillButton(
                    text: String(localized: "アンケートを追加", bundle: LanguageManager.appBundle),
                    selected: draft.hasPoll
                ) {
                    HapticManager.light()
                    withAnimation { draft.hasPoll.toggle() }
                }

                // 画像 — PhotosPicker (ラベル付きピル)
                PhotosPicker(selection: $photoItems, maxSelectionCount: maxImages, matching: .images) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 14, weight: .medium))
                        Text(String(localized: "画像", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(13))
                            .tracking(0.39)
                        if !draft.imagesData.isEmpty {
                            Text("(\(draft.imagesData.count))")
                                .font(MeloFonts.zenMaruMedium(12))
                        }
                    }
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18).fill(softBrown)
                    )
                }

                // 診断結果を追加 → opens DiagnosisPickerView (Fix #2)
                attachmentPillButton(
                    text: String(localized: "診断結果を追加", bundle: LanguageManager.appBundle),
                    selected: draft.hasDiagnosis
                ) {
                    HapticManager.light()
                    showDiagnosisPicker = true
                }

                // ハッシュタグ
                Button {
                    HapticManager.light()
                    withAnimation { showHashtagEditor.toggle() }
                    if showHashtagEditor {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isHashtagFocused = true
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 14, weight: .medium))
                        Text(String(localized: "ハッシュタグ", bundle: LanguageManager.appBundle))
                            .font(MeloFonts.zenMaruMedium(13))
                            .tracking(0.39)
                    }
                    .foregroundColor(showHashtagEditor ? koiPink : MeloColors.Dark.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(showHashtagEditor ? koiPink.opacity(0.15) : softBrown)
                    )
                }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // Fix #5: consistent height 36, font 13, padding 14, fixedSize so label never truncates
    private func attachmentPillButton(text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(selected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
                .tracking(0.39)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(selected ? koiPink : softBrown)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hashtag section (Fix #2: bigger chips)
    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !draft.hashtags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(draft.hashtags, id: \.self) { tag in
                        hashtagChip(tag)
                    }
                }
            }

            if showHashtagEditor {
                HStack(spacing: 6) {
                    Text("#")
                        .font(MeloFonts.zenMaruMedium(14))
                        .foregroundColor(koiPink)
                    TextField(
                        String(localized: "タグを入力（例: 片思い相談）", bundle: LanguageManager.appBundle),
                        text: $hashtagInput
                    )
                    .font(MeloFonts.zenMaruMedium(14))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .focused($isHashtagFocused)
                    .submitLabel(.done)
                    .onSubmit { commitHashtag() }
                    if !hashtagInput.isEmpty {
                        Button {
                            commitHashtag()
                        } label: {
                            Text(String(localized: "追加", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(13))
                                .foregroundColor(MeloColors.Dark.onAccent)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(Capsule().fill(koiPink))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    Capsule().stroke(chipBorder, lineWidth: 0.5)
                )
            }

            if !draft.hashtags.isEmpty || showHashtagEditor {
                Text("\(draft.hashtags.count)/\(maxHashtags)")
                    .font(MeloFonts.zenMaruMedium(10))
                    .foregroundColor(placeholderGray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func hashtagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(koiPink)
            Button {
                draft.hashtags.removeAll { $0 == tag }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(placeholderGray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Capsule().fill(koiPink.opacity(0.1)))
        .overlay(Capsule().stroke(koiPink.opacity(0.3), lineWidth: 0.5))
    }

    private func commitHashtag() {
        let trimmed = hashtagInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        // IME (日本語入力) の未確定文字を確実にフラッシュするため、フォーカスを外す。
        isHashtagFocused = false
        guard !trimmed.isEmpty,
              !draft.hashtags.contains(trimmed),
              draft.hashtags.count < maxHashtags else {
            hashtagInput = ""
            DispatchQueue.main.async { self.hashtagInput = "" }
            return
        }
        draft.hashtags.append(trimmed)
        hashtagInput = ""
        // SwiftUI の TextField は IME 確定タイミングで再描画されるため、
        // 次の runloop でも空文字を再投入しておく (取りこぼしを防止)。
        DispatchQueue.main.async { self.hashtagInput = "" }
    }

    // MARK: - Theme picker sheet
    private var themePickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "テーマを選ぶ（最大\(maxThemes)つ）", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(16))
                    .foregroundColor(MeloColors.Dark.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    FlowLayout(spacing: 10) {
                        ForEach(PostTheme.allCases) { theme in
                            let isSelected = draft.themes.contains(theme)
                            Button {
                                if isSelected {
                                    draft.themes.remove(theme)
                                } else if draft.themes.count < maxThemes {
                                    draft.themes.insert(theme)
                                }
                            } label: {
                                Text(theme.label)
                                    .font(MeloFonts.zenMaruMedium(14))
                                    .foregroundColor(isSelected ? MeloColors.Dark.onAccent : MeloColors.Dark.textPrimary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 36)
                                    .background(
                                        Capsule().fill(isSelected ? koiPink : MeloColors.Dark.bgElevated)
                                    )
                                    .overlay(
                                        Capsule().stroke(isSelected ? Color.clear : chipBorder, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完了", bundle: LanguageManager.appBundle)) {
                        showThemePicker = false
                    }
                    .font(MeloFonts.zenMaruOrFallback(15))
                    .foregroundColor(koiPink)
                }
            }
        }
    }

    // MARK: - MBTI picker sheet (Fix #4)
    private var mbtiPickerSheet: some View {
        let mbtiTypes = [
            "INTJ", "INTP", "ENTJ", "ENTP",
            "INFJ", "INFP", "ENFJ", "ENFP",
            "ISTJ", "ISFJ", "ESTJ", "ESFJ",
            "ISTP", "ISFP", "ESTP", "ESFP"
        ]
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String(localized: "MBTIを選択", bundle: LanguageManager.appBundle))
                        .font(MeloFonts.zenMaruOrFallback(16))
                        .foregroundColor(MeloColors.Dark.textPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(mbtiTypes, id: \.self) { mbti in
                            mbtiGridCell(mbti)
                        }
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "完了", bundle: LanguageManager.appBundle)) {
                        showMbtiPicker = false
                    }
                    .foregroundColor(koiPink)
                }
            }
        }
    }

    private func mbtiGridCell(_ mbti: String) -> some View {
        let isSelected = (resolvedMbtiCode == mbti)
        let fillColor: Color = isSelected ? MeloColors.mbtiColor(for: mbti) : MeloColors.Dark.bgElevated
        return Button {
            manualMbtiCode = mbti
            draft.showsMbti = true
            showMbtiPicker = false
        } label: {
            Text(mbti)
                .font(MeloFonts.zenMaruMedium(13))
                .foregroundColor(isSelected ? .white : MeloColors.Dark.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(fillColor)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Diagnosis source (for Fix #4)
    private var uniqueResults: [StoredAnalysisResult] {
        var seen = Set<UUID>()
        return analysisHistory.filter { result in
            guard result.period == "all" else { return false }
            guard !seen.contains(result.sessionId) else { return false }
            seen.insert(result.sessionId)
            return true
        }
    }

    // MARK: - Photo loading
    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items.prefix(maxImages) {
            guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
            // 端末で先に圧縮 (長辺 1600px / JPEG quality 0.7)。
            // R2 egress (画像配信帯域) を抑える主目的、加えてアップロード時間と端末メモリも軽くなる。
            let compressed = await Task.detached(priority: .userInitiated) {
                ImageCompressor.compressForPost(raw)
            }.value
            loaded.append(compressed ?? raw)
        }
        await MainActor.run {
            draft.imagesData = loaded
        }
    }
}

// MARK: - Helpers
private struct BoardComposeV2RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    BoardComposeViewV2()
}
