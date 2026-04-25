// LegalDocumentView.swift
// Eye & Posture Reminder
//
// Reusable sheet for displaying legal documents (Terms & Conditions / Privacy Policy).

import SwiftUI

enum LegalDocument {
    case terms
    case privacy
}

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    switch document {
                    case .terms:
                        termsContent
                    case .privacy:
                        privacyContent
                    }
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "legal.dismissButton", bundle: .module)) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var navTitle: Text {
        switch document {
        case .terms:  Text("legal.terms.navTitle", bundle: .module)
        case .privacy: Text("legal.privacy.navTitle", bundle: .module)
        }
    }

    // MARK: - Terms Content

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            LegalSection(
                heading: Text("legal.terms.notMedical.heading", bundle: .module),
                content: Text("legal.terms.notMedical.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.terms.professional.heading", bundle: .module),
                content: Text("legal.terms.professional.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.terms.liability.heading", bundle: .module),
                content: Text("legal.terms.liability.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.terms.warranty.heading", bundle: .module),
                content: Text("legal.terms.warranty.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.terms.contact.heading", bundle: .module),
                content: Text("legal.terms.contact.body", bundle: .module)
            )
        }
    }

    // MARK: - Privacy Content

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            LegalSection(
                heading: Text("legal.privacy.collect.heading", bundle: .module),
                content: Text("legal.privacy.collect.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.privacy.noCollect.heading", bundle: .module),
                content: Text("legal.privacy.noCollect.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.privacy.rights.heading", bundle: .module),
                content: Text("legal.privacy.rights.body", bundle: .module)
            )
            LegalSection(
                heading: Text("legal.privacy.contact.heading", bundle: .module),
                content: Text("legal.privacy.contact.body", bundle: .module)
            )
        }
    }
}

// MARK: - LegalSection

private struct LegalSection: View {
    let heading: Text
    let content: Text

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            heading
                .font(AppFont.bodyEmphasized)
                .foregroundStyle(.primary)
            content
                .font(AppFont.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LegalDocumentView(document: .terms)
}

#Preview("Privacy") {
    LegalDocumentView(document: .privacy)
}
