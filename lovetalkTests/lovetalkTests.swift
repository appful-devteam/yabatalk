//
//  lovetalkTests.swift
//  lovetalkTests
//
//  Created by 岡本隆誠 on 1/7/26.
//

import Testing
import Foundation
@testable import yabatalk

struct lovetalkTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testGroupCallDetection() async throws {
        // グループ通話を含むサンプルデータ（スペース区切り）
        let sampleContent = """
        [LINE] テストグループのトーク履歴

        2026/02/15(土)
        00:17 りゅうせい 画像
        01:38 SHUNPEI グループ通話が終了しました。
        14:17 りゅうせい グループ通話が開始されました
        15:39 りゅうせい グループ通話が終了しました。
        19:01 SHUNPEI グループ通話が開始されました
        19:01 SHUNPEI グループ通話が終了しました。
        20:00 りゅうせい テスト
        """

        let parser = LineChatParser()
        let session = try parser.parse(sampleContent)

        // グループ通話が .call イベントとしてカウントされていることを確認
        let callMessages = session.messages.filter { $0.eventType == .call }
        #expect(callMessages.count == 3, "グループ通話終了が3回あるので3回カウント")

        // グループ通話開始は .system（二重カウント防止）
        let systemMessages = session.messages.filter { $0.eventType == .system }
        let groupCallStarts = systemMessages.filter { $0.content.contains("グループ通話が開始されました") }
        #expect(groupCallStarts.count == 2, "グループ通話開始は2回")

        // 参加者のcallCountも更新されていること
        let totalCallCount = session.participants.reduce(0) { $0 + $1.callCount }
        #expect(totalCallCount == 3, "参加者の通話カウント合計が3")

        // 通話時間が計算されていること（14:17→15:39 = 82分 = 4920秒）
        let callWithDuration = callMessages.first { $0.callDurationSeconds != nil && $0.callDurationSeconds! > 0 }
        #expect(callWithDuration != nil, "通話時間が計算されているものがある")
        if let duration = callWithDuration?.callDurationSeconds {
            #expect(duration == 4920, "14:17→15:39 = 82分 = 4920秒")
        }
    }

    @Test func testGroupCallDetectionExactFileFormat() async throws {
        // 実際のファイルと同じ形式（日付行がパーサーに認識されない形式）
        let sampleContent = """
        [LINE] appfulのトーク履歴

        2026.02.15 日曜日
        00:17 りゅうせい 画像
        01:38 SHUNPEI グループ通話が終了しました。
        14:17 りゅうせい グループ通話が開始されました
        15:39 りゅうせい グループ通話が終了しました。
        19:01 SHUNPEI グループ通話が開始されました
        19:01 SHUNPEI グループ通話が終了しました。
        20:00 りゅうせい テスト
        20:01 SHUNPEI テスト
        20:02 ちさと_chisato テスト
        """

        let parser = LineChatParser()
        let session = try parser.parse(sampleContent)

        let callMessages = session.messages.filter { $0.eventType == .call }
        #expect(callMessages.count == 3, "グループ通話終了3回 → .call 3個。実際: \(callMessages.count)")

        let totalCallCount = session.participants.reduce(0) { $0 + $1.callCount }
        #expect(totalCallCount == 3, "参加者通話カウント合計3。実際: \(totalCallCount)")
    }

    @Test func testGroupCallDetectionTabDelimited() async throws {
        // タブ区切りのグループ通話
        let sampleContent = """
        [LINE] テストグループのトーク履歴

        2026/02/15(土)
        00:17\tりゅうせい\t画像
        01:38\tSHUNPEI\tグループ通話が終了しました。
        14:17\tりゅうせい\tグループ通話が開始されました
        15:39\tりゅうせい\tグループ通話が終了しました。
        20:00\tりゅうせい\tテスト
        """

        let parser = LineChatParser()
        let session = try parser.parse(sampleContent)

        let callMessages = session.messages.filter { $0.eventType == .call }
        #expect(callMessages.count == 2, "グループ通話終了が2回")

        let totalCallCount = session.participants.reduce(0) { $0 + $1.callCount }
        #expect(totalCallCount == 2, "参加者の通話カウント合計が2")
    }

    @Test func testScoreCalculation() async throws {
        // サンプルLINEチャットデータ
        let sampleContent = """
        [LINE] テストとのトーク履歴
        保存日時：2025/01/01 12:00

        2025/01/01(水)
        10:00\t自分\tおはよう
        10:05\t相手\tおはよう！
        10:06\t自分\t今日何してる？
        10:10\t相手\t特に予定ないよ
        10:11\t相手\t一緒に遊ばない？
        10:15\t自分\tいいね！
        10:16\t自分\tどこ行く？
        10:20\t相手\tカフェとかどう？
        """

        // パーサーで解析
        let parser = LineChatParser()
        let session = try parser.parse(sampleContent)

        // 参加者確認
        #expect(session.participants.count == 2)
        #expect(session.totalMessageCount >= 8)

        // 分析実行
        let useCase = AnalyzeChatUseCase()
        let result = try await useCase.analyze(
            session: session,
            period: .all,
            confirmedSelfName: "自分"
        )

        // スコアが妥当な範囲にあるかチェック
        #expect(result.totalScore >= 0 && result.totalScore <= 100)
        #expect(result.axisScore.balanceScore >= 0 && result.axisScore.balanceScore <= 100)
        #expect(result.axisScore.tensionScore >= 0 && result.axisScore.tensionScore <= 100)
        #expect(result.axisScore.responseScore >= 0 && result.axisScore.responseScore <= 100)
        #expect(result.axisScore.wordScore >= 0 && result.axisScore.wordScore <= 100)

        // totalScoreは4軸平均をスケーリング
        let rawTotal = (result.axisScore.balanceScore + result.axisScore.tensionScore + result.axisScore.responseScore + result.axisScore.wordScore) / 4
        let expectedTotal = max(0, min(100, (rawTotal - 30.0) / 50.0 * 100.0))
        #expect(abs(result.totalScore - expectedTotal) < 0.1)
    }
}
