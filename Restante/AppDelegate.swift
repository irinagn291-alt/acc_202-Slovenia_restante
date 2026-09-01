import UIKit
import Alamofire

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        APIConfig.apply()
        if let parchment = UIColor(named: "background") {
            UIWindow.appearance().backgroundColor = parchment
        }
        return true
    }
}
