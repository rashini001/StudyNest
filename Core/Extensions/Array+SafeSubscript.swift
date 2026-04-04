extension Array {
    // Safe subscript — returns nil instead of crashing on out-of-bounds
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
