//
//  XCBuildConfiguration+Extension.swift
//  
//
//  Created by Corey Roberts on 8/6/20.
//

import Foundation
import XcodeProj

extension XCBuildConfiguration {
    
    var targetName: String {
        
        if let name = buildSettings["TARGET_NAME"] as? String {
            return name
        }
        
        if let name = buildSettings["PRODUCT_NAME"] as? String {
            return name
        }
        
        return ""
    }
    
}
