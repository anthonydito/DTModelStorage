//
//  SectionModelTestCase.swift
//  DTModelStorageTests
//
//  Created by Denys Telezhkin on 10.07.15.
//  Copyright (c) 2015 Denys Telezhkin. All rights reserved.
//

import UIKit
import XCTest

class SectionModelTestCase: XCTestCase {

    func testSectionModelSupplementaryModelChange()
    {
        var section = SectionModel()
        section.setSupplementaryModel("bar", forKind: "foo")
        
        XCTAssertEqual(section.supplementaryModelOfKind("foo") as? String ?? "", "bar")
        
        section.setSupplementaryModel(nil, forKind: "foo")
        XCTAssert(section.supplementaryModelOfKind("foo") == nil)
    }

}
