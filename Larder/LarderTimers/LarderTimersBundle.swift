//
//  LarderTimersBundle.swift
//  LarderTimers
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI
import WidgetKit

/// Larder's lock-screen extension. It has one job: showing Cook Mode timers
/// as a Live Activity.
@main
struct LarderTimersBundle: WidgetBundle {
    var body: some Widget {
        CookTimerLiveActivity()
    }
}
