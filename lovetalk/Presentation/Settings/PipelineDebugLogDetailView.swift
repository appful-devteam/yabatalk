import SwiftUI

struct PipelineDebugLogDetailView: View {
    let fileURL: URL
    @State private var entry: PipelineLogEntry?

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection(entry)
                        if let ctx = entry.inputContext { inputContextSection(ctx) }
                        if let pre = entry.preprocessing { preprocessingSection(pre) }
                        if let c1 = entry.call1 { apiCallSection(title: "Call 1: 内容設計", log: c1) }
                        if let c2a = entry.call2a { apiCallSection(title: "Call 2a: 内容起草", log: c2a) }
                        if let c2b = entry.call2b { apiCallSection(title: "Call 2b: スタイル転写", log: c2b) }
                        if let hc = entry.hardConstraints { hardConstraintSection(hc) }
                        if let ev = entry.evaluation { evaluationSection(ev) }
                        if let c25 = entry.call25 { apiCallSection(title: "Call 2.5: リライト", log: c25) }
                        if let fo = entry.finalOutput { finalOutputSection(fo) }
                        if let err = entry.error { errorSection(err) }
                    }
                    .padding()
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("ログ詳細")
        .navigationBarTitleDisplayMode(.inline)
        // 開発者専用デバッグ画面。多数のシステムセマンティック色 (.primary/.secondary/Color(.systemBackground) 等)
        // を使うため、ルートの forced .light を打ち消して Apple 標準のダーク色に揃える。
        // TODO(dark): 要確認 — MeloColors.Dark トークンへの厳密置換ではなくシステムダーク配色を採用
        .preferredColorScheme(.dark)
        .background(MeloColors.Dark.bg.ignoresSafeArea())
        .toolbar {
            if entry != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            entry = PipelineDebugLogger.shared.loadEntry(from: fileURL)
        }
    }

    // MARK: - Sections

    private func headerSection(_ entry: PipelineLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total: \(String(format: "%.2fs", entry.durationTotal))")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
            Text(entry.createdAt, format: .dateTime)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    private func inputContextSection(_ ctx: PipelineLogEntry.InputContext) -> some View {
        DisclosureGroup("Input Context") {
            VStack(alignment: .leading, spacing: 6) {
                labelValue("userGoal", ctx.userGoal)
                labelValue("self", ctx.selfName)
                labelValue("partner", ctx.partnerName)
                labelValue("messages", "\(ctx.messageCount) (recent: \(ctx.recentMessageCount))")
                labelValue("history", "\(ctx.historyEntryCount) entries")
                monoText("Snippet preview:", ctx.recentSnippetPreview)
            }
        }
        .disclosureGroupStyle()
    }

    private func preprocessingSection(_ pre: PipelineLogEntry.Preprocessing) -> some View {
        DisclosureGroup("Preprocessing (\(String(format: "%.2fs", pre.duration)))") {
            VStack(alignment: .leading, spacing: 6) {
                labelValue("RAG examples", "\(pre.ragExampleCount)")
                labelValue("backfill", pre.usedBackfill ? "\(pre.backfillBlockCount) blocks" : "none")
                monoText("StyleDNA:", pre.styleDNASummary)
                monoText("Personality:", pre.personalityContext)
                monoText("Relationship:", pre.relationshipIntel)
            }
        }
        .disclosureGroupStyle()
    }

    private func apiCallSection(title: String, log: PipelineLogEntry.APICallLog) -> some View {
        DisclosureGroup("\(title) (\(String(format: "%.2fs", log.duration)))") {
            VStack(alignment: .leading, spacing: 8) {
                if let error = log.error {
                    Text("ERROR: \(error)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
                labelValue("Summary", log.parsedSummary)
                monoText("Prompt:", log.prompt)
                monoText("Raw Response:", log.rawResponse)
            }
        }
        .disclosureGroupStyle()
    }

    private func hardConstraintSection(_ hc: PipelineLogEntry.HardConstraintLog) -> some View {
        DisclosureGroup("Hard Constraints (\(String(format: "%.2fs", hc.duration)))") {
            VStack(alignment: .leading, spacing: 8) {
                monoText("Rules:", hc.appliedRules)

                Text("Before:").font(.system(size: 12, weight: .semibold))
                ForEach(hc.candidatesBefore, id: \.self) { c in
                    Text(c)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text("After:").font(.system(size: 12, weight: .semibold))
                ForEach(hc.candidatesAfter, id: \.self) { c in
                    Text(c)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
        .disclosureGroupStyle()
    }

    private func evaluationSection(_ ev: PipelineLogEntry.EvaluationLog) -> some View {
        DisclosureGroup("Evaluation (\(String(format: "%.2fs", ev.duration)))") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scores:").font(.system(size: 12, weight: .semibold))
                ForEach(ev.scores, id: \.self) { s in
                    Text(s).font(.system(size: 11, design: .monospaced))
                }

                if !ev.rewriteTargets.isEmpty {
                    Text("Rewrite Targets:").font(.system(size: 12, weight: .semibold))
                    ForEach(ev.rewriteTargets, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .disclosureGroupStyle()
    }

    private func finalOutputSection(_ fo: PipelineLogEntry.FinalOutputLog) -> some View {
        DisclosureGroup("Final Output (\(String(format: "%.2fs", fo.totalDuration)))") {
            VStack(alignment: .leading, spacing: 6) {
                labelValue("lenient fallback", fo.usedLenientFallback ? "yes" : "no")
                Text("Accepted:").font(.system(size: 12, weight: .semibold))
                ForEach(fo.acceptedCandidates, id: \.self) { c in
                    Text(c).font(.system(size: 11, design: .monospaced))
                }

                if !fo.notes.isEmpty {
                    Text("Notes:").font(.system(size: 12, weight: .semibold))
                    ForEach(fo.notes, id: \.self) { n in
                        Text("• \(n)").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }
        }
        .disclosureGroupStyle()
    }

    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Error")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
            Text(error)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(minWidth: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
        }
    }

    private func monoText(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .padding(6)
            .background(MeloColors.Dark.bgElevated)
            .cornerRadius(6)
        }
    }
}

// MARK: - DisclosureGroup Styling

private extension View {
    func disclosureGroupStyle() -> some View {
        self
            .padding(10)
            .background(MeloColors.Dark.card)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
    }
}
