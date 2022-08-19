//
//  GameViewController.swift
//  TeapotLighting
//
//  Created by Janie Clayton on 1/20/17.
//  Copyright © 2017 RedQueenCoder. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import simd

let MaxBuffers = 3
let ConstantBufferSize = 1024*1024
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100
let maxBuffersInFlight = 3

class GameViewController:UIViewController, MTKViewDelegate {
    
    var device: MTLDevice!
    var meshes: (modelIOMeshes:[MDLMesh],metalKitMeshes:[MTKMesh])!
    var dynamicUniformBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    let vertexDescriptor = MTLVertexDescriptor()
    var pipelineState: MTLRenderPipelineState!
    var diffuseTextre: MTLTexture!
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>!
    
    var cameraPosition: simd_float3 = simd_float3(0,0,-1000.0)
    
    var rotationAngle: Float = 0
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        guard device != nil else { // Fallback to a blank UIView, an application could also fallback to OpenGL ES here.
            print("Metal is not supported on this device")
            self.view = UIView(frame: self.view.frame)
            return
        }

        // setup view properties
        let view = self.view as! MTKView
        view.device = device
        view.delegate = self
        
        loadAssets()
        initializeAssets()
    }
    
    func loadAssets() {
        
        // load any resources required for rendering
        let view = self.view as! MTKView
        commandQueue = device.makeCommandQueue()
        commandQueue.label = "main command queue"
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "lightingFragment")!
        let vertexProgram = defaultLibrary.makeFunction(name: "lightingVertex")!
        
        
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].format = MTLVertexFormat.float3 // position
        vertexDescriptor.attributes[1].offset = 12
        vertexDescriptor.attributes[1].format = MTLVertexFormat.float3 // Vertex normal
        vertexDescriptor.layouts[0].stride = 24
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineStateDescriptor.sampleCount = view.sampleCount
        pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            try pipelineState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            print("Failed to create pipeline state, error \(error)")
        }
        
        /*if let textureUrl =  URL(string: "ColorMap")
        {
            let textureLoader = MTKTextureLoader(device:device)
            do{
                diffuseTextre = try textureLoader.newTexture(URL: textureUrl, options: nil)
            }catch _ {
                print("diffuseTexture assignment failed")
            }
        }*/
    }
    
    func initializeAssets() {
        let desc = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        var attribute = desc.attributes[0] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributePosition
        attribute = desc.attributes[1] as! MDLVertexAttribute
        attribute.name = MDLVertexAttributeNormal
        let mtkBufferAllocator = MTKMeshBufferAllocator(device: device!)
        let url = Bundle.main.url(forResource: "Meshes/Temple", withExtension: "obj")
        let asset = MDLAsset(url: url!, vertexDescriptor: desc, bufferAllocator: mtkBufferAllocator)
        
        do {
            meshes = try MTKMesh.newMeshes(asset: asset, device: device!)
        }
        catch let error {
            fatalError("\(error)")
        }
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length: uniformBufferSize, options: [MTLResourceOptions.storageModeShared]) else { return }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to: Uniforms.self, capacity: 1)
        
        
        /*let uniform = Uniforms(lightPosition: lightPosition, color: teapotColor, reflectivity: reflectivity, lightIntensity: intensity, projectionMatrix: projectionMatrix, modelViewMatrix: modelViewMatrix)
        let uniforms = [uniform]
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
        memcpy(uniformBuffer.contents(), uniforms, MemoryLayout<Uniforms>.size)*/
    }

    private func updateDynamicBufferState(){
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()+uniformBufferOffset).bindMemory(to: Uniforms.self, capacity: 1)
    }
    
    private func updateGameState(){
        // Vector Uniforms
        let teapotColor = float4(0.7, 0.47, 0.18, 1.0)
        let lightPosition = float4(5.0, 5.0, 2.0, 1.0)
        let reflectivity = float3(1.0, 1.0, 1.0)
        let intensity = float3(2.0, 2.0, 2.0)
        
        // Matrix Uniforms
        //cameraPosition += simd_float3(x:0,y:0,z:-0.01)
        let cameraViewMatrix = matrix4x4_translation(cameraPosition.x, cameraPosition.y, cameraPosition.z)
        let templeRotationMatrix = matrix4x4_rotation(radians:rotationAngle,axis:simd_float3(0,1,0))
        let templeTranslationMatrix = matrix4x4_translation(0, -200, 0)
        let templeModelMatrix = templeRotationMatrix*templeTranslationMatrix
        let templeModelViewMatrix = cameraViewMatrix*templeModelMatrix
        
        let aspect = Float32(self.view.bounds.width) / Float32(self.view.bounds.height)
        
        let projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(60), aspectRatio: aspect, nearZ: 0.1, farZ: 5000.0)
        
        uniforms[0].color = teapotColor
        uniforms[0].lightPosition = lightPosition
        uniforms[0].reflectivity = reflectivity
        uniforms[0].lightIntensity = intensity
        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].modelViewMatrix = templeModelViewMatrix
        
        rotationAngle += 0.01
    }
    
    func draw(in view: MTKView) {
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "Frame command buffer"
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            // Generate render pass descriptor
            if let renderPassDescriptor = view.currentRenderPassDescriptor,let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor){
                renderEncoder.label = "render encoder"
                
                renderEncoder.setCullMode(MTLCullMode.back)
                renderEncoder.pushDebugGroup("draw teapot")
                renderEncoder.setRenderPipelineState(pipelineState)
                let mesh:MTKMesh = meshes.metalKitMeshes.first!
                let vertexBuffer = mesh.vertexBuffers[0]
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index:1)
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset: uniformBufferOffset, index: 0)
                renderEncoder.setFragmentTexture(diffuseTextre, index: 0)
                let submesh = mesh.submeshes.first!
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
                    
                if let currentDrawable = view.currentDrawable {
                    commandBuffer.present(currentDrawable)
                }
            }
            commandBuffer.addCompletedHandler({(commandBuffer:MTLCommandBuffer)->Void in
                if commandBuffer.status == .error {
                    self.handleMetalCommandBufferFailure(completedBuffer:commandBuffer)
                }
            })
            commandBuffer.commit()
        }
    }
    
    func handleMetalCommandBufferFailure( completedBuffer:MTLCommandBuffer) {
        if let error = completedBuffer.error as NSError? {
            if error.domain == MTLCommandBufferErrorDomain {
                handleMetalCommandBufferError(completedBuffer: completedBuffer)
            } else {
                reportMetalCommandBufferFailure(completedBuffer: completedBuffer, errorType: "UnKnown")
            }
        }
    }
    
    func handleMetalCommandBufferError( completedBuffer: MTLCommandBuffer) {
        if let error = completedBuffer.error as? MTLCommandBufferError{
            
            switch error.code {
            case .none:
                print("none")
            case .`internal`:
                print("internal")
            case .timeout:
                print("timeout")
            case .pageFault:
                print("pageFault")
            case .blacklisted:
                print("blacklisted")
            case .notPermitted:
                print("notPermitted")
            case .outOfMemory:
                print("outOfMemory")
            case .invalidResource:
                print("invalidResource")
            case .memoryless:
                print("memoryless")
            default:
                print("default")
            }
        }
    }
    
    func reportMetalCommandBufferFailure( completedBuffer: MTLCommandBuffer, errorType: String) {
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
