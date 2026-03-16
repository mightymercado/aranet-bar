import SwiftUI

@main
struct AranetBarApp: App {
    @StateObject private var aranet = AranetService()
    @StateObject private var alexa = AlexaService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(aranet: aranet, alexa: alexa)
        } label: {
            Image(nsImage: renderMenuBarIcon(
                reading: aranet.latestReading,
                connected: aranet.isConnected,
                alexaReading: alexa.latestReading
            ))
            .task {} // keep alive
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Icon

private let iconHeight: CGFloat = 18

private func renderMenuBarIcon(reading: AranetReading?, connected: Bool, alexaReading: AlexaReading?) -> NSImage {
    let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    let unitFont = NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .medium)
    let dimColor = NSColor.labelColor.withAlphaComponent(0.4)
    let dimUnitColor = NSColor.labelColor.withAlphaComponent(0.25)
    let separatorFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
    let separatorColor = NSColor.labelColor.withAlphaComponent(0.2)
    let dotSize: CGFloat = 5

    // CO2 segment
    let co2Text: String
    let co2Color: NSColor
    if let r = reading {
        co2Text = "\(r.co2)"
        co2Color = co2NSColor(r.co2)
    } else {
        co2Text = connected ? "..." : "--"
        co2Color = dimColor
    }
    let co2Attrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: co2Color]
    let co2UnitAttrs: [NSAttributedString.Key: Any] = [.font: unitFont, .foregroundColor: co2Color.withAlphaComponent(0.6)]
    let co2Str = NSAttributedString(string: co2Text, attributes: co2Attrs)
    let co2Unit = NSAttributedString(string: " ppm", attributes: co2UnitAttrs)

    // VOC + PM2.5 segment
    var vocStr: NSAttributedString?
    var vocUnit: NSAttributedString?
    var pmStr: NSAttributedString?
    var pmUnit: NSAttributedString?
    var sepStr: NSAttributedString?

    if let aq = alexaReading {
        let vocColor = vocNSColor(aq.voc)
        let pmColor = pm25NSColor(aq.pm25)

        vocStr = NSAttributedString(string: "\(aq.voc)", attributes: [.font: valueFont, .foregroundColor: vocColor])
        vocUnit = NSAttributedString(string: "voc ", attributes: [.font: unitFont, .foregroundColor: vocColor.withAlphaComponent(0.6)])

        let pmText = aq.pm25 < 10 ? String(format: "%.1f", aq.pm25) : "\(Int(aq.pm25))"
        pmStr = NSAttributedString(string: pmText, attributes: [.font: valueFont, .foregroundColor: pmColor])
        pmUnit = NSAttributedString(string: "pm", attributes: [.font: unitFont, .foregroundColor: pmColor.withAlphaComponent(0.6)])

        sepStr = NSAttributedString(string: " │ ", attributes: [.font: separatorFont, .foregroundColor: separatorColor])
    }

    // Calculate total width
    var totalWidth = dotSize + 4 + co2Str.size().width + co2Unit.size().width
    if let sep = sepStr, let vs = vocStr, let vu = vocUnit, let ps = pmStr, let pu = pmUnit {
        totalWidth += sep.size().width + vs.size().width + vu.size().width + ps.size().width + pu.size().width
    }

    let size = NSSize(width: ceil(totalWidth), height: iconHeight)

    let image = NSImage(size: size, flipped: false) { _ in
        let cy = size.height / 2

        // Status dot
        let dotRect = NSRect(x: 0, y: cy - dotSize / 2, width: dotSize, height: dotSize)
        co2Color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        var x: CGFloat = dotSize + 4

        // CO2
        let co2Size = co2Str.size()
        co2Str.draw(at: NSPoint(x: x, y: cy - co2Size.height / 2))
        x += co2Size.width
        let co2USize = co2Unit.size()
        co2Unit.draw(at: NSPoint(x: x, y: cy - co2USize.height / 2 + 0.5))
        x += co2USize.width

        // Separator + VOC + PM2.5
        if let sep = sepStr, let vs = vocStr, let vu = vocUnit, let ps = pmStr, let pu = pmUnit {
            let sepSize = sep.size()
            sep.draw(at: NSPoint(x: x, y: cy - sepSize.height / 2))
            x += sepSize.width

            let vsSize = vs.size()
            vs.draw(at: NSPoint(x: x, y: cy - vsSize.height / 2))
            x += vsSize.width
            let vuSize = vu.size()
            vu.draw(at: NSPoint(x: x, y: cy - vuSize.height / 2 + 0.5))
            x += vuSize.width

            let psSize = ps.size()
            ps.draw(at: NSPoint(x: x, y: cy - psSize.height / 2))
            x += psSize.width
            let puSize = pu.size()
            pu.draw(at: NSPoint(x: x, y: cy - puSize.height / 2 + 0.5))
        }

        return true
    }
    image.isTemplate = false
    return image
}

func co2NSColor(_ ppm: Int) -> NSColor {
    if ppm < 800 {
        return NSColor(red: 0.25, green: 0.78, blue: 0.5, alpha: 1)
    } else if ppm < 1000 {
        return NSColor(red: 0.55, green: 0.75, blue: 0.3, alpha: 1)
    } else if ppm < 1400 {
        return NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1)
    } else {
        return NSColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
    }
}

private func vocNSColor(_ ppb: Int) -> NSColor {
    if ppb <= 300 {
        return NSColor(red: 0.25, green: 0.78, blue: 0.5, alpha: 1)
    } else if ppb <= 1000 {
        return NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1)
    } else {
        return NSColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
    }
}

private func pm25NSColor(_ ugm3: Double) -> NSColor {
    if ugm3 <= 12 {
        return NSColor(red: 0.25, green: 0.78, blue: 0.5, alpha: 1)
    } else if ugm3 <= 35 {
        return NSColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1)
    } else {
        return NSColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
    }
}
