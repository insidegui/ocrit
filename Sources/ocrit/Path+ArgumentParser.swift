import ArgumentParser
import PathKit

extension Path: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self = Path(argument).absolute()
    }
}
