import Foundation
import os.log

enum Logger {
    private static let logger = os.Logger()
    
    static func log(_ level: OSLogType, _ message: @autoclosure @escaping () -> String, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) {
        let filename = (file.description as NSString).lastPathComponent
        logger.log(level: level, "\(filename):\(line), \(function) -> \(message())")
    }
    
    static func assertFail(_ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        assertionFailure(message(), file: file, line: line)
    }
    
    static func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
        if !condition() {
            assertionFailure(message(), file: file, line: line)
        }
    }
}
