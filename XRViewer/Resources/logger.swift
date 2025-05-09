//
//  logger.swift
//  iQ3ConnectXRViewer
//
//  Created by iQ3 on 7/5/25.
//  Copyright © 2025 iQ3Connect. All rights reserved.
//

import Foundation

func DDLogDebug(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    #if DEBUG
    print("DEBUG: \(message())")
    #endif
}

func DDLogError(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    print("ERROR: \(message())")
}

func DDLogWarn(_ message: @autoclosure () -> String, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    print("WARNING: \(message())")
}

