//
//  WxWApp.swift
//  WxW Watch App
//
//  Created by C Zilla on 6/27/26.
//

import SwiftUI

@main
struct WxW_Watch_AppApp: App {
    // Initialize session on launch so WCSession is ready before ContentView appears
    private let session = WxWSession.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
