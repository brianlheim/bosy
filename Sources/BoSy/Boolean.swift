import Foundation

public typealias BooleanAssignment = [Proposition: Literal]

public protocol Boolean: CustomStringConvertible {
    func accept<T where T: BooleanVisitor>(visitor: T) -> T.T
    
    func eval(assignment: BooleanAssignment) -> Boolean
}

/*func ==(lhs: Boolean, rhs: Boolean) -> Bool {
    return false
}*/

public func & (lhs: Boolean, rhs: Boolean) -> Boolean {
    switch (lhs, rhs) {
    case (let element as Literal, _):
        if element == Literal.True {
            return rhs
        } else if element == Literal.False {
            return Literal.False
        }
    case (_, let element as Literal):
        if element == Literal.True {
            return lhs
        } else if element == Literal.False {
            return Literal.False
        }
    case (let element as BinaryOperator, _):
        if element.type == .And {
            return BinaryOperator(.And, operands: element.operands + [rhs])
        }
    default:
        break
    }
    return BinaryOperator(.And, operands: [lhs, rhs])
}

public func | (lhs: Boolean, rhs: Boolean) -> Boolean {
    switch (lhs, rhs) {
    case (let element as Literal, _):
        if element == Literal.True {
            return Literal.True
        } else {
            assert(element == Literal.False)
            return rhs
        }
    case (_, let element as Literal):
        if element == Literal.True {
            return Literal.True
        } else {
            assert(element == Literal.False)
            return lhs
        }
    case (let element as BinaryOperator, _):
        if element.type == .Or {
            return BinaryOperator(.Or, operands: element.operands + [rhs])
        }
    default:
        break
    }
    return BinaryOperator(.Or, operands: [lhs, rhs])
}

infix operator --> {}

public func --> (lhs: Boolean, rhs: Boolean) -> Boolean {
    switch (lhs, rhs) {
    case (let element as Literal, _):
        if element == Literal.False {
            return Literal.True
        } else {
            assert(element == Literal.True)
            return rhs
        }
    case (_, let element as Literal):
        if element == Literal.True {
            return Literal.True
        } else {
            assert(element == Literal.False)
            return !lhs
        }
    default:
        break
    }
    return BinaryOperator(.Implication, operands: [lhs, rhs])
}

infix operator <-> {}

public func <-> (lhs: Boolean, rhs: Boolean) -> Boolean {
    switch (lhs, rhs) {
    case (let lhsLiteral as Literal, let rhsLiteral as Literal):
        return lhsLiteral == rhsLiteral ? Literal.True : Literal.False
    case (let element as Literal, _):
        if element == Literal.True {
            return rhs
        } else if element == Literal.False {
            return !rhs
        }
    case (_, let element as Literal):
        if element == Literal.True {
            return lhs
        } else if element == Literal.False {
            return !lhs
        }
    default:
        break
    }
    return BinaryOperator(.Xnor, operands: [lhs, rhs])
}

public prefix func ! (op: Boolean) -> Boolean {
    switch op {
    case let element as UnaryOperator:
        if element.type == .Negation {
            return element.operand
        }
    case let element as Literal:
        return element == Literal.True ? Literal.False: Literal.True
    default:
        break
    }
    return UnaryOperator(.Negation, operand: op)
}

public struct UnaryOperator: Boolean {
    public enum OperatorType: CustomStringConvertible {
        case Negation
        
        public var description: String {
            switch self {
            case .Negation:
                return "¬"
            }
        }
    }
    
    let type: OperatorType
    var operand: Boolean
    
    public init(_ type: OperatorType, operand: Boolean) {
        self.type = type
        self.operand = operand
    }
    
    public func accept<T where T: BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(unaryOperator: self)
    }
    
    public var description: String {
        return "\(type)\(operand)"
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        return !operand.eval(assignment: assignment)
    }
}

public struct BinaryOperator: Boolean {
    public enum OperatorType: CustomStringConvertible {
        case And
        case Or
        case Implication
        case Xnor
        
        public var description: String {
            switch self {
            case .And:
                return "∧"
            case .Or:
                return "∨"
            case .Implication:
                return "→"
            case .Xnor:
                return "↔︎"
            }
        }
    }
    
    let type: OperatorType
    var operands: [Boolean]
    
    public init(_ type: OperatorType, operands: [Boolean]) {
        self.type = type
        self.operands = operands
    }
    
