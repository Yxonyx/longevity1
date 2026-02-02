import SwiftUI
import PhotosUI

struct NutritionView: View {
    @StateObject private var foodService = FoodAnalysisService()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingMealLog = false
    @State private var selectedMealType: MealType = .lunch
    @State private var mealNotes: String = ""
    @State private var searchQuery: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's summary
                    todaySummaryCard
                    
                    // Photo capture section
                    photoCaptureSection
                    
                    // Analysis results
                    if !foodService.currentResults.isEmpty {
                        analysisResultsCard
                    }
                    
                    // Manual search
                    manualSearchSection
                    
                    // Recent meals
                    recentMealsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nutrition")
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        await foodService.analyzeImage(image)
                    }
                }
            }
            .sheet(isPresented: $showingMealLog) {
                LogMealSheet(
                    foodService: foodService,
                    mealType: $selectedMealType,
                    notes: $mealNotes
                )
            }
        }
    }
    
    // MARK: - Today's Summary
    
    private var todaySummaryCard: some View {
        let today = foodService.todayNutrition()
        
        return VStack(spacing: 16) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text("\(Int(today.calories)) kcal")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Macro breakdown
            HStack(spacing: 16) {
                macroCircle(label: "Protein", value: today.protein, goal: 150, color: .red)
                macroCircle(label: "Carbs", value: today.carbs, goal: 200, color: .blue)
                macroCircle(label: "Fat", value: today.fat, goal: 65, color: .yellow)
                macroCircle(label: "Fiber", value: today.fiber, goal: 30, color: .green)
            }
            
            // Micro highlights
            HStack {
                microItem(label: "Sugar", value: today.sugar, unit: "g", warning: today.sugar > 50)
                Spacer()
                microItem(label: "Sodium", value: today.sodium, unit: "mg", warning: today.sodium > 2300)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func macroCircle(label: String, value: Double, goal: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: min(1, value / goal))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))g")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(width: 60, height: 60)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func microItem(label: String, value: Double, unit: String, warning: Bool) -> some View {
        HStack(spacing: 4) {
            if warning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption2)
            }
            Text("\(label): \(Int(value))\(unit)")
                .font(.caption)
                .foregroundColor(warning ? .orange : .secondary)
        }
    }
    
    // MARK: - Photo Capture
    
    private var photoCaptureSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Log a Meal")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                Button {
                    showingCamera = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Camera")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.teal.opacity(0.1))
                    .foregroundColor(.teal)
                    .cornerRadius(12)
                }
                
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.title2)
                        Text("Gallery")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
                }
            }
            
            if foodService.isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyzing food...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Analysis Results
    
    private var analysisResultsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Detected Foods")
                    .font(.headline)
                Spacer()
                Button("Log Meal") {
                    showingMealLog = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            
            ForEach(foodService.currentResults) { result in
                FoodResultRow(result: result) { serving in
                    // Update serving size
                    if let index = foodService.currentResults.firstIndex(where: { $0.id == result.id }) {
                        var updated = foodService.currentResults[index]
                        updated = FoodRecognitionResult(
                            id: updated.id,
                            foodName: updated.foodName,
                            confidence: updated.confidence,
                            estimatedServing: serving,
                            nutrition: updated.nutrition,
                            alternatives: updated.alternatives
                        )
                        foodService.currentResults[index] = updated
                    }
                }
            }
            
            // Totals
            let totals = foodService.currentResults.reduce(into: NutritionEstimate.unknown) { result, food in
                let scaled = food.nutrition.scaled(by: food.estimatedServing.multiplier)
                result.calories += scaled.calories
                result.protein += scaled.protein
                result.carbs += scaled.carbs
                result.fat += scaled.fat
            }
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(totals.calories)) kcal")
                    .fontWeight(.bold)
                Text("P: \(Int(totals.protein))g")
                    .foregroundColor(.secondary)
                Text("C: \(Int(totals.carbs))g")
                    .foregroundColor(.secondary)
                Text("F: \(Int(totals.fat))g")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Manual Search
    
    private var manualSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Foods")
                .font(.headline)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search by name...", text: $searchQuery)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            
            if !searchQuery.isEmpty {
                let results = foodService.searchFoods(query: searchQuery)
                
                if results.isEmpty {
                    Text("No matches found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(results.prefix(5), id: \.name) { entry in
                        Button {
                            let result = FoodRecognitionResult(
                                foodName: entry.name,
                                confidence: 1.0,
                                nutrition: entry.nutrition
                            )
                            foodService.currentResults.append(result)
                            searchQuery = ""
                        } label: {
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Text("\(Int(entry.nutrition.calories)) kcal")
                                    .foregroundColor(.secondary)
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.teal)
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Meals
    
    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Meals")
                .font(.headline)
            
            let todayMeals = foodService.mealLogs.filter {
                Calendar.current.isDateInToday($0.timestamp)
            }
            
            if todayMeals.isEmpty {
                Text("No meals logged today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(todayMeals.sorted(by: { $0.timestamp > $1.timestamp })) { meal in
                    HStack {
                        Image(systemName: meal.mealType.icon)
                            .foregroundColor(.teal)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.mealType.rawValue.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(meal.foods.map { $0.foodName }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(meal.totalNutrition.calories)) kcal")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(meal.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Food Result Row

struct FoodResultRow: View {
    let result: FoodRecognitionResult
    let onServingChange: (ServingSize) -> Void
    
    @State private var expandedServing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.foodName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 4) {
                        Text("Conf: \(Int(result.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !result.alternatives.isEmpty {
                            Text("• Also: \(result.alternatives.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Serving picker
                Menu {
                    ForEach(ServingSize.allCases, id: \.self) { size in
                        Button(size.rawValue) {
                            onServingChange(size)
                        }
                    }
                } label: {
                    HStack {
                        Text(result.estimatedServing.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
                }
            }
            
            // Nutrition preview
            let scaled = result.nutrition.scaled(by: result.estimatedServing.multiplier)
            HStack(spacing: 16) {
                nutritionTag("Cal", value: scaled.calories, unit: "")
                nutritionTag("P", value: scaled.protein, unit: "g")
                nutritionTag("C", value: scaled.carbs, unit: "g")
                nutritionTag("F", value: scaled.fat, unit: "g")
            }
        }
        .padding(.vertical, 8)
    }
    
    private func nutritionTag(_ label: String, value: Double, unit: String) -> some View {
        Text("\(label): \(Int(value))\(unit)")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(4)
    }
}

// MARK: - Log Meal Sheet

struct LogMealSheet: View {
    @ObservedObject var foodService: FoodAnalysisService
    @Binding var mealType: MealType
    @Binding var notes: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Type") {
                    Picker("Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue.capitalized)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Foods (\(foodService.currentResults.count))") {
                    ForEach(foodService.currentResults) { result in
                        HStack {
                            Text(result.foodName)
                            Spacer()
                            Text("\(Int(result.nutrition.scaled(by: result.estimatedServing.multiplier).calories)) kcal")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section {
                    let total = foodService.currentResults.reduce(into: NutritionEstimate.unknown) { acc, food in
                        let scaled = food.nutrition.scaled(by: food.estimatedServing.multiplier)
                        acc.calories += scaled.calories
                        acc.protein += scaled.protein
                        acc.carbs += scaled.carbs
                        acc.fat += scaled.fat
                    }
                    
                    HStack {
                        Text("Total Calories")
                        Spacer()
                        Text("\(Int(total.calories)) kcal")
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Macros")
                        Spacer()
                        Text("P: \(Int(total.protein))g  C: \(Int(total.carbs))g  F: \(Int(total.fat))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        foodService.logMeal(
                            type: mealType,
                            foods: foodService.currentResults,
                            notes: notes.isEmpty ? nil : notes
                        )
                        foodService.currentResults = []
                        notes = ""
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(foodService.currentResults.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NutritionView()
}
