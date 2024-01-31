export class Mensa {
  static start(application, configuration = {}) {
    if (!application) {
      application = Application.start()
    }

    this.application = application
    this.application.mensa = {
      configuration: configuration,
    }

    Mensa.setupControllers()
  }

  static setupControllers() {
    const componentControllers = require.context("../app/components/", true, /component_controller\.js$/)

    componentControllers
      .keys()
      .map((key) => {
        // Take the last part (before component_controller) of the path as the name
        const [_, name] = /([^/]+)\/component_controller\.js$/.exec(key)
        return [name, componentControllers(key).default]
      })
      .forEach(([name, controller]) => {
        let identifier = `mensa-${name.replace(/_/g, "-")}`
        this.application.register(identifier, controller)
      })
  }
}