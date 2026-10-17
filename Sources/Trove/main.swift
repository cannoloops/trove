import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
        app.setActivationPolicy(.prohibited)
        Snapshot.run(URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        exit(0)
    }
    if let i = CommandLine.arguments.firstIndex(of: "--record"), CommandLine.arguments.count > i + 1 {
        app.setActivationPolicy(.prohibited)
        Snapshot.record(URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        exit(0)
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
