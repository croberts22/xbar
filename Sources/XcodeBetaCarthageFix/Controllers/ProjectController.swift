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
    case armv7, i386
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
        Architecture.allCases.forEach { (architecture) in
            print("Removing architecture \(architecture) from \(projects.count) projects...")
            projects.forEach { remove(architecture: architecture, for: $0) }
        }
        
        print("Done! Now use the following command to rebuild your workspace:")
        print("$ carthage build --cache-builds --platform iOS,watchOS")
    }
    
    // MARK: - Private Methods
    
    private func remove(architecture: Architecture, for tuple: ProjectPathTuple) {
        let project: XcodeProj = tuple.project
        
        print("Reading project: \(tuple.path)")
        for configuration in project.pbxproj.buildConfigurations {
            
            var shouldSave: Bool = false
            
            shouldSave = updateValidArchsIfNeeded(removing: architecture, for: configuration) || updateExcludedArchsIfNeeded(removing: architecture, for: configuration)

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
                print("Removed \(architecture), updated VALID_ARCHS for \(configuration.name): \(validArchitectures)")
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
    
    private func updateExcludedArchsIfNeeded(removing architecture: Architecture, for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false
        
        if var excludedArchs = configuration.buildSettings["EXCLUDED_ARCHS"] as? String, excludedArchs.contains(architecture.rawValue) == false {
            print("Adding \"\(architecture)\" as an excluded archs in EXCLUDED_ARCHS...")
            excludedArchs += " \(architecture)"
            configuration.buildSettings["EXCLUDED_ARCHS"] = excludedArchs
            shouldSave = true
        }
        
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
