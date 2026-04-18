//
//  VendeView.swift
//  milpa
//
//  Created by Alumno on 17/04/26.
//

import SwiftUI

import SwiftUI
import Charts

struct VendeView: View {
    @StateObject private var viewModel = VendeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                MilpaColor.cream.ignoresSafeArea()
                VStack {
                    LinearGradient(colors: [MilpaColor.green.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 300)
                        .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Milpa vigila el precio por ti")
                            .font(MilpaFont.sans(15))
                            .foregroundStyle(MilpaColor.ink2)
                            .padding(.bottom, 8)
                            
                        priceCard
                        recommendation
                        markets
                    }
                    .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 110)
                }
            }
            .navigationTitle("Mercado")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.selectedCrop)
                        .font(MilpaFont.sans(12, weight: .medium))
                        .kerning(0.4).foregroundStyle(MilpaColor.ink3)
                        .accessibilityAddTraits(.isHeader)
                    Text(String(format: "$%.2f", viewModel.currentPrice)).font(MilpaFont.serif(44, weight: .medium))
                        .foregroundStyle(MilpaColor.ink)
                        .accessibilityLabel(Text("Precio actual: \(viewModel.currentPrice) pesos por kilo"))
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MilpaColor.greenD)
                            .padding(4).background(MilpaColor.greenBg, in: Circle())
                            .accessibilityHidden(true)
                        Text(String(format: "+%.1f%% esta semana", viewModel.priceTrend))
                            .font(MilpaFont.sans(13, weight: .medium))
                            .foregroundStyle(MilpaColor.greenD)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Chip(text: "Buen momento", bg: MilpaColor.greenBg, fg: MilpaColor.greenD)
                    ListenButton(
                        text: "Frijol negro, 25 pesos con 40 centavos el kilo. Subió 8.1 por ciento esta semana.",
                        variant: .icon)
                }
            }
            
            // Native SwiftUI Charts instead of custom Sparkline
            Chart(viewModel.priceHistory) { point in
                LineMark(
                    x: .value("Día", point.day),
                    y: .value("Precio", point.price)
                )
                .foregroundStyle(MilpaColor.greenD)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Día", point.day),
                    y: .value("Precio", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [MilpaColor.greenD.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 90)
            .accessibilityLabel("Gráfica de precios históricos con tendencia al alza")
        }
        .padding(18)
        .background(MilpaColor.paper, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    private var recommendation: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22).fill(MilpaColor.green)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    MilpaMark(size: 22)
                    Text("MILPA RECOMIENDA")
                        .font(MilpaFont.sans(12, weight: .medium))
                        .kerning(0.3).foregroundStyle(MilpaColor.cream.opacity(0.7))
                        .accessibilityAddTraits(.isHeader)
                }
                Text("Vende el viernes en el mercado de Oaxaca. Pronóstico sube a $26.80/kg.")
                    .font(MilpaFont.serif(20, weight: .regular))
                    .foregroundStyle(MilpaColor.cream)
                HStack {
                    Chip(text: "+$420 vs. vender hoy",
                         bg: MilpaColor.corn.opacity(0.22), fg: MilpaColor.corn)
                    Spacer()
                    ListenButton(text: viewModel.recommendationAudio, variant: .onDark)
                }
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
    }

    private var markets: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Mercados cerca de ti", trailing: "Ver mapa")
            
            ForEach(viewModel.markets) { market in
                MarketRow(name: market.name, km: market.km, price: market.price, trend: market.trend, best: market.isBest)
            }
        }
    }
}

#Preview {
    VendeView()
}

