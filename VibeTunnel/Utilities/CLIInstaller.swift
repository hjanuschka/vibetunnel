import AppKit
import Foundation
import Observation
import os.log
import SwiftUI

/// Service responsible for creating symlinks to command line tools with sudo authentication.
///
/// ## Overview
/// This service creates symlinks from the application bundle's resources to system locations like /usr/local/bin
/// to enable command line access to bundled tools. It handles sudo authentication through system dialogs.
///
/// ## Usage
/// ```swift
/// let installer = CLIInstaller()
/// installer.installCLITool()
/// ```
///
/// ## Safety Considerations
/// - Always prompts user before performing operations requiring sudo
/// - Provides clear error messages and graceful failure handling
/// - Checks for existing symlinks and handles conflicts appropriately
/// - Logs all operations for debugging purposes
@MainActor
@Observable
final class CLIInstaller {
    // MARK: - Properties

    private let logger = Logger(subsystem: "sh.vibetunnel.vibetunnel", category: "CLIInstaller")

    var isInstalled = false
    var isInstalling = false
    var lastError: String?
    var installedVersion: String?
    var bundledVersion: String?
    var needsUpdate = false

    // MARK: - Public Interface

    /// Checks if the CLI tool is installed
    func checkInstallationStatus() {
        Task { @MainActor in
            let targetPath = "/usr/local/bin/vt"
            let installed = FileManager.default.fileExists(atPath: targetPath)

            // Update state without animation
            isInstalled = installed
            
            // Move version checks to background
            Task.detached(priority: .userInitiated) {
                var installedVer: String? = nil
                var bundledVer: String? = nil
                
                if installed {
                    // Check version of installed tool
                    installedVer = await self.getInstalledVersionAsync()
                }
                
                // Get bundled version
                bundledVer = await self.getBundledVersionAsync()
                
                // Update UI on main thread
                await MainActor.run {
                    self.installedVersion = installedVer
                    self.bundledVersion = bundledVer
                    
                    // Check if update is needed
                    self.needsUpdate = installed && self.installedVersion != self.bundledVersion

                    self.logger.info("CLIInstaller: CLI tool installed: \(self.isInstalled), installed version: \(self.installedVersion ?? "unknown"), bundled version: \(self.bundledVersion ?? "unknown"), needs update: \(self.needsUpdate)")
                }
            }
        }
    }
    
    /// Gets the version of the installed vt tool
    private func getInstalledVersion() -> String? {
        let task = Process()
        task.launchPath = "/usr/local/bin/vt"
        task.arguments = ["--version"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse version from output like "vt version 2.0.0"
            if let output = output, output.contains("version") {
                let components = output.components(separatedBy: " ")
                if let versionIndex = components.firstIndex(of: "version"), versionIndex + 1 < components.count {
                    return components[versionIndex + 1]
                }
            }
            
            return output
        } catch {
            logger.error("Failed to get installed vt version: \(error)")
            return nil
        }
    }
    
    /// Gets the version of the bundled vt tool
    private func getBundledVersion() -> String? {
        guard let vtPath = Bundle.main.path(forResource: "vt", ofType: nil) else {
            return nil
        }
        
        let task = Process()
        task.launchPath = vtPath
        task.arguments = ["--version"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse version from output like "vt version 2.0.0"
            if let output = output, output.contains("version") {
                let components = output.components(separatedBy: " ")
                if let versionIndex = components.firstIndex(of: "version"), versionIndex + 1 < components.count {
                    return components[versionIndex + 1]
                }
            }
            
            return output
        } catch {
            logger.error("Failed to get bundled vt version: \(error)")
            return nil
        }
    }
    
    /// Gets the version of the installed vt tool (async version for background execution)
    private nonisolated func getInstalledVersionAsync() async -> String? {
        let task = Process()
        task.launchPath = "/usr/local/bin/vt"
        task.arguments = ["--version"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse version from output like "vt version 2.0.0"
            if let output = output, output.contains("version") {
                let components = output.components(separatedBy: " ")
                if let versionIndex = components.firstIndex(of: "version"), versionIndex + 1 < components.count {
                    return components[versionIndex + 1]
                }
            }
            
            return output
        } catch {
            return nil
        }
    }
    
    /// Gets the version of the bundled vt tool (async version for background execution)
    private nonisolated func getBundledVersionAsync() async -> String? {
        guard let vtPath = Bundle.main.path(forResource: "vt", ofType: nil) else {
            return nil
        }
        
        let task = Process()
        task.launchPath = vtPath
        task.arguments = ["--version"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse version from output like "vt version 2.0.0"
            if let output = output, output.contains("version") {
                let components = output.components(separatedBy: " ")
                if let versionIndex = components.firstIndex(of: "version"), versionIndex + 1 < components.count {
                    return components[versionIndex + 1]
                }
            }
            
            return output
        } catch {
            return nil
        }
    }

    /// Installs the CLI tool (async version for WelcomeView)
    func install() async {
        await MainActor.run {
            installCLITool()
        }
    }
    
