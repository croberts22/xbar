
do {
    let controller: ProjectController = try ProjectController()
    controller.run()
}
catch let exception {
    print("An exception was thrown while trying to run dgraph: \(exception)")
}
