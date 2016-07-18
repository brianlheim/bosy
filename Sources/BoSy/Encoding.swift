
enum BoSyEncodingError: ErrorProtocol {
    case EncodingFailed(String)
    case SolvingFailed(String)
}

protocol BoSyEncoding {
    
    mutating func solve(forBound bound: Int) throws -> Bool
    func extractSolution() -> BoSySolution?
    
}
