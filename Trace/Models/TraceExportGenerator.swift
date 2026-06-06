import Foundation
import UIKit

struct TraceExportGenerator {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    func makeExcelFile(categories: [EventCategory], presets: [EventPresetItem]) throws -> URL {
        let csv = makeExcelCSV(categories: categories, presets: presets)
        let fileURL = exportURL(fileName: "EventTrace-Excel-Export.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func makePDFFile(categories: [EventCategory], presets: [EventPresetItem]) throws -> URL {
        let fileURL = exportURL(fileName: "EventTrace-PDF-Summary.pdf")
        let data = makePDFData(categories: categories, presets: presets)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func makeEventExcelFile(
        category: EventCategory,
        presets: [EventPresetItem],
        events: [LoggedEvent],
        scopeTitle: String
    ) throws -> URL {
        let csv = makeEventCSV(category: category, presets: presets, events: events, scopeTitle: scopeTitle)
        let fileURL = exportURL(fileName: "EventTrace-\(safeFileName(category.name))-Events.csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func makeEventPDFFile(
        category: EventCategory,
        presets: [EventPresetItem],
        events: [LoggedEvent],
        scopeTitle: String
    ) throws -> URL {
        let fileURL = exportURL(fileName: "EventTrace-\(safeFileName(category.name))-Events.pdf")
        let data = makeEventPDFData(category: category, presets: presets, events: events, scopeTitle: scopeTitle)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func exportURL(fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    }

    private func makeExcelCSV(categories: [EventCategory], presets: [EventPresetItem]) -> String {
        let header = [
            "Type",
            "ID",
            "Name",
            "Category",
            "Category ID",
            "SF Symbol",
            "Color",
            "Preset Count"
        ]

        let categoryRows = categories.map { category in
            [
                "Category",
                category.id.uuidString,
                category.name,
                "",
                "",
                category.icon,
                category.tintName,
                String(presets.filter { $0.categoryID == category.id }.count)
            ]
        }

        let presetRows = presets.map { preset in
            let categoryName = categories.first { $0.id == preset.categoryID }?.name ?? "Deleted Category"
            return [
                "Preset",
                preset.id.uuidString,
                preset.name,
                categoryName,
                preset.categoryID.uuidString,
                "",
                "",
                ""
            ]
        }

        let rows = [header] + categoryRows + presetRows
        return "\u{feff}" + rows.map(csvLine).joined(separator: "\n")
    }

    private func makeEventCSV(
        category: EventCategory,
        presets: [EventPresetItem],
        events: [LoggedEvent],
        scopeTitle: String
    ) -> String {
        let presetNames = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0.name) })
        let groupedByPreset = Dictionary(grouping: events) { event in
            event.presetID.flatMap { presetNames[$0] } ?? event.title
        }
        let groupedByDay = Dictionary(grouping: events) { event in
            Calendar.current.startOfDay(for: event.loggedAt)
        }

        let summaryRows = [
            ["Report", "\(category.name) logged events"],
            ["Range", scopeTitle],
            ["Total Events", String(events.count)],
            ["Included Presets", includedPresetText(presets)],
            []
        ]

        let presetRows = [["Preset", "Event Count"]] + groupedByPreset
            .sorted { first, second in
                if first.value.count == second.value.count {
                    return first.key < second.key
                }

                return first.value.count > second.value.count
            }
            .map { [$0.key, String($0.value.count)] }

        let dailyRows = [["Date", "Event Count"]] + groupedByDay
            .sorted { $0.key < $1.key }
            .map { [dayFormatter.string(from: $0.key), String($0.value.count)] }

        let eventRows = [["Logged At", "Category", "Preset", "Title", "Event ID"]] + events
            .sorted { $0.loggedAt < $1.loggedAt }
            .map { event in
                [
                    dateFormatter.string(from: event.loggedAt),
                    category.name,
                    event.presetID.flatMap { presetNames[$0] } ?? "",
                    event.title,
                    event.id.uuidString
                ]
            }

        let rows = summaryRows + presetRows + [[]] + dailyRows + [[]] + eventRows
        return "\u{feff}" + rows.map(csvLine).joined(separator: "\n")
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    private func csvField(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }

    private func makePDFData(categories: [EventCategory], presets: [EventPresetItem]) -> Data {
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let margin: CGFloat = 44
        let contentWidth = pageBounds.width - margin * 2
        let titleFont = UIFont.preferredFont(forTextStyle: .title1)
        let headingFont = UIFont.preferredFont(forTextStyle: .headline)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let captionFont = UIFont.preferredFont(forTextStyle: .caption1)
        let smallFont = UIFont.systemFont(ofSize: 9)

        return renderer.pdfData { context in
            var y = beginPage(
                context: context,
                pageBounds: pageBounds,
                margin: margin,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )

            y = drawSectionTitle("Categories", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawTableHeader(["Name", "Color", "Presets", "ID"], y: y, margin: margin, contentWidth: contentWidth, font: captionFont)

            for category in categories {
                y = beginNewPageIfNeeded(
                    y: y,
                    rowHeight: 38,
                    pageBounds: pageBounds,
                    margin: margin,
                    context: context,
                    contentWidth: contentWidth,
                    titleFont: titleFont,
                    captionFont: captionFont
                )

                let presetCount = presets.filter { $0.categoryID == category.id }.count
                y = drawTableRow(
                    [category.name, category.tintName, String(presetCount), category.id.uuidString],
                    widths: [0.24, 0.16, 0.14, 0.46],
                    y: y,
                    margin: margin,
                    contentWidth: contentWidth,
                    font: bodyFont,
                    smallFont: smallFont
                )
            }

            y += 18
            y = beginNewPageIfNeeded(
                y: y,
                rowHeight: 70,
                pageBounds: pageBounds,
                margin: margin,
                context: context,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )
            y = drawSectionTitle("Preset Items", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawTableHeader(["Name", "Category", "Category ID"], y: y, margin: margin, contentWidth: contentWidth, font: captionFont)

            if presets.isEmpty {
                drawText("No preset items yet.", in: CGRect(x: margin, y: y, width: contentWidth, height: 24), font: bodyFont, color: .darkGray)
            } else {
                for preset in presets {
                    y = beginNewPageIfNeeded(
                        y: y,
                        rowHeight: 34,
                        pageBounds: pageBounds,
                        margin: margin,
                        context: context,
                        contentWidth: contentWidth,
                        titleFont: titleFont,
                        captionFont: captionFont
                    )

                    let categoryName = categories.first { $0.id == preset.categoryID }?.name ?? "Deleted Category"
                    y = drawTableRow(
                        [preset.name, categoryName, preset.categoryID.uuidString],
                        widths: [0.28, 0.22, 0.50],
                        y: y,
                        margin: margin,
                        contentWidth: contentWidth,
                        font: bodyFont,
                        smallFont: smallFont
                    )
                }
            }
        }
    }

    private func makeEventPDFData(
        category: EventCategory,
        presets: [EventPresetItem],
        events: [LoggedEvent],
        scopeTitle: String
    ) -> Data {
        let reportTitle = "\(category.name) Event Report"
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let margin: CGFloat = 44
        let contentWidth = pageBounds.width - margin * 2
        let titleFont = UIFont.preferredFont(forTextStyle: .title1)
        let headingFont = UIFont.preferredFont(forTextStyle: .headline)
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let captionFont = UIFont.preferredFont(forTextStyle: .caption1)
        let smallFont = UIFont.systemFont(ofSize: 9)
        let accentColor = uiColor(forTintName: category.tintName)

        return renderer.pdfData { context in
            let presetNames = Dictionary(uniqueKeysWithValues: presets.map { ($0.id, $0.name) })
            let groupedByPreset = Dictionary(grouping: events) { event in
                event.presetID.flatMap { presetNames[$0] } ?? event.title
            }
            let presetSummaries = groupedByPreset.sorted { first, second in
                if first.value.count == second.value.count {
                    return first.key < second.key
                }

                return first.value.count > second.value.count
            }
            let groupedByDay = Dictionary(grouping: events) { event in
                Calendar.current.startOfDay(for: event.loggedAt)
            }
            let dailySummaries = groupedByDay
                .sorted { $0.key < $1.key }
                .map { PDFChartItem(label: shortDayFormatter.string(from: $0.key), value: $0.value.count) }
            let timeOfDaySummaries = timeOfDayChartItems(from: events)
            let activeDayCount = groupedByDay.count
            let topPresetText = presetSummaries.first.map { "\($0.key) (\($0.value.count))" } ?? "None"

            var y = beginPage(
                title: reportTitle,
                context: context,
                pageBounds: pageBounds,
                margin: margin,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )

            y = drawSectionTitle("Summary", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawMetricCards(
                [
                    PDFMetricCard(title: "Events", value: String(events.count), detail: scopeTitle),
                    PDFMetricCard(title: "Active Days", value: String(activeDayCount), detail: activeDayCount == 1 ? "day with events" : "days with events"),
                    PDFMetricCard(title: "Top Preset", value: topPresetText, detail: includedPresetText(presets))
                ],
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                accentColor: accentColor,
                titleFont: captionFont,
                valueFont: bodyFont,
                detailFont: smallFont
            )

            y += 18
            y = drawSectionTitle("Daily Pattern", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawHeatmap(
                items: dailySummaries,
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                accentColor: accentColor,
                font: smallFont
            )

            y += 18
            y = beginNewPageIfNeeded(
                title: reportTitle,
                y: y,
                rowHeight: 160,
                pageBounds: pageBounds,
                margin: margin,
                context: context,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )
            y = drawSectionTitle("Preset Frequency", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawHorizontalBarChart(
                items: presetSummaries.map { PDFChartItem(label: $0.key, value: $0.value.count) },
                emptyMessage: "No matching events yet.",
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                accentColor: accentColor,
                font: bodyFont,
                smallFont: smallFont
            )

            y += 18
            y = beginNewPageIfNeeded(
                title: reportTitle,
                y: y,
                rowHeight: 150,
                pageBounds: pageBounds,
                margin: margin,
                context: context,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )
            y = drawSectionTitle("Time of Day", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)
            y = drawHorizontalBarChart(
                items: timeOfDaySummaries,
                emptyMessage: "No matching events yet.",
                y: y,
                margin: margin,
                contentWidth: contentWidth,
                accentColor: UIColor.systemTeal,
                font: bodyFont,
                smallFont: smallFont
            )

            y += 18
            y = beginNewPageIfNeeded(
                title: reportTitle,
                y: y,
                rowHeight: 80,
                pageBounds: pageBounds,
                margin: margin,
                context: context,
                contentWidth: contentWidth,
                titleFont: titleFont,
                captionFont: captionFont
            )
            y = drawSectionTitle("Event Log", y: y, margin: margin, contentWidth: contentWidth, headingFont: headingFont)

            for event in events.sorted(by: { $0.loggedAt < $1.loggedAt }) {
                y = beginNewPageIfNeeded(
                    title: reportTitle,
                    y: y,
                    rowHeight: 42,
                    pageBounds: pageBounds,
                    margin: margin,
                    context: context,
                    contentWidth: contentWidth,
                    titleFont: titleFont,
                    captionFont: captionFont
                )
                y = drawTimelineRow(
                    title: event.title,
                    subtitle: "\(dateFormatter.string(from: event.loggedAt))  |  \(event.presetID.flatMap { presetNames[$0] } ?? "No preset")",
                    y: y,
                    margin: margin,
                    contentWidth: contentWidth,
                    accentColor: accentColor,
                    titleFont: bodyFont,
                    subtitleFont: captionFont
                )
            }
        }
    }

    private func beginPage(
        title: String = "EventTrace PDF Summary",
        context: UIGraphicsPDFRendererContext,
        pageBounds: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat,
        titleFont: UIFont,
        captionFont: UIFont
    ) -> CGFloat {
        context.beginPage()
        UIColor.white.setFill()
        UIBezierPath(rect: pageBounds).fill()

        var y = margin
        drawText(title, in: CGRect(x: margin, y: y, width: contentWidth, height: 34), font: titleFont, color: .black)
        y += 40

        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        drawText("Generated \(generatedDate)", in: CGRect(x: margin, y: y, width: contentWidth, height: 22), font: captionFont, color: .darkGray)
        return y + 36
    }

    private func beginNewPageIfNeeded(
        title: String = "EventTrace PDF Summary",
        y: CGFloat,
        rowHeight: CGFloat,
        pageBounds: CGRect,
        margin: CGFloat,
        context: UIGraphicsPDFRendererContext,
        contentWidth: CGFloat,
        titleFont: UIFont,
        captionFont: UIFont
    ) -> CGFloat {
        guard y + rowHeight > pageBounds.maxY - margin else { return y }
        return beginPage(
            title: title,
            context: context,
            pageBounds: pageBounds,
            margin: margin,
            contentWidth: contentWidth,
            titleFont: titleFont,
            captionFont: captionFont
        )
    }

    private func drawSectionTitle(_ title: String, y: CGFloat, margin: CGFloat, contentWidth: CGFloat, headingFont: UIFont) -> CGFloat {
        drawText(title, in: CGRect(x: margin, y: y, width: contentWidth, height: 26), font: headingFont, color: .black)
        return y + 30
    }

    private func drawTableHeader(_ values: [String], y: CGFloat, margin: CGFloat, contentWidth: CGFloat, font: UIFont) -> CGFloat {
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: 24)
        UIColor(white: 0.92, alpha: 1).setFill()
        UIBezierPath(rect: rect).fill()
        drawText(values.joined(separator: "   "), in: rect.insetBy(dx: 8, dy: 5), font: font, color: .darkGray)
        return y + 26
    }

    private func drawTableRow(
        _ values: [String],
        widths: [CGFloat],
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        font: UIFont,
        smallFont: UIFont
    ) -> CGFloat {
        let rowHeight: CGFloat = 34
        var x = margin

        UIColor(white: 0.72, alpha: 1).setStroke()
        UIBezierPath(rect: CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)).stroke()

        for (index, value) in values.enumerated() {
            let width = contentWidth * widths[index]
            let cellRect = CGRect(x: x + 6, y: y + 7, width: width - 12, height: 20)
            drawText(value, in: cellRect, font: value.count > 24 ? smallFont : font, color: .black)
            x += width
        }

        return y + rowHeight
    }

    private func drawMetricCards(
        _ cards: [PDFMetricCard],
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        accentColor: UIColor,
        titleFont: UIFont,
        valueFont: UIFont,
        detailFont: UIFont
    ) -> CGFloat {
        let spacing: CGFloat = 10
        let cardWidth = (contentWidth - spacing * CGFloat(cards.count - 1)) / CGFloat(cards.count)
        let cardHeight: CGFloat = 92

        for (index, card) in cards.enumerated() {
            let x = margin + CGFloat(index) * (cardWidth + spacing)
            let rect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            UIColor(white: 0.97, alpha: 1).setFill()
            path.fill()

            accentColor.withAlphaComponent(0.16).setFill()
            UIBezierPath(roundedRect: CGRect(x: x, y: y, width: cardWidth, height: 5), cornerRadius: 2.5).fill()

            drawText(card.title.uppercased(), in: CGRect(x: x + 10, y: y + 14, width: cardWidth - 20, height: 14), font: titleFont, color: .darkGray)
            drawText(card.value, in: CGRect(x: x + 10, y: y + 34, width: cardWidth - 20, height: 26), font: valueFont, color: .black)
            drawText(card.detail, in: CGRect(x: x + 10, y: y + 64, width: cardWidth - 20, height: 18), font: detailFont, color: .darkGray)
        }

        return y + cardHeight
    }

    private func drawHorizontalBarChart(
        items: [PDFChartItem],
        emptyMessage: String,
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        accentColor: UIColor,
        font: UIFont,
        smallFont: UIFont
    ) -> CGFloat {
        guard !items.isEmpty else {
            drawText(emptyMessage, in: CGRect(x: margin, y: y, width: contentWidth, height: 24), font: font, color: .darkGray)
            return y + 30
        }

        let maxValue = max(items.map(\.value).max() ?? 1, 1)
        let labelWidth = min(contentWidth * 0.34, 170)
        let valueWidth: CGFloat = 34
        let barWidth = contentWidth - labelWidth - valueWidth - 18
        let rowHeight: CGFloat = 28
        var rowY = y

        for item in items {
            drawText(item.label, in: CGRect(x: margin, y: rowY + 4, width: labelWidth, height: 18), font: item.label.count > 20 ? smallFont : font, color: .black)

            let trackRect = CGRect(x: margin + labelWidth + 10, y: rowY + 8, width: barWidth, height: 12)
            UIColor(white: 0.91, alpha: 1).setFill()
            UIBezierPath(roundedRect: trackRect, cornerRadius: 6).fill()

            let filledWidth = max(8, trackRect.width * CGFloat(item.value) / CGFloat(maxValue))
            accentColor.withAlphaComponent(0.78).setFill()
            UIBezierPath(roundedRect: CGRect(x: trackRect.minX, y: trackRect.minY, width: filledWidth, height: trackRect.height), cornerRadius: 6).fill()

            drawText(String(item.value), in: CGRect(x: trackRect.maxX + 8, y: rowY + 4, width: valueWidth, height: 18), font: font, color: .black)
            rowY += rowHeight
        }

        return rowY
    }

    private func drawHeatmap(
        items: [PDFChartItem],
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        accentColor: UIColor,
        font: UIFont
    ) -> CGFloat {
        guard !items.isEmpty else {
            drawText("No matching days yet.", in: CGRect(x: margin, y: y, width: contentWidth, height: 24), font: font, color: .darkGray)
            return y + 30
        }

        let maxValue = max(items.map(\.value).max() ?? 1, 1)
        let columns = min(max(items.count, 1), 14)
        let cellSpacing: CGFloat = 6
        let cellWidth = (contentWidth - CGFloat(columns - 1) * cellSpacing) / CGFloat(columns)
        let cellHeight: CGFloat = 42
        var currentY = y

        for chunkStart in stride(from: 0, to: items.count, by: columns) {
            let chunk = Array(items[chunkStart..<min(chunkStart + columns, items.count)])

            for (index, item) in chunk.enumerated() {
                let x = margin + CGFloat(index) * (cellWidth + cellSpacing)
                let rect = CGRect(x: x, y: currentY, width: cellWidth, height: cellHeight)
                let intensity = CGFloat(item.value) / CGFloat(maxValue)

                accentColor.withAlphaComponent(0.16 + 0.68 * intensity).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()

                drawText(String(item.value), in: CGRect(x: x + 4, y: currentY + 7, width: cellWidth - 8, height: 16), font: font, color: .black)
                drawText(item.label, in: CGRect(x: x + 4, y: currentY + 23, width: cellWidth - 8, height: 13), font: font, color: .darkGray)
            }

            currentY += cellHeight + cellSpacing
        }

        return currentY
    }

    private func drawTimelineRow(
        title: String,
        subtitle: String,
        y: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        accentColor: UIColor,
        titleFont: UIFont,
        subtitleFont: UIFont
    ) -> CGFloat {
        let dotCenter = CGPoint(x: margin + 8, y: y + 18)
        accentColor.setFill()
        UIBezierPath(ovalIn: CGRect(x: dotCenter.x - 4, y: dotCenter.y - 4, width: 8, height: 8)).fill()

        UIColor(white: 0.82, alpha: 1).setStroke()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: dotCenter.x, y: y + 24))
        linePath.addLine(to: CGPoint(x: dotCenter.x, y: y + 40))
        linePath.stroke()

        drawText(title, in: CGRect(x: margin + 24, y: y, width: contentWidth - 24, height: 20), font: titleFont, color: .black)
        drawText(subtitle, in: CGRect(x: margin + 24, y: y + 20, width: contentWidth - 24, height: 18), font: subtitleFont, color: .darkGray)
        return y + 42
    }

    private func drawText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private func includedPresetText(_ presets: [EventPresetItem]) -> String {
        presets.isEmpty ? "All presets in category" : presets.map(\.name).joined(separator: ", ")
    }

    private func safeFileName(_ value: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let pieces = value.components(separatedBy: allowedCharacters.inverted).filter { !$0.isEmpty }
        return pieces.isEmpty ? "Category" : pieces.joined(separator: "-")
    }

    private func timeOfDayChartItems(from events: [LoggedEvent]) -> [PDFChartItem] {
        let periods = [
            ("Morning", 5..<12),
            ("Afternoon", 12..<17),
            ("Evening", 17..<22),
            ("Night", 0..<5)
        ]
        let calendar = Calendar.current

        return periods.map { period in
            let count = events.filter { event in
                let hour = calendar.component(.hour, from: event.loggedAt)
                return period.1.contains(hour) || (period.0 == "Night" && hour >= 22)
            }.count

            return PDFChartItem(label: period.0, value: count)
        }
    }

    private func uiColor(forTintName tintName: String) -> UIColor {
        switch tintName {
        case "Red":
            return .systemRed
        case "Green":
            return .systemGreen
        case "Yellow":
            return .systemYellow
        case "Indigo":
            return .systemIndigo
        case "Orange":
            return .systemOrange
        case "Teal":
            return .systemTeal
        case "Purple":
            return .systemPurple
        case "Pink":
            return .systemPink
        default:
            return .systemBlue
        }
    }
}

private struct PDFMetricCard {
    let title: String
    let value: String
    let detail: String
}

private struct PDFChartItem {
    let label: String
    let value: Int
}
