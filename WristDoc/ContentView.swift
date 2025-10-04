import SwiftUI
import Charts



// MARK: - Data Model
// This struct represents a single day's health data.
struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let restingHeartRate: Double
    let sleepingHeartRate: Double
    let sleepDuration: Double // in hours
    let wristTemperatureVariance: Double // in Celsius

    // Helper to format the day for chart labels
    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // e.g., "Mon", "Tue"
        return formatter.string(from: date)
    }
}

// MARK: - Sample Data
// A static list of mock data for the last 5 days.
extension HealthDataPoint {
    static var sampleData: [HealthDataPoint] {
        var data: [HealthDataPoint] = []
        for i in (0..<5).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            data.append(HealthDataPoint(
                date: date,
                restingHeartRate: Double.random(in: 80...100),
                sleepingHeartRate: Double.random(in: 48...54),
                sleepDuration: Double.random(in: 6.5...8.5),
                wristTemperatureVariance: Double.random(in: -0.5...0.5)
            ))
        }
        return data
    }
}


// MARK: - Main View
struct HealthChartsView: View {
    private let healthData = HealthDataPoint.sampleData

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Summary")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Last 5 Days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // Chart Cards
                    HeartRateCard(data: healthData)
                    SleepCard(data: healthData)
                    TemperatureCard(data: healthData)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Chart Card Components
struct ChartCard<Content: View>: View {
    let title: String
    let systemImageName: String
    let content: Content

    init(title: String, systemImageName: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImageName = systemImageName
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            HStack {
                Image(systemName: systemImageName)
                    .font(.title2)
                    .foregroundColor(.pink)
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            // Chart Content
            content
                .frame(height: 200)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}


// MARK: - Specific Chart Implementations

// 1. Heart Rate Chart
struct HeartRateCard: View {
    let data: [HealthDataPoint]

    var body: some View {
        ChartCard(title: "Heart Rate", systemImageName: "heart.fill") {
            Chart(data) { point in
                // Resting Heart Rate Line
                LineMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("BPM", point.restingHeartRate)
                )
                .foregroundStyle(by: .value("Metric", "Resting"))
                .symbol(by: .value("Metric", "Resting"))
                .interpolationMethod(.catmullRom)

                // Sleeping Heart Rate Line
                LineMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("BPM", point.sleepingHeartRate)
                )
                .foregroundStyle(by: .value("Metric", "Sleeping"))
                .symbol(by: .value("Metric", "Sleeping"))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel("\(value.as(Double.self) ?? 0, specifier: "%.0f") BPM")
                }
            }
            .chartForegroundStyleScale([
                "Resting": .pink,
                "Sleeping": .purple
            ])
            .chartLegend(position: .top, alignment: .trailing)
        }
    }
}

// 2. Sleep Time Chart
struct SleepCard: View {
    let data: [HealthDataPoint]

    var body: some View {
        ChartCard(title: "Sleep Time", systemImageName: "moon.stars.fill") {
            Chart(data) { point in
                BarMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("Hours", point.sleepDuration),
                    width: .ratio(0.6)
                )
                .foregroundStyle(Color.cyan.gradient)
                .cornerRadius(6)
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel("\(value.as(Double.self) ?? 0, specifier: "%.1f") hr")
                }
            }
        }
    }
}

// 3. Wrist Temperature Chart
struct TemperatureCard: View {
    let data: [HealthDataPoint]
    
    // Find the baseline (average) to draw the zero line
    private var averageVariance: Double {
        data.map(\.wristTemperatureVariance).reduce(0, +) / Double(data.count)
    }

    var body: some View {
        ChartCard(title: "Wrist Temperature", systemImageName: "thermometer.medium") {
            Chart(data) { point in
                // Line for the temperature variance
                LineMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("Variance", point.wristTemperatureVariance)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 8, height: 8))

                // Area under the line to highlight the variance
                AreaMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("Variance", point.wristTemperatureVariance)
                )
                .foregroundStyle(Color.orange.gradient.opacity(0.2))
                .interpolationMethod(.catmullRom)
                
                // Rule mark for the baseline
                RuleMark(y: .value("Baseline", 0))
                    .foregroundStyle(.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .leading) {
                         Text("Baseline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, position: .leading) { value in
                     AxisGridLine()
                     let tempValue = value.as(Double.self) ?? 0
                     AxisValueLabel(String(format: "%+.1f°C", tempValue))
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct HealthChartsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthChartsView()
            .preferredColorScheme(.dark)
    }
}

