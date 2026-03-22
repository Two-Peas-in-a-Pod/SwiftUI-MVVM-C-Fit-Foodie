//
//  MealPlanView.swift
//  SwiftUI-MVVM-C
//

import SwiftUI
import SwiftData
import EventKit
import UIKit

// MARK: - Main view

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [MealPlanEntry]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @AppStorage("salesTaxRate") private var salesTaxRate: Double = 0
    @AppStorage("alcoholTaxRate") private var alcoholTaxRate: Double = 0
    @AppStorage("weeklyMealBudget") private var weeklyBudget: Double = 0
    @AppStorage("weeklyBudgetEnabled") private var weeklyBudgetEnabled: Bool = false
    @AppStorage("preferredCalendarId") private var preferredCalendarId: String = ""

    @State private var baseWeekStart: Date = Date().startOfWeek
    @State private var pageIndex: Int = 500
    @State private var pickingDay: IdentifiableInt? = nil
    @State private var budgetText: String = ""
    @State private var isEditingBudget = false
    @State private var isShowingCalendarPicker = false
    @State private var isShowingSettings = false

    @StateObject private var calendarService = MealPlanCalendarService.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                weekHeader(ws: currentWeekStart)
                    .padding([.horizontal, .top])
                    .padding(.bottom, 8)
                TabView(selection: $pageIndex) {
                    ForEach(0..<1000, id: \.self) { index in
                        weekPage(forIndex: index).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if pageIndex != 500 {
                        Button("This Week") {
                            withAnimation { pageIndex = 500 }
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(item: $pickingDay) { wrapper in
                DayPlanSheet(
                    dayOffset: wrapper.value,
                    weekStart: currentWeekStart,
                    recipes: recipes,
                    onAssign: { assignMeal($0, toDayOffset: wrapper.value) },
                    onRemove: { removeMeal(fromDayOffset: wrapper.value) },
                    onSave: { try? modelContext.save() }
                )
            }
            .sheet(isPresented: $isShowingCalendarPicker) {
                CalendarPickerSheet(preferredCalendarId: preferredCalendarId) { calendar in
                    exportWeekToCalendar(calendar)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                CostSettingsSheet()
            }
        }
    }

    // MARK: - Week page

    private var currentWeekStart: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: pageIndex - 500, to: baseWeekStart) ?? baseWeekStart
    }

    @ViewBuilder
    private func weekPage(forIndex index: Int) -> some View {
        let ws = Calendar.current.date(byAdding: .weekOfYear, value: index - 500, to: baseWeekStart) ?? baseWeekStart
        let entries = allEntries.filter { Calendar.current.isDate($0.weekStartDate, inSameDayAs: ws) }
        let assigned = entries.filter { $0.recipe != nil }
        let totalCost = assigned.reduce(0.0) { sum, e in
            guard let r = e.recipe else { return sum }
            return sum + r.costResult(
                onHandIds: Set(e.onHandIngredientIds),
                groceryTaxRate: salesTaxRate / 100,
                alcoholTaxRate: alcoholTaxRate / 100
            ).totalWithTax
        }
        ScrollView {
            VStack(spacing: 16) {
                budgetCardView(totalCost: totalCost, assigned: assigned)
                daysSectionView(ws: ws, entries: entries)
            }
            .padding()
        }
    }

    // MARK: - Week header

    private func weekHeader(ws: Date) -> some View {
        HStack {
            Button { withAnimation { pageIndex -= 1 } } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(.horizontal, 8)
            }
            Spacer()
            Text(weekLabel(for: ws))
                .font(.headline)
            Spacer()
            Button { withAnimation { pageIndex += 1 } } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(.horizontal, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func weekLabel(for date: Date) -> String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: date) ?? date
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: date)) – \(fmt.string(from: end))"
    }

    // MARK: - Budget card

    private func budgetCardView(totalCost: Double, assigned: [MealPlanEntry]) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(weeklyBudgetEnabled ? "Weekly Budget" : "This Week")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if weeklyBudgetEnabled {
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
                        HStack(spacing: 8) {
                            Text(weeklyBudget > 0 ? String(format: "$%.2f", weeklyBudget) : "Not set")
                                .font(.subheadline)
                                .foregroundColor(weeklyBudget > 0 ? .primary : .secondary)
                            Button("Edit") {
                                budgetText = weeklyBudget > 0 ? String(format: "%g", weeklyBudget) : ""
                                isEditingBudget = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            if weeklyBudgetEnabled && weeklyBudget > 0 {
                let remaining = weeklyBudget - totalCost
                let overBudget = remaining < 0

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meals total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "$%.2f", totalCost))
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

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(overBudget ? Color.red : Color.green)
                            .frame(width: min(CGFloat(totalCost / weeklyBudget), 1.0) * geo.size.width)
                    }
                }
                .frame(height: 8)
            } else {
                Text(String(format: "Meals total: $%.2f", totalCost))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !assigned.isEmpty {
                Divider()
                Button {
                    Task { await addToCalendarTapped() }
                } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Days section

    private func daysSectionView(ws: Date, entries: [MealPlanEntry]) -> some View {
        VStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { offset in
                dayRow(offset: offset, weekStart: ws, entries: entries)
            }
        }
    }

    private func dayRow(offset: Int, weekStart ws: Date, entries: [MealPlanEntry]) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: ws) ?? ws
        let dayName = date.formatted(.dateTime.weekday(.wide))
        let dateLabel = date.formatted(.dateTime.month().day())
        let assignedEntry = entries.first { $0.dayOffset == offset }
        let assignedRecipe = assignedEntry?.recipe
        let isToday = Calendar.current.isDateInToday(date)

        return Button {
            pickingDay = IdentifiableInt(value: offset)
        } label: {
            HStack(spacing: 12) {
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
                    let onHandIds = Set(assignedEntry?.onHandIngredientIds ?? [])
                    let buyCost = recipe.costResult(onHandIds: onHandIds, groceryTaxRate: salesTaxRate / 100, alcoholTaxRate: alcoholTaxRate / 100)
                    let fullCost = onHandIds.isEmpty ? buyCost : recipe.costResult(groceryTaxRate: salesTaxRate / 100, alcoholTaxRate: alcoholTaxRate / 100)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if onHandIds.isEmpty {
                            Text(buyCost.formattedTotalCost)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 4) {
                                Text(buyCost.formattedTotalCost + " to buy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(fullCost.formattedTotalCost + " full")
                                    .font(.caption)
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                        }
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

    // MARK: - Meal assignment

    private func entry(for dayOffset: Int, weekStart ws: Date) -> MealPlanEntry? {
        allEntries.first {
            $0.dayOffset == dayOffset &&
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: ws)
        }
    }

    private func assignMeal(_ recipe: Recipe, toDayOffset offset: Int) {
        if let existing = entry(for: offset, weekStart: currentWeekStart) {
            if let oldId = existing.calendarEventId {
                try? calendarService.removeEvent(identifier: oldId)
            }
            existing.onHandIngredientIds = []
            existing.recipe = recipe
            existing.calendarEventId = nil
        } else {
            let newEntry = MealPlanEntry(weekStartDate: currentWeekStart, dayOffset: offset, recipe: recipe)
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
    }

    private func removeMeal(fromDayOffset offset: Int) {
        guard let existing = entry(for: offset, weekStart: currentWeekStart) else { return }
        if let oldId = existing.calendarEventId {
            try? calendarService.removeEvent(identifier: oldId)
        }
        existing.recipe = nil  // nil out before delete so stale @Query renders skip this entry
        modelContext.delete(existing)
        try? modelContext.save()
    }

    // MARK: - Calendar export

    private func addToCalendarTapped() async {
        if !calendarService.isAuthorized {
            guard await calendarService.requestAccess() else { return }
        }
        if let saved = calendarService.calendar(for: preferredCalendarId) {
            exportWeekToCalendar(saved)
        } else {
            isShowingCalendarPicker = true
        }
    }

    private func exportWeekToCalendar(_ calendar: EKCalendar) {
        preferredCalendarId = calendar.calendarIdentifier
        let entries = allEntries.filter { Calendar.current.isDate($0.weekStartDate, inSameDayAs: currentWeekStart) }
        for entry in entries where entry.recipe != nil {
            guard let recipe = entry.recipe else { continue }
            if let oldId = entry.calendarEventId {
                try? calendarService.removeEvent(identifier: oldId)
                entry.calendarEventId = nil
            }
            if let eventId = try? calendarService.addMeal(name: recipe.name, on: entry.date, to: calendar) {
                entry.calendarEventId = eventId
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Identifiable Int wrapper

private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - Day plan sheet (recipe picker with NavigationStack push/pop)

private struct DayPlanSheet: View {
    let dayOffset: Int
    let weekStart: Date
    let recipes: [Recipe]
    let onAssign: (Recipe) -> Void
    let onRemove: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var allEntries: [MealPlanEntry]
    @State private var searchText = ""
    @State private var path: [Recipe]

    init(dayOffset: Int, weekStart: Date, recipes: [Recipe],
         onAssign: @escaping (Recipe) -> Void,
         onRemove: @escaping () -> Void,
         onSave: @escaping () -> Void) {
        self.dayOffset = dayOffset
        self.weekStart = weekStart
        self.recipes = recipes
        self.onAssign = onAssign
        self.onRemove = onRemove
        self.onSave = onSave
        _path = State(initialValue: [])
    }

    private var entry: MealPlanEntry? {
        allEntries.first {
            $0.dayOffset == dayOffset &&
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }
    }

    private var filtered: [Recipe] {
        searchText.isEmpty ? recipes : recipes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            pickerList
                .navigationTitle("Choose a Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .navigationDestination(for: Recipe.self) { recipe in
                    PlanDayDetailView(
                        recipe: recipe,
                        entry: entry,
                        onBack: { path = [] },
                        onRemove: {
                            onRemove()
                            dismiss()
                        },
                        onSave: onSave,
                        dismissSheet: dismiss
                    )
                }
        }
        .onAppear {
            if path.isEmpty, let recipe = entry?.recipe {
                withAnimation(.none) { path = [recipe] }
            }
        }
        .onChange(of: entry == nil) { _, isNil in
            if isNil { dismiss() }
        }
    }

    private var pickerList: some View {
        List {
            Section(header: Text("Choose a Recipe")) {
                if filtered.isEmpty {
                    Text("No recipes found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filtered) { recipe in
                        Button {
                            onAssign(recipe)
                            searchText = ""
                            path = [recipe]
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.name)
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                Text(String(format: "$%.2f total · %d servings",
                                            recipe.totalCost, recipe.servingsPerBatch))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search recipes")
    }
}

// MARK: - Plan day detail view (on-hand ingredient checklist)

private struct PlanDayDetailView: View {
    let recipe: Recipe
    let entry: MealPlanEntry?
    let onBack: () -> Void
    let onRemove: () -> Void
    let onSave: () -> Void
    let dismissSheet: DismissAction

    var body: some View {
        List {
            Section {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                    Spacer()
                    Button("Change") { onBack() }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove from plan", systemImage: "trash")
                }
            }

            if !recipe.ingredients.isEmpty {
                Section(header: Text("What I Already Have")) {
                    ForEach(recipe.ingredients) { ingredient in
                        ingredientRow(ingredient)
                    }
                }
            }
        }
        .navigationTitle("Plan Day")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSave()
                    dismissSheet()
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        let isOnHand = entry?.onHandIngredientIds.contains(ingredient.id.uuidString) ?? false
        return Button {
            toggleOnHand(ingredient)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOnHand ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOnHand ? .accentColor : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.name)
                        .foregroundColor(.primary)
                        .font(.subheadline)
                    Text(String(format: "%g %@ · $%.2f",
                                ingredient.recipeQuantity,
                                ingredient.recipeUnit,
                                ingredient.costContribution))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isOnHand {
                    Text("on hand")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleOnHand(_ ingredient: Ingredient) {
        guard let entry else { return }
        let idStr = ingredient.id.uuidString
        if let idx = entry.onHandIngredientIds.firstIndex(of: idStr) {
            entry.onHandIngredientIds.remove(at: idx)
        } else {
            entry.onHandIngredientIds.append(idStr)
        }
    }
}

// MARK: - Calendar picker sheet

struct CalendarPickerSheet: View {
    let preferredCalendarId: String
    let onSelect: (EKCalendar) -> Void

    @StateObject private var service = MealPlanCalendarService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var calendars: [EKCalendar] = []
    @State private var isLoaded = false

    var body: some View {
        NavigationView {
            Group {
                if !isLoaded {
                    ProgressView("Loading calendars…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if calendars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No writable calendars found")
                            .foregroundColor(.secondary)
                        Text("Make sure calendar access is allowed in Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sources, id: \.self) { source in
                            Section(header: Text(source)) {
                                ForEach(calendarsFor(source: source), id: \.calendarIdentifier) { cal in
                                    calendarRow(cal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if !service.isAuthorized {
                    _ = await service.requestAccess()
                }
                calendars = service.availableCalendars()
                isLoaded = true
            }
        }
    }

    private func calendarRow(_ cal: EKCalendar) -> some View {
        Button {
            onSelect(cal)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(cgColor: cal.cgColor))
                    .frame(width: 12, height: 12)
                Text(cal.title)
                    .foregroundColor(.primary)
                Spacer()
                if cal.calendarIdentifier == preferredCalendarId {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.subheadline)
                }
            }
        }
    }

    private var sources: [String] {
        Array(Set(calendars.map { $0.source.title })).sorted()
    }

    private func calendarsFor(source: String) -> [EKCalendar] {
        calendars.filter { $0.source.title == source }
    }
}