    public func accept<T where T: BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(binaryOperator: self)
    }
    
    public var description: String {
        let expression = operands.map({ op in "\(op)" }).joined(separator: " \(type) ")
        return "(\(expression))"
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        let evaluatedOperands = operands.map({ $0.eval(assignment: assignment) })
        switch type {
        case .And:
            return evaluatedOperands.reduce(Literal.True, combine: &)
        case .Or:
            return evaluatedOperands.reduce(Literal.False, combine: |)
        case .Implication:
            assert(evaluatedOperands.count == 2)
            return evaluatedOperands[0] --> evaluatedOperands[1]
        case .Xnor:
            assert(evaluatedOperands.count == 2)
            return evaluatedOperands[0] <-> evaluatedOperands[1]
        }
    }
}

public struct Quantifier: Boolean {
    public enum QuantifierType: CustomStringConvertible {
        case Exists
        case Forall
        
        public var description: String {
            switch self {
            case .Exists:
                return "∃"
            case .Forall:
                return "∀"
            }
        }
    }
    
    let type: QuantifierType
    var variables: [Proposition]
    var scope: Boolean
    
    public init(_ type: QuantifierType, variables: [Proposition], scope: Boolean) {
        self.type = type
        self.variables = variables
        self.scope = scope
    }
    
    public func accept<T where T : BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(quantifier: self)
    }
    
    public var description: String {
        let variables = self.variables.map({ variable in "\(variable)" }).joined(separator: ", ")
        return "\(type) \(variables): \(scope)"
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        var copy = self
        copy.scope = scope.eval(assignment: assignment)
        copy.variables = variables.filter({ assignment[$0] == nil })
        if copy.variables.count == 0 {
            return copy.scope
        }
        return copy
    }
}

public struct Literal: Boolean, Equatable {
    public enum LiteralType: CustomStringConvertible {
        case True
        case False
        
        public var description: String {
            switch self {
            case .True:
                return "⊤"
            case .False:
                return "⊥"
            }
        }
    }
    
    let type: LiteralType
    
    public static let True = Literal(.True)
    public static let False = Literal(.False)
    
    internal init(_ type: LiteralType) {
        self.type = type
    }
    
    public func accept<T where T : BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(literal: self)
    }
    
    public var description: String {
        return "\(type)"
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        return self
    }
}

public func ==(lhs: Literal, rhs: Literal) -> Bool {
    return lhs.type == rhs.type
}

public struct Proposition: Boolean, Equatable, Hashable {
    var name: String
    
    public init(_ name: String) {
        precondition(!name.isEmpty)
        self.name = name
    }
    
    public func accept<T where T: BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(proposition: self)
    }
    
    public var description: String {
        return "\(name)"
    }
    
    public var hashValue: Int {
        return name.hashValue
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        guard let value = assignment[self] else {
            return self
        }
        return value
    }
}

public func ==(lhs: Proposition, rhs: Proposition) -> Bool {
    return lhs.name == rhs.name
}

public struct BooleanComparator: Boolean {
    public enum ComparatorType: CustomStringConvertible {
        case LessOrEqual
        case Less
        
        public var description: String {
            switch self {
            case .LessOrEqual:
                return "≤"
            case .Less:
                return "<"
            }
        }
    }
    
    let type: ComparatorType
    var lhs: Proposition
    var rhs: Proposition
    
    public init(_ type: ComparatorType, lhs: Proposition, rhs: Proposition) {
        self.type = type
        self.lhs = lhs
        self.rhs = rhs
    }
    
    public func accept<T where T: BooleanVisitor>(visitor: T) -> T.T {
        return visitor.visit(comparator: self)
    }
    
    public var description: String {
        return "\(lhs) \(type) \(rhs)"
    }
    
    public func eval(assignment: BooleanAssignment) -> Boolean {
        assert(assignment[lhs] == nil)
        assert(assignment[rhs] == nil)
        return self
    }
}

public protocol BooleanVisitor {
    associatedtype T
    func visit(literal: Literal) -> T
    func visit(proposition: Proposition) -> T
    func visit(unaryOperator: UnaryOperator) -> T
    func visit(binaryOperator: BinaryOperator) -> T
    func visit(quantifier: Quantifier) -> T
    func visit(comparator: BooleanComparator) -> T
}

struct RenamingBooleanVisitor: BooleanVisitor {
    typealias T = Boolean
    
    var rename: (String) -> String
    
    func visit(literal: Literal) -> T {
        return literal
    }
    func visit(proposition: Proposition) -> T {
        var copy = proposition
        copy.name = rename(proposition.name)
        return copy
    }
    func visit(unaryOperator: UnaryOperator) -> T {
        var copy = unaryOperator
        copy.operand = unaryOperator.operand.accept(visitor: self)
        return copy
    }
    func visit(binaryOperator: BinaryOperator) -> T {
        var copy = binaryOperator
        copy.operands = binaryOperator.operands.map({ $0.accept(visitor: self) })
        return copy
    }
    func visit(quantifier: Quantifier) -> T {
        var copy = quantifier
        copy.scope = quantifier.scope.accept(visitor: self)
        return copy
    }
    func visit(comparator: BooleanComparator) -> T {
        var copy = comparator
        copy.lhs = comparator.lhs.accept(visitor: self) as! Proposition
        copy.rhs = comparator.rhs.accept(visitor: self) as! Proposition
        return copy
    }
}

