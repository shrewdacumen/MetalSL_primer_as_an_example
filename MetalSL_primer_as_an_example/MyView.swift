//
//  MyView.swift
//  metaltest1
//
//  Created by sungwook on 1/22/19.
//  Copyright © 2019 Sungwook Kim. All rights reserved.
//

import Foundation
import UIKit

class MyView: UIView {
    class override var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
}
