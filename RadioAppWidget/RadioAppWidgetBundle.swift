//
//  RadioAppWidgetBundle.swift
//  RadioAppWidget
//
//  Created by longhai on 2026/2/14.
//

import WidgetKit
import SwiftUI

@main
struct RadioAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        RadioAppWidget()
        RadioAppWidgetControl()
        #if !targetEnvironment(macCatalyst)
        RadioAppWidgetLiveActivity()
        #endif
    }
}
