//
//  ProjectController.swift
//
//
//  Created by Corey Roberts on 7/20/20.
//

import Foundation
import XcodeProj
import PathKit
import ShellOut


enum Architecture: String, CaseIterable {
    case armv7, armv7s, armv6, armv8
//    case arm64, arm64e, armv7, armv7s, armv6, armv8, i386
//    case arm64_apple_watchos_simulator = "arm64-apple-watchos-simulator"
}

typealias ProjectPathTuple = (project: XcodeProj, path: String)

/// A controller that handles translating Xcode project paths to useable data.
final class ProjectController: Controller {
    
    // MARK: - Properties
    
    private(set) var allTargets: [PBXNativeTarget] = []
    private let arguments: [String]
    private let projects: [ProjectPathTuple]
    
    // MARK: - Initializers
    
    init() throws {
        arguments = []
        let output: String = try shellOut(to: ShellOutCommand(string: "find Carthage/Checkouts -type d -name \"*xcodeproj\" -print"))
        let projectPaths: [String] = output.components(separatedBy: .newlines)
        projects = try projectPaths.compactMap { (path) -> (ProjectPathTuple)? in
            let project: XcodeProj = try XcodeProj(path: Path(path))
            return (project, path)
        }
    }
    
    init(arguments: [String]) throws {
        self.arguments = arguments
        self.projects = try arguments[1...].compactMap { (path) -> (ProjectPathTuple)? in
            let project: XcodeProj = try XcodeProj(path: Path(path))
            return (project, path)
        }
    }
    
    // MARK: - Public Methods
    
    func run() {
        let architectures: [Architecture] = Architecture.allCases
        print("Removing architecture \(architectures) from \(projects.count) projects...")
        projects.forEach { remove(architectures: architectures, for: $0) }
        
        print("Done! Now use the following command to rebuild your workspace:")
        print("$ carthage build --cache-builds --platform iOS,watchOS")
    }
    
    // MARK: - Private Methods
    
    private func remove(architectures: [Architecture], for tuple: ProjectPathTuple) {
        let project: XcodeProj = tuple.project
        
        print("Reading project: \(tuple.path)")
        for configuration in project.pbxproj.buildConfigurations {
            
            var shouldSave: Bool = false
            
            shouldSave = updateExcludedArchsIfNeeded(adding: architectures, for: configuration)
            shouldSave = updateDeploymentTarget(to: "11.0", for: configuration) || shouldSave
            architectures.forEach {
                shouldSave = updateValidArchsIfNeeded(removing: $0, for: configuration) || shouldSave
            }

            if shouldSave {
                save(tuple: tuple, configuration: configuration)
            }
            
        }
        
    }
    
    private func updateValidArchsIfNeeded(removing architecture: Architecture, for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false

        if var validArchitectures = configuration.buildSettings["VALID_ARCHS"] as? String {

            print("Found armv7 in VALID_ARCHS for \(configuration.name): \(validArchitectures)")

            if let range = validArchitectures.range(of: "\(architecture) ") {

                validArchitectures.removeSubrange(range)
                configuration.buildSettings["VALID_ARCHS"] = validArchitectures
                print("Removed \(architecture), updated VALID_ARCHS for \(configuration.buildSettings["TARGET_NAME"] ?? "") (\(configuration.name)): \(validArchitectures)")
                shouldSave = true
            }

            let legacyArchStandardKeys: [String] = ["$(ARCHS_STANDARD)", "$(ARCHS_STANDARD_INCLUDING_64_BIT)"]

            legacyArchStandardKeys.forEach { (key) in
                if validArchitectures.contains(key) {
                    print("Found legacy key \(key) in VALID_ARCHS, updating to use $(ARCHS_STANDARD_64_BIT)...")
                    validArchitectures = "$(ARCHS_STANDARD_64_BIT)"
                    shouldSave = true
                }
            }

        }
        
        return shouldSave
    }
    
    private func updateDeploymentTarget(to version: String, for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false
        
        if let deploymentTarget = configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String, deploymentTarget != version {
            print("Updating iOS deployment target to \(version) for \(configuration.buildSettings["TARGET_NAME"] ?? "") (\(configuration.name))...")
            configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] = version
            shouldSave = true
        }
        
        return shouldSave
    }
    
    private func updateExcludedArchsIfNeeded(adding architectures: [Architecture], for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false
        
//        if configuration.buildSettings["EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200"] != nil {
//            print("No need to update, excluded archs custom variable was found.")
//        }
//        else {
        
        print("Updating EXCLUDED_ARCHS for \(configuration.buildSettings["TARGET_NAME"] ?? "") (\(configuration.name))...")
        configuration.buildSettings["EXCLUDED_ARCHS"] = ""//$(inherited) " + architectures.map { $0.rawValue }.joined(separator: " ")
            shouldSave = true
//        }
        
//        var excludedArchs: String = configuration.buildSettings["EXCLUDED_ARCHS"] as? String ?? ""
//
//        if excludedArchs.contains(architecture.rawValue) == false {
//
//            print("Adding \"\(architecture)\" as an excluded archs in EXCLUDED_ARCHS...")
//            if excludedArchs.isEmpty {
//                excludedArchs = "\(architecture)"
//            }
//            else {
//                excludedArchs += " \(architecture)"
//            }
//
//            configuration.buildSettings["EXCLUDED_ARCHS"] = excludedArchs
//            shouldSave = true
//        }
        
        return shouldSave
    }
    
    private func save(tuple: ProjectPathTuple, configuration: XCBuildConfiguration) {
        do {
            try tuple.project.write(path: Path(tuple.path))
            print("Saved changes for \(configuration.name)")
        }
        catch let exception {
            print("An exception occurred while trying to save changes: \(exception)")
        }
    }
    
}
