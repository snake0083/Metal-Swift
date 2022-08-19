//
//  TeapotLightingTests.swift
//  TeapotLightingTests
//
//  Created by snake solid on 2022/8/9.
//  Copyright © 2022 RedQueenCoder. All rights reserved.
//

import XCTest
import simd
@testable import TeapotLighting

class TeapotLightingTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMatrixExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        
        // test translation matrix
        let position:simd_float4 = simd_float4(0,0,3,1)
        let modMatrix = matrix4x4_translation(0,0,100)
        let outtpos = modMatrix*position
        XCTAssertEqual(outtpos, simd_float4(0,0,103,1))
        
        // test rotation matrix
        let rotMatrix = matrix4x4_rotation(radians: 0, axis: simd_float3(0,1,0))
        XCTAssertEqual(rotMatrix, matrix_identity_float4x4)
        
        let outtrpos = rotMatrix*modMatrix*position
        XCTAssertEqual(outtrpos, simd_float4(0,0,103,1))
        
        // test project matrix
        let screenRect = UIScreen.main.bounds
        let aspect = Float32(screenRect.size.width) / Float32(screenRect.size.height)
        let projMatrix = matrix_perspective_right_hand(fovyRadians:radians_from_degrees(60),aspectRatio: aspect,nearZ: 0.1, farZ: 100.0)
        
        let position2:simd_float4 = simd_float4(0,0,-99,1)
        let outppos = projMatrix*position2
        print(outppos)
        XCTAssertTrue(outppos.x/outppos.w < 1 && outppos.x/outppos.w > -1, "outppos \(outppos)")
        XCTAssertTrue(outppos.y/outppos.w < 1 && outppos.y/outppos.w > -1, "outppos \(outppos)")
        XCTAssertTrue(outppos.z/outppos.w < 1 && outppos.z/outppos.w > -1, "outppos \(outppos)")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
