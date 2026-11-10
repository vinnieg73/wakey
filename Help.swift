// Wakey Help: what the two faces mean and what each menu item does. Opened from the menu.
import AppKit

/// "Version 1.1", from the app's Info.plist (build.sh writes it). Empty outside an app bundle.
var versionText: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).map { "Version \($0)" } ?? ""
}

/// The help text. The two menu bar faces sit in front of their own lines.
func helpText() -> NSAttributedString {
    let body = NSFont.systemFont(ofSize: 13)
    let bold = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let out = NSMutableAttributedString()
    func add(_ title: String, _ text: String, face: NSImage? = nil, last: Bool = false) {
        if let face {
            let a = NSTextAttachment()
            a.image = face
            a.bounds = NSRect(x: 0, y: -4, width: 18, height: 18)   // sits on the text line
            out.append(NSAttributedString(attachment: a))
            out.append(NSAttributedString(string: "  ", attributes: [.font: body]))
        }
        out.append(NSAttributedString(string: title + " ", attributes: [.font: bold]))
        out.append(NSAttributedString(string: text + (last ? "" : "\n"), attributes: [.font: body]))
    }
    add("Orange and smiling:", "staying awake. The Mac keeps running with the lid closed.", face: awakeIcon)
    add("Blue and sleepy:", "normal sleep. The Mac sleeps like any other Mac.", face: sleepIcon)
    add("Click", "the face to switch. Right-click it for the menu.")
    add("Lights Off When Lid Closes:", "while orange, closing the lid turns off the screen and the keyboard light, which locks the Mac. With an external display attached, only the keyboard light goes off.")
    add("Open at Login:", "starts Wakey when you log in.")
    add("Quit:", "quitting from the menu switches back to normal sleep first, so the Mac is never left unable to sleep. A restart keeps the setting you had.")
    add("Password:", "the first switch asks for your password once. After that it never asks again.", last: true)
    let para = NSMutableParagraphStyle()
    para.paragraphSpacing = 9
    para.lineSpacing = 1.5
    out.addAttributes([.paragraphStyle: para, .foregroundColor: NSColor.labelColor],
                      range: NSRange(location: 0, length: out.length))
    return out
}

/// The Help window: a standard alert with the app icon, the version, and the help text below.
func makeHelpAlert() -> NSAlert {
    let a = NSAlert()
    a.messageText = "Wakey Help"
    a.informativeText = versionText
    let width: CGFloat = 380
    let label = NSTextField(wrappingLabelWithString: "")
    label.attributedStringValue = helpText()
    label.isSelectable = false
    label.preferredMaxLayoutWidth = width
    let fit = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: 10_000)) ?? NSSize(width: width, height: 300)
    // The alert puts the accessory view about 4 points left of the title text (measured in an off-screen render);
    // a wider plain container with the label shifted right lines the two left edges up.
    let shift: CGFloat = 4
    label.frame = NSRect(x: shift, y: 0, width: width, height: ceil(fit.height))
    let box = NSView(frame: NSRect(x: 0, y: 0, width: width + shift, height: ceil(fit.height)))
    box.addSubview(label)
    a.accessoryView = box
    a.addButton(withTitle: "OK")
    return a
}
