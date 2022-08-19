//
//  Uniforms.swift
//  TeapotLighting
//
//  Created by Janie Clayton on 1/26/17.
//  Copyright © 2017 RedQueenCoder. All rights reserved.
//

import Foundation
import simd

struct Uniforms {
    var lightPosition:float4
    var color:float4
    var reflectivity:float3
    var lightIntensity:float3
    var modelViewMatrix:simd_float4x4
    var projectionMatrix:simd_float4x4
}
