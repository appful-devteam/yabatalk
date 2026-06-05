import Foundation

// MARK: - Reply Style Profile

struct ReplyPunctuationProfile: Codable, Hashable {
    let periodRate: Double
    let commaRate: Double
    let exclamationRate: Double
    let questionRate: Double
    let ellipsisRate: Double
    let newlineRate: Double
}

struct ReplyStyleProfile: Codable, Hashable {
    let preferredFirstPerson: String?
    let firstPersonDistribution: [String: Double]
    let preferredAddressing: String?
    let addressingDistribution: [String: Double]
    let endingDistribution: [String: Double]
    let politenessRatio: Double
    let laughDistribution: [String: Double]
    let emojiUse: Bool
    let emojiTop: [String]
    let emojiDensity: Double
    let emojiPositionEnd: Bool
    let punctuation: ReplyPunctuationProfile
    let medianLength: Int
    let p90Length: Int
    let signatureWords: [String]
}

struct ReplyStyleProfiles: Codable, Hashable {
    let selfName: String
    let partnerName: String
    let selfStyle: ReplyStyleProfile
    let partnerStyle: ReplyStyleProfile
    let generatedAt: Date
}
