import ArgumentParser
import Foundation
import PathKit

enum Output {
    case stdOutput
    case path(Path)
}

extension Output: ExpressibleByArgument {
    init?(argument: String) {
        if argument == "-" {
            self = .stdOutput
        }

        let path = Path(argument).absolute()
        self = .path(path)
    }
}

extension Output {
    var isStdOutput: Bool {
        switch self {
        case .stdOutput: true
        default: false
        }
    }

    var path: Path? {
        switch self {
        case let .path(path): path
        default: nil
        }
    }
}
