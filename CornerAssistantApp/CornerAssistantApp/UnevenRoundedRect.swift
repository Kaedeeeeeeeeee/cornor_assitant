
// Use this to append the struct to the end of the file.
// Ideally I should put this in a separate file, but for now appending is fine or I can use write_to_file with append mode? 
// No, I can't append. I have to read the file and write it back or use replace_file_content to insert at end.
// I'll use replace_file_content to insert before the last brace or just use a new file?
// A new file is cleaner.

import SwiftUI

struct UnevenRoundedRect: InsettableShape {
    var topLeft: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomRight: CGFloat = 0
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        
        // Start top-left
        path.move(to: CGPoint(x: insetRect.minX + topLeft, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - topRight, y: insetRect.minY))
        path.addArc(center: CGPoint(x: insetRect.maxX - topRight, y: insetRect.minY + topRight), radius: topRight, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - bottomRight))
        path.addArc(center: CGPoint(x: insetRect.maxX - bottomRight, y: insetRect.maxY - bottomRight), radius: bottomRight, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: insetRect.minX + bottomLeft, y: insetRect.maxY))
        path.addArc(center: CGPoint(x: insetRect.minX + bottomLeft, y: insetRect.maxY - bottomLeft), radius: bottomLeft, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY + topLeft))
        path.addArc(center: CGPoint(x: insetRect.minX + topLeft, y: insetRect.minY + topLeft), radius: topLeft, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        
        return path
    }
    
    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
