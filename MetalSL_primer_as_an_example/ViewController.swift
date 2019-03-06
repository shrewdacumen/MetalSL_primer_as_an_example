//
//  ViewController.swift
//  metaltest1
//
//  Created by sungwook on 1/22/19.
//  Copyright © 2019 Sungwook Kim. All rights reserved.
//

import UIKit
import Metal
import QuartzCore

enum ErrorMessage: Error {
    case memory_run_out
    case device_error
    case unable_to_create_buffer
    case unable_to_create_library
    case unable_to_create_vertex_func
    case unable_to_create_fragment_func
    case unable_to_create_pipelinestate
    case unable_to_create_commandQueue
    case unable_to_create_commandBuffer
}

//
// Plan B : looks better
// pre-validation object MPSPrevalidatedPart
//
//  The following objects are not transient. Reuse these objects in performance sensitive code, and avoid creating them repeatedly.
//
//  Libraries
//  Command queues
//  Data buffers
//  Textures
//  Sampler states
//  Depth/stencil states
//  Compute states
//  Render pipeline states
class MTSPrevalidatedPart {
    
    //  * convenience properties
    let metalLayer: CAMetalLayer // this will be replaced by the corresponding function of MTLView
    let renderPassDescriptor: MTLRenderPassDescriptor
    
    let pipelineDescriptor: MTLRenderPipelineDescriptor // (it needs to confirm that this statement is right!) ???expensive to set up & this may NOT be necessary for later use.
    
    //  * properties are NOT transient:
    let device: MTLDevice
    //  .makeBuffer()
    //  .makeDefaultLibrary() -> MTLDefaultLibrary?
    //  try .makeRenderPipelineState() throws -> MTLRenderPipelineState
    //  .makeCommandQueue() -> MTLCommandQueue?
    //
    let defaultLibrary: MTLLibrary // this may NOT be necessary for later use.
    var vertexBuffer: MTLBuffer // A memory allocation for storing unformatted data that is accessible to the GPU.
    // var texture: MTLTexture
    // var sampler: MTLSampler
    let pipelineState: MTLRenderPipelineState // *1* expensive to set up
    let commandQueue: MTLCommandQueue // *2* expensive to set up
    //  .makeCommandBuffer() -> MTLCommandBuffer? , being created every render pass
    //
    //  And then
    //  MTLCommandBuffer?
    //      .makeRenderCommandEncoder() -> MTLRenderCommandEncoder? , being created every render pass
    //
    
    
    
