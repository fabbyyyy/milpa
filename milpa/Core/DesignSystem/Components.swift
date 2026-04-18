//
//  Components.swift
//  MilpaApp
//
//  Created by Alumno on 17/04/26.
//

import SwiftUI

enum MilpaTone {
    case green, ocre, sky, rust, ink
    var bg: Color { switch self {
        case .green: return MilpaColor.greenBg; case .ocre: return MilpaColor.ocreBg
        case .sky: return MilpaColor.skyBg; case .rust: return MilpaColor.rustBg
        case .ink: return MilpaColor.cream2
    } }
    var fg: Color { switch self {
        case .green: return MilpaColor.greenD; case .ocre: return MilpaColor.ocreD
        case .sky: return MilpaColor.sky; case .rust: return MilpaColor.rust
        case .ink: return MilpaColor.ink
    } }
}

struct Chip: View {
    let text: String; let bg: Color; let fg: Color
    init(text: String, bg: Color, fg: Color) {
        self.text = text; self.bg = bg; self.fg = fg
    }
    var body: some View {
        Text(text).font(MilpaFont.sans(12, weight: .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(bg, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String; var trailing: String?
    init(_ title: String, trailing: String? = nil) {
        self.title = title; self.trailing = trailing
    }
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(MilpaFont.sans(13, weight: .medium))
                .kerning(0.6).foregroundStyle(MilpaColor.ink3)
            Spacer()
            if let t = trailing {
                Text(t).font(MilpaFont.sans(13, weight: .medium))
                    .foregroundStyle(MilpaColor.greenD)
            }
        }
        .padding(.horizontal, 4)
    }
}



struct StripedPlaceholder: View {
    let label: String; var height: CGFloat = 100
    var body: some View {
        ZStack {
            LinearGradient(colors: [MilpaColor.greenBg, MilpaColor.paper],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(label).font(MilpaFont.mono(10))
                .foregroundStyle(MilpaColor.greenD.opacity(0.7))
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(MilpaColor.ink.opacity(0.08)))
    }
}

struct StatCol: View {
    var value: String? = nil
    var icon: String? = nil
    let label: String
    let tint: Color
    var body: some View {
        VStack(spacing: 2) {
            if let v = value {
                Text(v).font(MilpaFont.serif(26, weight: .semibold))
                    .foregroundStyle(tint)
            } else if let i = icon {
                Image(systemName: i).font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint).frame(height: 30)
            }
            Text(label).font(MilpaFont.sans(11))
                .foregroundStyle(MilpaColor.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ParcelaCard: View {
    let parcela: Parcela
    
    private var cropEmoji: String {
        switch parcela.crop.lowercased() {
        case let c where c.contains("maíz") || c.contains("maiz"): return "🌽"
        case let c where c.contains("frijol"): return "🫘"
        case let c where c.contains("calabaza"): return "🎃"
        case let c where c.contains("chile"): return "🌶️"
        case let c where c.contains("jitomate") || c.contains("tomate"): return "🍅"
        case let c where c.contains("nopal"): return "🌵"
        case let c where c.contains("aguacate"): return "🥑"
        default: return "🌱"
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background: Photo or gradient fallback
            if let data = parcela.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 230)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [MilpaColor.green.opacity(0.7), MilpaColor.greenD],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(cropEmoji)
                        .font(.system(size: 56))
                        .opacity(0.25)
                        .offset(x: 40, y: -30)
                )
            }
            
            // Dark dim overlay
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                
                // Day badge
                Text("día \(parcela.daysSinceCreation)")
                    .font(MilpaFont.mono(10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.2), in: Capsule())
                
                Text(parcela.name)
                    .font(MilpaFont.sans(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(cropEmoji).font(.system(size: 12))
                    Text(parcela.crop)
                        .font(MilpaFont.sans(12))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    if parcela.hectares > 0 {
                        Text("·").foregroundStyle(.white.opacity(0.5))
                        Text("\(parcela.hectares, specifier: "%.1f") ha")
                            .font(MilpaFont.sans(12))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 200, height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
    }
}

struct MarketRow: View {
    let name: String, km: String, price: String
    let trend: MarketRowTrend; var best: Bool = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(MilpaColor.ink2)
                .frame(width: 40, height: 40)
                .background(MilpaColor.cream2, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(MilpaFont.sans(14, weight: .semibold))
                    if best { Chip(text: "Mejor", bg: MilpaColor.greenBg, fg: MilpaColor.greenD) }
                }
                Text(km).font(MilpaFont.sans(12)).foregroundStyle(MilpaColor.ink3)
            }
            Spacer()
            Text(price).font(MilpaFont.serif(18, weight: .medium))
        }
        .padding(14)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 20))
    }
}

