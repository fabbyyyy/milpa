//
//  MilpaMark.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import Foundation
import SwiftUI

struct MilpaMark: View {
    var size: CGFloat = 48
    var body: some View {
        Image("milpa-no-bg")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct Sparkline: View {
    let values: [Double]; let color: Color
    var body: some View {
        GeometryReader { geo in
            let minV = values.min() ?? 0, maxV = values.max() ?? 1
            let pts = values.enumerated().map { i, v -> CGPoint in
                let x = CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                let y = (1 - CGFloat((v - minV) / (maxV - minV))) * geo.size.height
                return CGPoint(x: x, y: y)
            }
            Path { p in
                guard let first = pts.first else { return }
                p.move(to: first); pts.dropFirst().forEach { p.addLine(to: $0) }
            }
            .stroke(color, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
