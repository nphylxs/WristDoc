import SwiftUI
import Charts

// MARK: - App Entry Point
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            NavBarView() // This is the new root view
        }
    }
}

// MARK: - Navigation Structure
struct NavBarView: View {
    var body: some View {
        TabView {
            HealthChartsView()
                .tabItem {
                    Label("Summary", systemImage: "chart.bar.xaxis")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}


// MARK: - Main Health Charts Screen
struct HealthChartsView: View {
    private let healthData = HealthDataPoint.sampleData
    @State private var aiSummary: String = ""
    @State private var isLoadingSummary: Bool = false
    
    // Structure for Gemini API response
    struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String
                }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.green.opacity(0.4)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Header
                        VStack(alignment: .center, spacing: 2) {
                            Image("Header")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)

                        // Chart Cards
                        HeartRateCard(data: healthData)
                        SleepCard(data: healthData)
                        TemperatureCard(data: healthData)
                        
                        // AI Summary Card
                        AISummaryCard(summary: $aiSummary, isLoading: $isLoadingSummary) {
                            Task {
                                await generateAISummary()
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // Function to generate AI summary
    func generateAISummary() async {
        await MainActor.run {
            isLoadingSummary = true
            aiSummary = ""
        }

        let apiKey = "" // API key removed for security
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                 aiSummary = "Error: Invalid URL"
                 isLoadingSummary = false
            }
            return
        }
        
        let dataFormatter = DateFormatter()
        dataFormatter.dateFormat = "MMM d"
        let dataString = healthData.map { point in
            "Date: \(dataFormatter.string(from: point.date)), Resting HR: \(String(format: "%.0f", point.restingHeartRate)) BPM, Sleep: \(String(format: "%.1f", point.sleepDuration)) hours, Wrist Temp Variance: \(String(format: "%+.2f", point.wristTemperatureVariance))°C"
        }.joined(separator: "\n")
        
        let systemPrompt = "You are a helpful medical assistant. Analyze the following daily health data for a patient. Provide a concise, professional summary for a doctor, written in bullet points. Highlight any notable trends, potential concerns, or patterns in resting heart rate, sleep duration, and wrist temperature. Do not use markdown like asterisks."
        let userPrompt = "Here is the patient's health data for the last 5 days:\n\(dataString)"

        let payload: [String: Any] = [
            "contents": [["parts": [["text": userPrompt]]]],
            "systemInstruction": ["parts": [["text": systemPrompt]]]
        ]
        
        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body

            let (data, _) = try await URLSession.shared.data(for: request)
            let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            if let text = decodedResponse.candidates.first?.content.parts.first?.text {
                 await MainActor.run {
                    aiSummary = text
                 }
            } else {
                await MainActor.run {
                    aiSummary = "Could not generate a summary. Please try again."
                }
            }
        } catch {
            await MainActor.run {
                aiSummary = "An error occurred: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoadingSummary = false
        }
    }
}

// MARK: - Placeholder Screens
struct ProfileView: View {
    
    @State private var name: String = "John Doe"
    @State private var dob: Date = Calendar.current.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? Date()
    @State private var weight: Double = 70.0 // in kg
    @State private var height: Double = 170.0 // in cm
    @State private var isEditing: Bool = false
    
    var age: Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        return ageComponents.year ?? 0
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.green.opacity(0.4)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack{
                VStack(alignment: .leading, spacing:20) {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .topLeading ) // Keep title centered
                    VStack(spacing:0) {
                        
                    }
                    
                    if isEditing {
                        HStack {
                            Text("Name:")
                            TextField("", text: $name)
                                .textFieldStyle(DefaultTextFieldStyle())
                                .foregroundColor(.white)
                                .border(Color.white.opacity(0.3), width: 1)
                        }
                        
                        
                        DatePicker("DOB", selection: $dob, displayedComponents: .date)
                            .foregroundColor(.white)
                            .scaledToFit()
                        
                        HStack {
                            Text("Weight (kg):")
                            TextField("", value: $weight, format: .number)
                                .textFieldStyle(DefaultTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .border(Color.white.opacity(0.3), width: 1)
                        }
                        .foregroundColor(.white)
                        
                        HStack {
                            Text("Height (cm):")
                            TextField("", value: $height, format: .number)
                                .textFieldStyle(DefaultTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .border(Color.white.opacity(0.3), width: 1)
                        }
                        .foregroundColor(.white)
                    } else {
                        Text("Name: \(name)")
                            .foregroundColor(.white)
                        
                        Text("DOB: \(dob, formatter: dateFormatter)")
                            .foregroundColor(.white)
                        
                        Text("Age: \(age)")
                            .foregroundColor(.white)
                        
                        Text("Weight: \(weight, specifier: "%.1f") kg")
                            .foregroundColor(.white)
                        
                        Text("Height: \(height, specifier: "%.1f") cm")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "Save" : "Edit")
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Align button to left
                }
                .padding()
                Spacer()
            }
        }
        }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}

#Preview {
    ProfileView()
}
struct SettingsView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.green.opacity(0.4)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            Text("Settings Screen")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}


// MARK: - Data Model
struct HealthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let restingHeartRate: Double
    let sleepingHeartRate: Double
    let sleepDuration: Double // in hours
    let wristTemperatureVariance: Double // in Celsius

    var dayAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Sample Data
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

// MARK: - Chart Card and Other Components
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
            HStack {
                Image(systemName: systemImageName)
                    .font(.title2)
                    .foregroundColor(.pink)
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            content.frame(minHeight: 200)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .padding(.horizontal)
    }
}

struct AISummaryCard: View {
    @Binding var summary: String
    @Binding var isLoading: Bool
    var generateAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                Text("AI Health Report")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else if summary.isEmpty {
                Button(action: generateAction) {
                    Text("Generate Doctor's Summary")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                }
            } else {
                Text(summary)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .padding(.horizontal)
    }
}


// MARK: - Specific Chart Implementations
struct HeartRateCard: View {
    let data: [HealthDataPoint]

    var body: some View {
        ChartCard(title: "Heart Rate", systemImageName: "heart.fill") {
            Chart(data) { point in
                LineMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("BPM", point.restingHeartRate)
                )
                .foregroundStyle(by: .value("Metric", "Resting"))
                .symbol(by: .value("Metric", "Resting"))
                .interpolationMethod(.catmullRom)

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
            .chartForegroundStyleScale(["Resting": .pink, "Sleeping": .purple])
            .chartLegend(position: .top, alignment: .trailing)
        }
    }
}

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

struct TemperatureCard: View {
    let data: [HealthDataPoint]

    var body: some View {
        ChartCard(title: "Wrist Temperature", systemImageName: "thermometer.medium") {
            Chart(data) { point in
                LineMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("Variance", point.wristTemperatureVariance)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                .symbol(Circle().strokeBorder(lineWidth: 2))
                .symbolSize(CGSize(width: 8, height: 8))

                AreaMark(
                    x: .value("Day", point.dayAbbreviation),
                    y: .value("Variance", point.wristTemperatureVariance)
                )
                .foregroundStyle(Color.orange.gradient.opacity(0.2))
                .interpolationMethod(.catmullRom)
                
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
        NavBarView()
            .preferredColorScheme(.dark)
    }
}

