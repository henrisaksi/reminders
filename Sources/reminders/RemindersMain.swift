import Foundation

@main
enum RemindersMain {
  static func main() async {
    let code = await CommandRouter().run()
    exit(code)
  }
}