class BoundednessVisitor: BooleanVisitor {
    typealias T = Void
    
    var bounded: Set<Proposition> = Set()
    
    func visit(literal: Literal) {}
    func visit(proposition: Proposition) {
        assert(bounded.contains(proposition), "\(proposition) is not bound\n(\(bounded))")
    }
    func visit(unaryOperator: UnaryOperator) {
        unaryOperator.operand.accept(visitor: self)
    }
    func visit(binaryOperator: BinaryOperator) {
        binaryOperator.operands.forEach({ $0.accept(visitor: self) })
    }
    func visit(quantifier: Quantifier) {
        bounded = bounded.union(quantifier.variables)
        quantifier.scope.accept(visitor: self)
        bounded = bounded.subtracting(quantifier.variables)
    }
    func visit(comparator: BooleanComparator) {}
}

func order(binaryLhs: [Proposition], binaryRhs: [Proposition], strict: Bool) -> Boolean {
    precondition(binaryLhs.count == binaryRhs.count)
    precondition(binaryLhs.count >= 1)
    var binaryLhs = binaryLhs
    var binaryRhs = binaryRhs
    
    
    let lhs = binaryLhs.removeFirst()
    let rhs = binaryRhs.removeFirst()
    
    let greater = lhs & !rhs
    let equiv = BinaryOperator(.Xnor, operands: [lhs, rhs])
    if binaryLhs.count > 0 {
        let recursive = equiv & order(binaryLhs: binaryLhs, binaryRhs: binaryRhs, strict: strict)
        return greater | recursive
    } else if strict {
        return greater
    } else {
        return equiv
    }
}

func allBooleanAssignments(variables: [Proposition]) -> [BooleanAssignment] {
    var zeroAssignment: BooleanAssignment = [:]
    variables.forEach({ v in zeroAssignment[v] = Literal.False })
    var assignments: [BooleanAssignment] = [zeroAssignment]
    for v in variables {
        assignments = assignments.reduce([], combine: {
            newAssignments, element in
            var copy = element
            copy[v] = Literal.True
            return newAssignments + [ element, copy ]
        })
    }
    return assignments
}

func bitStringFromAssignment(_ assignment: BooleanAssignment) -> String {
    var bitstring = ""
    for key in assignment.keys.sorted(isOrderedBefore: { $0.name < $1.name }) {
        let value = assignment[key]!
        if value == Literal.True {
            bitstring += "1"
        } else {
            bitstring += "0"
        }
    }
    return bitstring
}

/*struct PrettifyBoolean: BooleanVisitor {
    typealias T = String
    
    func visit(literal: Literal) -> String {
        return "\(literal.type)"
    }
    
    func visit(proposition: Proposition) -> String {
        return proposition.name
    }
    
    func visit(unaryOperator: UnaryOperator) -> String {
        return "\(unaryOperator.type)\(unaryOperator.operand.accept(visitor: self))"
    }
    
    func visit(binaryOperator: BinaryOperator) -> String {
        let subExpression = binaryOperator.operands.map({ op in op.accept(visitor: self) }).joined(separator: " \(binaryOperator.type) ")
        return "(\(subExpression))"
    }
    
    func visit(quantifier: Quantifier) -> String {
        let variables = quantifier.variables.map({ variable in variable.accept(visitor: self) }).joined(separator: ", ")
        return "\(quantifier.type) \(variables): \(quantifier.operand.accept(visitor: self))"
    }
}*/

enum BooleanToken {
    typealias Precedence = Int
    
    case Literal(Bool)
    case Proposition(String)
    case Conjunction
    case Disjunction
    case Negation
    case LParen
    case RParen
    case EOF
    
    var isUnaryOperator: Bool {
        switch self {
        case .Negation:
            return true
        default:
            return false
        }
    }
    
    var isBinaryOperator: Bool {
        switch self {
        case .Conjunction:
            return true
        case .Disjunction:
            return true
        default:
            return false
        }
    }
    
    var precedence: Precedence {
        precondition(isBinaryOperator)
        switch self {
        case .Conjunction:
            return 3
        case .Disjunction:
            return 2
        default:
            assert(false)
            return 0
        }
    }
}

enum BooleanError: ErrorProtocol {
    case EndOfInput
    case Unexpected
    case Expect(BooleanToken)
}

struct BooleanLexer {
    let scanner: ScalarScanner
    
