import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let nav = UINavigationBar.appearance()
        nav.barStyle = .black
        nav.barTintColor = Theme.bg
        nav.tintColor = Theme.tint
        nav.isTranslucent = false

        let tab = UITabBar.appearance()
        tab.barStyle = .black
        tab.barTintColor = UIColor(white: 0.09, alpha: 1)
        tab.tintColor = Theme.tint
        tab.isTranslucent = false

        _ = AudioPlayer.shared
        application.beginReceivingRemoteControlEvents()

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.tintColor = Theme.tint
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    /// Lets other apps (Files, Filza "Open in…") hand audio files to Wavebox.
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        Library.importFile(url)
        if scoped { url.stopAccessingSecurityScopedResource() }
        return true
    }
}
