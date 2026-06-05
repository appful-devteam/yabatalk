import Foundation

enum StatisticsHelper {
    // MARK: - Basic Statistics

    /// 平均値
    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// 中央値
    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }

    /// 分散
    static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let sumSquaredDiff = values.reduce(0) { $0 + pow($1 - avg, 2) }
        return sumSquaredDiff / Double(values.count - 1)
    }

    /// 標準偏差
    static func standardDeviation(_ values: [Double]) -> Double {
        sqrt(variance(values))
    }

    /// 最小値
    static func min(_ values: [Double]) -> Double {
        values.min() ?? 0
    }

    /// 最大値
    static func max(_ values: [Double]) -> Double {
        values.max() ?? 0
    }

    /// 範囲
    static func range(_ values: [Double]) -> Double {
        max(values) - min(values)
    }

    // MARK: - Z-Score

    /// Z-scoreを計算
    static func zScore(value: Double, mean: Double, stdDev: Double) -> Double {
        guard stdDev > 0 else { return 0 }
        return (value - mean) / stdDev
    }

    /// 配列内の各値のZ-scoreを計算
    static func zScores(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let avg = mean(values)
        let stdDev = standardDeviation(values)
        guard stdDev > 0 else {
            return values.map { _ in 0 }
        }
        return values.map { zScore(value: $0, mean: avg, stdDev: stdDev) }
    }

    // MARK: - Normalization

    /// 0〜100にスケーリング（Z-scoreベース）
    /// Z-score -2〜+2 を 0〜100 にマッピング
    static func normalizeToPercentage(zScore: Double) -> Double {
        // Z-score -2 → 0, +2 → 100
        let clamped = Swift.max(-2, Swift.min(2, zScore))
        return (clamped + 2) / 4 * 100
    }

    /// 0〜100にスケーリング（Min-Max正規化）
    static func minMaxNormalize(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 50 }
        let normalized = (value - min) / (max - min)
        return Swift.max(0, Swift.min(100, normalized * 100))
    }

    /// 比率を0〜100に変換（0.5を中心に）
    /// ratio: 0〜1（0.5が均衡）
    /// 0.5 → 50, 0 or 1 → 0 or 100
    static func ratioToBalanceScore(_ ratio: Double) -> Double {
        // 0.5からの距離を計算
        let deviation = abs(ratio - 0.5)
        // 距離が小さいほど高スコア（バランスが良い）
        // deviation 0 → 100, deviation 0.5 → 0
        return (1 - deviation * 2) * 100
    }

    /// 比率を0〜100に変換（高いほど高スコア）
    static func ratioToScore(_ ratio: Double) -> Double {
        Swift.max(0, Swift.min(100, ratio * 100))
    }

    // MARK: - Percentile

    /// パーセンタイル値を計算
    static func percentile(_ values: [Double], percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = (percentile / 100) * Double(sorted.count - 1)
        let lower = Int(floor(index))
        let upper = Int(ceil(index))

        if lower == upper {
            return sorted[lower]
        }

        let fraction = index - Double(lower)
        return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
    }

    // MARK: - Coefficient of Variation

    /// 変動係数（CV = stdDev / mean）
    /// 低いほど安定
    static func coefficientOfVariation(_ values: [Double]) -> Double {
        let avg = mean(values)
        guard avg > 0 else { return 0 }
        return standardDeviation(values) / avg
    }

    /// 安定度スコア（変動係数の逆数を0〜100に正規化）
    static func stabilityScore(_ values: [Double]) -> Double {
        let cv = coefficientOfVariation(values)
        // CV 0 → 100（完全に安定）
        // CV 1以上 → 0に近づく
        let stability = 1 / (1 + cv)
        return stability * 100
    }

    // MARK: - Correlation

    /// ピアソン相関係数
    static func correlation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, !x.isEmpty else { return 0 }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }

    // MARK: - Confidence

    /// サンプルサイズに基づく信頼度
    static func sampleConfidence(count: Int, threshold: Int = 50) -> Double {
        guard count > 0 else { return 0 }
        // サンプル数が閾値を超えると1.0に漸近
        // sigmoid風の関数
        let x = Double(count) / Double(threshold)
        return Swift.min(1.0, x / (1 + x * 0.5))
    }

    /// 複合信頼度（複数の要素を考慮）
    static func compositeConfidence(
        sampleCount: Int,
        dataQuality: Double,  // 0〜1
        periodCoverage: Double // 0〜1
    ) -> Double {
        let sampleConf = sampleConfidence(count: sampleCount)
        // 加重平均
        return sampleConf * 0.5 + dataQuality * 0.3 + periodCoverage * 0.2
    }
}