    func next() throws -> BooleanToken {
        if scanner.isAtEnd() {
            return .EOF
        }
        switch scanner {
        case "(":
            return .LParen
        case ")":
            return .RParen
        case ["~", "!"]:
            return .Negation
        case ["||", "|", "\\/", "+"]:
            return .Disjunction
        case ["&&", "&", "/\\", "*"]:
            return .Conjunction
        case "0":
            return .Literal(false)
        case "1":
            return .Literal(true)
        case "a"..."z":
            return .Proposition(scanner.getIdentifier())
        default:
            throw BooleanError.Unexpected
        }
    }
}

/**
 * Recursive decent parser
 */
struct BooleanParser {
    let lexer: BooleanLexer
    var current: BooleanToken = .EOF
    init(lexer: BooleanLexer) {
        self.lexer = lexer
    }
    
    mutating func parse() throws -> Boolean {
        current = try lexer.next()
        return try parseExpression(minPrecedence: 0)
    }
    
    mutating func parseExpression(minPrecedence: BooleanToken.Precedence) throws -> Boolean {
        var lhs = try parseUnaryExpression()
        
        while current.isBinaryOperator && current.precedence >= minPrecedence {
            let op = current
            current = try lexer.next()
            let rhs = try parseExpression(minPrecedence: op.precedence + 1)
            switch op {
            case .Disjunction:
                lhs = lhs | rhs
            case .Conjunction:
                lhs = lhs & rhs
            default:
                assert(false)
            }
        }
        
        return lhs
    }
    
    mutating func parseUnaryExpression() throws -> Boolean {
        if current.isUnaryOperator {
            current = try lexer.next()
            return !(try parseUnaryExpression())
        }
        else {
            return try parsePrimaryExpression()
        }
    }
    
    mutating func parsePrimaryExpression() throws -> Boolean {
        switch current {
        case .Literal(let value):
            current = try lexer.next()
            return value ? Literal.True : Literal.False
        case .Proposition(let name):
            current = try lexer.next()
            return Proposition(name)
        case .LParen:
            current = try lexer.next()
            let expr = try parseExpression(minPrecedence: 0)
            switch current {
            case .RParen:
                current = try lexer.next()
                return expr
            default:
                throw BooleanError.Expect(BooleanToken.RParen)
            }
        default:
            throw BooleanError.Unexpected
        }
    }
}

func ~=(pattern: String, prefix: ScalarScanner) -> Bool {
    return prefix.matchAndProceed(pattern: pattern)
}

func ~=(patterns: [String], prefix: ScalarScanner) -> Bool {
    for pattern in patterns {
        if prefix.matchAndProceed(pattern: pattern) {
            return true
        }
    }
    return false
}

func ~=(range: ClosedRange<UnicodeScalar>, prefix: ScalarScanner) -> Bool {
    return prefix.firstScalarContained(inRange: range)
}

class ScalarScanner {
    let scalars: String.UnicodeScalarView
    var index: String.UnicodeScalarView.Index
    
    init(scalars: String.UnicodeScalarView) {
        self.scalars = scalars
        self.index = scalars.startIndex
    }
    
    func advance(by offset: String.UnicodeScalarView.IndexDistance, skipWhitespace: Bool = true) {
        index = scalars.index(index, offsetBy: offset)
        if !skipWhitespace {
            return
        }
        while (index < scalars.endIndex && NSCharacterSet.whitespacesAndNewlines.contains(scalars[index])) {
            index = scalars.index(after: index)
        }
    }
    
    func matchAndProceed(pattern: String) -> Bool {
        if scalars[self.index..<scalars.endIndex].starts(with: pattern.unicodeScalars) {
            advance(by: pattern.unicodeScalars.count)
            return true
        }
        return false
    }
    
    func firstScalarContained(inRange range: ClosedRange<UnicodeScalar>) -> Bool {
        return range.contains(scalars[index])
    }
    
    func isAtEnd() -> Bool {
        return index >= scalars.endIndex
    }
    
    func getIdentifier() -> String {
        var end = index
        while end < scalars.endIndex && (
            ("a"..."z").contains(scalars[end])
            || ("A"..."Z").contains(scalars[end])
            || ("0"..."9").contains(scalars[end])
            || scalars[end] == "_"
            ) {
            end = scalars.index(after: end)
        }
        let literal = scalars[index..<end]
        index = end
        advance(by: 0)
        return String(literal)
    }
}

struct BooleanUtils {
    static func parse(string: String) -> Boolean? {
        let lexer = BooleanLexer(scanner: ScalarScanner(scalars: string.unicodeScalars))
        var parser = BooleanParser(lexer: lexer)
        return try? parser.parse()
    }
}
