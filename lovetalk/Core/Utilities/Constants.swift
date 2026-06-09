import Foundation

enum Constants {
    // MARK: - App Info
    enum App {
        static let name = "ハラスメントーク"
        static let version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        static let build: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let bundleId = "appful.yabatalk"
        static let supportEmail = "info@appful.tokyo"
        /// 強制アップデート画面で開く App Store URL。Remote Config `force_update_config`
        /// の `app_store_url` を設定するとこちらより優先される。
        static let defaultAppStoreURL = "https://apps.apple.com/jp/app/id6757545135"
    }

    // MARK: - Analysis
    enum Analysis {
        /// 会話ブロックを分割する間隔（秒）
        static let blockGapThreshold: TimeInterval = 60 * 60 // 60分

        /// 追いトークと判定する連続送信数
        static let chaseMessageThreshold = 5

        /// 信頼度が低いと判定するメッセージ数
        static let lowConfidenceMessageThreshold = 50

        /// 分析に必要な最小メッセージ数
        static let minimumMessagesRequired = 20

        /// 分析期間（日数）
        enum Period {
            static let week = 7
            static let month = 30
        }

        /// スコアのしきい値
        enum ScoreThreshold {
            /// 軸の二値化しきい値
            static let axisThreshold: Double = 50.0

            /// 信頼度のしきい値
            static let confidenceLow: Double = 0.5
            static let confidenceMedium: Double = 0.7
            static let confidenceHigh: Double = 0.85
        }
    }

    // MARK: - Time Periods
    enum TimePeriod {
        /// 夜間開始時刻
        static let nightStartHour = 22

        /// 夜間終了時刻（翌日）
        static let nightEndHour = 2

        /// 深夜開始時刻
        static let lateNightStartHour = 0

        /// 深夜終了時刻
        static let lateNightEndHour = 5
    }

    // MARK: - UI
    enum UI {
        /// アニメーション時間
        enum Animation {
            static let fast: Double = 0.2
            static let standard: Double = 0.3
            static let slow: Double = 0.5
            static let analyzing: Double = 2.0
        }

        /// 角丸
        enum CornerRadius {
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
            static let extraLarge: CGFloat = 32
        }

        /// スペーシング
        enum Spacing {
            static let xs: CGFloat = 4
            static let sm: CGFloat = 8
            static let md: CGFloat = 16
            static let lg: CGFloat = 24
            static let xl: CGFloat = 32
        }

        /// レーダーチャート
        enum RadarChart {
            static let defaultSize: CGFloat = 200
            static let levels = 5
            static let axes = 4
        }
    }

    // MARK: - Storage Keys
    enum StorageKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let surveyCompletedVersion = "surveyCompletedVersion"
        static let surveyAge = "surveyAge"
        static let surveyGender = "surveyGender"
        static let surveySource = "surveySource"
        static let analysisCompletedCount = "analysisCompletedCount"
        static let lastReviewRequestDate = "lastReviewRequestDate"
        static let reviewAppVersion = "reviewAppVersion"
        static let appLanguage = "appLanguage"
        static let pipelineDebugEnabled = "pipelineDebugEnabled"
        static let devSectionUnlocked = "devSectionUnlocked"
        static let hasAgreedToTerms = "hasAgreedToTerms"
        static let hasPerformedSessionMerge = "hasPerformedSessionMerge"
        static let hasSeenExpandHint = "hasSeenExpandHint"
        static let pushPermissionRequested = "pushPermissionRequested"
        static let pushPermissionGranted = "pushPermissionGranted"
        static let apnsDeviceToken = "apnsDeviceToken"
        static let announcementDisplayStates = "announcementDisplayStates"
        static let hasSeenConsultationTutorial = "hasSeenConsultationTutorial"
        static let hasSeenPersonaChatTutorial = "hasSeenPersonaChatTutorial"
        /// めろまるがユーザーを呼ぶ名前（ニックネーム）。設定 > プロフィールで編集可能。
        /// 「とりあえず話す」のように selfName が分析履歴から取れない場面で使われる。
        static let userPreferredName = "userPreferredName"
        /// 「とりあえず話す」(resultId なし) フローのセッション履歴。
        /// 結果紐付けの履歴は SwiftData (StoredAnalysisResult) に入るが、こちらは
        /// 紐付け先が無いため UserDefaults に [ReplySession] を JSON で保存する。
        static let generalConsultationSessions = "general_consultation_sessions"
        /// 「とりあえず話す」フローの進行中セッションのエントリ。クラッシュ復帰用の flat history。
        static let generalConsultationCurrentEntries = "general_consultation_current_entries"
        /// 相談機能を初めてタップした時の「呼び名入力ポップアップ」を 1 回だけ表示するためのフラグ。
        /// true = 既に表示済み (もう出さない)。
        static let hasSeenPreferredNamePrompt = "hasSeenPreferredNamePrompt"
        /// 診断 CTA / ファイルを開く タップ時に表示する「使い方はわかりますか？」ポップアップを今後表示しない
        static let suppressUsageGuidePrompt = "suppress_usage_guide_prompt"

        // 通知設定
        static let notifyReplies = "notifyReplies"
        static let notifyReactions = "notifyReactions"
        static let notifyNewFollowers = "notifyNewFollowers"
        static let notifyFollowingPosts = "notifyFollowingPosts"
    }

    // MARK: - Remote Config Keys
    enum RemoteConfigKeys {
        static let inAppAnnouncements = "in_app_announcements"
        /// 強制アップデートの設定を JSON で 1 行にまとめた value。
        /// 値が空 / null / 不正 JSON = 強制アップデート OFF (デフォルト)。
        ///
        /// 例:
        /// ```json
        /// {
        ///   "minimum_version": "2.3",
        ///   "app_store_url": "https://apps.apple.com/jp/app/id1234567890",
        ///   "message": "新機能追加のため最新版に更新してください"
        /// }
        /// ```
        /// minimum_version 未満で起動した場合、全画面ロック画面に遷移する。
        static let forceUpdateConfig = "force_update_config"
        /// 全広告（バナー / App Open / Rewarded）の ON/OFF。
        /// デフォルト false（公開前は広告なし）。ストア公開後に Console で true に切り替える。
        /// ⚠️ darkめろとーくと同一 Firebase プロジェクトを共有するため、**やばトーク専用キー**。
        /// （RemoteConfig はプロジェクト単位 → アプリ別キーで独立制御。darkめろとーく=ads_enabled）
        static let adsEnabled = "ads_enabled_yabatalk"
    }

    // MARK: - Validation
    enum Validation {
        /// ファイルサイズ上限（バイト）
        static let maxFileSize = 20 * 1024 * 1024 // 20MB

        /// 許可されるファイル拡張子
        static let allowedExtensions = ["txt"]
    }

    // MARK: - Supabase (将来用)
    enum Supabase {
        static let projectUrl = "https://jsjrttkuzexjkkuzcnuq.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpzanJ0dGt1emV4amtrdXpjbnVxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2Mjk1MjksImV4cCI6MjA4NjIwNTUyOX0.fco5cQ81MJDzm6Jp0CiHgKwx0-M6tJtzDcU81shx2qA"
    }
}
