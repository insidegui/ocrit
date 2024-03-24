import Quartz

extension CGPDFDocument {
    func cgImage(at pageNumber: Int) throws -> CGImage {
        guard let page = page(at: pageNumber) else {
            throw Failure("Page #\(pageNumber) not found.")
        }

        let pageRect = page.getBoxRect(.mediaBox)

        let img = NSImage(size: pageRect.size, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            NSColor.white.setFill()
            rect.fill()

            ctx.translateBy(x: 0, y: pageRect.size.height)
            ctx.scaleBy(x: 1.0, y: -1.0)

            ctx.drawPDFPage(page)

            return true
        }

        guard let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Failure("Failed to create CGImage.")
        }

        return cgImage
    }
}
