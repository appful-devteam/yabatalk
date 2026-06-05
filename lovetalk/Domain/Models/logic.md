#ロジック

めろとーく 計算ロジック（完成版）
0. 前処理（全軸共通）
0-1. 期間フィルタ

periodEnd = ログ内の最終イベント日時

全期間：全件

30日：periodEnd - 30日 以降

7日：periodEnd - 7日 以降

0-2. テキスト/イベントの定義

textMessage：EventType.text のみ（メッセ数に含める）

mediaEvent：写真/動画（別カウント）

stickerEvent：スタンプ（別カウント）

callEvent：通話時間あり/なし、missed（別カウント）

0-3. 会話ブロック（Session）

直前イベントから 60分以内 → 同一Session

60分超 → 新Session

sessionStarter = session内最初の テキスト送信者（テキストが無ければ最初のイベント送信者）

0-4. 追いトーク（Chase）

「相手から返信がない状態で、自分が連続送信した」回数

テキストのみ対象

連投は 最大5通まで同一ターン扱い

6通目以降を “追い増分” として加算

追いは 相手側も同様に計測する（差/比率で使う）

0-5. 低データガード

N_text < 20：診断不可（UIで「まだ材料が少ないかも」）

20 ≤ N_text < 80：スコアを中心(50)へ縮める（shrink）

Shrink係数

k = (N_text - 20) / 60（20→0, 80→1）

Score = 50 + (Score - 50) * clamp(k, 0...1)

1. Volume（量）— B / U

目的：やり取りの「偏りの強さ」を測る（Balanced=偏り小）

指標（3つ：冗長を排除）

送信量偏り

p_msg = myText / (myText + otherText)

Session開始偏り

p_start = mySessionStart / (mySessionStart + otherSessionStart)

追いトーク偏り

p_chase = myChase / (myChase + otherChase)
※両方0なら p_chase = 0.5

偏りの大きさ（0〜1）

d(p) = 2 * abs(p - 0.5)（0=完全均等、1=片寄りMAX）

合成（偏り）

重み：

送信量 45%

開始 35%

追い 20%

bias = 0.45*d(p_msg) + 0.35*d(p_start) + 0.20*d(p_chase)

スコア（0〜100）

VolumeScore = 100 * (1 - bias)

二値化

VolumeScore >= 55 → B

< 55 → U

2. Temperature（温度）— W / C

目的：踏み込みの「熱量の強さ」を測る
※夜密度を主因にしない（W偏り対策）

2-1. 感情記号密度（0〜100）

カウント対象（例）

絵文字（unicode emoji）

！ ？

笑 w 草

♡ ♥ ハート

emotionRate = emotionCount / max(textCharCount, 1)

正規化（ロバスト）

Emotion = percentileNormalize(emotionRate)（0〜100）

実装簡易版：Emotion = clamp( (emotionRate / T_emotion) * 100, 0...100 )

T_emotion は固定（例 0.03）でOK

2-2. 深さ（0〜100）

avgLen = 平均文字数

longRate = 30文字以上の割合

Depth = 0.6*norm(avgLen) + 0.4*norm(longRate)（0〜100）

2-3. 通話（0〜100）

callPerWeek = callCount / max(weeksInPeriod, 1)

missedCallは 0.3倍で加算

Call = norm(callPerWeek)（0〜100）

2-4. メディア（0〜100）

mediaPerWeek = (photo+video) / max(weeksInPeriod, 1)

Media = norm(mediaPerWeek)（0〜100）

2-5. 夜ブースト（0〜+10点）

nightRatio = nightTextCount(22-02) / max(totalText, 1)

NightBoost = clamp( (nightRatio - 0.15) / 0.25 * 10 , 0...10 )

15%以下はブーストなし

40%で最大+10

合成（0〜100）

重み（合計1.0）：

感情記号 35%

深さ 25%

通話 25%

メディア 15%

TempBase = 0.35*Emotion + 0.25*Depth + 0.25*Call + 0.15*Media

TempScore = clamp(TempBase + NightBoost, 0...100)

二値化

TempScore >= 58 → W

< 58 → C

3. Rhythm（リズム）— S / J

目的：波の「強さ」を測る
※日別CVだけだとJに寄るので、ブロック間隔を入れてロバスト化

3-1. 日別波（0〜100）

dailyCounts[]（日ごとのtext数）

cv = std(dailyCounts)/mean(dailyCounts)（mean=0ならcv=0）

ロバスト化：cv2 = log(1 + cv)

DailyWave = norm(cv2)（高いほど波が大きい）

3-2. Session間隔波（0〜100）

session開始時刻の差分（hours）配列 gaps[]

gapRobust = IQR(gaps) / max(median(gaps), eps)

SessionGapWave = norm(gapRobust)

3-3. 返信一貫性（0〜100）

“返信”は「相手→自分の次の自分発言」時間差（最大24hでクリップ）

replyStd = std(replyTimes) / median(replyTimes)（ロバスト）

ReplyWave = norm(replyStd)

合成（波の強さ）

重み：

日別 35%

間隔 45%

返信 20%

Jumpy = 0.35*DailyWave + 0.45*SessionGapWave + 0.20*ReplyWave

スコア（高いほど安定）

RhythmScore = 100 * (1 - Jumpy/100)

二値化

RhythmScore >= 55 → S

< 55 → J

4. Structure（構造）— F / L

目的：「どっちが主導か」ではなく、役割が固定されているかを見る
※これが偏り改善の最重要

4-1. 全体の偏り（差の大きさ）

各指標の p を計算して diff = 2*abs(p-0.5)

対象：

Session開始：p_start

質問率：p_q = myQuestions / (myQuestions + otherQuestions)（?の数でOK）

提案率：簡易辞書マッチ（「行こ」「いつ」「どうする」「会う」「予約」「決めよ」等）

p_prop = myPropose / (myPropose + otherPropose)

diffStart, diffQ, diffProp（0〜1）

4-2. 固定性（時間一貫性）

期間を週単位に分割して、各週の p の分散を見る。

varStartWeek varQWeek varPropWeek

固定性：consistency = 1 - norm(variance)（0〜1）

4-3. Fix（固定の強さ）を作る（0〜1）

FixX = 0.6*diffX + 0.4*(1 - varX_norm)

合成（Leadの強さ）

重み：

開始 45%

質問 30%

提案 25%

LeadStrength = 0.45*FixStart + 0.30*FixQ + 0.25*FixProp（0〜1）

スコア（高いほどFree=入れ替わる）

StructureScore = 100 * (1 - LeadStrength)

二値化

StructureScore >= 55 → F

< 55 → L

5. 16タイプ決定

code = [B/U][W/C][S/J][F/L]

RelationshipType(rawValue: code) に変換

6. 追加：境界（揺れ）扱いで正確さUP（推奨）

二値化境界付近（55±3）を「揺れ」として内部に保持：

if abs(Score - 55) < 3 → borderline

borderline軸が多いほど confidence を少し下げる

表示は基本1タイプ、confidence低い時のみ「近いタイプ」を薄く表示（任意）

まとめ（このロジックの狙い）

BWJF / BWJLに寄るバイアス（JとWとLの過剰）を潰した

小データで暴れる指標を shrink で抑えて 誤判定を減らす

Structureを「主導」から「固定性」に変えて F/Lがちゃんと散る
