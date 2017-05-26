//
//  AppDelegate.swift
//  iOS-FPVDemo-Swift
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        application.isIdleTimerDisabled = true
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
      
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        application.isIdleTimerDisabled = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        application.isIdleTimerDisabled = true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
    }

}

