import Foundation

enum Money {
    static func formatted(cents: Int, type: MovementType? = nil) -> String {
        let amount = Decimal(cents) / 100
        let value = amount.formatted(.currency(code: "EUR").locale(Locale(identifier: "pt_PT")))
        guard let type else { return value }
        return type == .income ? "+\(value)" : "−\(value)"
    }

    static func cents(from input: String) -> Int? {
        parsedCents(from: input, allowsNegative: false)
    }

    static func signedCents(from input: String) -> Int? {
        parsedCents(from: input, allowsNegative: true)
    }

    private static func parsedCents(from input: String, allowsNegative: Bool) -> Int? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_PT")
        guard let number = formatter.number(from: input),
              allowsNegative || number.decimalValue >= 0 else {
            return nil
        }
        return NSDecimalNumber(decimal: number.decimalValue * 100).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        ).intValue
    }

    static func inputValue(cents: Int) -> String {
        let amount = Decimal(cents) / 100
        return amount.formatted(
            .number.precision(.fractionLength(2)).locale(Locale(identifier: "pt_PT"))
        )
    }
}
