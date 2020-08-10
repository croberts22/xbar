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
    case arm64, arm64e, armv7, armv7s, armv6, armv8
}

typealias ProjectPathTuple = (project: XcodeProj, path: String)

/// A controller that handles translating Xcode project paths to useable data.
final class ProjectController: Controller {
    
    // MARK: - Properties
    
    private(set) var allTargets: [PBXNativeTarget] = []
    private let arguments: [String]
    private let projects: [ProjectPathTuple]
    
    // FIXME: This is static, but we could adjust this to be dynamic based on user input.
    private let acceptableDeploymentVersion: String = "11.0"
    
    // MARK: - Initializers
    
    init() throws {
        arguments = []
        
        let allCarthageProjectsCommand: String = "find Carthage/Checkouts -type d -name \"*xcodeproj\" -print"
        
        print("No arguments found, automatically looking for project files in Carthage/Checkouts using the following command:")
        print("$ \(allCarthageProjectsCommand)\n")
        
        let output: String = try shellOut(to: ShellOutCommand(string: allCarthageProjectsCommand))
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
        print("Removing architectures `\(architectures.map { $0.rawValue }.joined(separator: ", "))` from \(projects.count) projects...\n")
        projects.forEach { project in
            print("Reading project: \(project.path)")
            var shouldSave: Bool = false
            
            shouldSave = updateDeploymentTarget(to: acceptableDeploymentVersion, for: project)
            shouldSave = exclude(architectures: architectures, for: project) || shouldSave
            
            if shouldSave {
                save(tuple: project)
            }
        }
        
        print("\nDone! Now use the following command to rebuild your workspace:")
        print("$ carthage build --cache-builds --platform iOS,watchOS")
    }
    
    // MARK: - Private Methods
    
    private func updateDeploymentTarget(to version: String, for tuple: ProjectPathTuple) -> Bool {
        
        let project: XcodeProj = tuple.project
        var shouldSave: Bool = false
        
        for configuration in project.pbxproj.buildConfigurations {
            shouldSave = updateDeploymentTarget(to: version, for: configuration) || shouldSave
        }
        
        return shouldSave
    }
    
    private func exclude(architectures: [Architecture], for tuple: ProjectPathTuple) -> Bool {
        
        let project: XcodeProj = tuple.project
        var shouldSave: Bool = false
        
        print("Adding excluded architectures for \"\(tuple.path)\"...")
        project.pbxproj.buildConfigurations.forEach { configuration in
            architectures.forEach { architecture in
                shouldSave = updateValidArchsIfNeeded(for: configuration)
                shouldSave = updateExcludedArchsIfNeeded(adding: architectures, for: configuration)
            }
            
        }
        
        return shouldSave
    }
    
    private func updateValidArchsIfNeeded(for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false

        if let validArchitectures = configuration.buildSettings["VALID_ARCHS"] as? String, validArchitectures.count > 0 {
            print("Found existing deprecated `VALID_ARCHS` for \(configuration.name), clearing these out")
            configuration.buildSettings["VALID_ARCHS"] = ""
            shouldSave = true
        }
        
        return shouldSave
    }
    
    private func updateDeploymentTarget(to version: String, for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false
        
        if let deploymentTarget = configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String, deploymentTarget != version {
            print("Updating iOS deployment target to \(version) for \(configuration.targetName) (\(configuration.name))...")
            configuration.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] = version
            shouldSave = true
        }
        
        return shouldSave
    }
    
    private func updateExcludedArchsIfNeeded(adding architectures: [Architecture], for configuration: XCBuildConfiguration) -> Bool {
        
        var shouldSave: Bool = false
        
        func add(architecture: Architecture, toCurrentSetting settings: inout String) -> Bool {
            if settings.contains(architecture.rawValue) == false {
                settings.append(" \(architecture)")
                return true
            }
            
            return false
        }
        
        var projectExcludedArchs: String = configuration.buildSettings["EXCLUDED_ARCHS"] as? String ?? ""
        
        architectures.forEach { architecture in
            shouldSave = add(architecture: architecture, toCurrentSetting: &projectExcludedArchs) || shouldSave
        }
        
        print("Updated values for `EXCLUDED_ARCHS` for \(configuration.targetName) (\(configuration.name)).")
        
        return shouldSave
    }
    
    private func save(tuple: ProjectPathTuple) {
        do {
            try tuple.project.write(path: Path(tuple.path))
            print("Saved changes for \(tuple.path).")
        }
        catch let exception {
            print("An exception occurred while trying to save changes: \(exception)")
        }
    }
    
}
