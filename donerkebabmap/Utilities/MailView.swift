//
//  MailView.swift
//  donerkebabmap
//

import SwiftUI
import MessageUI

/// Uygulama içi mail yazma penceresi (MFMailComposeViewController sarmalayıcı).
/// Cihazda mail hesabı tanımlı değilse `canSendMail` false döner; o durumda
/// çağıran taraf `mailto:` linkine düşer.
struct MailView: UIViewControllerRepresentable {
    let recipient: String
    var subject: String = ""

    @Environment(\.dismiss) private var dismiss

    /// Cihazda mail gönderilebilir mi (hesap tanımlı mı)?
    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        if !subject.isEmpty {
            controller.setSubject(subject)
        }
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            dismiss()
        }
    }
}
