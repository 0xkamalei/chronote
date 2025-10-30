import Foundation

/// Parser for advanced search queries with operators and filters
class SearchQueryParser {
    
    // MARK: - Private Properties
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // MARK: - Public Methods
    
    /// Parses a search query string into structured components
    func parse(_ query: String) -> ParsedQuery {
        var parsedQuery = ParsedQuery()
        
        let tokens = tokenize(query)
        var i = 0
        
        while i < tokens.count {
            let token = tokens[i]
            
            if token.hasPrefix("-") {
                // Exclude term
                let term = String(token.dropFirst())
                if !term.isEmpty {
                    parsedQuery.excludeTerms.append(term)
                }
            } else if token.contains(":") {
                // Filter expression
                let components = token.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    let filterType = String(components[0]).lowercased()
                    let filterValue = String(components[1])
                    
                    switch filterType {
                    case "app", "application":
                        parsedQuery.appFilters.append(filterValue)
                    case "project", "proj":
                        parsedQuery.projectFilters.append(filterValue)
                    case "after", "since":
                        if let date = parseDate(filterValue) {
                            parsedQuery.dateFilters.append(ParsedQuery.DateFilter(type: .after, date: date))
                        }
                    case "before", "until":
                        if let date = parseDate(filterValue) {
                            parsedQuery.dateFilters.append(ParsedQuery.DateFilter(type: .before, date: date))
                        }
                    case "on", "date":
                        if let date = parseDate(filterValue) {
                            parsedQuery.dateFilters.append(ParsedQuery.DateFilter(type: .on, date: date))
                        }
                    case "duration", "dur":
                        if let duration = parseDuration(filterValue) {
                            parsedQuery.durationFilters.append(ParsedQuery.DurationFilter(type: .equalTo, duration: duration))
                        }
                    case "minduration", "mindur":
                        if let duration = parseDuration(filterValue) {
                            parsedQuery.durationFilters.append(ParsedQuery.DurationFilter(type: .greaterThan, duration: duration))
                        }
                    case "maxduration", "maxdur":
                        if let duration = parseDuration(filterValue) {
                            parsedQuery.durationFilters.append(ParsedQuery.DurationFilter(type: .lessThan, duration: duration))
                        }
                    default:
                        // Unknown filter, treat as regular text
                        parsedQuery.textTerms.append(token)
                    }
                }
            } else if token.hasPrefix("\"") && token.hasSuffix("\"") {
                // Quoted phrase
                let phrase = String(token.dropFirst().dropLast())
                if !phrase.isEmpty {
                    parsedQuery.textTerms.append(phrase)
                }
            } else if token.hasPrefix("\"") {
                // Start of quoted phrase - collect until closing quote
                var phrase = String(token.dropFirst())
                i += 1
                
                while i < tokens.count {
                    let nextToken = tokens[i]
                    if nextToken.hasSuffix("\"") {
                        phrase += " " + String(nextToken.dropLast())
                        break
                    } else {
                        phrase += " " + nextToken
                    }
                    i += 1
                }
                
                if !phrase.isEmpty {
                    parsedQuery.textTerms.append(phrase)
                }
            } else {
                // Regular text term
                parsedQuery.textTerms.append(token)
            }
            
            i += 1
        }
        
