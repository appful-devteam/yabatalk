import SwiftUI

// MARK: - Survey Colors (NewHome tokens)
private enum SurveyColors {
    static let brandPink = MeloColors.Brand.pink
    static let filledPink = MeloColors.Brand.pink
    static let softPink = MeloColors.Brand.pinkLight
    static let softFieldBg = MeloColors.Surface.pinkPale
    static let brownStroke = MeloColors.Text.primary
    static let textPrimary = MeloColors.Text.primary
    static let textBody = MeloColors.Text.primary
    static let textMuted = MeloColors.Text.secondary
    static let textFaint = MeloColors.Text.secondary
    static let divider = MeloColors.Gray.subButtonLight
}

// MARK: - Survey Option Models
private enum SurveyAge: String, CaseIterable {
    case elementary
    case middleSchool
    case highSchool
    case college
    case working
    case partTime

    var displayName: String {
        switch self {
        case .elementary: return String(localized: "survey_age_elementary", bundle: LanguageManager.appBundle)
        case .middleSchool: return String(localized: "survey_age_middle_school", bundle: LanguageManager.appBundle)
        case .highSchool: return String(localized: "survey_age_high_school", bundle: LanguageManager.appBundle)
        case .college: return String(localized: "survey_age_college", bundle: LanguageManager.appBundle)
        case .working: return String(localized: "survey_age_working", bundle: LanguageManager.appBundle)
        case .partTime: return String(localized: "survey_age_part_time", bundle: LanguageManager.appBundle)
        }
    }

    /// サーバー送信用の固定値（言語に依存しない）
    var serverValue: String {
        switch self {
        case .elementary: return "小学生"
        case .middleSchool: return "中学生"
        case .highSchool: return "高校生"
        case .college: return "大学・専門学生"
        case .working: return "社会人"
        case .partTime: return "アルバイト・無職"
        }
    }
}

private enum SurveyGender: String, CaseIterable {
    case female
    case male
    case other

    var displayName: String {
        switch self {
        case .female: return String(localized: "survey_gender_female", bundle: LanguageManager.appBundle)
        case .male: return String(localized: "survey_gender_male", bundle: LanguageManager.appBundle)
        case .other: return String(localized: "survey_gender_other", bundle: LanguageManager.appBundle)
        }
    }

    var serverValue: String {
        switch self {
        case .female: return "女性"
        case .male: return "男性"
        case .other: return "その他"
        }
    }
}

private enum SurveySource: String, CaseIterable {
    case tiktok
    case instagram
    case youtube
    case friend
    case appStore
    case other

    var displayName: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .friend: return String(localized: "survey_source_friend", bundle: LanguageManager.appBundle)
        case .appStore: return String(localized: "survey_source_app_store", bundle: LanguageManager.appBundle)
        case .other: return String(localized: "survey_source_other", bundle: LanguageManager.appBundle)
        }
    }

    var serverValue: String {
        switch self {
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        case .friend: return "友達の紹介"
        case .appStore: return "アプリストア"
        case .other: return "その他"
        }
    }
}

