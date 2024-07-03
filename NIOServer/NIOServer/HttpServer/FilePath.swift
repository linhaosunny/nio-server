//
//  FilePath.swift
//  NIOServer
//
//  Created by lishaxin on 2024/6/17.
//

import UIKit

public enum FilePath {
    
    case mainBundle
    case sandbox(Foundation.URL)
    
    public enum ScriptType: String {
        case js
    }
    
    public enum FileType: String {
        case txt
        case doc
        case realm
        case p12
    }
    
    public var URL: Foundation.URL? {
        switch self {
        case .mainBundle        : return nil
        case .sandbox(let path) : return path
        }
    }
    
    public func plistPath(name: String) -> String? {
        return filePath(name: name, ofType: "plist")
    }
    
    public func jsonPath(name: String) -> String? {
        return filePath(name: name, ofType: "json")
    }
    
    public func scriptPath(name: String, type: ScriptType) -> String? {
        return filePath(name: name, ofType: type.rawValue)
    }
    
    public func filePath(name: String, type: FileType) -> String? {
        return filePath(name: name, ofType: type.rawValue)
    }
    
    func filePath(name: String, ofType type: String) -> String? {
        switch self {
        case .mainBundle:
            return Bundle.main.path(forResource: name, ofType: type)
        case .sandbox(let path):
            let name = name.hasSuffix(".\(type)") ? name : "\(name).\(type)"
            let url = path.appendingPathComponent(name)
            return url.path
        }
    }
}

