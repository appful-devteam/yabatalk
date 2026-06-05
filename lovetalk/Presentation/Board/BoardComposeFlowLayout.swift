import SwiftUI

/// 子ビューを横に並べ、画面幅で折り返す `Layout`。
/// 投稿コンポーザの添付ボタン行 (アンケート / 画像 / 診断結果 / ハッシュタグ / 関係性) を、
/// 横スクロールではなく可視範囲で折り返して常に全件見える状態にするために使う。
struct BoardComposeFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat(0)) { partial, row in
            partial + row.height
        } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let width = rows.map { $0.width }.max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.subviewIndices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var subviewIndices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            // 現在行に乗らない場合は折り返し
            let projectedWidth = currentRow.width
                + (currentRow.subviewIndices.isEmpty ? 0 : spacing)
                + size.width
            if projectedWidth > maxWidth, !currentRow.subviewIndices.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
            }
            if !currentRow.subviewIndices.isEmpty {
                currentRow.width += spacing
            }
            currentRow.subviewIndices.append(index)
            currentRow.width += size.width
            currentRow.height = max(currentRow.height, size.height)
        }
        if !currentRow.subviewIndices.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}
