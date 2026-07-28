import Testing
@testable import AndroidFileTransfer

@Suite
struct ShellQuotingTests {
    @Test
    func wrapsPlainStringInSingleQuotes() {
        #expect(ShellQuoting.quote("notes.txt") == "'notes.txt'")
    }

    @Test
    func preservesSpaces() {
        #expect(ShellQuoting.quote("My Vacation Photo.jpg") == "'My Vacation Photo.jpg'")
    }

    @Test
    func escapesEmbeddedSingleQuotes() {
        #expect(ShellQuoting.quote("O'Brien's file.txt") == #"'O'\''Brien'\''s file.txt'"#)
    }

    @Test
    func neutralizesShellMetacharacters() {
        // The whole point: these must round-trip as literal filename
        // content, never be interpreted by the remote shell.
        let dangerous = "a; rm -rf /; echo $(whoami) `id` & | > out.txt"
        let quoted = ShellQuoting.quote(dangerous)

        #expect(quoted.hasPrefix("'"))
        #expect(quoted.hasSuffix("'"))
        // Every character of the original must still appear inside the
        // quoting (possibly split around escaped single quotes); since this
        // string has none, it must appear completely untouched inside.
        #expect(quoted == "'\(dangerous)'")
    }

    @Test
    func emptyStringProducesEmptyQuotedPair() {
        #expect(ShellQuoting.quote("") == "''")
    }
}
