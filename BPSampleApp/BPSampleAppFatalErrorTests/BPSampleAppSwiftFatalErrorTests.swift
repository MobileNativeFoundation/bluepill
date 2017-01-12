//
//  BPSampleAppSwiftFatalErrorTests.swift
//  BPSampleApp
//
//  Created by Keqiu Hu on 11/12/16.
//  Copyright © 2016 LinkedIn. All rights reserved.
//

import UIKit
import XCTest

class BPSampleAppSwiftFatalErrorTests: XCTestCase {
    func testForceUnwrap() {
        let c: Int? = nil
        print(c!)
    }

    func testZPass() {
        XCTAssert(true)
    }

}
