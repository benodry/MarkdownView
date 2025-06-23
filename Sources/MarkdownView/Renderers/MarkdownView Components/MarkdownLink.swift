
// Platform-conditional color and path types
#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformBezierPath = UIBezierPath
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformBezierPath = NSBezierPath
#endif

//
//  MarkdownLink.swift
//  MarkdownView
//
//  Created by Yanan Li on 2025/2/22.
//

import SwiftUI
import Markdown

struct MarkdownLink: View {
    var link: Markdown.Link
    var configuration: MarkdownRenderConfiguration
    
    private var attributer: LinkAttributer {
        LinkAttributer(
            tint: configuration.inlineCodeTintColor,
            font: configuration.fontGroup.body
        )
    }
    
    var body: SwiftUI.Text {
        attributer.attributed(link)
    }
}


// MARK: - Attributer

fileprivate struct LinkAttributer: MarkupVisitor {
    var tint: Color
    var font: Font
    
    func attributed(_ markup: Markup) -> SwiftUI.Text {
        var attributer = self
        return Text(attributer.visit(markup))
    }
    
    mutating func defaultVisit(_ markup: Markup) -> AttributedString {
        var attributedString = AttributedString()
        for child in markup.children {
            attributedString += visit(child)
        }
        return attributedString
    }
    
    func visitText(_ text: Markdown.Text) -> AttributedString {
        var attributedString = AttributedString(stringLiteral: "[" + text.plainText + "]")
        attributedString.font = font.smallCaps().weight(.medium)
        
        
        return attributedString
    }
    
    mutating func visitLink(_ link: Markdown.Link) -> AttributedString {
        var attributedString = attributedString(from: link)
        if let destination = link.destination {
            attributedString.link = URL(string: destination)
            attributedString.foregroundColor = tint
            
            
        } else {
            #if os(macOS)
            attributedString.foregroundColor = .linkColor
            #elseif os(iOS)
            attributedString.foregroundColor = .link
            #elseif os(watchOS)
            attributedString.foregroundColor = .blue
            #endif
        }
        return attributedString
    }
    
    mutating func visitStrong(_ strong: Strong) -> AttributedString {
        var attributedString = attributedString(from: strong)
        attributedString.font = font.bold()
        return attributedString
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> AttributedString {
        var attributedString = attributedString(from: emphasis)
        attributedString.font = font.italic()
        return attributedString
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var attributedString = attributedString(inlineCode.code, from: inlineCode)
        attributedString.foregroundColor = tint
        attributedString.backgroundColor = tint.opacity(0.1)
        return attributedString
    }
    
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> AttributedString {
        var attributedString = attributedString(inlineHTML.rawHTML, from: inlineHTML)
        attributedString.font = font
        return attributedString
    }
}

extension LinkAttributer {
    mutating func attributedString(
        _ text: String = "",
        from markup: some Markup
    ) -> AttributedString {
        var attributedString = AttributedString(stringLiteral: text)
        for child in markup.children {
            attributedString += visit(child)
        }
        return attributedString
    }
}

#if os(iOS) || os(macOS)
#Preview {
    MarkdownView("Hello [1](https://pubmed.ncbi.nlm.nih.gov/36209676/) [2](https://pubmed.ncbi.nlm.nih.gov/31462385/) how are you today? I am well thanks for asking. Why does this go to a new line when the text is long?")
        .padding()
}
#endif

extension NSAttributedString.Key {
    static let roundedBackgroundColor = NSAttributedString.Key("MyRoundedBackgroundColor")
}

#if os(iOS)
import UIKit
typealias PlatformView = UIView
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
#endif

class RoundedTextView: PlatformView {
    var attributedText: NSAttributedString? {
        didSet {
            #if os(iOS)
            self.setNeedsDisplay()
            #elseif os(macOS)
            self.needsDisplay = true
            #endif
        }
    }
    
    #if os(iOS)
    override func draw(_ rect: CGRect) {
        guard let attributedText = attributedText else { return }
        
        let context = UIGraphicsGetCurrentContext()!
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        drawContent(in: context, attributedText: attributedText)
    }
    #elseif os(macOS)
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        if let attributedText = attributedText {
            drawContent(in: context, attributedText: attributedText)
        }
        context.restoreGState()
    }
    #endif
    
    private func drawContent(in context: CGContext, attributedText: NSAttributedString) {
        let path = CGPath(rect: bounds, transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedText.length), path, nil)
        
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        
        var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lineCount), &lineOrigins)
        
        for i in 0..<lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, i), to: CTLine.self)
            let lineOrigin = lineOrigins[i]
            
            context.textPosition = lineOrigin
            
            let runs = CTLineGetGlyphRuns(line)
            let runCount = CFArrayGetCount(runs)
            
            for j in 0..<runCount {
                let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, j), to: CTRun.self)
                let runRange = CTRunGetStringRange(run)
                
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                
                let width = CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), &ascent, &descent, &leading))
                let height = ascent + descent
                
                let runOffset = CTLineGetOffsetForStringIndex(line, runRange.location, nil)
                let runBounds = CGRect(x: lineOrigin.x + runOffset, y: lineOrigin.y - descent, width: width, height: height)
                
                let attributes = CTRunGetAttributes(run) as NSDictionary
                if let bgColor = attributes[NSAttributedString.Key.roundedBackgroundColor.rawValue] as? PlatformColor {
                    // Draw rounded background
                    #if os(iOS)
                    let path = PlatformBezierPath(roundedRect: runBounds, cornerRadius: 6)
                    bgColor.setFill()
                    path.fill()
                    #elseif os(macOS)
                    let path = PlatformBezierPath(roundedRect: runBounds, cornerRadius: 6)
                    bgColor.setFill()
                    path.fill()
                    #endif
                }
                
                CTRunDraw(run, context, CFRange(location: 0, length: 0))
            }
        }
    }
}

#if os(macOS)
// Helper extension to create rounded rect NSBezierPath from CGRect
extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init()
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        self.append(NSBezierPath.pathFromCGPath(path))
    }

    private static func pathFromCGPath(_ cgPath: CGPath) -> NSBezierPath {
        let path = NSBezierPath()
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                path.move(to: element.points[0])
            case .addLineToPoint:
                path.line(to: element.points[0])
            case .addQuadCurveToPoint:
                path.curve(to: element.points[1], controlPoint1: element.points[0], controlPoint2: element.points[0])
            case .addCurveToPoint:
                path.curve(to: element.points[2], controlPoint1: element.points[0], controlPoint2: element.points[1])
            case .closeSubpath:
                path.close()
            @unknown default:
                break
            }
        }
        return path
    }
}
#endif
