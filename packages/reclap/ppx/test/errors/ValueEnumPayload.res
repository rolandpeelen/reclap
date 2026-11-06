// expect: @clap.valueEnum constructors cannot have payloads, but `Custom` has one.
// line: 4
@clap.valueEnum
type level = Low | Custom(int)