    init(view: UIView) throws {
        
        // 1. create device by *** MTLCreateSystemDefaultDevice() ***
        guard let device = MTLCreateSystemDefaultDevice() else {
            // What I learned from 'guard let else' triad:
            // guard retains out of the scope else clause defines an instance created by let command.
            throw ErrorMessage.device_error
        }
        self.device = device
        
        // 2. create a metalLayer by *** CAMetalLayer() ***
        self.metalLayer = CAMetalLayer()
        
        // 3. add the metalLayer to view.layer as sublayer after setting it up.
        self.metalLayer.device = self.device
        self.metalLayer.pixelFormat = .bgra8Unorm
        self.metalLayer.framebufferOnly = true
        self.metalLayer.frame = view.layer.frame
        //        view.layer = metalLayer // Cannot assign to property: 'layer' is a get-only property
        view.layer.addSublayer(metalLayer)
        
        // 4. make MTLBuffer? object and get it persistent through self.vertexBuffer
        let vertexData: [Float] = [
            0.0, 0.5, 0.0,
            -0.5, -0.5, 0.0,
            0.5, -0.5, 0.0]
        let dataSize = vertexData.count * MemoryLayout.size(ofValue:vertexData[0])
        guard let vertexBuffer = self.device.makeBuffer(bytes: vertexData, length: dataSize, options: []) else {
//guard let vertexBuffer = self.device.makeBuffer(bytes: vertexData, length: dataSize, options:.storageModePrivate) else { --> gives me an error!
            throw ErrorMessage.unable_to_create_buffer
        }
        self.vertexBuffer = vertexBuffer
        
        // 5. create defaultLibrary from self.device.makeDefaultLibrary()
        guard let defaultLibrary = self.device.makeDefaultLibrary() else {
            throw ErrorMessage.unable_to_create_library
        }
        self.defaultLibrary = defaultLibrary
        
        // 6. add vertex and fragment functions to defaultLibrary.
        guard let vertexFunc = self.defaultLibrary.makeFunction(name: "basic_vertex") else {
            assert(false, "GPU device couldn't create a basic_vertex()")
            throw ErrorMessage.unable_to_create_vertex_func
        }
        guard let fragmentFunc = self.defaultLibrary.makeFunction(name: "basic_fragment") else {
            assert(false, "GPU device couldn't create a basic_frament()")
            throw ErrorMessage.unable_to_create_fragment_func
        }
        
        // 7. create pipelineDescriptor from *** MTLRenderPipelineDescriptor() *** and then set it up.
        // setting up MTLRenderPiplelineDescriptor for creating a prevalidated MTLRenderPipelineState
        // , which is expensive to set up
        self.pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // 8. create pipelineState by 'try device.makeRenderPipelineState(descriptor: pipelineDescriptor)' from device with the argument pipelinedescriptor
        do {
            // The final phase of prevalidation of state is 'makeRenderPipelineState' taking a MTLRenderPipelineDescriptor object which was already set up.
            // which is a RenderPipelineState
            // , which is ** expensive to set up **
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            print("failed to create pipeline state with an error \(error)")
            throw ErrorMessage.unable_to_create_pipelinestate
        }
        
        
        // 9. create the expensive object 'commandQueue' from device by device.makeCommandQueue()
        // commandQueue
        // , which is ** expensive to set up **
        guard let commandQueue =  device.makeCommandQueue() else {
            throw ErrorMessage.unable_to_create_commandQueue
        }
        self.commandQueue = commandQueue
        
        
        // 10. create renderpassdescriptor by *** MTLRenderPassDescriptor(), which means that creating a renderpassdescriptor is not expensive. ????
        //  * Typically, you create a MTLRenderPassDescriptor object once and reuse it each time your app renders a frame. See Creating a Render Pass Descriptor.
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        
    }
    
}

class ViewController: UIViewController {

    
    var prevalidatedPart: MTSPrevalidatedPart! = nil
    var timer:CADisplayLink!
    
/*
//  Plan A : Putting all prevalidation of MTLRenderPipelineState into 2 designated initializers of 'ViewController' looks ugly!
     
    override init(nibName: String?, bundle: Bundle?) {
     
     guard let device = MTLCreateSystemDefaultDevice() else {
     // What I learned from 'guard let else' triad:
     // guard retains out of the scope else clause defines an instance created by let command.
     assert(false, "GPU device couldn't be created")
     throw ErrorMessage.device_error
     }
     ... many more after this!
     
     
        // If I use ViewController's initializer to setup device,
        // I need to set up device doubly here and there.
        super.init(nibName: nibName, bundle:bundle)
        
        
    }
    required init?(coder aDecoder: NSCoder) {
     
     guard let device = MTLCreateSystemDefaultDevice() else {
     // What I learned from 'guard let else' triad:
     // guard retains out of the scope else clause defines an instance created by let command.
     assert(false, "GPU device couldn't be created")
     throw ErrorMessage.device_error
     }
     ... many more after this!
     
     
        // If I use ViewController's initializer to setup device,
        // I need to set up device doubly here and there.
        super.init(coder: aDecoder)
 
    }
*/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        do {
            self.prevalidatedPart = try MTSPrevalidatedPart(view: self.view)
        } catch ErrorMessage.device_error {
            print("GPU device couldn't be created")
        } catch ErrorMessage.unable_to_create_buffer {
            print("GPU device couldn't create a buffer")
        } catch ErrorMessage.unable_to_create_library {
            print("GPU device couldn't create a library")
        } catch ErrorMessage.unable_to_create_vertex_func {
            print("GPU device couldn't create a basic_vertex()")
        } catch let error {
            print("error message = \(error)")
            return
        }
        
