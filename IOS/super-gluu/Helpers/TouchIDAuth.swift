//
//  TouchIDAuth.swift
//  Super Gluu
//
//  Created by Eric Webb on 3/8/18.
//  Copyright © 2018 Gluu. All rights reserved.
//

import UIKit
import LocalAuthentication


@objc class TouchIDAuth: NSObject {
    
    let context = LAContext()
    
    func canEvaluatePolicy() -> Bool {
        
        if (context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)) {
            
            if #available(iOS 11.0, *) {
                
                if (context.biometryType == .touchID) {
                    return true
                }
                
            } else {
                return true
            }
            
        } else {
            return false
        }
        
        return false
    }
    
    
    func authenticateUser(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard canEvaluatePolicy() else {
            return
        }
        
        let reason = "Identify yourself!"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) {
            [unowned self] success, authenticationError in
            
            DispatchQueue.main.async {
                if success {
                    completion(success, nil)
                    //                    self.runSecretCode()
                } else {
                    
                    let message: String
                    
                    switch authenticationError {
                        
                    case LAError.authenticationFailed?:
                        message = "There was a problem verifying your identity."
                    case LAError.userCancel?:
                        message = "You pressed cancel."
                    case LAError.userFallback?:
                        message = "You pressed password."
                    default:
                        message = "Touch ID may not be configured"
                    }
                    
                    completion(false, message)
                    
                }
            }
        }
    }
}
