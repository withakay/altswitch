import Testing
@testable import MacWindowDiscoveryCLI

@Suite("ListCommand option parsing")
struct ListCommandTests {

    @Test("Comma-separated values are split and trimmed")
    func testCommaSeparatedValues() {
        let values = ["Slack, Discord ,Notion"]
        let result = ListCommand.normalizeAppList(values)

        #expect(result == ["Slack", "Discord", "Notion"])
    }

    @Test("Mix of repeated and comma-separated values is flattened")
    func testMixedValueSources() {
        let values = ["Slack,Discord", "Notion", " Obsidian "]
        let result = ListCommand.normalizeAppList(values)

        #expect(result == ["Slack", "Discord", "Notion", "Obsidian"])
    }

    @Test("Empty entries are removed")
    func testEmptyEntriesRemoved() {
        let values = [", ,", "Slack", " ,Discord,, "]
        let result = ListCommand.normalizeAppList(values)

        #expect(result == ["Slack", "Discord"])
    }
}
