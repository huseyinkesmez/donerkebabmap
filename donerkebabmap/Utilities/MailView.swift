//
//  MailView.swift
//  donerkebabmap
//

import SwiftUI
import MessageUI

/// In-app mail composer (a wrapper around MFMailComposeViewController).
/// When no mail account is set up, `canSendMail` returns false and the caller
/// falls back to a `mailto:` link.
struct MailView: UIViewControllerRepresentable {
    let recipient: String
    var subject: String = ""

    @Environment(\.dismiss) private var dismiss

    /// Whether this device can send mail (i.e. has an account set up).
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
