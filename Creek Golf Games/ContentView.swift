import SwiftUI

struct ContentView: View {
    /// The bundled web app, or `nil` if `index.html` hasn't been added to the target.
    private let indexURL = Bundle.main.url(forResource: "index", withExtension: "html")

    var body: some View {
        if let indexURL {
            WebAppView(fileURL: indexURL)
        } else {
            ContentUnavailableView(
                "Game Not Found",
                systemImage: "flag.slash",
                description: Text("Add index.html to the Creek Golf Games target.")
            )
        }
    }
}

#Preview {
    ContentView()
}