// MARK: - Onboarding Survey View
struct OnboardingSurveyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var selectedAge: SurveyAge?
    @State private var selectedGender: SurveyGender?
    @State private var selectedSource: SurveySource?

    var body: some View {
        ZStack {
            // Background — フラット白
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                // 2D mascot (yahho)
                Image("char_meromaru_3d")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)
                    .padding(.top, 4)

                // Title
                Text(String(localized: "survey_title", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(22))
                    .foregroundColor(SurveyColors.textPrimary)
                    .padding(.top, 14)

                Text(String(localized: "survey_subtitle", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruOrFallback(13))
                    .foregroundColor(SurveyColors.textBody)
                    .padding(.top, 6)

                // Page indicator
                pageIndicator
                    .padding(.top, 18)

                // Content pages
                TabView(selection: $currentPage) {
                    agePage.tag(0)
                    genderPage.tag(1)
                    sourcePage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()
            }
        }
    }

    // MARK: - Age Page
    private var agePage: some View {
        surveyPage(
            question: String(localized: "survey_age_question", bundle: LanguageManager.appBundle),
            options: SurveyAge.allCases.map { ($0.displayName, $0) },
            selected: selectedAge
        ) { value in
            selectedAge = value
            advanceToNext()
        }
    }

    // MARK: - Gender Page
    private var genderPage: some View {
        surveyPage(
            question: String(localized: "survey_gender_question", bundle: LanguageManager.appBundle),
            options: SurveyGender.allCases.map { ($0.displayName, $0) },
            selected: selectedGender
        ) { value in
            selectedGender = value
            advanceToNext()
        }
    }

    // MARK: - Source Page
    private var sourcePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(String(localized: "survey_source_question", bundle: LanguageManager.appBundle))
                    .font(MeloFonts.zenMaruMedium(17))
                    .foregroundColor(SurveyColors.textPrimary)
                    .padding(.top, 20)

                VStack(spacing: 10) {
                    ForEach(SurveySource.allCases, id: \.self) { source in
                        optionButton(
                            title: source.displayName,
                            isSelected: selectedSource == source
                        ) {
                            selectedSource = source
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Start button (shown after selecting source) — flat pink pill
                if selectedSource != nil {
                    Button {
                        HapticManager.medium()
                        submitAndDismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(localized: "survey_start_button", bundle: LanguageManager.appBundle))
                                .font(MeloFonts.zenMaruMedium(16))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(SurveyColors.filledPink)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                Spacer().frame(height: 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Shared Survey Page
    private func surveyPage<T: Equatable>(
        question: String,
        options: [(displayName: String, value: T)],
        selected: T?,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(question)
                    .font(MeloFonts.zenMaruMedium(17))
                    .foregroundColor(SurveyColors.textPrimary)
                    .padding(.top, 20)

                VStack(spacing: 10) {
                    ForEach(0..<options.count, id: \.self) { index in
                        let option = options[index]
                        optionButton(
                            title: option.displayName,
                            isSelected: selected == option.value
                        ) {
                            onSelect(option.value)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Option Button (white + 1pt stroke / pink filled when selected)
    private func optionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(MeloFonts.zenMaruMedium(15))
                    .foregroundColor(isSelected ? .white : SurveyColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? SurveyColors.filledPink : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? SurveyColors.brandPink : SurveyColors.brownStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page Indicator
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? SurveyColors.brandPink : SurveyColors.textFaint.opacity(0.4))
                    .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Methods
    private func advanceToNext() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentPage += 1
            }
        }
    }

    private func submitAndDismiss() {
        // サーバー送信用の固定日本語値
        let ageValue = selectedAge?.serverValue
        let genderValue = selectedGender?.serverValue
        let sourceValue = selectedSource?.serverValue

        // Save to UserDefaults（serverValueで保存）
        let defaults = UserDefaults.standard
        defaults.set(Constants.App.version, forKey: Constants.StorageKeys.surveyCompletedVersion)
        if let age = ageValue {
            defaults.set(age, forKey: Constants.StorageKeys.surveyAge)
        }
        if let gender = genderValue {
            defaults.set(gender, forKey: Constants.StorageKeys.surveyGender)
        }
        if let source = sourceValue {
            defaults.set(source, forKey: Constants.StorageKeys.surveySource)
        }

        AnalyticsManager.shared.track("onboarding_survey_complete", properties: [
            "age": ageValue ?? "",
            "gender": genderValue ?? "",
            "source": sourceValue ?? ""
        ])

        Task {
            await AppDataFirestoreService.shared.saveSurvey(
                age: ageValue,
                gender: genderValue,
                source: sourceValue
            )
        }

        dismiss()
    }
}

// MARK: - Preview
#Preview {
    OnboardingSurveyView()
}
