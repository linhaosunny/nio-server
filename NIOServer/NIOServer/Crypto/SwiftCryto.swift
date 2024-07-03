//
//  SwiftCryto.swift
//  NIOServer
//
//  Created by lishaxin on 2024/7/3.
//

import Foundation
import CryptoSwift

let aesKey = "123456789"

let ivKey =  "abcdefgh"

extension Data {

    /// Array of UInt8
    var bytes: [UInt8] {
        let bytes: [UInt8] = self.withUnsafeBytes {
            Array($0.bindMemory(to: UInt8.self))
        }
        return bytes
    }

    var md5: String {
        return self.md5().toHexString()
    }
}

extension String {
    
    var base64SafeUrlText: String {
        // 兼容 base64 safe URL模式
        var base64Str = self
        base64Str = base64Str.replacingOccurrences(of: "-", with: "+")
        base64Str = base64Str.replacingOccurrences(of: "_", with: "/")
        let mod4 = base64Str.count % 4
        if mod4 > 0 {
            let full = "===="
            let endIndex = full.index(full.startIndex, offsetBy: 4-mod4)
            let wantStr = String(full[..<endIndex])
            base64Str.append(wantStr)
        }
        
        return base64Str
    }
    
    public var encrypt: String {
        return SwiftCrypto.encrypt(plaintext: self, key: aesKey, iv: ivKey)
    }

    public var decrypt: String? {
        return SwiftCrypto.decrypt(ciphertext: self, key: aesKey, iv: ivKey)
    }
}

struct SwiftCrypto {

    static func encrypt(plaintext: String, key: String, iv: String) -> String {
        let ps = plaintext.data(using: .utf8)?.bytes ?? []

        var encrypted: [UInt8] = []

        do {
            encrypted = try AES.init(key: key, iv: iv, padding: .pkcs7).encrypt(ps)
        } catch {
            logger.error(error)
        }

        let encoded = Data(encrypted)

        // 加密结果要用Base64转码
        return encoded.base64EncodedString(options: Data.Base64EncodingOptions.endLineWithLineFeed)
    }

    static func decrypt(ciphertext: String, key: String, iv: String) -> String? {

        // decode base64
        let data = Data(base64Encoded: ciphertext.base64SafeUrlText, options: Data.Base64DecodingOptions())

        guard let encrypted = data?.bytes else {
            return nil
        }

        var decrypted: [UInt8] = []

        do {

            decrypted = try AES.init(key: key, iv: iv, padding: .pkcs7).decrypt(encrypted)
        } catch {
            logger.error(error)
        }

        let encoded = Data(decrypted)

        // 解密结果要从Base64转码回来
        return String(data: encoded, encoding: .utf8)
    }
}


