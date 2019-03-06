//
//  basic_vertices_fragments.metal
//  metaltest1
//
//  Created by sungwook on 1/23/19.
//  Copyright © 2019 Sungwook Kim. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

vertex float4 basic_vertex(const device packed_float3* vertex_array [[ buffer(0) ]], // per-vertex operation
                           unsigned int index [[ vertex_id ]]) {
    return float4(vertex_array[index], 1.0);
}

fragment half4 basic_fragment() { // per-fragment operation
//    return half4( 1.0); // white
    return half4(0.0, 210.0/255.0, 180.0/255.0, 1.0); // bluish green
}
                  