        return parsedQuery
    }
    
    /// Validates a search query for syntax errors
    func validate(_ query: String) -> QueryValidationResult {
        let tokens = tokenize(query)
        
        var openQuotes = 0
        var hasValidContent = false
        
        for token in tokens {
            // Check for unmatched quotes
            let quoteCount = token.filter { $0 == "\"" }.count
            openQuotes += quoteCount
            
            // Check for valid content
            if !token.isEmpty && token != "\"" {
                hasValidContent = true
            }
            
            // Validate filter syntax
            if token.contains(":") {
                let components = token.split(separator: ":", maxSplits: 1)
                if components.count != 2 || components[1].isEmpty {
                    return .invalid("Invalid filter syntax: \(token)")
                }
                
                let filterType = String(components[0]).lowercased()
                let filterValue = String(components[1])
                
                // Validate specific filter types
                switch filterType {
                case "after", "before", "on", "since", "until", "date":
                    if parseDate(filterValue) == nil {
                        return .invalid("Invalid date format in filter: \(token)")
                    }
                case "duration", "dur", "minduration", "mindur", "maxduration", "maxdur":
                    if parseDuration(filterValue) == nil {
                        return .invalid("Invalid duration format in filter: \(token)")
                    }
                case "app", "application", "project", "proj":
                    // These are always valid as long as they have a value
                    break
                default:
                    // Unknown filter type - this is okay, we'll treat it as text
                    break
                }
            }
        }
        
        // Check for unmatched quotes
        if openQuotes % 2 != 0 {
            return .invalid("Unmatched quotation marks")
        }
        
        // Check for empty query
        if !hasValidContent {
            return .invalid("Query cannot be empty")
        }
        
        return .valid
    }
    
    // MARK: - Private Helper Methods
    
    private func tokenize(_ query: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inQuotes = false
        
        for char in query {
            if char == "\"" {
                if inQuotes {
                    currentToken += String(char)
                    tokens.append(currentToken)
                    currentToken = ""
                    inQuotes = false
                } else {
                    if !currentToken.isEmpty {
                        tokens.append(currentToken)
                        currentToken = ""
                    }
                    currentToken += String(char)
                    inQuotes = true
                }
            } else if char.isWhitespace && !inQuotes {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken += String(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        return tokens
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try various date formats
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "yyyy/MM/dd",
            "MM-dd-yyyy",
            "dd-MM-yyyy"
        ]
        
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try relative dates
        let lowercaseString = dateString.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        switch lowercaseString {
        case "today":
            return calendar.startOfDay(for: now)
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        case "thisweek":
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case "lastweek":
            let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .weekOfYear, for: lastWeek)?.start
        case "thismonth":
            return calendar.dateInterval(of: .month, for: now)?.start
        case "lastmonth":
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: lastMonth)?.start
        default:
            break
        }
        
        // Try parsing relative days (e.g., "3d", "1w", "2m")
        if let relativeDays = parseRelativeDays(dateString) {
            return calendar.date(byAdding: .day, value: -relativeDays, to: calendar.startOfDay(for: now))
        }
        
        return nil
    }
    
    private func parseRelativeDays(_ string: String) -> Int? {
        let pattern = #"^(\d+)([dwmy])$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: string.count)
        
        guard let match = regex?.firstMatch(in: string, options: [], range: range),
              match.numberOfRanges == 3 else {
            return nil
        }
        
        let numberRange = Range(match.range(at: 1), in: string)!
        let unitRange = Range(match.range(at: 2), in: string)!
        
        guard let number = Int(String(string[numberRange])) else {
            return nil
        }
        
        let unit = String(string[unitRange]).lowercased()
        
        switch unit {
        case "d":
            return number
        case "w":
            return number * 7
        case "m":
            return number * 30 // Approximate
        case "y":
            return number * 365 // Approximate
        default:
            return nil
        }
    }
    
    private func parseDuration(_ durationString: String) -> TimeInterval? {
        let lowercaseString = durationString.lowercased()
        
        // Try parsing formats like "1h30m", "90m", "1.5h", "30s"
        let patterns: [(String, (String) -> TimeInterval?)] = [
            (#"^(\d+)h(\d+)m$"#, parseCompoundDuration),
            (#"^(\d+)h$"#, parseIntDuration),
            (#"^(\d+)m$"#, parseIntDuration),
            (#"^(\d+)s$"#, parseIntDuration),
            (#"^(\d+\.?\d*)h$"#, parseDoubleDuration),
            (#"^(\d+\.?\d*)m$"#, parseDoubleDuration)
        ]
        
        for (pattern, converter) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: lowercaseString.count)
            
            if let match = regex?.firstMatch(in: lowercaseString, options: [], range: range) {
                if match.numberOfRanges == 2 {
                    // Single value pattern
                    let valueRange = Range(match.range(at: 1), in: lowercaseString)!
                    let valueString = String(lowercaseString[valueRange])
                    
                    if let intValue = Int(valueString) {
                        return (converter as? (Int) -> TimeInterval)?(intValue)
                    } else if let doubleValue = Double(valueString) {
                        return (converter as? (Double) -> TimeInterval)?(doubleValue)
                    }
                } else if match.numberOfRanges == 3 {
                    // Two value pattern (hours and minutes)
                    let value1Range = Range(match.range(at: 1), in: lowercaseString)!
                    let value2Range = Range(match.range(at: 2), in: lowercaseString)!
                    
                    if let value1 = Int(String(lowercaseString[value1Range])),
                       let value2 = Int(String(lowercaseString[value2Range])) {
                        return (converter as? (Int, Int) -> TimeInterval)?(value1, value2)
                    }
                }
            }
        }
        
        // Try parsing as plain number (assume minutes)
        if let minutes = Int(lowercaseString) {
            return TimeInterval(minutes * 60)
        }
        
        if let minutes = Double(lowercaseString) {
            return TimeInterval(minutes * 60)
        }
        
        return nil
    }
}

// MARK: - Helper Extensions

extension Character {
    var isWhitespace: Bool {
        return self == " " || self == "\t" || self == "\n" || self == "\r"
    }
}

// MARK: - Duration Parsing Helpers

private func parseCompoundDuration(_ input: String) -> TimeInterval? {
    let components = input.split(separator: Character("m")).joined().split(separator: Character("h"))
    if components.count == 2,
       let h = Int(components[0]),
       let m = Int(components[1]) {
        return TimeInterval(h * 3600 + m * 60)
    }
    return nil
}

private func parseIntDuration(_ input: String) -> TimeInterval? {
    // Extract numeric part before the unit character
    let numericPart = input.dropLast() // Remove the unit character (h, m, s)
    if let value = Int(String(numericPart)) {
        let unit = input.last
        switch unit {
        case "h": return TimeInterval(value * 3600)
        case "m": return TimeInterval(value * 60)
        case "s": return TimeInterval(value)
        default: return nil
        }
    }
    return nil
}

private func parseDoubleDuration(_ input: String) -> TimeInterval? {
    // Extract numeric part before the unit character
    let numericPart = input.dropLast() // Remove the unit character (h, m)
    if let value = Double(String(numericPart)) {
        let unit = input.last
        switch unit {
        case "h": return TimeInterval(value * 3600)
        case "m": return TimeInterval(value * 60)
        default: return nil
        }
    }
    return nil
}