        timer = CADisplayLink(target: self, selector: #selector(ViewController.gameLoop))
        timer.add(to: RunLoop.main, forMode: .`default`)
    }
    
    
    @objc func gameLoop() {
        
        self.render()
        
    }
    
    // for render pass, being called every frame of rendering.
    func render() {
        
        // Unsolved Question:
        //                      why can not it be thrown for
        //                      func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result?
        autoreleasepool { // in order to release drawable from memory after its use.
            
            // 1. get drawable from metalLayer
            guard let drawable = prevalidatedPart.metalLayer.nextDrawable() else {
                // why can not it be thrown for func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result
                //          throw ErrorMessage.memory_run_out
                
                print("memory run out")
                return
            }
            prevalidatedPart.renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            prevalidatedPart.renderPassDescriptor.colorAttachments[0].loadAction = .clear
//            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 221.0/255.0, green: 160.0/255.0, blue: 221.0/255.0, alpha: 1.0) // the same as in the book
            prevalidatedPart.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 221.0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 1.0) // RED
            
            // 2. create commandBuffer from the prevalidated commandQueue
            //
            //  * Command buffer and command encoder objects are transient and designed for a single use. They are very inexpensive to allocate and deallocate, so their creation methods return autoreleased objects.
            //  * Command buffers are transient single-use objects and do not support reuse.
            guard let commandBuffer = self.prevalidatedPart.commandQueue.makeCommandBuffer() else {
                print("error in creating commandBuffer")
                return
            }
            
            // 3. create renderCommandEncoder by the commandBuffer, which means that the created renderCommandEncoder is subject to the commandBuffer
            //
            // a renderCommandEncoder (or a commandEncoder) is created from commandBuffer, which is, in turn, having 'argument tables',also which shader gets all the data passing through directly from the main program.
            //
            //  * Command buffer and command encoder objects are transient and designed for a single use. They are very inexpensive to allocate and deallocate, so their creation methods return autoreleased objects.  However, for some cases indirect command buffers (ICB), which enable you to store repeated commands for later use is very useful depending on the circumstance.
            guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: prevalidatedPart.renderPassDescriptor) else {
                print("error in creating renderCommandEncoder")
                return
            }
            
            // 4. setting up renderCommandEncoder with argument table which contains renderpiplelinestate, buffer, texture, sampler, which is the task of command encoding.
            //
            //  The following encoding prevalidated pipelineState as MTLRenderPipelineState for this command buffer!
            renderCommandEncoder.setRenderPipelineState(self.prevalidatedPart.pipelineState)
            //  The following encoding self.prevalidatedPart.vertexBuffer as "VertexBuffer": until here it was not a vertex buffer.
            //  * index:0 indicates [[buffer(0)]] in vertex function.
            renderCommandEncoder.setVertexBuffer(self.prevalidatedPart.vertexBuffer, offset: 0, index: 0) // note index:0
            // The following encoding "drawPrimitives()"
            renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            //  * When you finish encoding, call the endEncoding method of the command encoder, and a new command encoder object can then begin encoding commands to the command buffer
            //  * To paraphrase this, .endEncoding() on the renderCommandEncoder ensure that only single MTLCommandEncoder is running so that I don't have any necessity to create a grand central dispatch function to do this, for MTLCommandEncoder can only run across MTLCommandQueue!
            renderCommandEncoder.endEncoding()
            
            // 5. present drawable by commandBuffer
            commandBuffer.present(drawable)
            
            // 6. As final, commit commandBuffer containing the encodedCommand.
            commandBuffer.commit()
            
            //
            // just testing a throwing trailing closure, created 2nd command buffer for this test only!
            test_throwing {
                // @DiscardableResult  //   Caveat: this discards the result returning from a function,
                //                                  not variable itself.
                guard let commandBuffer2 = self.prevalidatedPart.commandQueue.makeCommandBuffer() else {
                    throw ErrorMessage.unable_to_create_commandBuffer
                }
            }
            
            
        }
    }

}

func test_throwing(_ farg:() throws -> Void) {
    do {
        try farg()
    } catch let error {
        print("error = \(error)")
    }
}
