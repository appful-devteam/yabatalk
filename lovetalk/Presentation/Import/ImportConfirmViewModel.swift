import Foundation
import SwiftUI

// MARK: - Import Confirm View Model
@MainActor
final class ImportConfirmViewModel: ObservableObject {
    // MARK: - Properties
    private(set) var session: ChatSession

    /// ユーザーが選択した自分の名前
    @Published var selectedSelfName: String

    /// ユーザーが選択した相手との関係性。必須選択。
    /// `nil` のまま分析開始は不可（UI 側で disabled）。
    @Published var selectedRelationship: RelationshipContext?

    // MARK: - Computed Properties

    /// 選択された自分
    var selfParticipant: ChatParticipant? {
        session.participants.first { $0.name == selectedSelfName }
    }

    /// グループチャットかどうか
    var isGroupChat: Bool {
        session.participants.count > 2
    }

    /// 相手（自分以外）— 1対1用
    var partnerParticipant: ChatParticipant? {
        session.participants.first { $0.name != selectedSelfName }
    }

    /// 相手の名前（グループ時は全メンバー名を「・」区切り）
    var partnerName: String {
        if isGroupChat {
            return session.participants
                .filter { $0.name != selectedSelfName }
                .map(\.name)
                .joined(separator: "・")
        }
        return partnerParticipant?.name ?? ""
    }

    /// 自分の名前（選択された）
    var selfName: String {
        selectedSelfName
    }

    /// 分析開始ボタンを押せるか。関係性が必須。
    var canStartAnalysis: Bool {
        !selectedSelfName.isEmpty && selectedRelationship != nil
    }

    /// 分析開始直前に呼ばれる。関係性と自分名を詰めた新しい ChatSession を返す。
    /// 呼び出し側はこの session を navigateToAnalyzing に渡す。
    func sessionForAnalysis() -> ChatSession? {
        guard let relationship = selectedRelationship else { return nil }
        var s = session
        s.estimatedSelfName = selectedSelfName
        s.relationship = relationship
        return s
    }

    // MARK: - Initialization

    init(session: ChatSession) {
        self.session = session

        // 初期値：ファイル名から推定された自分、またはフォールバック
        if let estimated = session.estimatedSelfName,
           session.participants.contains(where: { $0.name == estimated }) {
            self.selectedSelfName = estimated
        } else {
            // フォールバック：2番目の参加者を自分とする
            self.selectedSelfName = session.participants.last?.name ?? ""
        }
        // 関係性は事前選択なし（ユーザーが意識的に選ぶ）
        self.selectedRelationship = nil
    }

    // MARK: - Methods

    /// 自分を選択
    func selectSelf(_ name: String) {
        selectedSelfName = name
    }

    /// 関係性を選択
    func selectRelationship(_ relationship: RelationshipContext) {
        selectedRelationship = relationship
    }
}