    /// Updates the CLI tool to the bundled version
    func updateCLITool() {
        logger.info("CLIInstaller: Starting CLI tool update...")
        
        // Show update confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Update VT Command Line Tool"
        alert.informativeText = """
        A newer version of the 'vt' command line tool is available.
        
        Installed version: \(installedVersion ?? "unknown")
        Available version: \(bundledVersion ?? "unknown")
        
        Would you like to update it now? Administrator privileges will be required.
        """
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        
        let response = alert.runModal()
        if response != .alertFirstButtonReturn {
            logger.info("CLIInstaller: User cancelled update")
            return
        }
        
        // Proceed with installation (which will replace the existing tool)
        installCLITool()
    }

    /// Installs the vt CLI tool to /usr/local/bin with proper symlink
    func installCLITool() {
        logger.info("CLIInstaller: Starting CLI tool installation...")
        isInstalling = true
        lastError = nil

        guard let resourcePath = Bundle.main.path(forResource: "vt", ofType: nil) else {
            logger.error("CLIInstaller: Could not find vt binary in app bundle")
            lastError = "The vt command line tool could not be found in the application bundle."
            showError("The vt command line tool could not be found in the application bundle.")
            isInstalling = false
            return
        }

        let targetPath = "/usr/local/bin/vt"
        logger.info("CLIInstaller: Resource path: \(resourcePath)")
        logger.info("CLIInstaller: Target path: \(targetPath)")

        // Check if symlink already exists
        if FileManager.default.fileExists(atPath: targetPath) {
            let alert = NSAlert()
            alert.messageText = "CLI Tool Already Installed"
            alert
                .informativeText =
                "The 'vt' command line tool is already installed at \(targetPath). Would you like to replace it?"
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response != .alertFirstButtonReturn {
                logger.info("CLIInstaller: User cancelled replacement")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isInstalling = false
                }
                return
            }
        }

        // Show confirmation dialog
        let confirmAlert = NSAlert()
        confirmAlert.messageText = "Install CLI Tool"
        confirmAlert
            .informativeText =
            "This will create a symlink to the 'vt' command line tool in /usr/local/bin, allowing you to use it from the terminal. Administrator privileges are required."
        confirmAlert.addButton(withTitle: "Install")
        confirmAlert.addButton(withTitle: "Cancel")
        confirmAlert.alertStyle = .informational
        confirmAlert.icon = NSApp.applicationIconImage

        let response = confirmAlert.runModal()
        if response != .alertFirstButtonReturn {
            logger.info("CLIInstaller: User cancelled installation")
            isInstalling = false
            return
        }

        // Perform the installation
        performInstallation(from: resourcePath, to: targetPath)
    }

    // MARK: - Private Implementation

    /// Performs the actual symlink creation with sudo privileges
    private func performInstallation(from sourcePath: String, to targetPath: String) {
        logger.info("CLIInstaller: Performing installation from \(sourcePath) to \(targetPath)")

        // Create the /usr/local/bin directory if it doesn't exist
        let binDirectory = "/usr/local/bin"
        let script = """
        #!/bin/bash
        set -e

        # Create /usr/local/bin if it doesn't exist
        if [ ! -d "\(binDirectory)" ]; then
            mkdir -p "\(binDirectory)"
            echo "Created directory \(binDirectory)"
        fi

        # Remove existing symlink if it exists
        if [ -L "\(targetPath)" ] || [ -f "\(targetPath)" ]; then
            rm -f "\(targetPath)"
            echo "Removed existing file at \(targetPath)"
        fi

        # Create the symlink
        ln -s "\(sourcePath)" "\(targetPath)"
        echo "Created symlink from \(sourcePath) to \(targetPath)"

        # Make sure the symlink is executable
        chmod +x "\(targetPath)"
        echo "Set executable permissions on \(targetPath)"
        """

        // Write the script to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("install_vt_cli.sh")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)

            // Make the script executable
            let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: scriptURL.path)

            logger.info("CLIInstaller: Created installation script at \(scriptURL.path)")

            // Execute with osascript to get sudo dialog
            let appleScript = """
            do shell script "bash '\(scriptURL.path)'" with administrator privileges
            """

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", appleScript]

            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe

            try task.run()
            task.waitUntilExit()

            // Clean up the temporary script
            try? FileManager.default.removeItem(at: scriptURL)

            if task.terminationStatus == 0 {
                logger.info("CLIInstaller: Installation completed successfully")
                isInstalled = true
                isInstalling = false
                showSuccess()
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                logger.error("CLIInstaller: Installation failed with status \(task.terminationStatus): \(errorString)")
                lastError = "Installation failed: \(errorString)"
                isInstalling = false
                showError("Installation failed: \(errorString)")
            }
        } catch {
            logger.error("CLIInstaller: Installation failed with error: \(error)")
            lastError = "Installation failed: \(error.localizedDescription)"
            isInstalling = false
            showError("Installation failed: \(error.localizedDescription)")
        }
    }

    /// Shows success message after installation
    private func showSuccess() {
        let alert = NSAlert()
        alert.messageText = "CLI Tool Installed Successfully"
        alert.informativeText = "The 'vt' command line tool has been installed. You can now use 'vt' from the terminal."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.runModal()
    }

    /// Shows error message for installation failures
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CLI Tool Installation Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .critical
        alert.runModal()
    }
}
