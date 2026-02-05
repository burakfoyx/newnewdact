import SwiftUI

struct AnsiParser {
    
    /// Parses a string containing ANSI escape codes into a SwiftUI AttributedString
    static func parse(_ text: String) -> AttributedString {
        var attributed = AttributedString("")
        
        // Regex to find ANSI escape sequences
        // Matches \u001B[...m
        let regex = try! NSRegularExpression(pattern: "\u{001B}\\[([0-9;]*)m")
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        var currentIndex = 0
        var currentAttributes = AttributeContainer()
        // Default color white/gray
        currentAttributes.foregroundColor = .white.opacity(0.9)
        
        for match in matches {
            // Text before the escape code
            let rangeBefore = NSRange(location: currentIndex, length: match.range.location - currentIndex)
            if rangeBefore.length > 0 {
                let segment = nsString.substring(with: rangeBefore)
                var attrSegment = AttributedString(segment)
                attrSegment.mergeAttributes(currentAttributes)
                attributed.append(attrSegment)
            }
            
            // Allow parsing the code
            let codeRange = match.range(at: 1)
            if codeRange.length > 0 {
                let codeString = nsString.substring(with: codeRange)
                let codes = codeString.split(separator: ";").compactMap { Int($0) }
                
                if codes.isEmpty {
                    // Reset
                    currentAttributes.foregroundColor = .white.opacity(0.9)
                } else {
                    for code in codes {
                        updateAttributes(&currentAttributes, code: code)
                    }
                }
            } else {
                // Empty code usually means reset
                 currentAttributes.foregroundColor = .white.opacity(0.9)
            }
            
            currentIndex = match.range.location + match.range.length
        }
        
        // Remaining text
        if currentIndex < nsString.length {
            let remaining = nsString.substring(from: currentIndex)
            var attrSegment = AttributedString(remaining)
            attrSegment.mergeAttributes(currentAttributes)
            attributed.append(attrSegment)
        }
        
        return attributed
    }
    
    private static func updateAttributes(_ attributes: inout AttributeContainer, code: Int) {
        switch code {
        case 0:
            // Reset
            attributes.foregroundColor = .white.opacity(0.9)
            attributes.inlinePresentationIntent = []
        case 1:
            // Bold
            attributes.inlinePresentationIntent?.insert(.bold)
        case 30: attributes.foregroundColor = .black
        case 31: attributes.foregroundColor = .red
        case 32: attributes.foregroundColor = .green
        case 33: attributes.foregroundColor = .yellow
        case 34: attributes.foregroundColor = .blue
        case 35: attributes.foregroundColor = .purple
        case 36: attributes.foregroundColor = .cyan
        case 37: attributes.foregroundColor = .white
        case 90: attributes.foregroundColor = .gray
        case 91: attributes.foregroundColor = Color(red: 1.0, green: 0.4, blue: 0.4) // Bright Red
        case 92: attributes.foregroundColor = Color(red: 0.4, green: 1.0, blue: 0.4) // Bright Green
        case 93: attributes.foregroundColor = Color(red: 1.0, green: 1.0, blue: 0.4) // Bright Yellow
        case 94: attributes.foregroundColor = Color(red: 0.4, green: 0.4, blue: 1.0) // Bright Blue
        case 95: attributes.foregroundColor = Color(red: 1.0, green: 0.4, blue: 1.0) // Bright Magenta
        case 96: attributes.foregroundColor = Color(red: 0.4, green: 1.0, blue: 1.0) // Bright Cyan
        case 97: attributes.foregroundColor = .white
        default:
            break
        }
    }
}
