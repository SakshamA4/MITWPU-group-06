//
//  LabeledSliderView.swift
//  FilmsPage
//
//  A reusable slider component with a title, formatted value, and custom styling.
//

import SwiftUI

struct LabeledSliderView: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                Spacer()
                Text(unit.isEmpty ? String(format: "%.2f", value) : String(format: "%.2f%@", value, unit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}
