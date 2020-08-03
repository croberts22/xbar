
do {
    let controller: ProjectController = try ProjectController()
//    let controller: ProjectController = try ProjectController(arguments: CommandLine.arguments)
    controller.run()
}
catch let exception {
    print("An exception was thrown while trying to run dgraph: \(exception)")
}
