import Foundation

/// Every failure a user can see. Each case has a clear title and message.
enum ToolError: Error, Equatable {
    case noInput
    case passwordRequired(fileID: UUID, fileName: String)
    case wrongPassword(fileID: UUID, fileName: String)
    /// The PDF opens, but its owner blocked changes; the owner (permissions) password is needed.
    case ownerPasswordRequired(fileID: UUID, fileName: String, afterAttempt: Bool)
    case corruptedFile(fileName: String)
    case unsupportedFormat(fileName: String)
    case notEnoughStorage
    case photosAccessDenied
    case nothingToDo(reason: String)
    case writeFailed
    case resultUnavailable
    case unknown(message: String)

    /// Converts any thrown error into a ToolError the UI can show.
    init(_ error: Error) {
        if let toolError = error as? ToolError {
            self = toolError
            return
        }
        let nsError = error as NSError
        let outOfSpace = (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError)
            || (nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC))
        if outOfSpace {
            self = .notEnoughStorage
        } else {
            self = .unknown(message: nsError.localizedDescription)
        }
    }

    var isPasswordProblem: Bool {
        switch self {
        case .passwordRequired, .wrongPassword, .ownerPasswordRequired: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .noInput: return String(localized: "No file selected")
        case .passwordRequired: return String(localized: "Password needed")
        case .wrongPassword: return String(localized: "Wrong password")
        case .ownerPasswordRequired: return String(localized: "Owner password needed")
        case .corruptedFile: return String(localized: "Can't open this file")
        case .unsupportedFormat: return String(localized: "Unsupported file")
        case .notEnoughStorage: return String(localized: "Not enough storage")
        case .photosAccessDenied: return String(localized: "No access to Photos")
        case .nothingToDo: return String(localized: "Nothing to do")
        case .writeFailed: return String(localized: "Couldn't save the result")
        case .resultUnavailable: return String(localized: "Result no longer available")
        case .unknown: return String(localized: "Something went wrong")
        }
    }

    var message: String {
        switch self {
        case .noInput:
            return String(localized: "Add a file to get started.")
        case .passwordRequired(_, let name):
            return String(localized: "“\(name)” is protected. Enter its password to continue.")
        case .wrongPassword(_, let name):
            return String(localized: "That password didn't open “\(name)”. Check it and try again.")
        case .ownerPasswordRequired(_, let name, let afterAttempt):
            if afterAttempt {
                return String(localized: "That isn't the owner password of “\(name)”. The owner password (also called permissions password) is needed, not only the one that opens it.")
            }
            return String(localized: "“\(name)” opens, but its owner blocked changes. Enter the owner password (also called permissions password) to continue.")
        case .corruptedFile(let name):
            return String(localized: "“\(name)” is damaged or isn't a valid file.")
        case .unsupportedFormat(let name):
            return String(localized: "“\(name)” isn't a file type this tool can use.")
        case .notEnoughStorage:
            return String(localized: "Free up some space on your iPhone, then try again.")
        case .photosAccessDenied:
            return String(localized: "Allow Mihwal to add photos in Settings › Privacy › Photos.")
        case .nothingToDo(let reason):
            return reason
        case .writeFailed:
            return String(localized: "Something went wrong while writing the file. Please try again.")
        case .resultUnavailable:
            return String(localized: "The result file was removed. Run the tool again to recreate it.")
        case .unknown(let message):
            return message
        }
    }
}
