import Foundation

struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var ok: Bool { status == 0 }
    var combined: String {
        let parts = [stdout, stderr].filter { !$0.isEmpty }
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Shell {
    /// Runs an executable and drains both pipes concurrently so large outputs
    /// cannot deadlock the process.
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String] = [],
        timeout: TimeInterval = 180
    ) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let lock = NSLock()
        var outData = Data()
        var errData = Data()

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock()
            outData.append(chunk)
            lock.unlock()
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            lock.lock()
            errData.append(chunk)
            lock.unlock()
        }

        do {
            try process.run()
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            return ShellResult(status: -1, stdout: "", stderr: error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning {
            process.terminate()
            usleep(150_000)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        process.waitUntilExit()

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil

        lock.lock()
        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        lock.unlock()

        return ShellResult(status: process.terminationStatus, stdout: out, stderr: err)
    }

    /// Runs a command through `/bin/sh -lc`.
    @discardableResult
    static func sh(_ command: String, timeout: TimeInterval = 180) -> ShellResult {
        run("/bin/sh", ["-lc", command], timeout: timeout)
    }
}

enum Admin {
    /// Runs a command with administrator privileges through AppleScript, which
    /// shows the native macOS password prompt.
    @discardableResult
    static func run(_ command: String, timeout: TimeInterval = 600) -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let result = Shell.run("/usr/bin/osascript", ["-e", script], timeout: timeout)
        // osascript reports a user cancellation as error -128.
        return result
    }
}

enum Paths {
    /// Single-quote a path for safe use inside a POSIX shell command.
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    static func expand(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}
