//
//  MealPlanView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Main view

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [MealPlanEntry]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0
    @AppStorage("weeklyMealBudget") private var weeklyBudget: Double = 0

    @State private var weekStart: Date = Date().startOfWeek
    @State private var pickingDay: IdentifiableInt? = nil
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false

    @StateObject private var calendarService = MealPlanCalendarService.shared

    // Entries for the currently displayed week
    private var weekEntries: [MealPlanEntry] {
        allEntries.filter { Calendar.current.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    // Total cost of all assigned meals this week (with tax)
    private var weekTotalCost: Double {
        weekEntries.compactMap { $0.recipe }.reduce(0) { sum, recipe in
            sum + recipe.costResult(groceryTaxRate: salesTaxRate, alcoholTaxRate: alcoholTaxRate).totalWithTax
        }
    }

    private var weekLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekNavigator
                    budgetCard
                    daysSection
                }
                .padding()
            }
            .navigationTitle("Meal Plan")
            .sheet(item: $pickingDay) { wrapper in
                RecipePickerSheet(recipes: recipes) { chosen in
                    assignMeal(chosen, toDayOffset: wrapper.value)
                } onRemove: {
                    removeMeal(fromDayOffset: wrapper.value)
                } currentRecipe: {
                    entry(for: wrapper.value)?.recipe
                }
            }
        }
    }

    // MARK: - Subviews

    private var weekNavigator: some View {
        HStack {
            Button {
                weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(.horizontal, 8)
            }
            Spacer()
            Text(weekLabel)
                .font(.headline)
            Spacer()
            Button {
                weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(.horizontal, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var budgetCard: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Weekly Budget")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isEditingBudget {
                    HStack(spacing: 4) {
                        Text("$").foregroundColor(.secondary)
                        TextField("e.g. 150", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Done") {
                            weeklyBudget = Double(budgetText) ?? weeklyBudget
                            isEditingBudget = false
                        }
                        .font(.subheadline)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                } else {
                    Button {
                        budgetText = weeklyBudget > 0 ? String(format: "%g", weeklyBudget) : ""
                        isEditingBudget = true
                    } label: {
                        Text(weeklyBudget > 0 ? String(format: "$%.2f", weeklyBudget) : "Set budget")
                            .font(.subheadline)
                            .foregroundColor(weeklyBudget > 0 ? .primary : .accentColor)
                    }
                }
            }

            if weeklyBudget > 0 {
                let remaining = weeklyBudget - weekTotalCost
                let overBudget = remaining < 0

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meals total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", weekTotalCost))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(overBudget ? "Over budget" : "Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", abs(remaining)))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(overBudget ? .red : .green)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(overBudget ? Color.red : Color.green)
                            .frame(width: min(CGFloat(weekTotalCost / weeklyBudget), 1.0) * geo.size.width)
                    }
                }
                .frame(height: 8)
            } else {
                Text(String(format: "Meals total: $%.2f", weekTotalCost))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var daysSection: some View {
        VStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { offset in
                dayRow(offset: offset)
            }
        }
    }

    private func dayRow(offset: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
        let dayName = date.formatted(.dateTime.weekday(.wide))
        let dateLabel = date.formatted(.dateTime.month().day())
        let assignedRecipe = entry(for: offset)?.recipe
        let isToday = Calendar.current.isDateInToday(date)

        return Button {
            pickingDay = IdentifiableInt(value: offset)
        } label: {
            HStack(spacing: 12) {
                // Day label
                VStack(spacing: 2) {
                    Text(String(dayName.prefix(3)).uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isToday ? .accentColor : .secondary)
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundColor(isToday ? .accentColor : .primary)
                }
                .frame(width: 44)

                Divider().frame(height: 36)

                if let recipe = assignedRecipe {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        let cost = recipe.costResult(groceryTaxRate: salesTaxRate, alcoholTaxRate: alcoholTaxRate)
                        Text(cost.formattedTotalCost)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No meal planned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
                Image(systemName: assignedRecipe == nil ? "plus.circle" : "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isToday ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func entry(for dayOffset: Int) -> MealPlanEntry? {
        weekEntries.first { $0.dayOffset == dayOffset }
    }

    private func assignMeal(_ recipe: Recipe, toDayOffset offset: Int) {
        let calendarService = MealPlanCalendarService.shared
        let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart

        if let existing = entry(for: offset) {
            // Remove old calendar event if we stored one
            if let oldId = existing.calendarEventId {
                try? calendarService.removeEvent(identifier: oldId)
            }
            existing.recipe = recipe
            existing.calendarEventId = nil
        } else {
            let newEntry = MealPlanEntry(weekStartDate: weekStart, dayOffset: offset, recipe: recipe)
            modelContext.insert(newEntry)
        }
        try? modelContext.save()

        // Offer calendar integration
        Task {
            await addToCalendarIfAllowed(recipeName: recipe.name, date: date, dayOffset: offset)
        }
    }

    private func removeMeal(fromDayOffset offset: Int) {
        guard let existing = entry(for: offset) else { return }
        if let oldId = existing.calendarEventId {
            try? MealPlanCalendarService.shared.removeEvent(identifier: oldId)
        }
        modelContext.delete(existing)
        try? modelContext.save()
    }

    private func addToCalendarIfAllowed(recipeName: String, date: Date, dayOffset: Int) async {
        let status = calendarService.authorizationStatus
        let hasAccess: Bool
        if status == .notDetermined {
            hasAccess = await calendarService.requestAccess()
        } else {
            hasAccess = calendarService.isAuthorized
        }
        guard hasAccess else { return }
        if let eventId = try? calendarService.addMeal(name: recipeName, on: date),
           let existing = entry(for: dayOffset) {
            existing.calendarEventId = eventId
            try? modelContext.save()
        }
    }
}

// Thin Identifiable wrapper so we can use .sheet(item:) with an Int day offset.
private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - Recipe picker sheet

private struct RecipePickerSheet: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void
    let onRemove: () -> Void
    let currentRecipe: () -> Recipe?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Recipe] {
        searchText.isEmpty ? recipes : recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if let current = currentRecipe() {
                    Section {
                        Button(role: .destructive) {
                            onRemove()
                            dismiss()
                        } label: {
                            Label("Remove \(current.name)", systemImage: "trash")
                        }
                    }
                }

                Section(header: Text("Choose a Recipe")) {
                    if filtered.isEmpty {
                        Text("No recipes found.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filtered) { recipe in
                            Button {
                                onSelect(recipe)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name)
                                        .foregroundColor(.primary)
                                        .font(.subheadline)
                                    Text(String(format: "$%.2f total · %d servings", recipe.totalCost, recipe.servingsPerBatch))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Assign Meal")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}
