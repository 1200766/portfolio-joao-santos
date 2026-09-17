import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \Movement.date) private var movements: [Movement]
    @Query(sort: \RecurringRule.nextDueDate) private var recurringRules: [RecurringRule]
    @State private var displayedMonth = Date.now
    private let calendar = Calendar.current

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "pt_PT")))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(
            start: displayedMonth,
            duration: 0
        )
    }

    private var projectedOccurrences: [ProjectedOccurrence] {
        RecurrenceService.projectedOccurrences(
            for: recurringRules,
            in: monthInterval,
            excluding: movements,
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    monthHeader
                    calendarGrid
                    monthSummary
                }
                .padding()
            }
            .navigationTitle("Calendário")
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(monthTitle.capitalized)
                .font(.headline)
            Spacer()
            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                if let date {
                    NavigationLink(value: date) {
                        dayCell(date)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 52)
                }
            }
        }
        .navigationDestination(for: Date.self) { date in
            DayDetailView(date: date)
        }
    }

    private var monthSummary: some View {
        let values = movements.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
        let confirmedIncome = values.filter { $0.type == .income }.reduce(0) { $0 + $1.amountInCents }
        let confirmedExpenses = values.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountInCents }
        let projectedIncome = projectedOccurrences
            .filter { $0.rule.type == .income }
            .reduce(0) { $0 + $1.rule.amountInCents }
        let projectedExpenses = projectedOccurrences
            .filter { $0.rule.type == .expense }
            .reduce(0) { $0 + $1.rule.amountInCents }
        let income = confirmedIncome + projectedIncome
        let expenses = confirmedExpenses + projectedExpenses

        return VStack(spacing: 10) {
            summaryRow(title: "Ganhos", cents: income, color: .green)
            summaryRow(title: "Despesas", cents: expenses, color: .red)
            Divider()
            summaryRow(title: "Saldo do mês", cents: income - expenses, color: .primary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryRow(title: String, cents: Int, color: Color) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(Money.formatted(cents: cents))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dayMovements = movements.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let dayProjections = projectedOccurrences.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let confirmedBalance = dayMovements.reduce(0) { partial, movement in
            partial + (movement.type == .income ? movement.amountInCents : -movement.amountInCents)
        }
        let projectedBalance = dayProjections.reduce(0) { partial, occurrence in
            partial + (occurrence.rule.type == .income ? occurrence.rule.amountInCents : -occurrence.rule.amountInCents)
        }
        let balance = confirmedBalance + projectedBalance
        let movementCount = dayMovements.count + dayProjections.count
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 3) {
            Text(date, format: .dateTime.day())
                .font(.subheadline.weight(isToday ? .bold : .regular))
            if movementCount == 0 {
                Color.clear.frame(height: 8)
            } else {
                Circle()
                    .fill(balance >= 0 ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(isToday ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(movementCount == 0 ? "Sem movimentos" : "\(movementCount) movimentos")
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let days = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leading: [Date?] = Array(repeating: nil, count: leadingCount)
        let dates: [Date?] = days.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        return leading + dates
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}
