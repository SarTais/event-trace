import Foundation
import UIKit

struct TraceExportGenerator {
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

    private func beginPage(
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
        drawText("EventTrace PDF Summary", in: CGRect(x: margin, y: y, width: contentWidth, height: 34), font: titleFont, color: .black)
        y += 40

        let generatedDate = Date().formatted(date: .abbreviated, time: .shortened)
        drawText("Generated \(generatedDate)", in: CGRect(x: margin, y: y, width: contentWidth, height: 22), font: captionFont, color: .darkGray)
        return y + 36
    }

    private func beginNewPageIfNeeded(
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
}
